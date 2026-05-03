# Execute as SA — Privileged Operations Reference

This document explains when and how to use `EXECUTE AS LOGIN = 'sa'` to bypass permission restrictions in SQL Server.

---

## Why Run as SA

The `sa` login has elevated server-level privileges required for certain operations:

1. **RESTORE DATABASE** — Requires `CREATE ANY DATABASE`, file access permissions
2. **Database ownership** — May need to set owner, access protected paths
3. **TDE operations** — Requires server-level certificate access
4. **Avoids permission errors** — Files owned by SYSTEM/Administrators
5. **Consistent behavior** — Works regardless of user permissions

## Other Operations Requiring SA

- `CREATE DATABASE` (when files exist and need overwrite)
- `ALTER SERVER STATE` (trace flags, DAC access)
- `CREATE/ALTER/DELETE` endpoints
- Server-level certificates (TDE, SSL)
- Server-level roles (sysadmin, securityadmin)
- Linked servers with security context
- Querying system databases (master, msdb) with certain filters
- `xp_cmdshell` operations
- FILESTREAM operations
- Server-level DDL (`CREATE/ALTER/DROP SERVER AUDIT`)
- Policy-based management operations
- Always On AG operations (join database, failover)
- Service broker transport operations

---

## Usage

Run `EXECUTE AS LOGIN = 'sa'` before sensitive commands, then `REVERT` to return to original login context.

```sql
EXECUTE AS LOGIN = 'sa';

-- ... privileged commands here ...

REVERT;
```

---

## Example 1: Restore Database with Overwrite

Use when restoring over existing database or files owned by other accounts.

```sql
RESTORE DATABASE MyDB FROM DISK = 'C:\Backups\MyDB.bak' WITH REPLACE;
```

## Example 2: Create Database with Specific Paths

Use when needing to create DB files in protected directories.

```sql
CREATE DATABASE MyDB ON PRIMARY (
    NAME = 'MyDB_Data',
    FILENAME = 'D:\SQLData\MyDB.mdf',
    SIZE = 100MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 10MB
) LOG ON (
    NAME = 'MyDB_Log',
    FILENAME = 'E:\SQLLogs\MyDB.ldf',
    SIZE = 50MB,
    MAXSIZE = 200MB,
    FILEGROWTH = 10MB
);
```

## Example 3: Change Database Owner to SA

Use when source DB owner doesn't exist on target server.

```sql
ALTER AUTHORIZATION ON DATABASE::MyDB TO [sa];
```

## Example 4: Drop and Recreate Database

Use when you need to fully recreate a database.

```sql
DROP DATABASE IF EXISTS MyDB;
CREATE DATABASE MyDB;
```

## Example 5: Operate on System Databases

Use when needing to query or modify master/msdb with restricted access.

```sql
USE master;
SELECT * FROM sys.databases WHERE state_desc = 'OFFLINE';
```

## Example 6: Manage Server-Level Certificates (TDE)

Use when working with Transparent Data Encryption.

```sql
CREATE CERTIFICATE MyServerCert WITH SUBJECT = 'My TDE Certificate';
```

## Example 7: Access Restricted File Paths

Use when reading/writing to paths restricted to SYSTEM/Administrators.

```sql
EXEC xp_cmdshell 'dir C:\ProtectedFolder', NO_OUTPUT;
```

## Example 8: Always On AG Operations

Use when joining database to AG or failing over.

```sql
ALTER DATABASE MyDB SET HADR AVAILABILITY GROUP = MyAG;
```

## Example 9: Server Audit Operations

Use when creating/modifying server-level audits.

```sql
CREATE SERVER AUDIT MyAudit TO FILE (FILEPATH = 'C:\AuditLogs\');
```

---

> **Security Note**: Always wrap privileged operations with `EXECUTE AS` / `REVERT`. Never leave a session elevated longer than necessary. Audit usage of SA impersonation.
