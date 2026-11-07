#Requires -Version 5.1
<#[.SYNOPSIS
    Write one LOCAL LAB JSON record to localhost SQL Server after explicit confirmation.
]#>
[CmdletBinding()]
param([string]$ConfigPath,[Parameter(Mandatory)][string]$RecordId,[switch]$Apply,[string]$ConfirmEnvironment)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($ConfigPath)){
    $ConfigPath=Join-Path $PSScriptRoot '..\examples\config.sample.json'
}
if(-not $Apply -or $ConfirmEnvironment -cne 'LAB'){
    throw 'Uso permitido apenas com -Apply -ConfirmEnvironment LAB em SQL Server local.'
}
Import-Module (Join-Path $PSScriptRoot '..\src\BackupOperations.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\src\SqlLabRepository.psm1') -Force
$config=Read-BackupConfiguration -Path $ConfigPath
$entries=@(Get-LabBackupEntries -Configuration $config | Where-Object Id -eq $RecordId)
if($entries.Count -ne 1){throw 'ID nao encontrado entre registros locais de laboratorio.'}
$count=Save-BackupLabSqlEntry -Configuration $config -Entry $entries[0] -Apply -ConfirmEnvironment LAB
Write-Host "$count registro SQL inserido em BackupPortfolioLab (localhost)."
