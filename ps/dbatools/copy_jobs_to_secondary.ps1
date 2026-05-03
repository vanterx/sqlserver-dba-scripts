<#
.SYNOPSIS
    Copies SQL Agent jobs from primary replica to all secondary replicas in an Always On Availability Group.

.DESCRIPTION
    This script retrieves all SQL Agent jobs from the primary replica of an Availability Group
    and copies them to all secondary replicas. It uses dbatools' Copy-DbaAgentJob function which
    automatically handles job dependencies, categories, and schedules.

    The script is useful for:
    - Ensuring SQL Agent jobs exist on all AG replicas after failover
    - Synchronizing maintenance jobs across AG nodes
    - Deploying new jobs to multiple replicas

.PARAMETER AvailabilityGroupName
    The name of the Always On Availability Group. This parameter is mandatory.

.PARAMETER SqlInstance
    The SQL Server instance to query for Availability Group information.
    If not specified, uses localhost or searches across all reachable instances.

.PARAMETER ExcludeJobs
    An array of job names to exclude from copying.
    Default: @() (no exclusions)

.PARAMETER TrustServerCertificate
    Switch to enable TrustServerCertificate for SQL connections.
    Use this when connecting to instances with self-signed certificates.

.PARAMETER WhatIf
    Switch to preview what jobs would be copied without actually copying them.
    Shows which jobs would be copied to each secondary replica.

.EXAMPLE
    .\copy_jobs_to_secondary.ps1 -AvailabilityGroupName "AG_Production"

    Copies all jobs from the primary replica to all secondaries in AG_Production.

.EXAMPLE
    .\copy_jobs_to_secondary.ps1 -AvailabilityGroupName "AG_Production" -SqlInstance "PrimaryServer"

    Copies jobs using a specific SQL instance to find the AG.

.EXAMPLE
    .\copy_jobs_to_secondary.ps1 -AvailabilityGroupName "AG_Production" -ExcludeJobs @("JobToSkip","AnotherJob")

    Copies all jobs except the specified ones.

.EXAMPLE
    .\copy_jobs_to_secondary.ps1 -AvailabilityGroupName "AG_Production" -WhatIf

    Preview which jobs would be copied without making any changes.

.EXAMPLE
    .\copy_jobs_to_secondary.ps1 -AvailabilityGroupName "AG_Production" -TrustServerCertificate

    Copy jobs with self-signed certificate trust enabled.

.NOTES
    File Name      : copy_jobs_to_secondary.ps1
    Prerequisite   : dbatools module - Install with: Install-Module dbatools -Scope CurrentUser
    SQL Version    : SQL Server 2012+ with Always On Availability Groups
    Author         : DBA Tools Collection
    Last Updated   : 2026-05-03

    Requirements:
    - dbatools module must be installed
    - sysadmin or equivalent permissions on all AG replicas
    - SQL Agent must be running on all replicas
    - Target server must have the same job owner logins (or use -Force to set owner to sa)

    What Copy-DbaAgentJob handles automatically:
    - Job dependencies (databases, logins, proxies, operators)
    - Job categories (creates if missing on destination)
    - Job schedules
    - Job steps and configurations

    Limitations:
    - Does not copy jobs associated with Maintenance Plans
    - Jobs requiring server-specific credentials may need adjustment after copy
    - Does not handle linked server job steps automatically
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AvailabilityGroupName,

    [string]$SqlInstance,

    [string[]]$ExcludeJobs = @(),

    [switch]$TrustServerCertificate,

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Check for dbatools module
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Error "dbatools module is required. Install with: Install-Module dbatools -Scope CurrentUser"
    return
}

Import-Module dbatools

# Configure TrustServerCertificate if requested
if ($TrustServerCertificate) {
    Set-DbatoolsConfig -Name 'sql.connection.trustcert' -Value $true -Quiet
    Set-DbatoolsConfig -Name 'sql.connection.allowtrustcert' -Value $true -Quiet
}

# Get Availability Group information
if ($SqlInstance) {
    $ag = Get-DbaAvailabilityGroup -SqlInstance $SqlInstance -AvailabilityGroup $AvailabilityGroupName
} else {
    $ag = Get-DbaAvailabilityGroup -AvailabilityGroup $AvailabilityGroupName
}

if (-not $ag) {
    Write-Error "Availability Group '$AvailabilityGroupName' not found."
    return
}

# Identify primary and secondary replicas
$primaryReplica = $ag.PrimaryReplica
$secondaryReplicas = $ag.Replicas | Where-Object { $_.Role -ne 'Primary' } | Select-Object -ExpandProperty Name

if (-not $secondaryReplicas) {
    Write-Warning "No secondary replicas found in availability group '$AvailabilityGroupName'."
    return
}

Write-Host "Primary Replica: $primaryReplica"
Write-Host "Secondary Replicas: $($secondaryReplicas -join ', ')"

# Get jobs from primary replica (excluding specified jobs)
$jobs = Get-DbaAgentJob -SqlInstance $primaryReplica | Where-Object { $ExcludeJobs -notcontains $_.Name }

Write-Host "Found $($jobs.Count) jobs to copy"

# Copy jobs to each secondary replica
foreach ($secondary in $secondaryReplicas) {
    Write-Host "`nCopying jobs to $secondary..."

    $jobs | ForEach-Object {
        $jobName = $_.Name
        Write-Host "  Processing job: $jobName"
        Copy-DbaAgentJob -Source $primaryReplica -Destination $secondary -Job $jobName -Force -WhatIf:$WhatIf
    }
}

Write-Host "`nDone."