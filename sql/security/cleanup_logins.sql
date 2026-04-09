DECLARE @invalidlogins TABLE (
	SID VARBINARY(100)
	,[NT Login] VARCHAR(100)
	)

INSERT INTO @invalidlogins
EXEC sp_validatelogins

IF object_id('tempdb..#BadLogins') IS NOT NULL
	DROP TABLE #BadLogins

CREATE TABLE #BadLogins (loginname SYSNAME)

INSERT INTO #BadLogins
SELECT *
FROM (
	VALUES ('domain\login')
		/* search/replace list of warning from checks to create values for inserting
.+\[{.+}\].*
('\1'),
*/
	) a(name)

UNION

SELECT [NT Login]
FROM @invalidlogins

-- Only drop when you got a clean run
-- select @@servername,'drop login ['+l.loginname+'];' from sys.syslogins l join #BadLogins b on b.loginname=l.loginname
-- A: Check the Login's SIDs on the Domain using PowerShell
-- Run the "Method2" column via the PowerShell console.
DECLARE @BuildLoop INT
	,@RowID INT = 0
	,@LoginName NVARCHAR(128)
	,@BinarySID VARBINARY(85)
	,@StringSID VARCHAR(100);
DECLARE @PSVerifySID TABLE (
	RowID INT identity(1, 1)
	,LoginName NVARCHAR(128)
	,BinarySID VARBINARY(85)
	,StringSID VARCHAR(100)
	);

INSERT INTO @PSVerifySID (
	LoginName
	,BinarySID
	)
SELECT [name]
	,[sid]
FROM sys.syslogins
WHERE [name] IN (
		SELECT loginname
		FROM #BadLogins
		);

WHILE (1 = 1)
BEGIN
	SELECT TOP 1 @BuildLoop = 9
		,@RowID = RowID
		,@LoginName = LoginName
		,@BinarySID = BinarySID
		,@StringSID = 'S-' + convert(VARCHAR, convert(INT, convert(VARBINARY, substring(BinarySID, 1, 1)))) + '-' + convert(VARCHAR, convert(INT, convert(VARBINARY, substring(BinarySID, 3, 6))))
	FROM @PSVerifySID
	WHERE RowID > @RowID
	ORDER BY RowID;

	IF @@rowcount = 0
		BREAK;

	WHILE @BuildLoop < len(@BinarySID)
	BEGIN
		SET @StringSID = @StringSID + '-' + convert(VARCHAR, convert(BIGINT, convert(VARBINARY, reverse(convert(VARBINARY, substring(@BinarySID, @BuildLoop, 4))))));
		SET @BuildLoop = @BuildLoop + 4;
	END

	UPDATE @PSVerifySID
	SET StringSID = @StringSID
	WHERE RowID = @RowID;
END

SELECT 'A' AS [Check]
	,1 AS [Order]
	,'' AS [LoginName]
	,'<# Ignore for now #>' AS [Method1]
	,'<# Use PowerShell to check SIDs #> $Results = @();' AS [Method2]

UNION

SELECT ''
	,2
	,LoginName
	,'Get-WmiObject win32_useraccount | Where-Object { $_.sid -eq "' + StringSID + '" } | Select name,sid'
	,'try { $Results += "alter login [' + LoginName + '] with name = [$(((New-Object System.Security.Principal.SecurityIdentifier("' + StringSID + '")).Translate([System.Security.Principal.NTAccount])).Value)]"; } catch { $Results += "' + LoginName + ' = <Not found!>"}'
FROM @PSVerifySID

UNION

SELECT ''
	,3
	,''
	,''
	,'cls; if ("' + convert(NVARCHAR(128), serverproperty('MachineName')) + '" -ne $env:computername) { write-host -backgroundcolor red "Error: You must RDP to ' + convert(NVARCHAR(128), serverproperty('MachineName')) + ' and run this script locally!"; return }; $Results | % { if ($_ -like "*<Not found!>") { write-host -foregroundcolor green "`t$($_)" } else { write-host -foregroundcolor red "`t$($_)" }  }'
ORDER BY [Order];

-- B: Check for active sessions
SELECT 'B' AS [Check]
	,*
FROM sys.dm_exec_sessions
WHERE login_name IN (
		SELECT loginname
		FROM #BadLogins
		);

-- C: Check Database, AG and Endpoint ownership
DECLARE @ag TABLE (
	[Check] VARCHAR(10)
	,[T-SQL_DropOwner] VARCHAR(max)
	)

IF object_id('sys.availability_groups', 'V') IS NOT NULL
	INSERT INTO @ag
	SELECT 'C'
		,'alter authorization on availability group::[' + ag.name + '] to [' + suser_sname(0x01) + '];'
	FROM sys.availability_replicas r
	JOIN sys.availability_groups ag ON ag.group_id = r.group_id
	JOIN sys.syslogins l ON l.sid = r.owner_sid
	JOIN #BadLogins b ON b.loginname = l.loginname;

SELECT 'C' AS [Check]
	,'alter authorization on database::[' + d.name + '] to [' + suser_sname(0x01) + '];' AS [T-SQL_DropOwner]
FROM sys.databases d
JOIN sys.syslogins l ON l.sid = d.owner_sid
JOIN #BadLogins b ON b.loginname = l.loginname

UNION

SELECT *
FROM @ag

UNION

SELECT 'C' AS [Check]
	,'alter authorization on endpoint::[' + ep.name + '] to [' + suser_sname(0x01) + ']; grant connect on endpoint::[' + ep.name + '] to [' + gr.name + '];' AS [T-SQL_DropOwner]
FROM sys.endpoints ep
JOIN sys.server_principals p ON p.principal_id = ep.principal_id
LEFT JOIN sys.server_permissions pm ON ep.endpoint_id = pm.major_id
JOIN sys.server_principals gr ON gr.principal_id = pm.grantee_principal_id
JOIN #BadLogins b ON b.loginname = p.name;

-- D: Check SQL Agent jobs
SELECT 'D' AS [Check]
	,j.owner_sid sid
	,suser_sname(j.owner_sid) OWNER
	,j.name
	,'EXEC msdb.dbo.sp_update_job @job_id=N''' + cast(j.job_id AS VARCHAR(50)) + ''',@owner_login_name=N''' + SUSER_SNAME(0x01) + '''' cmd
FROM msdb.dbo.sysjobs j
JOIN sys.syslogins l ON l.sid = j.owner_sid
JOIN #BadLogins b ON b.loginname = l.loginname
ORDER BY 3;

-- E: Check maintenance plans & SSIS packages in SQL2008
SELECT 'E' AS [Check]
	,p.ownersid sid
	,SUSER_SNAME(p.ownersid) OWNER
	,p.name
	,'update msdb..sysssispackages set ownersid=0x01 where id=''' + convert(VARCHAR(100), id) + '''' cmd
FROM msdb..sysssispackages p
JOIN sys.syslogins l ON l.sid = p.ownersid
JOIN #BadLogins b ON b.loginname = l.loginname
ORDER BY 3;

-- F: Check Object ownership check
IF (object_id('tempdb..#t') IS NOT NULL)
	DROP TABLE #t;

CREATE TABLE #t (
	loginname SYSNAME
	,dbname SYSNAME NULL
	,user_name SYSNAME NULL
	,schema_name SYSNAME NULL
	,object_name SYSNAME NULL
	,[DROP USER] VARCHAR(4000) NULL
	)

DECLARE @cmd VARCHAR(4000);

SET @cmd = '
		select l.loginname,''?'',u.name [user],s.name [schema],o.name [object]
		, case when u.name is null
			then ''''
			else
				case when s.name is null
					then ''use [?]; drop user [''+u.name+''];''
					else
						case when o.name is null
							then 
								case when s.schema_id<16384 
									then ''use [?]; drop schema [''+s.name+'']; drop user [''+u.name+''];''
									else ''use [?]; alter authorization on schema::[''+s.name+''] to [''+s.name+'']; drop user [''+u.name+''];''
									end
							else ''-- the user owns objects!!''
							end
					end
			end
		from sys.syslogins l
		join #BadLogins b on l.loginname=b.loginname
		left join [?].sys.database_principals u on u.sid=l.sid
		left join [?].sys.schemas s on u.principal_id=s.principal_id
		left join [?].sys.objects o on o.schema_id=s.schema_id
		--where u.name is not null
	'

INSERT INTO #t
EXEC sp_MSforeachdb @cmd

SELECT 'F' AS [Check]
	,*
FROM #t
WHERE user_name IS NOT NULL;
