# PowerShell Monitor Reference Script

Collection of useful DBA and system monitoring commands for PowerShell. Use as reference — copy/paste commands as needed.

---

## 1. Environment & System Info

### Get all environment variables

Shows system paths, user info, temp directories, etc.

```powershell
Get-ChildItem env:
```

### Get current computer name

```powershell
$env:COMPUTERNAME
```

### Get PowerShell version info

```powershell
$PSVersionTable.PSVersion
```

---

## 2. Network & DNS

### Resolve IP address to hostname

```powershell
[System.Net.Dns]::GetHostEntry('10.10.10.1')
```

### Test TCP port connectivity with timeout

```powershell
Invoke-Command -ComputerName TST01 -ScriptBlock {
    $env:COMPUTERNAME + ' - Port 139 : ' +
    (New-Object System.Net.Sockets.TcpClient).ConnectAsync('destination', 139).Wait(1000)
}
```

---

## 3. Event Log Queries

### Get recent system reboots

EventID 1074 = System shutdown initiated by user/process.

```powershell
Get-EventLog -LogName System -Newest 10000 |
    Where-Object { $_.eventid -eq '1074' } |
    Select-Object MachineName, UserName, TimeGenerated |
    Sort-Object TimeGenerated -Descending
```

### Get specific service restart time

```powershell
Get-EventLog -LogName "System" -Source "Service Control Manager" `
    -EntryType "Information" `
    -Message "*Computer Browser service*running*" `
    -Newest 1
```

### Query event logs within a date/time range

```powershell
$Begin = Get-Date -Date '12/10/2020 04:30:00'
$End = Get-Date -Date '12/10/2020 05:30:00'

Get-EventLog -LogName System -After $Begin -Before $End
Get-EventLog -LogName Application -After $Begin -Before $End
Get-EventLog -LogName Setup -After $Begin -Before $End

# Security log failures only (show in GridView)
Get-EventLog -LogName Security -After $Begin -Before $End |
    Where-Object { $_.EntryType -eq 'FailureAudit' } |
    Out-GridView
```

---

## 4. Server Connectivity Monitoring

### Continuous ping monitor with logging

```powershell
$server = @('s1', 's2')
while ($true) {
    $server | ForEach-Object {
        if (-not (Test-Connection $PSItem -Count 1 -Quiet)) {
            Write-Output "$($PSItem) : $(Get-Date) - Request Timed Out" |
                Out-File C:\_tools\S_log.txt -Append
        }
    }
}
```

### PSPing with timestamp logging (requires PSPing tool)

```powershell
.\psping.exe -t SQL01:1433 | ForEach-Object {
    "{0} - {1}" -f (Get-Date), $_
} | Tee-Object -FilePath "C:\Log\SQL01_log.txt"
```

---

## 5. File & Directory Operations

### Find all .exe files in SQL Server install directory

```powershell
Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Filter *.exe -Recurse |
    ForEach-Object { $_.FullName }
```

### Find files older than 180 days

```powershell
Get-ChildItem "K:\" -Filter "*.*" -Recurse -File |
    Where-Object CreationTime -LT (Get-Date).AddDays(-180) |
    Select-Object fullname, creationtime |
    Out-GridView
```

### Find .bak files older than 20 days with size in GB

```powershell
Get-ChildItem "J:\" -Filter "*.bak" -Recurse -File |
    Where-Object CreationTime -LT (Get-Date).AddDays(-20) |
    Select-Object fullname, creationtime,
        @{ N = 'SizeIngb'; E = { [double]('{0:N2}' -f ($_.Length / 1gb)) } } |
    Out-GridView
```

### Remove empty directories

> **Always run with `-WhatIf` first** to preview before deleting.

```powershell
Get-ChildItem -Recurse -Directory |
    Where-Object { -not ($_.EnumerateFiles('*', 1) | Select-Object -First 1) } |
    Remove-Item -Recurse -WhatIf
```

---

## 6. Text Search in Files

Search for text pattern in all files under a directory. Exports results to CSV.

```powershell
Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server\" -Filter "*.*" -Recurse |
    Select-String -Pattern "Exception" |
    Select-Object -Property Path, LineNumber, Line |
    Export-Csv "C:\temp\Result.csv"
```

---

## 7. Large File Finder

Find files larger than specified size, older than X days.

```powershell
$path = "\\servername\d$"
$size = 1MB
$limit = 500
$Extension = "*.bak"

$largeSizefiles = Get-ChildItem -Path $path -Recurse -ErrorAction "SilentlyContinue" -Include $Extension |
    Where-Object { $_.GetType().Name -eq "FileInfo" } |
    Where-Object { $_.Length -gt $size } |
    Where-Object CreationTime -LT (Get-Date).AddDays(-7) |
    Sort-Object -Property length -Descending |
    Select-Object fullname, creationtime,
        @{ Name = "SizeInGB"; Expression = { $_.Length / 1GB } },
        @{ Name = "Path"; Expression = { $_.Directory } } -First $limit

$largeSizefiles | Out-GridView
```

---

## 8. Windows Cluster Operations

### Get cluster subnet configuration

```powershell
Get-Cluster | Format-List *subnet*
```

### Set cluster subnet settings for AG/failover

```powershell
(Get-Cluster).SameSubnetDelay = 2000        # milliseconds (heartbeat interval)
(Get-Cluster).SameSubnetThreshold = 10       # number of missed heartbeats before failover
```

### Rename cluster resource

```powershell
Get-ClusterResource "SQL Network Name (XXXXXXXXX)" | ForEach-Object {
    $_.Name = "YYYYYYYYYYY"
}
```

### Configure AG for multi-subnet failover

```powershell
Get-ClusterResource ag01 | Set-ClusterParameter RegisterAllProvidersIP 0  # register only active IP
Get-ClusterResource ag01 | Set-ClusterParameter HostRecordTTL 30           # DNS TTL in seconds
```

### List all cluster parameters for all resources

```powershell
$cn = Get-ClusterResource | Select-Object Name
$cn | ForEach-Object {
    Get-ClusterResource $cn.Name | Get-ClusterParameter
}
```

---

## 9. Module Operations

Download and save PowerShell module locally for offline use.

```powershell
$wc = New-Object System.Net.WebClient
$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

Find-Module -Name "azurerm.storage" -Repository "PSGallery" |
    Save-Module -Path "C:\temp\PSModules\" -Verbose
```

---

## 10. Elevated Execution

Run script/command as Administrator.

```powershell
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process -Verb runAs -ArgumentList $arguments -FilePath "C:\test.exe"
```

---

## 11. Active Directory Operations

Reset AD user password.

```powershell
$user = 'username'
$newPass = 'NewPassword123!'
Set-ADAccountPassword -Identity $user -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force)
```

---

## 12. Useful One-Liners

### Get last boot time

```powershell
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object LastBootUpTime
```

### Get system uptime

```powershell
(Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
```

### List running services

```powershell
Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object Name, DisplayName
```

### Get disk space info

```powershell
Get-Volume | Where-Object { $_.DriveLetter } |
    Select-Object DriveLetter,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},
        @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,2)}}
```

### Get IP configuration

```powershell
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway
```

### Test network connectivity to multiple servers

```powershell
Test-NetConnection -ComputerName "server1", "server2" -Port 1433 |
    Select-Object ComputerName, RemotePort, TcpTestSucceeded
```

---

## Tips

- Use `Out-GridView` for interactive data review
- Use `Export-Csv` to save results for documentation
- Use `-WhatIf` with `Remove-Item` to preview before deleting
- Use `-ErrorAction "SilentlyContinue"` to suppress errors on inaccessible paths
- Use `Tee-Object` to display and log simultaneously
