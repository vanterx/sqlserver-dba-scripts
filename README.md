## Essential DBA Tools & Resources

### Community Tools
- **[DBATools](https://dbatools.io/)** - sqlcollaborative
- **[MSSQL Performance Skills](https://github.com/vanterx/mssql-performance-skills)** - Performance tuning resources
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
- **[ThreadJob](https://github.com/Microsoft/ThreadJob)** - PowerShell parallel processing (PS 5.1+)
- **[PoshRSJob](https://github.com/proxb/PoshRSJob)** - Runspace-based parallel jobs

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