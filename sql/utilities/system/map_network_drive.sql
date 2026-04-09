EXEC sp_configure 'show advanced options'
	,1;
GO

RECONFIGURE;
GO

EXEC sp_configure 'xp_cmdshell'
	,1
GO

RECONFIGURE
GO

EXEC xp_cmdshell 'net use X: \\RemoteServerName\ShareName'

EXEC xp_cmdshell 'Dir X:'

EXEC xp_cmdshell 'Dir X: /DELETE'
