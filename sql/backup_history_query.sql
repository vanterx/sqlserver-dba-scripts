SELECT CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
	,msdb.dbo.backupset.database_name
	,msdb.dbo.backupset.backup_start_date
	,msdb.dbo.backupset.backup_finish_date
	,CASE 
		WHEN (datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00) < 60
			THEN left('Duration: ' + convert(VARCHAR(20), convert(DECIMAL(19, 2), datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00)) + ' sec' + replicate(' ', 20), 30)
		WHEN (datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00) > 60
			AND (datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00) < 3600
			THEN left('Duration: ' + convert(VARCHAR(20), convert(DECIMAL(19, 2), datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00 / 60)) + ' min' + replicate(' ', 20), 30)
		WHEN (datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00) > 3600
			THEN left('Duration: ' + convert(VARCHAR(20), convert(DECIMAL(19, 2), datediff(millisecond, msdb.dbo.backupset.backup_start_date, msdb.dbo.backupset.backup_finish_date) / 1000.00 / 60 / 60)) + ' hr' + replicate(' ', 20), 30)
		END duration
	,CASE msdb..backupset.type
		WHEN 'D'
			THEN 'Database'
		WHEN 'L'
			THEN 'Log'
		WHEN 'I'
			THEN 'Differential'
		END AS backup_type
	,CAST(msdb.dbo.backupset.compressed_backup_size / 1024 / 1024 / 1024 AS DECIMAL(10, 4)) compressed_backup_size_GB
	,CAST(msdb.dbo.backupset.backup_size / 1024 / 1024 / 1024 AS DECIMAL(10, 4)) backup_size_GB
	--,CAST([compressed_backup_size]/ 1024 / 1024 / 1024 AS DECIMAL(10, 4)) - lag(CAST([compressed_backup_size]/ 1024 / 1024 / 1024 AS DECIMAL(10, 4)) ) OVER (
	--		PARTITION BY [database_name] ORDER BY backup_start_date	) [backup_size_diff]
	--,msdb.dbo.backupset.backup_size
	--,msdb.dbo.backupset.compressed_backup_size
	--,msdb.dbo.backupmediafamily.logical_device_name
	,msdb.dbo.backupmediafamily.physical_device_name
	,msdb.dbo.backupset.user_name
	,msdb.dbo.backupset.is_copy_only
	,msdb.dbo.backupset.is_snapshot
	,msdb.dbo.backupset.checkpoint_lsn
	,msdb.dbo.backupset.database_backup_lsn
	,msdb.dbo.backupset.differential_base_lsn
	,msdb.dbo.backupset.first_lsn
	,msdb.dbo.backupset.fork_point_lsn
	,msdb.dbo.backupset.last_lsn
FROM msdb.dbo.backupmediafamily
INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id
WHERE (CONVERT(DATETIME, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 1)
	AND (
		msdb.dbo.backupset.is_copy_only != 1
		OR msdb.dbo.backupset.is_snapshot != 1
		)
	AND msdb..backupset.type != 'L'
