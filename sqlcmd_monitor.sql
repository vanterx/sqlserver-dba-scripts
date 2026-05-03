-- =============================================================================
-- SQLCMD Monitor Reference Script
-- Collection of useful DBA SQL commands for monitoring and administration
-- Use as reference - copy/paste commands as needed
-- =============================================================================

-- =============================================================================
-- SECTION 1: SECURITY & IMPERSONATION
-- =============================================================================

-- Execute commands as SA login to bypass permission restrictions
-- Use when elevated privileges are needed (backup/restore, TDE, etc.)
-- IMPORTANT: Always use REVERT after to return to original context
EXECUTE AS LOGIN = 'sa';

-- For user-level impersonation instead of login-level
-- EXECUTE AS USER = 'username';

-- REVERT; -- Uncomment to return to original login (end of elevated section)

-- =============================================================================
-- SECTION 2: SQL SERVER HEALTH CHECKS (SP_BLITZFIRST)
-- =============================================================================

-- Run sp_BlitzFirst from First Responder Kit by Brent Ozar
-- Captures: Wait stats, Perfmon counters, File stats, Running queries
-- Results stored in msdb tables for analysis
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

-- =============================================================================
-- SECTION 3: DOMAIN & ACTIVE DIRECTORY
-- =============================================================================

-- Get domain hash for server identification
-- Useful for tracking which domain/server you're connected to
SELECT '0x' + CONVERT(VARCHAR(256), HASHBYTES('SHA1', LOWER(DEFAULT_DOMAIN())), 2);

-- Alternative method for domain hash
SELECT '0x' + CONVERT(VARCHAR(256), UPPER(master.sys.fn_varbintohexsubstring(0, HashBytes('SHA1', CONVERT(NVARCHAR(128), LOWER(DEFAULT_DOMAIN()))), 1, 0)), 2);

-- Get current Windows login and AD group membership
DECLARE @user sysname = (SELECT SUSER_SNAME());
DECLARE @sql nvarchar(max) = 'xp_logininfo ''' + @user + ''',''all''';
EXEC sp_executesql @sql;

-- =============================================================================
-- SECTION 4: AD PASSWORD CHANGE VIA XP_CMDSHELL
-- =============================================================================

-- Change AD user password using PowerShell via xp_cmdshell
-- Requires xp_cmdshell to be enabled and appropriate permissions
EXEC xp_cmdshell 'powershell -command "([adsi]''WinNT://Domain/#USERNAME#,user'').ChangePassword(''oldpassword'',''newpassword'')"';

-- =============================================================================
-- SECTION 5: FILE CLEANUP OPERATIONS
-- =============================================================================

-- Delete old backup files older than X days from a network share
-- Syntax: xp_delete_file (0, path, extension, date, subfolders)
-- Parameters: 0=files only, path, extension ('trn', 'bak'), date, 1=include subfolders

DECLARE @DeleteDate nvarchar(50)
DECLARE @DeleteDateTime datetime
SET @DeleteDateTime = DATEADD(DD, -31, GETDATE())  -- Delete files older than 31 days
SET @DeleteDate = (
    SELECT REPLACE(CONVERT(nvarchar, @DeleteDateTime, 111), '/', '-') + 'T' + CONVERT(nvarchar, @DeleteDateTime, 108)
)

-- Example: Delete .trn files older than 31 days from share
EXECUTE master.dbo.xp_delete_file 0, N'\\SHARE\', N'trn', @DeleteDate, 1

-- =============================================================================
-- SECTION 6: CACHE CLEARING OPERATIONS
-- =============================================================================

-- Clear all clean buffers (cached data pages and indexes)
-- WARNING: Forces physical reads for subsequent queries
-- Recommended: Run CHECKPOINT first to flush dirty pages to disk
CHECKPOINT;
GO
DBCC DROPCLEANBUFFERS;
GO

-- Clear procedure cache (cached execution plans)
-- WARNING: Will cause recompilation of all stored procedures and ad-hoc queries
-- May cause temporary performance decrease as plans are rebuilt
DBCC FREEPROCCACHE;
GO

-- Clear ALL system caches (includes procedure cache, SQL plans, etc.)
-- More aggressive than FREEPROCCACHE
DBCC FREESYSTEMCACHE ('ALL');
GO

-- Clear distributed query connection cache
-- Used for queries between linked servers
DBCC FREESESSIONCACHE;
GO

-- =============================================================================
-- SECTION 7: TRACE FLAGS FOR DEADLOCK INFO
-- =============================================================================

-- Enable deadlock verbose logging (global level -1 applies to all sessions)
-- 1204: Returns deadlock info in text format
-- 1222: Returns deadlock info in XML format (more detailed)

-- Method 1: Enable individually
DBCC TRACEON (1204, -1);  -- -1 = global (all sessions)
GO
DBCC TRACEON (1222, -1);
GO

-- Method 2: Enable multiple at once
DBCC TRACEON (1204, 1222, -1);

-- Disable trace flags when done
-- Method 1: Disable individually
DBCC TRACEOFF (1204, -1);
DBCC TRACEOFF (1222, -1);

-- Method 2: Disable multiple at once
DBCC TRACEOFF (1204, 1222, -1);

-- =============================================================================
-- SECTION 8: SESSION & PROCESS MONITORING
-- =============================================================================

-- Find idle sessions for a specific login that are > 24 hours old
-- Useful for cleaning up hung/old connections
SELECT MAX(last_batch), MIN(last_batch),
    DATEADD(HOUR, -5, GETDATE()),  -- 5 hours ago
    DATEADD(HOUR, 5, GETDATE())    -- 5 hours from now
FROM sys.sysprocesses
WHERE loginame = 'DOMAIN\XXXX'      -- Replace with actual domain\username
AND status = 'sleeping'
AND last_batch < DATEADD(HOUR, -24, GETDATE());  -- Inactive for 24+ hours

-- Generate KILL commands for all sessions using a specific database
-- Useful when you need to disconnect all users before restore/drop
SELECT 'KILL ' + CAST(spid AS VARCHAR(max)) + ';', *
FROM sys.sysprocesses
WHERE dbid IN (
    SELECT database_id
    FROM sys.databases
    WHERE name = 'DB_Name'  -- Change to your database name
);

-- =============================================================================
-- SECTION 9: MULTI-VALUE STRING PARSING
-- =============================================================================

-- Parse comma-separated string into table (for sp parameters)
-- Example: '1,2,3,4,5' becomes table with rows 1,2,3,4,5
DECLARE @Local_ID NVARCHAR(20) = '1,2,3,4,5';  -- Input string

SELECT T.C.value('.', 'NVARCHAR(20)') AS [ID]
INTO #TempNHI
FROM (
    SELECT CAST('<ID>' + REPLACE(@Local_ID, ',', '</ID><ID>') + '</ID>' AS XML) AS [IDs]
) AS A
CROSS APPLY IDs.nodes('/ID') AS T(C);

-- =============================================================================
-- SECTION 10: DATABASE SINGLE USER MODE OPERATIONS
-- =============================================================================

-- Fix stuck database in single user mode
-- Step 1: Set high priority to avoid deadlocks during alter
SET DEADLOCK_PRIORITY HIGH;

-- Step 2: Take database offline
ALTER DATABASE [DBATools]  -- Change to your database name
SET OFFLINE;

-- Step 3: Set to multi-user (releases exclusive lock)
ALTER DATABASE [DBATools]
SET MULTI_USER;

-- Step 4: Bring back online
ALTER DATABASE [DBATools]
SET ONLINE;

-- =============================================================================
-- SECTION 11: STATIC VALUES TABLE (IN-LINE DATA)
-- =============================================================================

-- Create temp table from static values (alternative to UNION ALL)
-- Useful for testing, comparisons, or small reference datasets
SELECT DISTINCT FieldName1, FieldName2, FieldNameN
FROM (
    VALUES
        (ValueForField1, ValueForField2, ValueForFieldN),
        (ValueForField1, ValueForField2, ValueForFieldN),
        (ValueForField1, ValueForField2, ValueForFieldN),
        (ValueForField1, ValueForField2, ValueForFieldN),
        (ValueForField1, ValueForField2, ValueForFieldN)
) AS TempTableName (FieldName1, FieldName2, FieldNameN)

-- =============================================================================
-- SECTION 12: SERVER INFORMATION
-- =============================================================================

-- Get server name, version, and build info
-- Useful for documentation and version tracking
SELECT SERVERPROPERTY('MachineName') AS MachineName,
    SERVERPROPERTY('productversion') AS productversion,
    SUBSTRING(CAST(@@VERSION AS VARCHAR(max)), 1,
        CHARINDEX(CAST(SERVERPROPERTY('productversion') AS VARCHAR(max)),
            CAST(@@VERSION AS VARCHAR(max)), 1) +
        LEN(CAST(SERVERPROPERTY('productversion') AS VARCHAR(max)))
    ) AS Version
WHERE SERVERPROPERTY('MachineName') = '';  -- Filter specific server

-- =============================================================================
-- SECTION 13: ALERTS & TESTING
-- =============================================================================

-- Raise error that triggers SQL Server Agent alert
-- Useful for testing alert configuration
-- 16 = severity level, 1 = state, WITH LOG = write to Windows Event Log
RAISERROR ('Test alert', 16, 1) WITH LOG;

-- =============================================================================
-- SECTION 14: SQL SERVER STARTUP OPTIONS
-- =============================================================================

-- Start SQL Server in bypass script upgrade mode
-- Used when startup scripts cause issues or during recovery
-- /T902 = Trace flag 902 (disable upgrade scripts)
NET START MSSQLSERVER /T902

-- =============================================================================
-- SECTION 15: WMI/SMO COMPILATION
-- =============================================================================

-- Compile MOF file for SQL Server WMI provider
-- Use after restoring system databases or when WMI issues occur
-- Path varies by SQL Server version (110=2012, 120=2014, 130=2016, etc.)
mofcomp "C:\Program Files (x86)\Microsoft SQL Server\130\Shared\sqlmgmproviderxpsp2up.mof"

-- =============================================================================
-- USEFUL QUICK REFERENCES:
-- =============================================================================

-- Check SQL Server version: SELECT @@VERSION
-- Check server name: SELECT @@SERVERNAME
-- Check current user: SELECT SUSER_SNAME(), USER_NAME()
-- Check database size: EXEC sp_helpdb 'DatabaseName'
-- Check active connections: EXEC sp_who2
-- Kill session: KILL <spid>
-- =============================================================================