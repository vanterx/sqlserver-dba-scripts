SELECT rh.destination_database_name AS [Database]
	,CASE 
		WHEN rh.restore_type = 'D'
			THEN 'Database'
		WHEN rh.restore_type = 'F'
			THEN 'File'
		WHEN rh.restore_type = 'I'
			THEN 'Differential'
		WHEN rh.restore_type = 'L'
			THEN 'Log'
		ELSE rh.restore_type
		END AS [Restore Type]
	,rh.restore_date AS [Restore Date]
	,bmf.physical_device_name AS [Source]
	,rf.destination_phys_name AS [Restore File]
	,rh.user_name AS [Restored By]
FROM msdb.dbo.restorehistory rh
INNER JOIN msdb.dbo.backupset bs ON rh.backup_set_id = bs.backup_set_id
INNER JOIN msdb.dbo.restorefile rf ON rh.restore_history_id = rf.restore_history_id
INNER JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
ORDER BY rh.restore_history_id DESC


------------------------------
DECLARE @path NVARCHAR(260);

SELECT 
   @path = REVERSE(SUBSTRING(REVERSE([path]), 
   CHARINDEX(CHAR(92), REVERSE([path])), 260)) + N'log.trc'
FROM    sys.traces
WHERE   is_default = 1;

SELECT *, rn = ROW_NUMBER() OVER 
  (PARTITION BY DatabaseName ORDER BY StartTime)
INTO #blat
FROM sys.fn_trace_gettable(@path, DEFAULT) 
WHERE DatabaseName IN (
  N'db1', N'db2' -- , ...
)
ORDER BY StartTime DESC; 

SELECT b.DatabaseName, b.TextData, 
  ApproximateRestoreTime = DATEDIFF(MILLISECOND, b.StartTime, b2.StartTime)
FROM #blat AS b 
LEFT OUTER JOIN #blat AS b2
ON b.DatabaseName = b2.DatabaseName
AND b2.rn = b.rn + 1
WHERE b.EventClass = 115 AND b.EventSubClass = 2
ORDER BY b.StartTime DESC;

GO
DROP TABLE #blat;
