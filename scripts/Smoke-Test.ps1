#Requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..'
$preview=& (Join-Path $root 'gui\Start-BackupGui.ps1') -ValidateOnly
if($preview.Environment -ne 'LAB' -or $preview.Records -lt 1){throw 'GUI headless validation failed.'}
& (Join-Path $root 'BackupOperations.ps1') -Action Retention | Out-Null
& (Join-Path $root 'BackupOperations.ps1') | Out-Null
Write-Host "PowerShell $($PSVersionTable.PSVersion): smoke test OK ($($preview.Records) demo records, $($preview.RetentionCandidates) retention candidates)."
