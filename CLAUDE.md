# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo Type

This is a DBA scripts and tools collection — not a traditional software project. There is no build pipeline, package manager, or formal test suite. Scripts are manually executed against SQL Server instances.

## Environment

- **Platform**: Windows-only (PowerShell + SQL Server T-SQL)
- **PowerShell version**: 5.1+ required; some scripts use ThreadJob/PoshRSJob for parallel processing
- **Required module**: `dbatools` — install with `Install-Module dbatools -Scope CurrentUser`

## Running Scripts

```powershell
# Run a PowerShell script
powershell -NoProfile -File ps\script.ps1

# Validate PowerShell syntax without executing
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content file.ps1 -Raw), [ref]$null)
```

SQL scripts are executed directly in SSMS or via `sqlcmd` / `Invoke-DbaQuery`. No compilation or deployment step exists.

## Repository Structure

```
sql/
  agent/          SQL Agent job monitoring
  availability/   Always On AG, HADR, database mirroring
  backup/         Backup operations and history queries
  restore/        Recovery and restore scripting
  drive/          Disk space and storage management
  configuration/  Alerts, Database Mail, growth settings, credentials
  monitoring/     Active transactions, blocking, health checks, CPU
  performance/    Memory, query plans, resource governor, waits
  security/       Logins, permissions, orphaned users
  troubleshooting/ Error logs, extended events, DBCC repair
  utilities/      General-purpose diagnostics and helper scripts
ps/
  dbatools/       AG-targeted automation using the dbatools module
docs/             Study guides and certification notes
```

## Key Conventions

**T-SQL scripts:**
- All scripts begin with `SET NOCOUNT ON`
- Section headers use `-- ============` comment blocks
- Dynamic SQL uses `sp_executesql` with typed parameters
- Queries target `sys.*` DMVs and `msdb` system database
- Use `BIGINT` for file size calculations (avoids arithmetic overflow)
- Use `NULLIF` on divisors to prevent divide-by-zero

**PowerShell scripts:**
- `$ErrorActionPreference = "Stop"` at the top
- Use `-WhatIf` switches on destructive operations
- Configure dbatools connection settings via `Set-DbatoolsConfig` before connecting
- `ps/dbatools/` scripts are specifically designed for SQL Server AG (Availability Group) environments

## Elevated Permission Pattern

`execute_as_sa.sql` at the repo root is a template for running commands under the `sa` context using `EXECUTE AS LOGIN`. Use this pattern when a script requires elevated permissions not available to the current login.

## Script Index

`script_index.md` lists all ~93 scripts with descriptions. Consult it first when looking for an existing script before writing a new one.
