--  Global trace flag 9567 can be used to enable compression for all Availability Groups on the SQL Server instance.

SELECT dhas.start_time
	,dhas.completion_time
	,ag.name
	,adb.database_name
	,dhas.current_state
	,dhas.performed_seeding
	,dhas.failure_state
	,dhas.failure_state_desc
FROM sys.dm_hadr_automatic_seeding AS dhas
INNER JOIN sys.availability_databases_cluster AS adb ON dhas.ag_db_id = adb.group_database_id
INNER JOIN sys.availability_groups AS ag ON dhas.ag_id = ag.group_id

----
SELECT percent_complete
	,convert(VARCHAR, DATEADD(MS, estimated_completion_time, 0), 108) AS remaining
	,dateadd(MS, estimated_completion_time, GETDATE()) AS ETA
	,(
		SELECT SUBSTRING(TEXT, statement_start_offset / 2, CASE 
					WHEN statement_end_offset = - 1
						THEN 1000
					ELSE (statement_end_offset - statement_start_offset) / 2
					END)
		FROM sys.dm_exec_sql_text(sql_handle)
		) AS command
	,*
	,session_id
	,start_time
	,command
FROM sys.dm_exec_requests
WHERE percent_complete <> 0

----
SELECT local_database_name
	,remote_machine_name
	,role_desc
	,internal_state_desc
	,transfer_rate_bytes_per_second / 1024 / 1024 AS transfer_rate_MB_per_second
	,transferred_size_bytes / 1024 / 1024 AS transferred_size_MB
	,database_size_bytes / 1024 / 1024 / 1024 / 1024 AS Database_Size_TB
	,is_compression_enabled
FROM sys.dm_hadr_physical_seeding_stats

----
IF OBJECT_ID('tempdb..#Seeding') IS NOT NULL
	DROP TABLE #Seeding;

SELECT GETDATE() AS CollectionTime
	,instance_name
	,cntr_value
INTO #Seeding
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Backup/Restore Throughput/sec';

WAITFOR DELAY '00:00:05'

SELECT LTRIM(RTRIM(p2.instance_name)) AS [DatabaseName]
	,(p2.cntr_value - p1.cntr_value) / (DATEDIFF(SECOND, p1.CollectionTime, GETDATE())) / 1000000 AS ThroughputBytesSec
FROM sys.dm_os_performance_counters AS p2
INNER JOIN #Seeding AS p1 ON p2.instance_name = p1.instance_name
WHERE p2.counter_name LIKE 'Backup/Restore Throughput/sec%'
ORDER BY ThroughputBytesSec DESC;
