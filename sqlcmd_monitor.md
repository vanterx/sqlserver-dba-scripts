# SQLCMD Monitor Reference Script

Collection of useful DBA SQL commands for monitoring and administration. Use as reference — copy/paste commands as needed.

---

## 1. Security & Impersonation

### Execute commands as SA login

Use when elevated privileges are needed (backup/restore, TDE, etc.). **Always use `REVERT` after to return to original context.**

```sql
EXECUTE AS LOGIN = 'sa';

-- For user-level impersonation instead of login-level
-- EXECUTE AS USER = 'username';

-- REVERT; -- Uncomment to return to original login
```

---

## 2. SQL Server Health Checks (sp_BlitzFirst)

Run sp_BlitzFirst from First Responder Kit by Brent Ozar. Captures wait stats, Perfmon counters, file stats, and running queries. Results stored in msdb tables for analysis.

```sql
EXEC master.dbo.sp_BlitzFirst
    @OutputDatabaseName = 'msdb',
    @OutputSchemaName = 'dbo',
    @OutputTableName = 'BlitzFirst',
    @OutputTableNameFileStats = 'BlitzFirst_FileStats',
    @OutputTableNamePerfmonStats = 'BlitzFirst_PerfmonStats',
    @OutputTableNameWaitStats = 'BlitzFirst_WaitStats',
    @OutputTableNameBlitzCache = 'BlitzCache',
    @OutputTableNameBlitzWho = 'BlitzWho',
    @OutputTableRetentionDays = 14;
```

---

## 3. Domain & Active Directory

### Get domain hash for server identification

```sql
SELECT '0x' + CONVERT(VARCHAR(256), HASHBYTES('SHA1', LOWER(DEFAULT_DOMAIN())), 2);
```

### Alternative method for domain hash

```sql
SELECT '0x' + CONVERT(VARCHAR(256), UPPER(master.sys.fn_varbintohexsubstring(0, HashBytes('SHA1', CONVERT(NVARCHAR(128), LOWER(DEFAULT_DOMAIN()))), 1, 0)), 2);
```

### Get current Windows login and AD group membership

```sql
DECLARE @user sysname = (SELECT SUSER_SNAME());
DECLARE @sql nvarchar(max) = 'xp_logininfo ''' + @user + ''',''all''';
EXEC sp_executesql @sql;
```

---

## 4. AD Password Change via xp_cmdshell

> **WARNING**: Requires xp_cmdshell to be enabled and appropriate permissions. Command is logged.

```sql
EXEC xp_cmdshell 'powershell -command "([adsi]''WinNT://Domain/#USERNAME#,user'').ChangePassword(''oldpassword'',''newpassword'')"'
```

---

## 5. File Cleanup Operations

Delete old backup files older than X days from a network share.

```sql
DECLARE @DeleteDate nvarchar(50)
DECLARE @DeleteDateTime datetime
SET @DeleteDateTime = DATEADD(DD, -31, GETDATE())  -- Delete files older than 31 days
SET @DeleteDate = (
    SELECT REPLACE(CONVERT(nvarchar, @DeleteDateTime, 111), '/', '-') + 'T' + CONVERT(nvarchar, @DeleteDateTime, 108)
)

-- Delete .trn files older than 31 days from share
EXECUTE master.dbo.xp_delete_file 0, N'\\SHARE\', N'trn', @DeleteDate, 1
```

**Parameters**: `0` = files only, `path`, `extension` ('trn', 'bak'), `date`, `1` = include subfolders.

---

## 6. Cache Clearing Operations

### Clear clean buffers (cached data pages and indexes)

> **WARNING**: Forces physical reads for subsequent queries. Run `CHECKPOINT` first to flush dirty pages.

```sql
CHECKPOINT;
GO
DBCC DROPCLEANBUFFERS;
GO
```

### Clear procedure cache (cached execution plans)

> **WARNING**: Will cause recompilation of all stored procedures and ad-hoc queries. May cause temporary performance decrease.

```sql
DBCC FREEPROCCACHE;
GO
```

### Clear ALL system caches

```sql
DBCC FREESYSTEMCACHE ('ALL');
GO
```

### Clear distributed query connection cache

```sql
DBCC FREESESSIONCACHE;
GO
```

---

## 7. Trace Flags for Deadlock Info

Enable deadlock verbose logging. `1204` returns text format, `1222` returns XML format (more detailed). `-1` = global (all sessions).

```sql
-- Enable both at once
DBCC TRACEON (1204, 1222, -1);

-- Disable when done
DBCC TRACEOFF (1204, 1222, -1);
```

---

## 8. Session & Process Monitoring

### Find idle sessions for a specific login older than 24 hours

```sql
SELECT MAX(last_batch), MIN(last_batch),
    DATEADD(HOUR, -5, GETDATE()),
    DATEADD(HOUR, 5, GETDATE())
FROM sys.sysprocesses
WHERE loginame = 'DOMAIN\XXXX'      -- Replace with actual domain\username
AND status = 'sleeping'
AND last_batch < DATEADD(HOUR, -24, GETDATE());
```

### Generate KILL commands for all sessions using a specific database

```sql
SELECT 'KILL ' + CAST(spid AS VARCHAR(max)) + ';', *
FROM sys.sysprocesses
WHERE dbid IN (
    SELECT database_id
    FROM sys.databases
    WHERE name = 'DB_Name'  -- Change to your database name
);
```

---

## 9. Multi-Value String Parsing

Parse comma-separated string into table (for stored procedure parameters).

```sql
DECLARE @Local_ID NVARCHAR(20) = '1,2,3,4,5';

SELECT T.C.value('.', 'NVARCHAR(20)') AS [ID]
INTO #TempNHI
FROM (
    SELECT CAST('<ID>' + REPLACE(@Local_ID, ',', '</ID><ID>') + '</ID>' AS XML) AS [IDs]
) AS A
CROSS APPLY IDs.nodes('/ID') AS T(C);
```

---

## 10. Database Single User Mode Operations

Fix stuck database in single user mode.

```sql
SET DEADLOCK_PRIORITY HIGH;

-- Take database offline
ALTER DATABASE [DBATools] SET OFFLINE;

-- Set to multi-user (releases exclusive lock)
ALTER DATABASE [DBATools] SET MULTI_USER;

-- Bring back online
ALTER DATABASE [DBATools] SET ONLINE;
```

---

## 11. Static Values Table (In-line Data)

Create temp table from static values (alternative to UNION ALL). Useful for testing, comparisons, or small reference datasets.

```sql
SELECT DISTINCT FieldName1, FieldName2, FieldNameN
FROM (
    VALUES
        (ValueForField1, ValueForField2, ValueForFieldN),
        (ValueForField1, ValueForField2, ValueForFieldN),
        (ValueForField1, ValueForField2, ValueForFieldN)
) AS TempTableName (FieldName1, FieldName2, FieldNameN);
```

---

## 12. Server Information

Get server name, version, and build info.

```sql
SELECT SERVERPROPERTY('MachineName') AS MachineName,
    SERVERPROPERTY('productversion') AS productversion,
    SUBSTRING(CAST(@@VERSION AS VARCHAR(max)), 1,
        CHARINDEX(CAST(SERVERPROPERTY('productversion') AS VARCHAR(max)),
            CAST(@@VERSION AS VARCHAR(max)), 1) +
        LEN(CAST(SERVERPROPERTY('productversion') AS VARCHAR(max)))
    ) AS Version
WHERE SERVERPROPERTY('MachineName') = '';  -- Filter specific server
```

---

## 13. Alerts & Testing

Raise error that triggers SQL Server Agent alert (useful for testing alert configuration).

```sql
RAISERROR ('Test alert', 16, 1) WITH LOG;
```

---

## 14. SQL Server Startup Options

Start SQL Server in bypass script upgrade mode (`/T902` = disable upgrade scripts). Used when startup scripts cause issues or during recovery.

```cmd
NET START MSSQLSERVER /T902
```

---

## 15. WMI/SMO Compilation

Compile MOF file for SQL Server WMI provider. Use after restoring system databases or when WMI issues occur. Path varies by SQL Server version (110=2012, 120=2014, 130=2016, etc.).

```cmd
mofcomp "C:\Program Files (x86)\Microsoft SQL Server\130\Shared\sqlmgmproviderxpsp2up.mof"
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Check SQL Server version | `SELECT @@VERSION` |
| Check server name | `SELECT @@SERVERNAME` |
| Check current user | `SELECT SUSER_SNAME(), USER_NAME()` |
| Check database size | `EXEC sp_helpdb 'DatabaseName'` |
| Check active connections | `EXEC sp_who2` |
| Kill session | `KILL <spid>` |
