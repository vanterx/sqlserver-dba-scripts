DECLARE @log_reduce_percent INT = 50;
DECLARE @target_p FLOAT = 15;
DECLARE @p1 FLOAT;
DECLARE @p2 FLOAT;
DECLARE @path NVARCHAR(260);
DECLARE @NewDataFileGrowth VARCHAR(100) = '512MB';
DECLARE @NewLogGrowth VARCHAR(100) = '256MB';
DECLARE @TempDBNewDataFileGrowth VARCHAR(100) = '1024MB';
DECLARE @TempDBNewLogGrowth VARCHAR(100) = '512MB';
DECLARE @DTCheck BIT = 0;

SET @p1 = @target_p / 100;
SET @p2 = 1 - (@target_p / 100);

SELECT @path = path
FROM sys.traces
WHERE is_default = 1;

IF OBJECT_ID(N'tempdb..#log_stats') IS NOT NULL
	DROP TABLE #log_stats;

IF OBJECT_ID(N'tempdb..#rows_stats') IS NOT NULL
	DROP TABLE #rows_stats;

IF OBJECT_ID(N'tempdb..#dtrace_growth') IS NOT NULL
	DROP TABLE #dtrace_growth;

CREATE TABLE #dtrace_growth (
	dbname SYSNAME
	,[FileName] SYSNAME
	,EventClass NVARCHAR(max)
	,DT_StartTime DATETIME
	,DT_EndTime DATETIME
	);

IF @DTCheck = 1
BEGIN
	INSERT INTO #dtrace_growth (
		dbname
		,[FileName]
		,EventClass
		,DT_StartTime
		,DT_EndTime
		)
	SELECT DatabaseName
		,[FileName]
		,CASE EventClass
			WHEN 92
				THEN 'ROWS'
			WHEN 93
				THEN 'LOG'
			END AS EventClass
		,MAX(StartTime)
		,MAX(EndTime)
	FROM sys.fn_trace_gettable(@path, DEFAULT)
	WHERE EventClass IN (
			92
			,93
			)
		AND StartTime > GETDATE() - 1
	GROUP BY DatabaseName
		,[FileName]
		,EventClass;
END

CREATE TABLE #log_stats (
	dbname SYSNAME
	,fname SYSNAME
	,log_file_size_mb DECIMAL(38, 2) DEFAULT(0)
	,log_space_used_mb DECIMAL(30, 2) DEFAULT(0)
	,log_free_space_mb DECIMAL(30, 2) DEFAULT(0)
	);

INSERT INTO #log_stats (
	dbname
	,fname
	,log_file_size_mb
	,log_space_used_mb
	,log_free_space_mb
	)
EXEC sp_MSforeachdb 'use [?]; 
  select db_name() as dbname, [name],
sum(size)/128.0 as log_file_size_mb, 
sum(cast(fileproperty(name, ''spaceused'') as int))/128.0 as log_space_used_mb, 
sum( size)/128.0 - sum(cast(fileproperty(name,''spaceused'') as int))/128.0 as log_free_space_mb  
from sys.database_files  where type=1 group by type,name';

CREATE TABLE #rows_stats (
	dbname SYSNAME
	,fname SYSNAME
	,rows_file_size_mb DECIMAL(38, 2) DEFAULT(0)
	,rows_space_used_mb DECIMAL(30, 2) DEFAULT(0)
	,rows_free_space_mb DECIMAL(30, 2) DEFAULT(0)
	);

INSERT INTO #rows_stats (
	dbname
	,fname
	,rows_file_size_mb
	,rows_space_used_mb
	,rows_free_space_mb
	)
EXEC sp_MSforeachdb 'use [?]; 
  select db_name() as dbname, [name],
sum(size)/128.0 as rows_file_size_mb, 
sum(cast(fileproperty(name, ''spaceused'') as int))/128.0 as rows_space_used_mb, 
sum( size)/128.0 - sum(cast(fileproperty(name,''spaceused'') as int))/128.0 as rows_free_space_mb  
from sys.database_files  where type=0 group by type,name';

WITH data1
AS (
	SELECT d.name dbname
		,mf.name db_logical_name
		,mf.physical_name physicalfilelocation
		,CAST((mf.size * 8 / 1024) AS DECIMAL(10, 2)) size_mb
		,type_desc
		,dovs.logical_volume_name AS logical_volume_name
		,dovs.volume_mount_point AS drive
		,(convert(INT, dovs.total_bytes / 1048576.0) / 1024) AS drive_size_gb
		,(convert(INT, dovs.available_bytes / 1048576.0) / 1024) AS drive_free_space_available_gb
		,cast((convert(FLOAT, dovs.available_bytes / 1048576.0) / 1024) / (convert(FLOAT, dovs.total_bytes / 1048576.0) / 1024) * 100 AS DECIMAL(10, 2)) AS [disk_free_%]
		,cast(((((convert(INT, dovs.total_bytes / 1048576.0) / 1024) * @p1) - (convert(INT, dovs.available_bytes / 1048576.0) / 1024)) / @p2) AS DECIMAL(10, 2)) [target_%_add_gb]
		,((convert(INT, dovs.available_bytes / 1048576.0) / 1024)) + (cast(((((convert(INT, dovs.total_bytes / 1048576.0) / 1024) * @p1) - (convert(INT, dovs.available_bytes / 1048576.0) / 1024)) / @p2) AS DECIMAL(10, 2))) [drive_total_target_gb]
		,r.rows_file_size_mb
		,r.rows_space_used_mb
		,r.rows_free_space_mb
		,cast((r.rows_free_space_mb / r.rows_file_size_mb) * 100 AS DECIMAL(10, 2)) [rows_free_%]
		,dt1.DT_StartTime rows_dt_starttime
		,dt1.DT_EndTime rows_dt_endtime
		,l.log_file_size_mb
		,l.log_space_used_mb
		,l.log_free_space_mb
		,cast((l.log_free_space_mb / l.log_file_size_mb) * 100 AS DECIMAL(10, 2)) [log_free_%]
		,dt2.DT_StartTime log_dt_starttime
		,dt2.DT_EndTime log_dt_endtime
		,d.log_reuse_wait_desc
		,CASE mf.is_percent_growth
			WHEN 1
				THEN 'Yes'
			ELSE 'No'
			END AS [is_percent_growth]
		,CASE mf.is_percent_growth
			WHEN 1
				THEN CONVERT(VARCHAR, mf.growth) + '%'
			WHEN 0
				THEN CONVERT(VARCHAR, mf.growth / 128) + ' MB'
			END AS [growth_in_increment_of]
		,CASE mf.is_percent_growth
			WHEN 1
				THEN CONVERT(DECIMAL(20, 2), (((CONVERT(DECIMAL, size) * growth) / 100) * 8) / 1024)
			WHEN 0
				THEN CONVERT(DECIMAL(20, 2), (CONVERT(DECIMAL, growth) / 128))
			END AS [next_auto_growth_size_mb]
		,CONVERT(VARCHAR, mf.max_size) [max_size]
		,CASE 
			WHEN lower(d.log_reuse_wait_desc) = 'nothing'
				THEN 'USE [' + d.name + N']' + CHAR(13) + CHAR(10) + 'DBCC SHRINKFILE (N''' + mf.name + N''' , ' + CAST(CAST(l.log_free_space_mb * @log_reduce_percent / 100 AS INT) AS NVARCHAR(128)) + ');' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
			END [tsql]
		,CASE 
			WHEN lower(physical_name) LIKE '%.ldf'
				AND lower(DB_NAME(mf.database_id)) != 'tempdb'
				THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @NewLogGrowth + ', MAXSIZE = UNLIMITED);'
			WHEN (
					lower(physical_name) LIKE '%.mdf'
					OR lower(physical_name) LIKE '%.ndf'
					)
				AND lower(DB_NAME(mf.database_id)) != 'tempdb'
				THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @NewDataFileGrowth + ', MAXSIZE = UNLIMITED);'
			WHEN lower(physical_name) LIKE '%.ldf'
				AND lower(DB_NAME(mf.database_id)) = 'tempdb'
				THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @TempDBNewLogGrowth + ');'
			WHEN (
					lower(physical_name) LIKE '%.mdf'
					OR lower(physical_name) LIKE '%.ndf'
					)
				AND lower(DB_NAME(mf.database_id)) = 'tempdb'
				THEN 'USE [master]; ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @TempDBNewDataFileGrowth + ');'
			ELSE 'Error - Invalid Option'
			END AS [change_autogrow]
	FROM sys.master_files mf
	CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) dovs
	LEFT JOIN sys.databases d ON mf.database_id = d.database_id
	LEFT JOIN #log_stats l ON l.dbname = d.name
		AND mf.type = 1
		AND mf.name = l.[fname]
	LEFT JOIN #rows_stats r ON r.dbname = d.name
		AND mf.type = 0
		AND mf.name = r.[fname]
	LEFT JOIN #dtrace_growth dt1 ON dt1.dbname = d.name
		AND dt1.EventClass = 'ROWS'
		AND mf.name = r.[fname]
	LEFT JOIN #dtrace_growth dt2 ON dt2.dbname = d.name
		AND dt2.EventClass = 'LOG'
		AND mf.name = r.[fname]
	WHERE lower(d.name) NOT IN ('tempdb','master','msdb','model')
		--and dovs.volume_mount_point=''
	)
SELECT @@SERVERNAME [ServerName]
	,[dbname]
	,[db_logical_name]
	,[physicalfilelocation]
	,[size_mb]
	,[type_desc]
	,[logical_volume_name]
	,[drive]
	,[drive_size_gb]
	,[drive_free_space_available_gb]
	,[disk_free_%]
	,[target_%_add_gb]
	,[drive_total_target_gb]
	,[rows_file_size_mb]
	,[rows_space_used_mb]
	,[rows_free_space_mb]
	,[rows_free_%]
	,[rows_dt_starttime]
	,[rows_dt_endtime]
	,[log_file_size_mb]
	,[log_space_used_mb]
	,[log_free_space_mb]
	,[log_free_%]
	,[log_dt_starttime]
	,[log_dt_endtime]
	,[log_reuse_wait_desc]
	,[is_percent_growth]
	,[growth_in_increment_of]
	,[next_auto_growth_size_mb]
	,[max_size]
	,[tsql]
	,[change_autogrow]
FROM data1
	--WHERE RIGHT(RTRIM(growth_in_increment_of), 1) = '%'
	--	OR CAST(REPLACE(growth_in_increment_of, ' MB', '') AS FLOAT) < 64
