#Requires -Version 5.1
# Independent portfolio sample. No company endpoints or deletion functionality.
Set-StrictMode -Version Latest
$script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))

function Assert-BackupIdentifier {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)
    if ($Value -notmatch '^[A-Za-z][A-Za-z0-9_-]{1,39}$') {
        throw "Identificador invalido: '$Value'. Use letras, numeros, hifen e underscore."
    }
    return $Value
}

function Resolve-BackupLabPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or
        $RelativePath -match '^[\\/]{2}') {
        throw 'O laboratorio nao aceita caminhos absolutos, UNC ou navegacao por ..'
    }
    $full = [System.IO.Path]::GetFullPath((Join-Path -Path $script:RepositoryRoot -ChildPath $RelativePath))
    $rootPrefix = $script:RepositoryRoot.TrimEnd([char[]]@('\','/')) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'O caminho precisa permanecer dentro do repositorio.'
    }
    return $full
}

function Read-BackupConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Configuracao nao encontrada: $Path"
    }
    $cfg = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $cfg -or [string]$cfg.environment -cne 'LAB') {
        throw 'Esta demonstracao aceita somente environment = LAB.'
    }
    if ([string]$cfg.backupRoot -cne 'lab-storage' -or
        [string]$cfg.dataFile -notmatch '^lab-data[/\\][A-Za-z0-9_-]+\.json$') {
        throw 'Os caminhos permitidos sao lab-storage e lab-data/*.json.'
    }
    if (@($cfg.sites).Count -lt 1 -or @($cfg.components).Count -lt 1) {
        throw 'Informe pelo menos um site e um componente na configuracao.'
    }
    foreach ($site in @($cfg.sites)) { $null = Assert-BackupIdentifier -Value ([string]$site) }
    foreach ($component in @($cfg.components)) { $null = Assert-BackupIdentifier -Value ([string]$component) }
    $cfg | Add-Member -NotePropertyName ResolvedBackupRoot -NotePropertyValue (Resolve-BackupLabPath -RelativePath ([string]$cfg.backupRoot)) -Force
    $cfg | Add-Member -NotePropertyName ResolvedDataFile -NotePropertyValue (Resolve-BackupLabPath -RelativePath ([string]$cfg.dataFile)) -Force
    return $cfg
}

function Assert-BackupChoice {
    param([string]$Value,[string[]]$Allowed,[string]$Label)
    if ($Value -cnotin $Allowed) { throw "$Label nao permitido: $Value" }
}

function New-BackupEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string]$Site,
        [Parameter(Mandatory)][string]$Component,
        [Parameter(Mandatory)][ValidateSet('Local','Remoto')][string]$Type,
        [Parameter(Mandatory)][ValidateSet('Total','Parcial')][string]$Format,
        [Parameter(Mandatory)][datetime]$BackupDate,
        [string]$Ticket = '',
        [string]$Notes = '',
        [string]$Operator = $env:USERNAME
    )
    Assert-BackupChoice -Value $Site -Allowed @($Configuration.sites) -Label 'Site'
    Assert-BackupChoice -Value $Component -Allowed @($Configuration.components) -Label 'Componente'
    if ($Ticket.Length -gt 60 -or $Notes.Length -gt 500) { throw 'Ticket ou observacoes excedem o tamanho permitido.' }
    if ([string]::IsNullOrWhiteSpace($Operator)) { $Operator = 'OperadorLab' }
    return [pscustomobject]@{
        Id           = [guid]::NewGuid().ToString()
        Site         = $Site
        Component    = $Component
        Type         = $Type
        Format       = $Format
        BackupDate   = $BackupDate.Date.ToString('yyyy-MM-dd')
        Ticket       = $Ticket.Trim()
        Notes        = $Notes.Trim()
        Operator     = $Operator
        RegisteredAt = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Get-BackupDestination {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration,[Parameter(Mandatory)]$Entry)
    Assert-BackupChoice -Value ([string]$Entry.Site) -Allowed @($Configuration.sites) -Label 'Site'
    Assert-BackupChoice -Value ([string]$Entry.Component) -Allowed @($Configuration.components) -Label 'Componente'
    Assert-BackupChoice -Value ([string]$Entry.Format) -Allowed @('Total','Parcial') -Label 'Formato'
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse([string]$Entry.Id,[ref]$parsedId)) { throw 'ID invalido no registro.' }
    $root = [string]$Configuration.ResolvedBackupRoot
    $tier = if ([string]$Entry.Component -eq 'Rede') { 'Rede' } else { [string]$Entry.Format }
    $destination = Join-Path -Path $root -ChildPath $tier
    $destination = Join-Path -Path $destination -ChildPath ([string]$Entry.Site)
    $destination = Join-Path -Path $destination -ChildPath ([string]$Entry.Component)
    $day = ([datetime]::ParseExact([string]$Entry.BackupDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)).ToString('yyyyMMdd')
    return Join-Path -Path $destination -ChildPath ("{0}_{1}_{2}" -f $day,([string]$Entry.Id).Substring(0,8),$Entry.Format)
}

function Get-SampleBackupEntries {
    [CmdletBinding()]
    param()
    $file = Join-Path -Path $script:RepositoryRoot -ChildPath 'examples\records.sample.json'
    if (-not (Test-Path -LiteralPath $file)) { throw 'Arquivo de dados demonstrativos ausente.' }
    $records = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($record in @($records)) { Write-Output $record }
}

function Get-LabBackupEntries {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration)
    $file = [string]$Configuration.ResolvedDataFile
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return }
    $raw = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return }
    $records = ConvertFrom-Json -InputObject $raw
    foreach ($record in @($records)) { Write-Output $record }
}

function Get-BackupEntries {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration,[switch]$OnlyLocal)
    if (-not $OnlyLocal) { Get-SampleBackupEntries }
    Get-LabBackupEntries -Configuration $Configuration
}

function Save-LabBackupEntry {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration,[Parameter(Mandatory)]$Entry,
          [switch]$Apply,[string]$ConfirmEnvironment)
    $destination = Get-BackupDestination -Configuration $Configuration -Entry $Entry
    if (-not $Apply) {
        return [pscustomobject]@{ Mode='PREVIEW'; Destination=$destination; Entry=$Entry }
    }
    if ($ConfirmEnvironment -cne 'LAB' -or [string]$Configuration.environment -cne 'LAB') {
        throw 'Gravacao bloqueada: informe -Apply -ConfirmEnvironment LAB.'
    }
    $file = [string]$Configuration.ResolvedDataFile
    $dir = Split-Path -Path $file -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }
    $items = @(Get-LabBackupEntries -Configuration $Configuration)
    if (@($items | Where-Object { $_.Id -eq $Entry.Id }).Count -gt 0) {
        throw 'Ja existe um registro com este ID.'
    }
    $items = @($items) + @($Entry)
    $json = ConvertTo-Json -InputObject @($items) -Depth 6
    $tmp = Join-Path -Path $dir -ChildPath ('.records-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tmp -Destination $file -Force
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
    return [pscustomobject]@{ Mode='LAB-METADATA'; Destination=$destination; Entry=$Entry }
}

function Get-BackupReport {
    [CmdletBinding()]
    param([object[]]$Entries=@(), [datetime]$StartDate=[datetime]::MinValue,
          [datetime]$EndDate=[datetime]::MaxValue,[string]$Site='Todas')
    if ($StartDate.Date -gt $EndDate.Date) { throw 'A data inicial nao pode ser maior que a final.' }
    foreach ($entry in @($Entries | Sort-Object { [datetime]$_.RegisteredAt } -Descending)) {
        $d = ([datetime]$entry.BackupDate).Date
        if ($d -lt $StartDate.Date -or $d -gt $EndDate.Date) { continue }
        if ($Site -ne 'Todas' -and [string]$entry.Site -ne $Site) { continue }
        Write-Output $entry
    }
}

function Get-BackupRetentionPreview {
    [CmdletBinding()]
    param([object[]]$Entries=@(),[int]$Keep=3)
    if ($Keep -lt 1 -or $Keep -gt 50) { throw 'Keep deve ser entre 1 e 50.' }
    $groups = @($Entries | Group-Object { "$($_.Site)|$($_.Component)|$($_.Format)" })
    foreach ($group in $groups) {
        $sorted = @($group.Group | Sort-Object { [datetime]$_.BackupDate }, { [datetime]$_.RegisteredAt } -Descending)
        for ($i=0; $i -lt $sorted.Count; $i++) {
            $e=$sorted[$i]
            $status = if ($i -lt $Keep) { 'Manter' } else { 'Revisar (nao exclui)' }
            [pscustomobject]@{
                Site=$e.Site; Component=$e.Component; Format=$e.Format
                BackupDate=$e.BackupDate; Id=$e.Id; Result=$status
            }
        }
    }
}

function Protect-BackupCsvValue {
    param([AllowNull()][object]$Value)
    $str=[string]$Value
    if ($str -match '^\s*[=+@-]') { return "'" + $str }
    return $str
}

function Export-BackupCsv {
    [CmdletBinding()]
    param([object[]]$Entries=@(),[Parameter(Mandatory)][string]$Path)
    $columns=@('Id','Site','Component','Type','Format','BackupDate','Ticket','Notes','Operator','RegisteredAt')
    $rows=@(foreach($entry in @($Entries)){
        $row=[ordered]@{}
        foreach($column in $columns){$row[$column]=Protect-BackupCsvValue -Value $entry.$column}
        [pscustomobject]$row
    })
    if($rows.Count -eq 0) { throw 'Nao existem registros para exportar.' }
    $rows | Export-Csv -LiteralPath $Path -Delimiter ';' -NoTypeInformation -Encoding UTF8
    return $Path
}

function ConvertTo-BackupHtmlReport {
    [CmdletBinding()]
    param([object[]]$Entries=@(),[string]$Title='Relatorio de Backups')
    $sb=New-Object System.Text.StringBuilder
    $null=$sb.AppendLine('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">')
    $null=$sb.AppendLine('<title>Relatorio de Backups</title><style>body{font-family:Segoe UI,Arial,sans-serif;margin:30px;color:#1f2937}table{border-collapse:collapse;width:100%}td,th{border:1px solid #cbd5e1;padding:8px;text-align:left}th{background:#e2e8f0}h1{margin-bottom:4px}small{color:#64748b}</style></head><body>')
    $null=$sb.AppendLine('<h1>'+[System.Net.WebUtility]::HtmlEncode($Title)+'</h1><small>Relatorio demonstrativo. Sem dados corporativos.</small>')
    $cols=@('Site','Component','Type','Format','BackupDate','Ticket','Notes','Operator')
    $null=$sb.AppendLine('<table><thead><tr>')
    foreach($col in $cols){$null=$sb.AppendLine('<th>'+[System.Net.WebUtility]::HtmlEncode($col)+'</th>')}
    $null=$sb.AppendLine('</tr></thead><tbody>')
    foreach($entry in @($Entries)){
        $null=$sb.AppendLine('<tr>')
        foreach($col in $cols){$null=$sb.AppendLine('<td>'+[System.Net.WebUtility]::HtmlEncode([string]$entry.$col)+'</td>')}
        $null=$sb.AppendLine('</tr>')
    }
    $null=$sb.AppendLine('</tbody></table><p><small>Para PDF, use Imprimir &gt; Salvar como PDF no navegador.</small></p></body></html>')
    return $sb.ToString()
}

Export-ModuleMember -Function Assert-BackupIdentifier,Resolve-BackupLabPath,Read-BackupConfiguration,New-BackupEntry,Get-BackupDestination,Get-SampleBackupEntries,Get-LabBackupEntries,Get-BackupEntries,Save-LabBackupEntry,Get-BackupReport,Get-BackupRetentionPreview,Export-BackupCsv,ConvertTo-BackupHtmlReport
