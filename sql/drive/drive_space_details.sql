-- =============================================================================
-- Comprehensive Drive & Database File Space Report
-- Shows per-file breakdown: size, free space, growth settings, auto-grow history
-- Generates commands to fix percent-based growth and shrink log files
-- =============================================================================

SET NOCOUNT ON;

-- =============================================================================
-- CONFIGURABLE PARAMETERS
-- =============================================================================
DECLARE @log_reduce_percent INT = 50;                -- % of free log space to reclaim
DECLARE @target_p FLOAT = 15;                        -- Target free disk space %
DECLARE @p1 FLOAT;
DECLARE @p2 FLOAT;
DECLARE @path NVARCHAR(260);                         -- Default trace path
DECLARE @NewDataFileGrowth VARCHAR(100) = '512MB';   -- New growth setting for data files
DECLARE @NewLogGrowth VARCHAR(100) = '256MB';        -- New growth setting for log files
DECLARE @TempDBNewDataFileGrowth VARCHAR(100) = '1024MB'; -- TempDB data file growth
DECLARE @TempDBNewLogGrowth VARCHAR(100) = '512MB';  -- TempDB log file growth
DECLARE @DTCheck BIT = 0;                            -- 1 = check default trace for growth events

-- Calculate p1 (target ratio) and p2 (complement)
SET @p1 = @target_p / 100;
SET @p2 = 1 - (@target_p / 100);

-- Get default trace path (used for auto-grow event history)
SELECT @path = path
FROM sys.traces
WHERE is_default = 1;

-- =============================================================================
-- TEMP TABLE SETUP
-- =============================================================================

-- Clean up any leftovers
IF OBJECT_ID(N'tempdb..#log_stats') IS NOT NULL
    DROP TABLE #log_stats;

IF OBJECT_ID(N'tempdb..#rows_stats') IS NOT NULL
    DROP TABLE #rows_stats;

IF OBJECT_ID(N'tempdb..#dtrace_growth') IS NOT NULL
    DROP TABLE #dtrace_growth;

-- Default trace auto-grow events (optional, enabled with @DTCheck = 1)
CREATE TABLE #dtrace_growth (
    dbname SYSNAME,
    [FileName] SYSNAME,
    EventClass NVARCHAR(max),
    DT_StartTime DATETIME,
    DT_EndTime DATETIME
);

IF @DTCheck = 1 AND @path IS NOT NULL
BEGIN
    INSERT INTO #dtrace_growth (dbname, [FileName], EventClass, DT_StartTime, DT_EndTime)
    SELECT DatabaseName,
        [FileName],
        CASE EventClass
            WHEN 92 THEN 'ROWS'
            WHEN 93 THEN 'LOG'
        END AS EventClass,
        MAX(StartTime),
        MAX(EndTime)
    FROM sys.fn_trace_gettable(@path, DEFAULT)
    WHERE EventClass IN (92, 93)                    -- 92=Data File Auto Grow, 93=Log File Auto Grow
        AND StartTime > DATEADD(DAY, -1, GETDATE())  -- Last 24 hours
    GROUP BY DatabaseName, [FileName], EventClass;
END;

-- Log file stats per database
CREATE TABLE #log_stats (
    dbname SYSNAME,
    fname SYSNAME,
    log_file_size_mb DECIMAL(38, 2) DEFAULT(0),
    log_space_used_mb DECIMAL(30, 2) DEFAULT(0),
    log_free_space_mb DECIMAL(30, 2) DEFAULT(0)
);

INSERT INTO #log_stats (dbname, fname, log_file_size_mb, log_space_used_mb, log_free_space_mb)
EXEC sp_MSforeachdb '
    USE [?];
    SELECT DB_NAME() AS dbname,
        [name],
        SUM(size) / 128.0 AS log_file_size_mb,
        SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)) / 128.0 AS log_space_used_mb,
        SUM(size) / 128.0 - SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)) / 128.0 AS log_free_space_mb
    FROM sys.database_files
    WHERE type = 1
    GROUP BY type, name';

-- Data file (ROWS) stats per database
CREATE TABLE #rows_stats (
    dbname SYSNAME,
    fname SYSNAME,
    rows_file_size_mb DECIMAL(38, 2) DEFAULT(0),
    rows_space_used_mb DECIMAL(30, 2) DEFAULT(0),
    rows_free_space_mb DECIMAL(30, 2) DEFAULT(0)
);

INSERT INTO #rows_stats (dbname, fname, rows_file_size_mb, rows_space_used_mb, rows_free_space_mb)
EXEC sp_MSforeachdb '
    USE [?];
    SELECT DB_NAME() AS dbname,
        [name],
        SUM(size) / 128.0 AS rows_file_size_mb,
        SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)) / 128.0 AS rows_space_used_mb,
        SUM(size) / 128.0 - SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)) / 128.0 AS rows_free_space_mb
    FROM sys.database_files
    WHERE type = 0
    GROUP BY type, name';

-- =============================================================================
-- MAIN REPORT: Per-file breakdown with drive space, growth, and fix scripts
-- =============================================================================
WITH data1
AS (
    SELECT
        d.name AS dbname,
        mf.name AS db_logical_name,
        mf.physical_name AS physicalfilelocation,
        CAST((mf.size * 8 / 1024) AS DECIMAL(10, 2)) AS size_mb,
        type_desc,
        dovs.logical_volume_name AS logical_volume_name,
        dovs.volume_mount_point AS drive,
        (CONVERT(INT, dovs.total_bytes / 1048576.0) / 1024) AS drive_size_gb,
        (CONVERT(INT, dovs.available_bytes / 1048576.0) / 1024) AS drive_free_space_available_gb,
        CAST(
            (CONVERT(FLOAT, dovs.available_bytes / 1048576.0) / 1024) /
            (CONVERT(FLOAT, dovs.total_bytes / 1048576.0) / 1024) * 100
            AS DECIMAL(10, 2)
        ) AS [disk_free_%],
        -- GB to add to reach target free %
        CAST(
            ((((CONVERT(INT, dovs.total_bytes / 1048576.0) / 1024) * @p1) -
              (CONVERT(INT, dovs.available_bytes / 1048576.0) / 1024)) / @p2)
            AS DECIMAL(10, 2)
        ) AS [target_%_add_gb],
        -- Total drive GB after adding target
        ((CONVERT(INT, dovs.available_bytes / 1048576.0) / 1024)) +
        CAST(
            ((((CONVERT(INT, dovs.total_bytes / 1048576.0) / 1024) * @p1) -
              (CONVERT(INT, dovs.available_bytes / 1048576.0) / 1024)) / @p2)
            AS DECIMAL(10, 2)
        ) AS [drive_total_target_gb],

        -- ROWS (data) file stats
        r.rows_file_size_mb,
        r.rows_space_used_mb,
        r.rows_free_space_mb,
        CAST((r.rows_free_space_mb / NULLIF(r.rows_file_size_mb, 0)) * 100 AS DECIMAL(10, 2)) AS [rows_free_%],
        dt1.DT_StartTime AS rows_dt_starttime,
        dt1.DT_EndTime AS rows_dt_endtime,

        -- LOG file stats
        l.log_file_size_mb,
        l.log_space_used_mb,
        l.log_free_space_mb,
        CAST((l.log_free_space_mb / NULLIF(l.log_file_size_mb, 0)) * 100 AS DECIMAL(10, 2)) AS [log_free_%],
        dt2.DT_StartTime AS log_dt_starttime,
        dt2.DT_EndTime AS log_dt_endtime,

        -- Log reuse wait
        d.log_reuse_wait_desc,

        -- Growth settings
        CASE mf.is_percent_growth
            WHEN 1 THEN 'Yes'
            ELSE 'No'
        END AS [is_percent_growth],
        CASE mf.is_percent_growth
            WHEN 1 THEN CONVERT(VARCHAR, mf.growth) + '%'
            WHEN 0 THEN CONVERT(VARCHAR, mf.growth / 128) + ' MB'
        END AS [growth_in_increment_of],
        CASE mf.is_percent_growth
            WHEN 1 THEN CONVERT(DECIMAL(20, 2), (((CONVERT(DECIMAL, size) * growth) / 100) * 8) / 1024)
            WHEN 0 THEN CONVERT(DECIMAL(20, 2), (CONVERT(DECIMAL, growth) / 128))
        END AS [next_auto_growth_size_mb],

        -- Max file size: show 'UNLIMITED' or MB value
        CONVERT(VARCHAR, CASE
            WHEN mf.max_size = -1 THEN 'UNLIMITED'
            ELSE CONVERT(VARCHAR, CAST(mf.max_size AS BIGINT) * 8 / 1024) + ' MB'
        END) AS [max_size],

        -- DBCC SHRINKFILE command (only when log reuse wait is NOTHING)
        CASE
            WHEN LOWER(d.log_reuse_wait_desc) = 'nothing'
                THEN 'USE [' + d.name + N']' + CHAR(13) + CHAR(10) +
                     'DBCC SHRINKFILE (N''' + mf.name + N''' , ' +
                     CAST(CAST(l.log_free_space_mb * @log_reduce_percent / 100 AS INT) AS NVARCHAR(128)) +
                     ');' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
        END AS [tsql],

        -- ALTER DATABASE command to fix percent-based growth -> fixed MB
        CASE
            -- Non-TempDB log files
            WHEN LOWER(physical_name) LIKE '%.ldf'
                AND LOWER(DB_NAME(mf.database_id)) != 'tempdb'
                THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) +
                     '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' +
                     @NewLogGrowth + ', MAXSIZE = UNLIMITED);'
            -- Non-TempDB data files
            WHEN (LOWER(physical_name) LIKE '%.mdf' OR LOWER(physical_name) LIKE '%.ndf')
                AND LOWER(DB_NAME(mf.database_id)) != 'tempdb'
                THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) +
                     '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' +
                     @NewDataFileGrowth + ', MAXSIZE = UNLIMITED);'
            -- TempDB log files
            WHEN LOWER(physical_name) LIKE '%.ldf'
                AND LOWER(DB_NAME(mf.database_id)) = 'tempdb'
                THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) +
                     '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' +
                     @TempDBNewLogGrowth + ');'
            -- TempDB data files
            WHEN (LOWER(physical_name) LIKE '%.mdf' OR LOWER(physical_name) LIKE '%.ndf')
                AND LOWER(DB_NAME(mf.database_id)) = 'tempdb'
                THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) +
                     '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' +
                     @TempDBNewDataFileGrowth + ');'
            ELSE 'Error - Invalid Option'
        END AS [change_autogrow]
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) dovs
    LEFT JOIN sys.databases d ON mf.database_id = d.database_id
    LEFT JOIN #log_stats l ON l.dbname = d.name
        AND mf.type = 1                 -- Only LOG file rows get log stats
        AND mf.name = l.[fname]
    LEFT JOIN #rows_stats r ON r.dbname = d.name
        AND mf.type = 0                 -- Only ROWS file rows get rows stats
        AND mf.name = r.[fname]
    -- Default trace auto-grow events: join on matching file name
    LEFT JOIN #dtrace_growth dt1 ON dt1.dbname = d.name
        AND dt1.EventClass = 'ROWS'
        AND dt1.[FileName] = mf.name   -- Match trace file name to current master file
    LEFT JOIN #dtrace_growth dt2 ON dt2.dbname = d.name
        AND dt2.EventClass = 'LOG'
        AND dt2.[FileName] = mf.name   -- FIX: was using r.[fname] (NULL for LOG rows)
    WHERE LOWER(d.name) NOT IN ('tempdb', 'master', 'msdb', 'model')
        --AND dovs.volume_mount_point = ''  -- Uncomment to filter specific drive
)
SELECT
    @@SERVERNAME AS [ServerName],
    [dbname],
    [db_logical_name],
    [physicalfilelocation],
    [size_mb],
    [type_desc],
    [logical_volume_name],
    [drive],
    [drive_size_gb],
    [drive_free_space_available_gb],
    [disk_free_%],
    [target_%_add_gb],
    [drive_total_target_gb],
    [rows_file_size_mb],
    [rows_space_used_mb],
    [rows_free_space_mb],
    [rows_free_%],
    [rows_dt_starttime],
    [rows_dt_endtime],
    [log_file_size_mb],
    [log_space_used_mb],
    [log_free_space_mb],
    [log_free_%],
    [log_dt_starttime],
    [log_dt_endtime],
    [log_reuse_wait_desc],
    [is_percent_growth],
    [growth_in_increment_of],
    [next_auto_growth_size_mb],
    [max_size],
    [tsql],
    [change_autogrow]
FROM data1
-- Uncomment to filter only percent-based growth or small increments:
--WHERE RIGHT(RTRIM(growth_in_increment_of), 1) = '%'
--    OR CAST(REPLACE(growth_in_increment_of, ' MB', '') AS FLOAT) < 64
