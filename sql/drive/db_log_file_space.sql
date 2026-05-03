-- =============================================================================
-- Database Log File Space Report
-- Shows log file size, usage, and free space per database
-- Generates DBCC SHRINKFILE commands when reuse wait is 'NOTHING'
-- =============================================================================

-- Configurable: percentage of free log space to reclaim (default 50%)
DECLARE @log_reduce_percent INT = 50;

CREATE TABLE #logsize (
    Dbname SYSNAME,
    Log_File_Size_MB DECIMAL(38, 2) DEFAULT(0),
    log_Space_Used_MB DECIMAL(30, 2) DEFAULT(0),
    log_Free_Space_MB DECIMAL(30, 2) DEFAULT(0)
);

-- Collect log file stats for each database using sp_MSforeachdb
INSERT INTO #logsize (Dbname, Log_File_Size_MB, log_Space_Used_MB, log_Free_Space_MB)
EXEC sp_MSforeachdb '
    USE [?];
    SELECT DB_NAME() AS DbName,
        SUM(size) / 128.0 AS Log_File_Size_MB,
        SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)) / 128.0 AS log_Space_Used_MB,
        SUM(size) / 128.0 - SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)) / 128.0 AS log_Free_Space_MB
    FROM sys.database_files
    WHERE type = 1
    GROUP BY type';

SELECT @@SERVERNAME AS [Server],
    l.*,
    CAST((log_Free_Space_MB / NULLIF(Log_File_Size_MB, 0)) * 100 AS DECIMAL(10, 2)) AS [%Free],
    log_reuse_wait_desc,
    -- Generate DBCC SHRINKFILE only when log reuse wait allows (NOTHING)
    CASE
        WHEN log_reuse_wait_desc = 'NOTHING'
            THEN 'USE [' + d.name + N']' + CHAR(13) + CHAR(10) +
                 'DBCC SHRINKFILE (N''' + mf.name + N''' , ' +
                 CAST(CAST(log_Free_Space_MB * @log_reduce_percent / 100 AS BIGINT) AS NVARCHAR(128)) +
                 ');' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    END AS [tsql]
FROM #logsize l
LEFT JOIN sys.databases d ON l.Dbname = d.name
LEFT JOIN sys.master_files mf ON mf.database_id = d.database_id
    AND mf.type = 1  -- Only join to LOG file (fix: was missing type filter)
WHERE d.database_id > 4;  -- Exclude system databases
-- Uncomment to only show databases with LOG files:
-- AND mf.type_desc = 'LOG'

DROP TABLE #logsize;
