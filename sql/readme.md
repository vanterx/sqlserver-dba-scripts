# Welcome - DBA Scripts and Links

## Essential DBA Tools & Resources

### Community Tools
- **[DBATools](https://dbatools.io/)** - sqlcollaborative
- **[sp_whoisactive](http://whoisactive.com/downloads/)** - Adam Machanic
- **[SQL Server Maintenance](https://ola.hallengren.com/downloads.html)** - Ola Hallengren
- **[sp_blitz*](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/releases)** - Brent Ozar Unlimited
- **[Dynamic Management Views](https://sqlserverperformance.wordpress.com/)** - Glenn Berry
- **[sp_pressure_detector](https://github.com/erikdarlingdata/DarlingData/tree/master/sp_pressure_detector)** - Erik Darling
- **[sp_RestoreScriptGenie](https://paulbrewer.wordpress.com/sp_restoregene/)** - Paul Brewer
- **[How's My Plan?](http://www.howsmyplan.com/)** - Daniel Janik
- **[Statistics Parser](http://statisticsparser.com/)** - Richie Rump
- **[sp_srvpermissions & sp_dbpermissions](https://github.com/sqlstudent144/SQL-Server-Scripts)** - Kenneth Fisher
- **[Blocking_Alert](https://am2.co/2017/12/alerting-sql-server-blocking/)** - Andy M Mallon

### Microsoft Tools
- **[MissingMsi](https://docs.microsoft.com/en-US/troubleshoot/sql/install/restore-missing-windows-installer-cache-files)**
- **[SqlNexus](https://github.com/Microsoft/SqlNexus)**
- **[tigertoolbox](https://github.com/Microsoft/tigertoolbox)**
- **[SQLServerTiger Blog](https://techcommunity.microsoft.com/t5/SQL-Server/bg-p/SQLServer/label-name/SQLServerTiger)**
- **[Reporting-Services](https://github.com/Microsoft/Reporting-Services)**
- **[DiagManager](https://github.com/Microsoft/DiagManager)**
- **[kerberos configuration manager](https://www.microsoft.com/en-us/download/details.aspx?id=39046)**
- **[sp_help_revlogin](https://support.microsoft.com/en-nz/help/918992/how-to-transfer-logins-and-passwords-between-instances-of-sql-server)**

### Additional Tools
- **[CurrPorts](http://www.nirsoft.net/utils/cports.html#DownloadLinks)**
- **[SqlMax](http://sqlmax.chuvash.eu/)** - SQL Max Memory Calculator
- **[NetSPI_PS](https://github.com/NetSPI/Powershell-Modules)** - MSSQL Credentials
- **[dba-multitool](https://github.com/LowlyDBA/dba-multitool)**
- **[WorkloadTools](https://github.com/spaghettidba/WorkloadTools)**

---

## Performance Monitoring

### Key SQL Server Performance Counters
```
Memory - Available MBytes
Physical Disk - Avg. Disk sec/Read
Physical Disk - Avg. Disk sec/Write
Physical Disk - Disk Reads/sec
Physical Disk - Disk Writes/sec
Processor - % Processor Time
SQLServer: General Statistics - User Connections
SQLServer: Memory Manager - Memory Grants Pending
SQLServer: SQL Statistics - Batch Requests/sec
SQLServer: SQL Statistics - Compilations/sec
SQLServer: SQL Statistics - Recompilations/sec
System - Processor Queue Length
```

### Performance Data Collection Commands
```bash
# Create performance counter log
logman.exe create counter Perf-Log -o "C:\PerfLogs\Admin\Perf-Log" -f bincirc -v mmddhhmm -max 500 -c "\Memory\Available MBytes" "\PhysicalDisk(*)\Avg. Disk sec/Read" "\PhysicalDisk(*)\Avg. Disk sec/Write" "\PhysicalDisk(*)\Disk Reads/sec" "\PhysicalDisk(*)\Disk Writes/sec" "\Processor(_Total)\% Processor Time" "\SQLServer:General Statistics\User Connections" "\SQLServer:Memory Manager\Memory Grants Pending" "\SQLServer:SQL Statistics\Batch Requests/sec" "\SQLServer:SQL Statistics\SQL Compilations/sec" "\SQLServer:SQL Statistics\SQL Re-Compilations/sec" "\System\Processor Queue Length"  -si 00:00:01

# Start performance logging
logman start Perf-Log

# Stop performance logging
logman stop Perf-Log

# Convert binary log to CSV
relog C:\PerfLogs\Admin\Perf-Log_000001.blg /o C:\Perflogs\Admin\Reduced_Log_000001.csv /f csv
```

---

# DBA SQL Scripts Collection

A comprehensive collection of SQL Server administration scripts organized by purpose for easy navigation and maintenance.

## Overview

This repository contains **83 SQL scripts** organized into **11 main categories** with **24 specialized subcategories**, providing maximum granularity for finding the right script for any DBA task.

## Folder Structure

### Main Categories (11 folders)

#### **agent/** (3 files)
SQL Agent management and job monitoring scripts
- `agentjob_running_time.sql` - Monitor SQL Agent job execution times
- `sqljob_average_runtime.sql` - Calculate average runtime for SQL jobs
- `agent_job_status_update.sql` - Update SQL Agent job status

#### **availability/** (5 files)
High availability, Always On, and HADR management scripts
- `alwayson_connection_details.sql` - Always On connection monitoring
- `alwayson_diagnostics.sql` - Always On diagnostic utilities
- `alwayson_extendedevent_details.sql` - Extended event monitoring
- `hadr_automatic_seeding.sql` - Automatic seeding configuration
- `mirroring_alwayson_endpoint.sql` - Endpoint management

#### **backup/** (6 files)
Backup operations and utilities
- `backup_eta_query.sql` - Backup completion time estimation
- `backup_frequency_query.sql` - Backup frequency analysis
- `backup_history_query.sql` - Backup history reporting
- `backup_last_details.sql` - Last backup details
- `backup_utilities.sql` - General backup utilities
- `email_backup_history.sql` - Email backup notifications

#### **restore/** (2 files)
Database restore operations and recovery
- `restore_history.sql` - Restore history tracking
- `restore_suspect_database.sql` - Suspect database recovery

#### **drive/** (4 files)
Storage and drive management scripts
- `DriveSpace_ps.sql` - PowerShell-based drive space monitoring
- `drive_space_details.sql` - Detailed drive space analysis
- `db_disk_space.sql` - Database disk space monitoring
- `db_log_file_space.sql` - Database log file space monitoring

#### **configuration/** (8 files)
Server and database configuration scripts

**alerts/** (2 files)
- `configure_alerts.sql` - SQL Server Agent alert configuration
- `configure_serverside_trace.sql` - Server-side trace setup

**mail/** (1 file)
- `configure_dbmail.sql` - Database Mail configuration

**growth/** (4 files)
- `autogrowth_settings.sql` - Database autogrowth configuration
- `configure_data_movement.sql` - Data movement settings
- `configure_restrict_io.sql` - I/O restriction configuration
- `database_growth_settings.sql` - Database growth management

**credentials/** (1 file)
- `create_sas_backup_credential.sql` - SAS backup credential creation

#### **monitoring/** (8 files)
Database monitoring and health checks

**transactions/** (1 file)
- `monitor_transactions.sql` - Transaction monitoring and analysis

**blocking/** (1 file)
- `head_blocker.sql` - Head blocker analysis and resolution

**database_health/** (3 files)
- `database_size_monitor.sql` - Database size monitoring
- `database_state_monitor.sql` - Database state monitoring
- `log_reuse_wait_monitor.sql` - Log reuse wait analysis

**progress/** (1 file)
- `monitor_progress.sql` - Operation progress tracking

**Root level** (2 files)
- `alwayson_status_monitor.sql` - Always On status monitoring
- `cpu_scheduler_monitor.sql` - CPU scheduler monitoring

#### **performance/** (11 files)
Performance tuning and resource monitoring

**memory/** (4 files)
- `memory_calculator.sql` - Max server memory calculator
- `check_memory_settings.sql` - Memory configuration validation
- `sql05_virtualmemory.sql` - SQL 2005 virtual memory analysis
- `worker_threads.sql` - Worker thread monitoring

**cpu/** (2 files)
- `cpu_consuming_queries.sql` - CPU-intensive query identification
- `recent_expensive_queries.sql` - Expensive query analysis

**queries/** (1 file)
- `redundant_queries.sql` - Redundant query detection

**connections/** (1 file)
- `connections_details.sql` - Connection monitoring and analysis

**features/** (2 files)
- `enterprise_features_query.sql` - Enterprise features monitoring
- `azure_tde_keyvault_details.sql` - Azure TDE and KeyVault details

**resource_governor/** (1 file)
- `resource_governor_throttle_io.sql` - Resource Governor I/O throttling

#### **security/** (6 files)
Security management and access control
- `cleanup_logins.sql` - Invalid login cleanup
- `database_permissions_query.sql` - Database permissions analysis
- `database_permissions_usp.sql` - Permissions stored procedure
- `database_orphaned_users.sql` - Orphaned user detection
- `generate_dbo_authorization.sql` - DBO authorization generation
- `sp_help_revlogin.sql` - Login transfer between servers

#### **troubleshooting/** (7 files)
Diagnostic and repair utilities
- `check_sql_backup.sql` - SQL backup validation
- `extended_events_failing_queries.sql` - Extended events for failing queries
- `kill_connections.sql` - Connection termination utility
- `ms_errorlog_syshealth.sql` - Error log and system health analysis
- `read_errorlog.sql` - Error log reading utilities
- `repair_suspect_database.sql` - Suspect database repair
- `spn_check.sql` - SPN validation

#### **utilities/** (23 files)
General utility scripts and helpers

**scripts/** (6 files)
- `generate_credproxy.sql` - Credential proxy generation
- `generate_database_growth.sql` - Database growth script generation
- `generate_index_script.sql` - Index script generation
- `generate_registered_servers.sql` - Registered servers script
- `generate_schema_transfer.sql` - Schema transfer script
- `generate_shrink_log.sql` - Log shrink script generation

**examples/** (2 files)
- `simple_cursor.sql` - Simple cursor example
- `while_loop_example.sql` - While loop example

**diagnostics/** (3 files)
- `dbcc_lastknowngood.sql` - DBCC last known good
- `default_trace_cursor.sql` - Default trace cursor utilities
- `default_trace_details.sql` - Default trace details

**system/** (3 files)
- `datetime_cheat_sheet.sql` - DateTime functions reference
- `machine_powerplan.sql` - Power plan configuration
- `map_network_drive.sql` - Network drive mapping

**file_operations/** (9 files)
- `fileobject_modified_time.sql` - File modification time tracking
- `forwardedrecord_details.sql` - Forwarded record analysis
- `fulltextstatus_details.sql` - Full-text status monitoring
- `msdtc_activity_details.sql` - MSDTC activity monitoring
- `orphaned_datalog_files.sql` - Orphaned data log file detection
- `replication_immediate_sync.sql` - Replication immediate sync
- `storedproc_search.sql` - Stored procedure search
- `storedproc_search_query.sql` - Stored procedure query search
- `xp_delete_file.sql` - File deletion utility

## Navigation Tips

### Finding Scripts by Purpose

1. **Backup/Restore Operations**:
   - Use `backup/` for backup-related tasks
   - Use `restore/` for recovery operations

2. **Performance Issues**:
   - `performance/memory/` for memory-related problems
   - `performance/cpu/` for CPU-intensive queries
   - `performance/queries/` for query optimization
   - `drive/` for storage capacity issues

3. **Monitoring**:
   - `monitoring/transactions/` for transaction issues
   - `monitoring/blocking/` for blocking problems
   - `monitoring/database_health/` for general health checks

4. **Security Tasks**:
   - `security/` for all login, permission, and user management

5. **Configuration**:
   - `configuration/alerts/` for alert setup
   - `configuration/mail/` for email configuration
   - `configuration/growth/` for autogrowth settings

6. **Troubleshooting**:
   - `troubleshooting/` for diagnostic and repair utilities

7. **Script Generation**:
   - `utilities/scripts/` for automated script generation
   - `utilities/examples/` for learning and reference

## File Naming Conventions

All files follow standardized naming conventions:
- Use lowercase with underscores
- Descriptive names indicating purpose
- Category prefixes for easy identification
- Version suffixes for multiple versions (e.g., `_v2`, `_v3`)

## Statistics

- **Total Scripts**: 83 files
- **Main Categories**: 11 folders
- **Specialized Subcategories**: 24 folders
- **Largest Category**: utilities/ (23 files)
- **Most Granular**: performance/ (6 subcategories)

## Version Information

- **Branch**: `main`
- **Latest Commit**: `fec2e9f`
- **Organization Date**: April 10, 2026

## Usage Guidelines

1. **Script Execution**: Always test scripts in non-production environments first
2. **Permissions**: Ensure appropriate permissions before running administrative scripts
3. **Backups**: Take backups before running configuration or repair scripts
4. **Documentation**: Review script comments for specific usage instructions
5. **Version Compatibility**: Check SQL Server version compatibility for each script

## Contributing

When adding new scripts:
1. Place in the appropriate category/subcategory
2. Follow the naming conventions
3. Include descriptive comments
4. Update this README if new categories are created

---

*This README provides comprehensive navigation for the DBA SQL Scripts Collection while preserving the original DBA resources and links. For specific script usage, refer to individual file comments and documentation.*