-- Executes commands as SA login to bypass permission restrictions
-- SA has elevated server-level privileges required for certain operations
--
-- WHY RUN AS SA:
-- 1. RESTORE DATABASE - Requires CREATE ANY DATABASE, file access permissions
-- 2. Database ownership - May need to set owner, access protected paths
-- 3. TDE operations - Requires server-level certificate access
-- 4. Avoids permission errors - Files owned by SYSTEM/Administrators
-- 5. Consistent behavior - Works regardless of user permissions
--
-- OTHER OPERATIONS REQUIRING SA:
-- - CREATE DATABASE (when files exist and need overwrite)
-- - ALTER SERVER STATE (trace flags, DAC access)
-- - CREATE/ALTER/DELETE endpoints
-- - Server-level certificates (TDE, SSL)
-- - Server-level roles (sysadmin, securityadmin)
-- - Linked servers with security context
-- - Querying system databases (master, msdb) with certain filters
-- - xp_cmdshell operations
-- - FILESTREAM operations
-- - Server-level DDL (CREATE/ALTER/DROP SERVER AUDIT)
-- - Policy-based management operations
-- - Always On AG operations (join database, failover)
-- - Service broker transport operations
--
-- Usage: Run before sensitive commands, use REVERT to return to original login

EXECUTE AS LOGIN = 'sa';

-- =============================================================================
-- EXAMPLE 1: RESTORE DATABASE WITH OVERWRITE
-- =============================================================================
-- Use when restoring over existing database or files owned by other accounts
-- RESTORE DATABASE MyDB FROM DISK = 'C:\Backups\MyDB.bak' WITH REPLACE;

-- =============================================================================
-- EXAMPLE 2: CREATE DATABASE WITH SPECIFIC PATHS
-- =============================================================================
-- Use when needing to create DB files in protected directories
-- CREATE DATABASE MyDB ON PRIMARY (
--     NAME = 'MyDB_Data',
--     FILENAME = 'D:\SQLData\MyDB.mdf',
--     SIZE = 100MB,
--     MAXSIZE = 500MB,
--     FILEGROWTH = 10MB
-- ) LOG ON (
--     NAME = 'MyDB_Log',
--     FILENAME = 'E:\SQLLogs\MyDB.ldf',
--     SIZE = 50MB,
--     MAXSIZE = 200MB,
--     FILEGROWTH = 10MB
-- );

-- =============================================================================
-- EXAMPLE 3: CHANGE DATABASE OWNER TO SA
-- =============================================================================
-- Use when source DB owner doesn't exist on target server
-- ALTER AUTHORIZATION ON DATABASE::MyDB TO [sa];

-- =============================================================================
-- EXAMPLE 4: DROP AND RECREATE DATABASE
-- =============================================================================
-- Use when you need to fully recreate a database
-- DROP DATABASE IF EXISTS MyDB;
-- CREATE DATABASE MyDB;

-- =============================================================================
-- EXAMPLE 5: OPERATE ON SYSTEM DATABASES
-- =============================================================================
-- Use when needing to query or modify master/msdb with restricted access
-- USE master;
-- SELECT * FROM sys.databases WHERE state_desc = 'OFFLINE';

-- =============================================================================
-- EXAMPLE 6: MANAGE SERVER-LEVEL CERTIFICATES (TDE)
-- =============================================================================
-- Use when working with Transparent Data Encryption
-- CREATE CERTIFICATE MyServerCert WITH SUBJECT = 'My TDE Certificate';

-- =============================================================================
-- EXAMPLE 7: ACCESS RESTRICTED FILE PATHS
-- =============================================================================
-- Use when reading/writing to paths restricted to SYSTEM/Administrators
-- xp_cmdshell 'dir C:\ProtectedFolder', NO_OUTPUT;

-- =============================================================================
-- EXAMPLE 8: ALWAYS ON AG OPERATIONS
-- =============================================================================
-- Use when joining database to AG or failing over
-- ALTER DATABASE MyDB SET HADR AVAILABILITY GROUP = MyAG;

-- =============================================================================
-- EXAMPLE 9: SERVER AUDIT OPERATIONS
-- =============================================================================
-- Use when creating/modifying server-level audits
-- CREATE SERVER AUDIT MyAudit TO FILE (FILEPATH = 'C:\AuditLogs\');

-- =============================================================================
-- ADD YOUR PRIVILEGED COMMANDS HERE

-- =============================================================================

REVERT; -- Return to original login context