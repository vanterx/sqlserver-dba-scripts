-- BACKUP CHECK
IF object_id('tempdb..#tmp', 'u') IS NOT NULL
	DROP TABLE #tmp

CREATE TABLE #tmp (
	name SYSNAME
	,backup_start_date DATETIME
	,type CHAR(1)
	)

IF charindex('Microsoft SQL Server  2000', @@version) = 0
BEGIN -- it is not SQL2000
	INSERT INTO #tmp (
		name
		,backup_start_date
		,type
		)
	SELECT name
		,NULL
		,NULL
	FROM sys.databases
	WHERE STATE = 0
		AND database_id <> 2
		AND is_in_standby <> 1 -- do we need extra checks around mirroring?

	IF object_id('sys.fn_hadr_backup_is_preferred_replica') IS NOT NULL
	BEGIN
		-- removed dbs that are not preferred to be backed up on this replica
		DELETE #tmp
		WHERE sys.fn_hadr_backup_is_preferred_replica(name) = 0
	END
END
ELSE
BEGIN -- it is SQL2000
	INSERT INTO #tmp (
		name
		,backup_start_date
		,type
		)
	SELECT name
		,NULL
		,NULL
	FROM master.dbo.sysdatabases
	WHERE dbid <> 2
		AND DATABASEPROPERTYEX(name, 'Status') = 'ONLINE'
		AND DATABASEPROPERTYEX(name, 'IsInStandBy') = 0
END

UPDATE #tmp
SET backup_start_date = x.backup_start_date
	,type = b.type
FROM #tmp t
JOIN (
	SELECT database_name AS name
		,MAX(backup_start_date) AS backup_start_date
	FROM msdb..backupset WITH (NOLOCK)
	WHERE type <> 'L'
		AND is_snapshot = 0
	GROUP BY database_name
	) AS x ON x.name = t.name
LEFT OUTER JOIN msdb..backupset b WITH (NOLOCK) ON b.database_name = x.name
	AND b.backup_start_date = x.backup_start_date
	AND b.type <> 'L'
	AND b.is_snapshot = 0

-- #tmp now holds all databases that should be backed up, their latest backup date and what type
-- of backup it was (Differential or Full)
SELECT 'Backup' AS FindingsGroup
	,'Backups Not Performed Recently' AS Finding
	,CASE 
		WHEN backup_start_date IS NULL
			THEN 'Database ' + name + ' never backed up.'
		WHEN backup_start_date < DATEADD(D, - 7, GETDATE())
			THEN 'Database ' + name + ' last backed up over a week ago: ' + CONVERT(VARCHAR, backup_start_date, 120) + ' (' + CONVERT(VARCHAR, DATEDIFF(D, backup_start_date, GETDATE())) + ' day' + CASE 
					WHEN DATEDIFF(D, backup_start_date, GETDATE()) > 1
						THEN 's'
					ELSE ''
					END + ' ago)' + CASE 
					WHEN type = 'I'
						THEN ' (differential backup)'
					ELSE ''
					END
		WHEN backup_start_date < DATEADD(D, - 1, GETDATE())
			THEN 'Database ' + name + ' last backed up: ' + CONVERT(VARCHAR, backup_start_date, 120) + ' (' + CONVERT(VARCHAR, DATEDIFF(D, backup_start_date, GETDATE())) + ' day' + CASE 
					WHEN DATEDIFF(D, backup_start_date, GETDATE()) > 1
						THEN 's'
					ELSE ''
					END + ' ago)' + CASE 
					WHEN type = 'I'
						THEN ' (differential backup)'
					ELSE ''
					END
		END AS Details
FROM #tmp
WHERE backup_start_date < DATEADD(D, - 1, GETDATE())
	OR backup_start_date IS NULL

-- LOG BACKUP CHECK
IF charindex('Microsoft SQL Server  2000', @@version) > 0 -- is it SQL2000
	DELETE #tmp
	WHERE DATABASEPROPERTYEX(name, 'Recovery') = 'SIMPLE'
		OR name = 'model'
		OR DATABASEPROPERTYEX(name, 'updateability') = 'READ_ONLY'
ELSE
	DELETE #tmp
	FROM #tmp t
	JOIN sys.databases d ON d.name = t.name
	WHERE d.recovery_model_desc = 'SIMPLE'
		OR d.name = 'model'
		OR d.is_read_only = 1

UPDATE #tmp
SET backup_start_date = x.backup_start_date
	,type = b.type
FROM #tmp t
LEFT OUTER JOIN (
	SELECT database_name AS name
		,MAX(backup_start_date) AS backup_start_date
	FROM msdb..backupset WITH (NOLOCK)
	WHERE type = 'L'
	GROUP BY database_name
	) AS x ON x.name = t.name
LEFT OUTER JOIN msdb..backupset b WITH (NOLOCK) ON b.database_name = x.name
	AND b.backup_start_date = x.backup_start_date
	AND b.type = 'L'

-- #tmp now holds only databases that need transaction log backups, and their most recent backup date
SELECT DISTINCT 'Backup' AS FindingsGroup
	,'Full Recovery Mode w/o Log Backups' AS Finding
	,CASE 
		WHEN backup_start_date IS NULL
			THEN 'Database ' + name + ' has never had a log backup.'
		WHEN backup_start_date < DATEADD(MINUTE, - 60, GETDATE())
			THEN 'Database ' + name + ' had its last log backup on: ' + CONVERT(VARCHAR, backup_start_date, 120) + ' (' + CONVERT(VARCHAR, DATEDIFF(MINUTE, backup_start_date, GETDATE())) + ' min' + CASE 
					WHEN DATEDIFF(MINUTE, backup_start_date, GETDATE()) > 1
						THEN 's'
					ELSE ''
					END + ' ago)'
		END AS Details
FROM #tmp
WHERE backup_start_date < DATEADD(MINUTE, - 60, GETDATE())
	OR backup_start_date IS NULL;
