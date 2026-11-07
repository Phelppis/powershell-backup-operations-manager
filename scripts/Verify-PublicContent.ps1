#Requires -Version 5.1
# Basic hygiene; this is not a comprehensive secret or IP audit.
[CmdletBinding()]
param([string]$Root)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($Root)){$Root=Join-Path $PSScriptRoot '..'}
$files=@(Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -in @('.ps1','.psm1','.json','.md','.sql') -and $_.FullName -ne $PSCommandPath
})
# Local identifiers from the original source are intentionally NOT included here.
$patternSecrets=@('BEGIN (RSA |OPENSSH )?PRIVATE KEY','AKIA[0-9A-Z]{16}','(?i)(?:password|senha)\s*[:=]\s*["'']\S{8,}')
foreach($file in $files){
    $content=Get-Content -LiteralPath $file.FullName -Raw
    foreach($pattern in $patternSecrets){
        if($content -match $pattern){throw "Possivel credencial em $($file.Name)"}
    }
}
Write-Host "Verificacao basica concluida: $($files.Count) arquivos. Auditoria manual ainda necessaria."
