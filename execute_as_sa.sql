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

-- Your privileged commands go here

REVERT; -- Return to original login context
