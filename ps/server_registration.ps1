<#
.SYNOPSIS
    Creates SQL Server registered servers in SSMS from an INI-style text file.

.DESCRIPTION
    This script parses a text file containing SQL Server names organized in folders
    and sub-folders, then creates registered server entries in SSMS's Central Management
    Server (CMS) or local server registration groups.

    The input file format is:
        [FolderName]
        [FolderName\SubFolder]
        server1
        server2

    Lines starting with ; or # are treated as comments.

.PARAMETER IniFilePath
    Path to the text file containing server registrations.
    Default: C:\TS\server.txt

.PARAMETER RegistrationGroup
    The target registration group in SSMS.
    Default: Database Engine Server Group
    Options: "Database Engine Server Group", "Central Management Server Group\ServerName"

.PARAMETER Credential
    SQL Server authentication credential (username/password).
    If not specified, uses Windows integrated authentication.

.PARAMETER CleanFirst
    Switch to remove existing registrations in the target group before creating new ones.
    Use with -Confirm to preview what will be deleted.

.PARAMETER WhatIf
    Shows what would be created without making any changes.

.PARAMETER Confirm
    Prompts for confirmation before destructive operations (cleaning up registrations).

.EXAMPLE
    .\server_registration.ps1 -IniFilePath "C:\TS\servers.txt"

    Creates registrations from servers.txt using integrated security.

.EXAMPLE
    .\server_registration.ps1 -IniFilePath "C:\TS\servers.txt" -CleanFirst -WhatIf

    Preview what would be cleaned and created without making changes.

.EXAMPLE
    .\server_registration.ps1 -IniFilePath "C:\TS\servers.txt" -Credential (Get-Credential)

    Creates registrations using SQL Server authentication.

.NOTES
    File Name      : server_registration.ps1
    Prerequisite   : SQLPS module (SQL Server PowerShell)
    SQL Version    : SQL Server 2012+
    Author         : DBA Tools Collection

    Input file format example:
        ; This is a comment
        [Production]
        ProdServer1
        ProdServer2

        [Production\Databases]
        ProdDB01
        ProdDB02

        [Staging]
        StagingServer1
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$false)]
    [string]$IniFilePath = "C:\TS\server.txt",

    [Parameter(Mandatory=$false)]
    [string]$RegistrationGroup = "Database Engine Server Group",

    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

$ErrorActionPreference = "Stop"

# =============================================================================
# PRE-REQUISITE CHECKS
# =============================================================================

# Check for SQLPS module (SQL Server PowerShell)
if (-not (Get-Module -ListAvailable -Name SQLPS -ErrorAction SilentlyContinue)) {
    Write-Error "SQLPS module is required. Please run this script from SSMS or import SQLPS module."
    return
}

# Check if running in SQL Server PowerShell window (optional check)
$isSqlPsContext = $PSContext -or (Get-PSDrive -Name SQLServer -ErrorAction SilentlyContinue)
if (-not $isSqlPsContext) {
    Import-Module SQLPS -DisableNameChecking -ErrorAction Stop
}

# Validate INI file exists
if (-not (Test-Path -LiteralPath $IniFilePath)) {
    Write-Error "INI file not found: $IniFilePath"
    return
}

Write-Host "Reading server registrations from: $IniFilePath" -ForegroundColor Cyan

# =============================================================================
# PART 1: Parse the INI file
# =============================================================================

$serverList = @()
$currentFolder = '.'

# Parse file line by line
Get-Content -LiteralPath $IniFilePath | ForEach-Object {
    $line = $_.Trim()

    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($line)) {
        return
    }

    # Skip comment lines (starting with ; or #)
    if ($line -match '^[;#]') {
        return
    }

    # Match folder (no backslash): [FolderName]
    if ($line -match '^\[(\w+[^\\])\]$') {
        $currentFolder = $Matches[1]
        $serverList += [PSCustomObject]@{
            ParentFolder = '.'
            Type = 'Directory'
            Value = $currentFolder
        }
        Write-Verbose "Found folder: $currentFolder"
        return
    }

    # Match sub-folder (with backslash): [Folder\SubFolder]
    if ($line -match '^\[(\w+\\.+)\]$') {
        $parentFolder = Split-Path -Path $Matches[1] -Parent
        $folderName = Split-Path -Path $Matches[1] -Leaf
        $currentFolder = $Matches[1]
        $serverList += [PSCustomObject]@{
            ParentFolder = $parentFolder
            Type = 'Directory'
            Value = $folderName
        }
        Write-Verbose "Found sub-folder: $folderName under $parentFolder"
        return
    }

    # Match server entry (non-empty, non-comment, non-bracket line)
    if ($line -match '^\s*(?![;#\[])(.+)' -and $Matches[1].Trim() -ne '') {
        $serverName = $Matches[1].Trim()
        $serverList += [PSCustomObject]@{
            ParentFolder = $currentFolder
            Type = 'Registration'
            Value = $serverName
        }
        Write-Verbose "Found server: $serverName"
        return
    }
}

Write-Host "Parsed $($serverList.Count) items ($($serverList.Where({$_.Type -eq 'Directory'}).Count) folders, $($serverList.Where({$_.Type -eq 'Registration'}).Count) servers)"

if ($serverList.Count -eq 0) {
    Write-Warning "No valid entries found in INI file."
    return
}

# =============================================================================
# PART 2: Clean up existing registrations (if requested)
# =============================================================================

$registrationPath = "SQLServer:\SqlRegistration\$($RegistrationGroup)"

if ($CleanFirst) {
    if (Test-Path -LiteralPath $registrationPath) {
        Write-Warning "Existing registrations will be removed from: $RegistrationGroup"
        if ($PSCmdlet.ShouldProcess($RegistrationGroup, "Remove all existing registrations")) {
            Set-Location -LiteralPath $registrationPath
            Get-ChildItem -Recurse | Remove-Item -Recurse -Force
            Write-Host "Existing registrations cleaned." -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# PART 3: Create folders and registered servers
# =============================================================================

if (-not (Test-Path -LiteralPath $registrationPath)) {
    Write-Error "Registration group path not found: $registrationPath"
    return
}

Set-Location -LiteralPath $registrationPath

$createdFolders = @()
$createdServers = @()
$errors = @()

foreach ($item in $serverList) {
    try {
        if ($item.Type -eq 'Directory') {
            # Create folder
            $folderPath = if ($item.ParentFolder -eq '.') {
                $registrationPath
            } else {
                "$registrationPath\$($item.ParentFolder)"
            }

            if (-not (Test-Path -LiteralPath $folderPath)) {
                Write-Warning "Parent folder does not exist: $folderPath"
                continue
            }

            Set-Location -LiteralPath $folderPath

            if ($PSCmdlet.ShouldProcess($item.Value, "Create folder")) {
                $newFolder = New-Item -Path $item.Value -ItemType Directory -Force -ErrorAction Stop
                $createdFolders += $item.Value
                Write-Verbose "Created folder: $($item.Value)"
            }
        }
        else {
            # Create registered server
            $serverPath = "$registrationPath\$($item.ParentFolder)"
            $serverName = $item.Value.Replace("%5C", "\")
            $encodedName = Encode-SqlName -Name $serverName

            # Build connection string
            if ($Credential) {
                $connectionString = "Server=$serverName ; User ID=$($Credential.UserName) ; Password=$($Credential.GetNetworkCredential().Password)"
            } else {
                $connectionString = "Server=$serverName ; integrated security=true"
            }

            if ($PSCmdlet.ShouldProcess($serverName, "Register server")) {
                $newServer = New-Item -Name $encodedName -Path $serverPath -ItemType Registration -Value $connectionString -ErrorAction Stop
                $createdServers += $serverName
                Write-Host "  Registered: $serverName" -ForegroundColor Green
            }
        }
    }
    catch {
        $errors += [PSCustomObject]@{
            Item = $item.Value
            Error = $_.Exception.Message
        }
        Write-Warning "Failed to create '$($item.Value)': $($_.Exception.Message)"
    }
}

# =============================================================================
# PART 4: Summary
# =============================================================================

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
Write-Host "Folders created: $($createdFolders.Count)"
Write-Host "Servers registered: $($createdServers.Count)"

if ($errors.Count -gt 0) {
    Write-Warning "Errors encountered: $($errors.Count)"
    $errors | ForEach-Object { Write-Host "  - $($_.Item): $($_.Error)" }
}

# Return to original location
Set-Location -LiteralPath $registrationPath
Write-Host "`nDone."