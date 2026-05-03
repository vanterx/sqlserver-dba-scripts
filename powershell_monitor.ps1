# =============================================================================
# PowerShell Monitor Reference Script
# Collection of useful DBA/system monitoring commands
# Use as reference - copy/paste commands as needed
# =============================================================================

# =============================================================================
# SECTION 1: ENVIRONMENT & SYSTEM INFO
# =============================================================================

# Get all environment variables
# Shows system paths, user info, temp directories, etc.
Get-ChildItem env:

# Get current computer name from $env variable
$env:COMPUTERNAME

# Get PowerShell version info
$PSVersionTable.PSVersion

# =============================================================================
# SECTION 2: NETWORK & DNS
# =============================================================================

# Resolve IP address to hostname
# Useful when you only have IP and need to identify the server
[system.net.dns]::gethostentry('10.10.10.1')

# Test TCP port connectivity with timeout
# Syntax: New-Object System.Net.Sockets.TcpClient.ConnectAsync('hostname', port).Wait(timeout_ms)
Invoke-Command -ComputerName TST01 -ScriptBlock {
    $env:COMPUTERNAME + ' - Port 139 : ' +
    (New-Object System.Net.Sockets.TcpClient).ConnectAsync('destination', 139).Wait(1000)
}

# =============================================================================
# SECTION 3: EVENT LOG QUERIES
# =============================================================================

# Get recent system reboots
# EventID 1074 = System shutdown initiated by user/process
# Shows: MachineName, Username, TimeGenerated
Get-EventLog -LogName System -Newest 10000 |
    Where-Object { $_.eventid -eq '1074' } |
    Select-Object MachineName, UserName, TimeGenerated |
    Sort-Object TimeGenerated -Descending

# Get specific service restart time
# Example: Computer Browser service restart
Get-EventLog -LogName "System" -Source "Service Control Manager" `
    -EntryType "Information" `
    -Message "*Computer Browser service*running*" `
    -Newest 1

# Query event logs within a date/time range
$Begin = Get-Date -Date '12/10/2020 04:30:00'
$End = Get-Date -Date '12/10/2020 05:30:00'

# Check different event log types
Get-EventLog -LogName System -After $Begin -Before $End
Get-EventLog -LogName Application -After $Begin -Before $End
Get-EventLog -LogName Setup -After $Begin -Before $End

# Get Security log failures only (show in GridView for easy review)
Get-EventLog -LogName Security -After $Begin -Before $End |
    Where-Object { $_.EntryType -eq 'FailureAudit' } |
    Out-GridView

# =============================================================================
# SECTION 4: SERVER CONNECTIVITY MONITORING
# =============================================================================

# Continuous ping monitor with logging
# Monitors list of servers and logs timeouts to file
$server = @('s1', 's2')
while ($true) {
    $server | ForEach-Object {
        if (-not (Test-Connection $PSItem -Count 1 -Quiet)) {
            Write-Output "$($PSItem) : $(Get-Date) - Request Timed Out" |
                Out-File C:\_tools\S_log.txt -Append
        }
    }
}

# PSPing with timestamp logging (requires PSPing tool)
# Measures latency to SQL Server port 1433
.\psping.exe -t SQL01:1433 | ForEach-Object {
    "{0} - {1}" -f (Get-Date), $_
} | Tee-Object -FilePath "C:\Log\SQL01_log.txt"

# =============================================================================
# SECTION 5: FILE & DIRECTORY OPERATIONS
# =============================================================================

# Find all .exe files in SQL Server install directory
Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Filter *.exe -Recurse |
    ForEach-Object { $_.FullName }

# Find files older than 180 days in a drive (show in GridView)
Get-ChildItem "K:\" -Filter "*.*" -Recurse -File |
    Where-Object CreationTime -LT (Get-Date).AddDays(-180) |
    Select-Object fullname, creationtime |
    Out-GridView

# Find .bak files older than 20 days with size in GB (GridView output)
Get-ChildItem "J:\" -Filter "*.bak" -Recurse -File |
    Where-Object CreationTime -LT (Get-Date).AddDays(-20) |
    Select-Object fullname, creationtime,
        @{ N = 'SizeIngb'; E = { [double]('{0:N2}' -f ($_.Length / 1gb)) } } |
    Out-GridView

# Remove empty directories (dry run with -WhatIf first!)
Get-ChildItem -Recurse -Directory |
    Where-Object { -not ($_.EnumerateFiles('*', 1) | Select-Object -First 1) } |
    Remove-Item -Recurse -WhatIf

# =============================================================================
# SECTION 6: TEXT SEARCH IN FILES
# =============================================================================

# Search for text pattern in all files under a directory
# Exports results to CSV for analysis
Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server\" -Filter "*.*" -Recurse |
    Select-String -Pattern "Exception" |
    Select-Object -Property Path, LineNumber, Line |
    Export-Csv "C:\temp\Result.csv"

# =============================================================================
# SECTION 7: LARGE FILE Finder
# =============================================================================

# Find files larger than specified size, older than X days
# Parameters: path, size threshold, date limit, file extension, row limit
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

# =============================================================================
# SECTION 8: WINDOWS CLUSTER OPERATIONS
# =============================================================================

# Get cluster subnet configuration
Get-Cluster | Format-List *subnet*

# Set cluster subnet settings for AG/failover
# SameSubnetDelay = milliseconds ( heartbeat interval)
# SameSubnetThreshold = number of missed heartbeats before failover
(Get-Cluster).SameSubnetDelay = 2000
(Get-Cluster).SameSubnetThreshold = 10

# Rename cluster resource (e.g., SQL Network Name)
Get-ClusterResource "SQL Network Name (XXXXXXXXX)" | ForEach-Object {
    $_.Name = "YYYYYYYYYYY"
}

# Configure AG for multi-subnet failover
# RegisterAllProvidersIP = 0 (register only active IP)
# HostRecordTTL = seconds (DNS TTL for failover)
Get-ClusterResource ag01 | Set-ClusterParameter RegisterAllProvidersIP 0
Get-ClusterResource ag01 | Set-ClusterParameter HostRecordTTL 30

# List all cluster parameters for all resources
$cn = Get-ClusterResource | Select-Object Name
$cn | ForEach-Object {
    Get-ClusterResource $cn.Name | Get-ClusterParameter
}

# =============================================================================
# SECTION 9: MODULE OPERATIONS
# =============================================================================

# Download and save PowerShell module locally (offline use)
$wc = New-Object System.Net.WebClient
$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

Find-Module -Name "azurerm.storage" -Repository "PSGallery" |
    Save-Module -Path "C:\temp\PSModules\" -Verbose

# =============================================================================
# SECTION 10: ELEVATED EXECUTION
# =============================================================================

# Run script/command as Administrator
# Uses automatic variable to reference current script path
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process -Verb runAs -ArgumentList $arguments -FilePath "C:\test.exe"

# =============================================================================
# SECTION 11: ACTIVE DIRECTORY OPERATIONS
# =============================================================================

# Reset AD user password
$user = 'username'
$newPass = 'NewPassword123!'
Set-ADAccountPassword -Identity $user -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force)

# =============================================================================
# SECTION 12: USEFUL ONE-LINERS (Copy/Paste as needed)
# =============================================================================

# Get last boot time
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object LastBootUpTime

# Get system uptime
(Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

# List running services
Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object Name, DisplayName

# Get disk space info
Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}}, @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,2)}}

# Get IP configuration
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway

# Test network connectivity to multiple servers
Test-NetConnection -ComputerName "server1", "server2" -Port 1433 | Select-Object ComputerName, RemotePort, TcpTestSucceeded

# =============================================================================
# NOTES:
# - Use Out-GridView for interactive data review
# - Use Export-Csv to save results for documentation
# - Use -WhatIf with Remove-Item to preview before deleting
# - Use -ErrorAction "SilentlyContinue" to suppress errors on inaccessible paths
# - Use Tee-Object to display and log simultaneously
# =============================================================================