WITH backupset
AS (
	SELECT bs.database_name
		,bs.type bstype
		,user_name
		,MAX(backup_finish_date) MaxBkp
	FROM msdb.dbo.backupset bs
	where  bs.is_copy_only !=1
	GROUP BY bs.database_name
		,bs.type
		,user_name
	)
	,main
AS (
	SELECT db.name
		,db.state_desc
		,db.recovery_model_desc
		,bs.type
		,bs.name AS BackupSetName
		,bs.backup_start_date
		,bs.backup_finish_date
		,CAST(bs.backup_size / 1024 / 1024 / 1024 AS DECIMAL(10, 4)) backup_size_GB
		,CAST(bs.compressed_backup_size / 1024 / 1024 / 1024 AS DECIMAL(10, 4)) compressed_backup_size_GB
		,CAST(bs.backup_size / bs.compressed_backup_size AS DECIMAL(10, 2)) [Compression_Ratio]
		,bmf.physical_device_name
		,bss.user_name
	FROM master.sys.databases db
	LEFT JOIN backupset bss ON bss.database_name = db.name
	LEFT JOIN msdb.dbo.backupset bs ON bs.database_name = db.name
	INNER JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
		AND bss.bstype = bs.type
		AND bss.MaxBkp = bs.backup_finish_date
)
SELECT @@servername [Server]
	,sd.name
	,type
	,backup_finish_date
	,CASE 
		WHEN (datediff(second, backup_start_date, backup_finish_date)) >= 0
			AND (datediff(second, backup_start_date, backup_finish_date)) < 60
			THEN left('Duration: ' + convert(VARCHAR(20), convert(DECIMAL(19, 2), datediff(millisecond, backup_start_date, backup_finish_date) / 1000.00)) + ' sec' + replicate(' ', 20), 30)
		WHEN (datediff(second, backup_start_date, backup_finish_date)) >= 60
			AND (datediff(second, backup_start_date, backup_finish_date)) < 3600
			THEN left('Duration: ' + convert(VARCHAR(20), convert(DECIMAL(19, 2), datediff(millisecond, backup_start_date, backup_finish_date) / 1000.00 / 60)) + ' min' + replicate(' ', 20), 30)
		WHEN (datediff(second, backup_start_date, backup_finish_date)) >= 3600
			THEN left('Duration: ' + convert(VARCHAR(20), convert(DECIMAL(19, 2), datediff(millisecond, backup_start_date, backup_finish_date) / 1000.00 / 60 / 60)) + ' hr' + replicate(' ', 20), 30)
		END [RunTime]
	,CASE 
		WHEN (datediff(second, backup_finish_date, getdate())) >= 0
			AND (datediff(second, backup_finish_date, getdate())) < 60
			THEN left('Duration: ' + convert(VARCHAR(max), convert(DECIMAL(19, 2), datediff(millisecond, backup_finish_date, getdate()) / 1000.00)) + ' sec' + replicate(' ', 20), 30)
		WHEN (datediff(second, backup_finish_date, getdate())) >= 60
			AND (datediff(second, backup_finish_date, getdate())) < 3600
			THEN left('Duration: ' + convert(VARCHAR(max), convert(DECIMAL(19, 2), datediff(millisecond, backup_finish_date, getdate()) / 1000.00 / 60)) + ' min' + replicate(' ', 20), 30)
		WHEN (datediff(second, backup_finish_date, getdate())) >= 3600
			THEN left('Duration: ' + convert(VARCHAR(max), convert(DECIMAL(19, 2), datediff(millisecond, backup_finish_date, getdate()) / 1000.00 / 60 / 60)) + ' hr' + replicate(' ', 20), 30)
		END [TimeSinceBkp]
	,backup_size_GB
	,compressed_backup_size_GB
	,Compression_Ratio
	,physical_device_name
	,user_name
FROM sys.databases sd
LEFT JOIN main m ON sd.name = m.name
WHERE backup_finish_date >= DATEADD(HOUR, - 596, GETDATE()) --For millisecond, the maximum difference between startdate and enddate is 24 days, 20 hours, 31 minutes and 23.647 seconds.
	--AND type = ''
	--AND user_name = ''
ORDER BY name
	,type
	,backup_finish_date
