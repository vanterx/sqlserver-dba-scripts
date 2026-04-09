SELECT DB_NAME(dbid) AS DBName
	,hostname
	,loginame
	,[program_name]
	,COUNT(dbid) AS NumberOfConnections
FROM sys.sysprocesses
--where hostname in ('','','')
GROUP BY dbid
	,hostname
	,loginame
	,[program_name]
ORDER BY DB_NAME(dbid)

-------------------------------------

SELECT DISTINCT CaptureTime = (
		SELECT GETDATE()
		)
	,s.login_name AS [Login]
	,ISNULL(s.host_name, N'') AS [Host]
	,ISNULL(s.program_name, N'') AS [Program]
	,ISNULL(DB_NAME(r.database_id), N'') AS [Database]
	,count(*)
FROM sys.dm_exec_sessions AS s
LEFT OUTER JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
WHERE CAST(~ s.is_user_process AS BIT) = 0
GROUP BY s.login_name
	,ISNULL(s.host_name, N'')
	,ISNULL(s.program_name, N'')
	,ISNULL(DB_NAME(r.database_id), N'')
