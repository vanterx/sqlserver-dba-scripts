# Script Index

## PowerShell Scripts (5 files)

| Script | Path | Description |
|--------|------|-------------|
| copy_jobs_to_secondary.ps1 | ps/dbatools/ | Copy SQL Agent jobs from primary replica to all secondary replicas in an AG |
| sqlcmd_runner_v2.ps1 | ps/ | SQLCMD runner v2 |
| sqlcmd_runner_v3.ps1 | ps/ | SQLCMD runner v3 |
| server_registration.ps1 | ps/ | Server registration script |
| powershell_monitor.ps1 | ps/ | PowerShell monitoring script |

## SQL Scripts (88 files)

### agent (3 files)

| Script | Description |
|--------|-------------|
| agentjob_running_time.sql | Monitor SQL Agent job execution times |
| agent_job_status_update.sql | Update SQL Agent job status |
| sqljob_average_runtime.sql | Calculate average runtime for SQL jobs |

### availability (5 files)

| Script | Description |
|--------|-------------|
| alwayson_connection_details.sql | Always On connection monitoring |
| alwayson_diagnostics.sql | Always On diagnostic utilities |
| alwayson_extendedevent_details.sql | Extended event monitoring for AG |
| hadr_automatic_seeding.sql | Automatic seeding configuration |
| mirroring_alwayson_endpoint.sql | Endpoint management |

### backup (6 files)

| Script | Description |
|--------|-------------|
| backup_eta_query.sql | Backup completion time estimation |
| backup_frequency_query.sql | Backup frequency analysis |
| backup_history_query.sql | Backup history reporting |
| backup_last_details.sql | Last backup details |
| backup_utilities.sql | General backup utilities |
| email_backup_history.sql | Email backup notifications |

### restore (2 files)

| Script | Description |
|--------|-------------|
| restore_history.sql | Restore history tracking |
| restore_suspect_database.sql | Suspect database recovery |

### drive (4 files)

| Script | Description |
|--------|-------------|
| DriveSpace_ps.sql | PowerShell-based drive space monitoring |
| drive_space_details.sql | Detailed drive space analysis |
| db_disk_space.sql | Database disk space monitoring |
| db_log_file_space.sql | Database log file space monitoring |

### configuration (8 files)

**alerts (2 files)**

| Script | Description |
|--------|-------------|
| configure_alerts.sql | SQL Server Agent alert configuration |
| configure_serverside_trace.sql | Server-side trace setup |

**mail (1 file)**

| Script | Description |
|--------|-------------|
| configure_dbmail.sql | Database Mail configuration |

**growth (4 files)**

| Script | Description |
|--------|-------------|
| autogrowth_settings.sql | Database autogrowth configuration |
| configure_data_movement.sql | Data movement settings |
| configure_restrict_io.sql | I/O restriction configuration |
| database_growth_settings.sql | Database growth management |

**credentials (1 file)**

| Script | Description |
|--------|-------------|
| create_sas_backup_credential.sql | SAS backup credential creation |

### monitoring (8 files)

**transactions (1 file)**

| Script | Description |
|--------|-------------|
| monitor_transactions.sql | Transaction monitoring and analysis |

**blocking (1 file)**

| Script | Description |
|--------|-------------|
| head_blocker.sql | Head blocker analysis and resolution |

**database_health (3 files)**

| Script | Description |
|--------|-------------|
| database_size_monitor.sql | Database size monitoring |
| database_state_monitor.sql | Database state monitoring |
| log_reuse_wait_monitor.sql | Log reuse wait analysis |

**progress (1 file)**

| Script | Description |
|--------|-------------|
| monitor_progress.sql | Operation progress tracking |

**root level (2 files)**

| Script | Description |
|--------|-------------|
| alwayson_status_monitor.sql | Always On status monitoring |
| cpu_scheduler_monitor.sql | CPU scheduler monitoring |

### performance (11 files)

**memory (4 files)**

| Script | Description |
|--------|-------------|
| memory_calculator.sql | Max server memory calculator |
| check_memory_settings.sql | Memory configuration validation |
| sql05_virtualmemory.sql | SQL 2005 virtual memory analysis |
| worker_threads.sql | Worker thread monitoring |

**cpu (2 files)**

| Script | Description |
|--------|-------------|
| cpu_consuming_queries.sql | CPU-intensive query identification |
| recent_expensive_queries.sql | Expensive query analysis |

**queries (1 file)**

| Script | Description |
|--------|-------------|
| redundant_queries.sql | Redundant query detection |

**connections (1 file)**

| Script | Description |
|--------|-------------|
| connections_details.sql | Connection monitoring and analysis |

**features (2 files)**

| Script | Description |
|--------|-------------|
| enterprise_features_query.sql | Enterprise features monitoring |
| azure_tde_keyvault_details.sql | Azure TDE and KeyVault details |

**resource_governor (1 file)**

| Script | Description |
|--------|-------------|
| resource_governor_throttle_io.sql | Resource Governor I/O throttling |

### security (6 files)

| Script | Description |
|--------|-------------|
| cleanup_logins.sql | Invalid login cleanup |
| database_permissions_query.sql | Database permissions analysis |
| database_permissions_usp.sql | Permissions stored procedure |
| database_orphaned_users.sql | Orphaned user detection |
| generate_dbo_authorization.sql | DBO authorization generation |
| sp_help_revlogin.sql | Login transfer between servers |

### troubleshooting (7 files)

| Script | Description |
|--------|-------------|
| check_sql_backup.sql | SQL backup validation |
| extended_events_failing_queries.sql | Extended events for failing queries |
| kill_connections.sql | Connection termination utility |
| ms_errorlog_syshealth.sql | Error log and system health analysis |
| read_errorlog.sql | Error log reading utilities |
| repair_suspect_database.sql | Suspect database repair |
| spn_check.sql | SPN validation |

### utilities (23 files)

**scripts (6 files)**

| Script | Description |
|--------|-------------|
| generate_credproxy.sql | Credential proxy generation |
| generate_database_growth.sql | Database growth script generation |
| generate_index_script.sql | Index script generation |
| generate_registered_servers.sql | Registered servers script |
| generate_schema_transfer.sql | Schema transfer script |
| generate_shrink_log.sql | Log shrink script generation |

**examples (2 files)**

| Script | Description |
|--------|-------------|
| simple_cursor.sql | Simple cursor example |
| while_loop_example.sql | While loop example |

**diagnostics (3 files)**

| Script | Description |
|--------|-------------|
| dbcc_lastknowngood.sql | DBCC last known good |
| default_trace_cursor.sql | Default trace cursor utilities |
| default_trace_details.sql | Default trace details |

**system (3 files)**

| Script | Description |
|--------|-------------|
| datetime_cheat_sheet.sql | DateTime functions reference |
| machine_powerplan.sql | Power plan configuration |
| map_network_drive.sql | Network drive mapping |

**file_operations (9 files)**

| Script | Description |
|--------|-------------|
| fileobject_modified_time.sql | File modification time tracking |
| forwardedrecord_details.sql | Forwarded record analysis |
| fulltextstatus_details.sql | Full-text status monitoring |
| msdtc_activity_details.sql | MSDTC activity monitoring |
| orphaned_datalog_files.sql | Orphaned data log file detection |
| replication_immediate_sync.sql | Replication immediate sync |
| storedproc_search.sql | Stored procedure search |
| storedproc_search_query.sql | Stored procedure query search |
| xp_delete_file.sql | File deletion utility |

---

## Summary

| Category | Count |
|----------|-------|
| PowerShell | 5 |
| SQL | 88 |
| **Total** | **93** |

## Quick Search

Use `Ctrl+F` (or `Cmd+F` on Mac) to search this index by script name or keyword.

For category-specific search, look at the section headers above.