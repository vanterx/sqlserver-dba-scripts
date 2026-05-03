# Windows & SQL Server DBA Command Reference

A mixed collection of Windows CMD, PowerShell, and netsh/fsutil commands commonly used by SQL Server DBAs for troubleshooting, configuration, and performance tuning.

> **Usage**: Most lines are NOT meant to be run as a single batch file. Copy individual commands into CMD or PowerShell as needed. PowerShell lines should be run in a PS prompt (not cmd.exe). Replace placeholder values before use.

> **Prerequisites**: Administrator rights for most commands, PowerShell 5.1+ recommended, RSAT for cluster/WMI queries, Sysinternals psping.exe for TCP latency testing.

> **Warnings**: Several commands modify system/network settings — test in non-prod first. The empty folder delete command (Section 7) removes folders in-place. The AD password reset via `xp_cmdshell` (Section 19) is logged.

---

## 1. Network & Port Diagnostics

### Check if an application is listening on a port

```cmd
@REM  Replace 1234 with the port number
netstat -ano | find "1234" | find "LISTEN"
```

### Get the process name for a given PID

```cmd
tasklist /fi "PID eq 1234"
```

### TCP latency test to SQL Server (Sysinternals psping)

```powershell
.\psping.exe -t SQL01:1433 | ForEach-Object { "{0} - {1}" -f (Get-Date), $_ } | Tee-Object -FilePath "C:\Log\SQL01_log.txt"
```

Runs continuously, timestamps output, and logs to file.

---

## 2. Software Installation

### Silent install of SQL Server Data Migration Assistant

```cmd
msiexec /i "DataMigrationAssistant.msi" INSTALLFOLDER="D:\Program Files (x86)\DataMigrationAssistant\" /qb
```

---

## 3. WiFi & Network Profiles

### Show stored WiFi profile including plaintext password (requires admin)

```cmd
netsh wlan show profile WiFiName key=clear
```

---

## 4. Server Connectivity Monitor

Continuously pings servers and logs failures with timestamps.

```powershell
$server = @('s1','s2')
while($true) {
    $server | ForEach-Object {
        if(-not(test-connection $PSItem -Count 1 -Quiet )){
            Write-Output "$($PSItem) : $(get-date) - Request Timed Out" |
            Out-File c:\_tools\S_log.txt -Append
        }
    }
}
```

---

## 5. SQL Server WMI Provider Registration

Re-register SQL Server WMI provider (fixes WMI-related SSMS errors). Path may vary by SQL Server version (130 = SQL 2016).

```cmd
mofcomp "C:\Program Files (x86)\Microsoft SQL Server\130\Shared\sqlmgmproviderxpsp2up.mof"
```

---

## 6. Event Log & Security Audit

Query Windows Event Logs within a specific time window.

```powershell
$Begin = Get-Date -Date '12/10/2020 04:30:00'
$End = Get-Date -Date '12/10/2020 05:30:00'

# System log
Get-EventLog -LogName System -After $Begin -Before $End

# Application log
Get-EventLog -LogName Application -After $Begin -Before $End

# Setup log
Get-EventLog -LogName Setup -After $Begin -Before $End

# Security log - failures only
Get-EventLog -LogName Security -After $Begin -Before $End | Where-Object {$_.EntryType -eq 'FailureAudit'} | Out-GridView
```

---

## 7. File System Operations

### Delete all empty subfolders recursively from the current script directory

> **WARNING**: Run from the correct directory — this deletes empty folders in-place.

```cmd
echo off
for /f "usebackq delims=" %%d in (`"dir "%~dp0" /ad/b/s | sort /R"`) do rd "%%d"
```

---

## 8. System Information

### Get system boot time

```cmd
systeminfo | find /i "Boot Time"
```

### Check PowerShell version

```powershell
$PSVersionTable.PSVersion
```

### Get computer name

```powershell
$env:computername
```

---

## 9. File Search

### Find SQL Server executable files

```powershell
Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Filter *.exe -Recurse | ForEach-Object { $_.FullName }
Get-ChildItem "C:\Program Files (x86)\Microsoft SQL Server" -Filter *.exe -Recurse | ForEach-Object { $_.FullName }
```

### Find old files (older than 180 days) on a drive

```powershell
Get-ChildItem "K:\" -Filter "*.*" -Recurse -File | Where CreationTime -lt (Get-Date).AddDays(-180) | Select-Object fullname, creationtime | Out-GridView
```

### Find old .bak files (older than 20 days) with size in GB

```powershell
Get-ChildItem "J:\" -Filter "*.bak" -Recurse -File | Where CreationTime -lt (Get-Date).AddDays(-20) | Select-Object fullname, creationtime, @{N='SizeIngb';E={[double]('{0:N2}' -f ($_.Length/1gb))}} | Out-GridView
```

### Advanced file search: large, old backup files

```powershell
$path = "\\d$"
$size = 1MB
$limit = 500
$Extension = "*.bak"

$largeSizefiles = Get-ChildItem -Path $path -Recurse -ErrorAction "SilentlyContinue" -Include $Extension |
    Where-Object { $_.GetType().Name -eq "FileInfo" } |
    Where-Object { $_.Length -gt $size } |
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) } |
    Sort-Object -Property Length -Descending |
    Select-Object fullname, creationtime, @{Name="SizeInGB";Expression={$_.Length / 1GB}}

$largeSizefiles | Out-GridView
```

---

## 10. Services Export

Export all Windows services to CSV for auditing.

```powershell
Get-WmiObject win32_service | Select-Object Name, DisplayName, State, PathName | Export-Csv -Path "C:\services.csv" -NoTypeInformation
```

---

## 11. File System & NTFS Information

### Get NTFS volume information (allocation unit size, etc.)

Useful for verifying 64K allocation unit size for data/tempdb drives.

```cmd
fsutil fsinfo ntfsinfo d:\tempdb
```

### Query volume block sizes across all NTFS drives

```powershell
$wql = "SELECT Label, Blocksize, Name FROM Win32_Volume WHERE FileSystem='NTFS'"
Get-WmiObject -Query $wql -ComputerName '.' | Select-Object Label, Blocksize, Name
```

---

## 12. Filestream & 8.3 Short Name Best Practices

Query, disable, and strip 8.3 short names (recommended for SQL data drives). Replace `F:` with the target drive letter.

```cmd
FSUTIL.EXE 8dot3name query F:
FSUTIL.EXE 8dot3name set F: 1
fsutil.exe 8dot3name strip /s /v F:
```

---

## 13. Windows Firewall

Enable WMI firewall rules (required for remote management/monitoring).

```cmd
netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes
```

---

## 14. Remote Session Management

```cmd
@REM  Query active sessions on a remote server
query session /server:SERVER_NAME

@REM  Reset a disconnected session (replace [ID] with session ID)
reset session [ID] /server:SERVER_NAME

@REM  Query users across multiple servers (reads from servers.txt)
for /f %i in (servers.txt) do query user *username* /server:%i
for /f %i in (servers.txt) do query session /server:%i
```

---

## 15. TCP/IP Tuning — Cluster & SQL Server Best Practices

### Show current TCP global settings

```cmd
netsh int tcp show global
```

### Disable features that can cause issues with SQL Server clustering

These should be disabled on SQL Server nodes per Microsoft best practices.

```cmd
Netsh int tcp set global chimney=disabled
Netsh int tcp set global netdma=disabled
netsh int ipv4 set global taskoffload=disabled
```

---

## 16. Windows Cluster Configuration

### Check and configure cluster subnet settings (for multi-subnet AG)

```powershell
get-cluster | fl *subnet*
(get-cluster).SameSubnetDelay = 2000
(get-cluster).SameSubnetThreshold = 10
```

### Rename a cluster network name resource

Replace `XXXXXXXXX` (current) and `YYYYYYYYY` (new) with actual values.

```powershell
Get-ClusterResource "SQL Network Name (XXXXXXXXX)" | ForEach-Object { $_.Name = "YYYYYYYYYYY" }
```

---

## 17. Always On AG — Multi-Subnet DNS Configuration

```powershell
@REM  View cluster resources
Get-ClusterResource

@REM  Get AG cluster resource parameters
Get-ClusterResource ag01 | Get-ClusterParameter

@REM  Disable RegisterAllProvidersIP (use 0 for multi-subnet AG with older clients)
Get-ClusterResource ag01 | Set-ClusterParameter RegisterAllProvidersIP 0

@REM  Set DNS TTL to 30 seconds for faster failover client reconnection
Get-ClusterResource ag01 | Set-ClusterParameter HostRecordTTL 30
```

---

## 18. PowerShell Module Management

### Configure proxy credentials for corporate networks

```powershell
$wc = New-Object System.Net.WebClient
$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
```

### Save a PowerShell module for offline/side-by-side installation

```powershell
Find-Module -Name "azurerm.storage" -Repository "PSGallery" | Save-Module -Path "C:\temp\PSModules\" -Verbose
```

### Show current PSModulePath

```powershell
$env:PSModulePath
```

---

## 19. Active Directory — Password Reset via xp_cmdshell

> **WARNING**: This command is logged in SQL error log and Windows security log.

```sql
exec xp_cmdshell 'powershell -command "([adsi]''WinNT://Domain/#USERNAME#,user'').ChangePassword(''oldpassword'',''newpassword'')"'
```

---

## 20. VMware — Balloon Driver Check

Check VMware balloon driver memory reclamation status.

```cmd
VMWareToolBoxCMD stat balloon
```
