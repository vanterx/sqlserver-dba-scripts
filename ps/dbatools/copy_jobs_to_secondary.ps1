param(
    [Parameter(Mandatory=$true)]
    [string]$AvailabilityGroupName,

    [string]$SqlInstance,

    [string[]]$ExcludeJobs = @(),

    [switch]$TrustServerCertificate,

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Error "dbatools module is required. Install with: Install-Module dbatools -Scope CurrentUser"
    return
}

Import-Module dbatools

if ($TrustServerCertificate) {
    Set-DbatoolsConfig -Name 'sql.connection.trustcert' -Value $true -Quiet
    Set-DbatoolsConfig -Name 'sql.connection.allowtrustcert' -Value $true -Quiet
}

if ($SqlInstance) {
    $ag = Get-DbaAvailabilityGroup -SqlInstance $SqlInstance -AvailabilityGroup $AvailabilityGroupName
} else {
    $ag = Get-DbaAvailabilityGroup -AvailabilityGroup $AvailabilityGroupName
}

if (-not $ag) {
    Write-Error "Availability Group '$AvailabilityGroupName' not found."
    return
}

$primaryReplica = $ag.PrimaryReplica
$secondaryReplicas = $ag.Replicas | Where-Object { $_.Role -ne 'Primary' } | Select-Object -ExpandProperty Name

if (-not $secondaryReplicas) {
    Write-Warning "No secondary replicas found in availability group '$AvailabilityGroupName'."
    return
}

Write-Host "Primary Replica: $primaryReplica"
Write-Host "Secondary Replicas: $($secondaryReplicas -join ', ')"

$jobs = Get-DbaAgentJob -SqlInstance $primaryReplica | Where-Object { $ExcludeJobs -notcontains $_.Name }

foreach ($secondary in $secondaryReplicas) {
    Write-Host "`nCopying jobs to $secondary..."

    $jobs | ForEach-Object {
        $jobName = $_.Name

        if ($WhatIf) {
            Write-Host "  [WhatIf] Would copy job: $jobName"
        } else {
            Copy-DbaAgentJob -Source $primaryReplica -Destination $secondary -Job $jobName -Force
            Write-Host "  Copied job: $jobName"
        }
    }
}

Write-Host "`nDone."