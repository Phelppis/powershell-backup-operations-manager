#Requires -Version 5.1
<#
.SYNOPSIS
    Portfolio CLI: view sample backups, retention simulation or register lab-only metadata.
.EXAMPLE
    .\BackupOperations.ps1
.EXAMPLE
    .\BackupOperations.ps1 -Action Retention
.EXAMPLE
    .\BackupOperations.ps1 -Action Register -Site LAB-NORTE -Component Banco -Type Local -Format Total -Apply -ConfirmEnvironment LAB
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [ValidateSet('Report','Retention','Register')][string]$Action='Report',
    [string]$Site='LAB-NORTE',
    [string]$Component='Banco',
    [ValidateSet('Local','Remoto')][string]$Type='Local',
    [ValidateSet('Total','Parcial')][string]$Format='Total',
    [datetime]$BackupDate=(Get-Date),
    [string]$Ticket='',
    [string]$Notes='',
    [switch]$Apply,
    [string]$ConfirmEnvironment
)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath=Join-Path $PSScriptRoot 'examples\config.sample.json'
}
Import-Module (Join-Path $PSScriptRoot 'src\BackupOperations.psm1') -Force
$config=Read-BackupConfiguration -Path $ConfigPath
switch($Action) {
    'Report' {
        @(Get-BackupEntries -Configuration $config) |
            Select-Object Site,Component,Type,Format,BackupDate,Ticket,Operator |
            Format-Table -AutoSize
        Write-Host 'Visualizacao demonstrativa; nenhuma alteracao realizada.' -ForegroundColor Cyan
    }
    'Retention' {
        $entries=@(Get-BackupEntries -Configuration $config)
        Get-BackupRetentionPreview -Entries $entries -Keep 3 |
            Select-Object Site,Component,Format,BackupDate,Result |
            Format-Table -AutoSize
        Write-Host 'Retencao apenas simulada: nenhum arquivo sera excluido.' -ForegroundColor Yellow
    }
    'Register' {
        $entry=New-BackupEntry -Configuration $config -Site $Site -Component $Component -Type $Type `
            -Format $Format -BackupDate $BackupDate -Ticket $Ticket -Notes $Notes
        if ($Apply -and $ConfirmEnvironment -cne 'LAB') {
            throw 'Gravacao bloqueada. Use -Apply -ConfirmEnvironment LAB somente em laboratorio.'
        }
        $result=Save-LabBackupEntry -Configuration $config -Entry $entry -Apply:$Apply -ConfirmEnvironment $ConfirmEnvironment
        $result | Format-List Mode,Destination
        if (-not $Apply) { Write-Host 'PREVIEW ONLY. Para salvar metadados locais, informe -Apply -ConfirmEnvironment LAB.' -ForegroundColor Yellow }
        else { Write-Host 'Metadados salvos localmente. Nenhum backup real foi executado e nenhuma pasta foi apagada.' -ForegroundColor Green }
    }
}
