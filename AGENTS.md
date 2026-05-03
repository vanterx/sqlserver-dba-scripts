# AGENTS.md

## Repo Type
DBA Scripts & Tools collection - not a traditional software project with build/test pipelines.

## Key Directories
- `ps/` - PowerShell scripts (includes dbatools automation)
- `sql/` - SQL scripts and queries
- `docs/` - Documentation and notes

## Important Commands
- dbatools module required for many PowerShell scripts: `Install-Module dbatools -Scope CurrentUser`
- ThreadJob/PoshRSJob for PS 5.x parallel processing
- Standard PowerShell execution: `powershell -NoProfile -File script.ps1`

## Testing Notes
- No formal test suite exists - scripts are manually executed
- Validate PowerShell syntax: `$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content file -Raw), [ref]$null)`

## Community Tools Referenced (in README)
- DBATools: https://dbatools.io/
- Ola Hallengren Maintenance: https://ola.hallengren.com/
- sp_whoisactive: http://whoisactive.com/
- Brent Ozar First Responder Kit

## Special Considerations
- PS scripts in `ps/dbatools/` target SQL Server AG environments
- SQL scripts include operational queries and maintenance procedures
- Windows-only (PowerShell/SQL Server context)