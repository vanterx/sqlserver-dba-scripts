-- Get the credentials from sys.credentials, the password is unknown
SELECT 'CREATE CREDENTIAL ' + [name] + ' WITH IDENTITY=''' + [credential_identity] + ''',SECRET=''identity_pwd'''
FROM [sys].[credentials]
ORDER BY [name]

-- Get the proxies from sp_help_proxy and sys.credentials
CREATE TABLE #Info (
	[proxy_id] INT
	,[name] SYSNAME
	,[credential_identity] SYSNAME
	,[enabled] TINYINT
	,[description] NVARCHAR(1024)
	,[user_sid] VARBINARY(85)
	,[credential_id] INT
	,[credential_identity_exists] INT
	)

INSERT INTO #Info
EXEC msdb..sp_help_proxy

SELECT 'EXEC dbo.sp_add_proxy @proxy_name=''' + [i].[name] + ''',@enabled=' + CAST([enabled] AS VARCHAR) + ',@description=' + (
		CASE 
			WHEN [description] IS NULL
				THEN 'NULL'
			ELSE '''' + [description] + ''''
			END
		) + ',@credential_name=''' + [c].[name] + ''''
FROM #Info [i]
INNER JOIN [sys].[credentials] [c] ON [c].[credential_id] = [i].[credential_id]

-- Get the proxy authorizations from sp_enum_proxy_for_subsystem
CREATE TABLE #Info2 (
	[subsystem_id] INT
	,[subsystem_name] SYSNAME
	,[proxy_id] INT
	,[proxy_name] SYSNAME
	)

INSERT INTO #Info2
EXEC msdb..sp_enum_proxy_for_subsystem

SELECT 'EXEC msdb..dbo.sp_grant_proxy_to_subsystem @proxy_name=N''' + [proxy_name] + ''',@subsystem_id=' + CAST([subsystem_id] AS VARCHAR)
FROM #Info2

-- Get Proxy Login mapping

SELECT 'EXEC msdb.dbo.sp_grant_login_to_proxy @proxy_name=N''' + i.name + ''', @login_name=N''' + SUSER_SNAME(sid) + ''';'
FROM msdb..sysproxylogin pl
JOIN #Info i ON pl.proxy_id = i.proxy_id

DROP TABLE #Info

DROP TABLE #Info2
