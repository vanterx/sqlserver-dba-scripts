-- =============================================================================
-- Database Disk Space Report
-- Shows drive-level free space for each database file
-- Includes target growth calculations to hit a desired free space percentage
-- =============================================================================

-- Configurable target free space percentage (default 15%)
DECLARE @target_p FLOAT = 15;

DECLARE @p1 FLOAT;
DECLARE @p2 FLOAT;

-- p1 = target as decimal, p2 = complement (1 - target)
SET @p1 = @target_p / 100;
SET @p2 = 1 - (@target_p / 100);

WITH D
AS (
    SELECT DISTINCT
        @@SERVERNAME AS ServerName,
        DB_NAME(dovs.database_id) AS DBName,
        mf.physical_name AS PhysicalFileLocation,
        CAST(mf.size AS BIGINT) * 8 / 1048576.0 AS size_GB,        -- File size in GB (BIGINT prevents overflow >2TB)
        type_desc,
        dovs.logical_volume_name AS LogicalName,
        dovs.volume_mount_point AS Drive,
        (CONVERT(INT, dovs.total_bytes / 1048576.0) / 1024) AS Drive_Size_InGB,
        (CONVERT(INT, dovs.available_bytes / 1048576.0) / 1024) AS Drive_Free_Space_Available_InGB,
        CAST(
            (CONVERT(FLOAT, dovs.available_bytes / 1048576.0) / 1024) /
            NULLIF(CONVERT(FLOAT, dovs.total_bytes / 1048576.0) / 1024, 0) * 100
            AS DECIMAL(10, 2)
        ) AS [%_Free],
        -- Calculate how many GB to add to reach target free %
        -- Formula: (total * p1 - free) / p2 = GB to add
        CAST(
            ((((CONVERT(INT, dovs.total_bytes / 1048576.0) / 1024) * @p1) -
              (CONVERT(INT, dovs.available_bytes / 1048576.0) / 1024)) / NULLIF(@p2, 0))
            AS DECIMAL(10, 2)
        ) AS [target_%_add_gb]
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) dovs
    WHERE DB_NAME(dovs.database_id) NOT IN ('master', 'model', 'msdb', 'tempdb')
        --AND type_desc = 'Rows'        -- Uncomment to filter data files only
        --AND dovs.volume_mount_point='' -- Uncomment to filter specific drive
)
SELECT *,
    Drive_Free_Space_Available_InGB + [target_%_add_gb] AS Total_Target_gb
FROM D
ORDER BY Drive_Free_Space_Available_InGB ASC;
GO
