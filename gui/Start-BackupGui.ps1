#Requires -Version 5.1
<#
.SYNOPSIS
    Portfolio WinForms UI: safe backup registry demo.
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\gui\Start-BackupGui.ps1
.EXAMPLE
    .\gui\Start-BackupGui.ps1 -ValidateOnly
.NOTES
    The UI never creates a real backup, removes files, or accesses employer systems.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$ValidateOnly,
    [switch]$EnableLabWrites
)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath=Join-Path $PSScriptRoot '..\examples\config.sample.json'
}
Import-Module (Join-Path $PSScriptRoot '..\src\BackupOperations.psm1') -Force
$config=Read-BackupConfiguration -Path $ConfigPath
if ($ValidateOnly) {
    $entries=@(Get-BackupEntries -Configuration $config)
    $preview=@(Get-BackupRetentionPreview -Entries $entries -Keep 3)
    [pscustomobject]@{Environment=$config.environment; Records=$entries.Count; RetentionCandidates=@($preview | Where-Object Result -ne 'Manter').Count; WritesEnabled=$false}
    return
}
if ($env:OS -ne 'Windows_NT') { throw 'A GUI requer Windows.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function New-UiLabel {
    param([string]$Text,[int]$X,[int]$Y,[int]$W=155)
    $c=New-Object System.Windows.Forms.Label
    $c.Text=$Text; $c.Location=New-Object System.Drawing.Point($X,$Y)
    $c.Size=New-Object System.Drawing.Size($W,22)
    return $c
}
function New-UiCombo {
    param([object[]]$Choices,[int]$X,[int]$Y,[int]$W=230)
    $c=New-Object System.Windows.Forms.ComboBox
    $c.Location=New-Object System.Drawing.Point($X,$Y)
    $c.Size=New-Object System.Drawing.Size($W,28)
    $c.DropDownStyle='DropDownList'
    $c.Items.AddRange([object[]]$Choices)
    if($c.Items.Count -gt 0){$c.SelectedIndex=0}
    return $c
}
function New-UiButton {
    param([string]$Text,[int]$X,[int]$Y,[int]$W=160)
    $c=New-Object System.Windows.Forms.Button
    $c.Text=$Text; $c.Location=New-Object System.Drawing.Point($X,$Y)
    $c.Size=New-Object System.Drawing.Size($W,36)
    $c.FlatStyle='Flat'
    $c.BackColor=[System.Drawing.Color]::FromArgb(35,112,103)
    $c.ForeColor=[System.Drawing.Color]::White
    return $c
}
function New-UiGrid {
    param([int]$X,[int]$Y,[int]$W,[int]$H)
    $g=New-Object System.Windows.Forms.DataGridView
    $g.Location=New-Object System.Drawing.Point($X,$Y)
    $g.Size=New-Object System.Drawing.Size($W,$H)
    $g.Anchor='Top,Bottom,Left,Right'
    $g.ReadOnly=$true
    $g.AllowUserToAddRows=$false
    $g.AllowUserToDeleteRows=$false
    $g.RowHeadersVisible=$false
    $g.AutoSizeColumnsMode='Fill'
    $g.BackgroundColor=[System.Drawing.Color]::FromArgb(239,244,248)
    $g.SelectionMode='FullRowSelect'
    return $g
}
function New-UiTable {
    param([string[]]$Columns,[object[]]$Rows)
    $t=New-Object System.Data.DataTable
    foreach($col in $Columns){$null=$t.Columns.Add($col,[string])}
    foreach($row in @($Rows)){
        $values=@(foreach($col in $Columns){[string]$row.$col})
        $null=$t.Rows.Add([object[]]$values)
    }
    return ,$t
}

$form=New-Object System.Windows.Forms.Form
$form.Text='Backup Operations Manager | Portfólio'
$form.Size=New-Object System.Drawing.Size(1040,735)
$form.MinimumSize=New-Object System.Drawing.Size(950,700)
$form.StartPosition='CenterScreen'
$form.BackColor=[System.Drawing.Color]::FromArgb(245,248,251)
$form.Font=New-Object System.Drawing.Font('Segoe UI',10)
$title=New-UiLabel 'Backup Operations Manager' 25 18 700
$title.Font=New-Object System.Drawing.Font('Segoe UI Semibold',19)
# The default 22px label height clips large fonts in Windows Forms.
$title.Size=New-Object System.Drawing.Size(700,42)
$form.Controls.Add($title)
$sub=New-UiLabel 'PowerShell  |  Inventário  |  Relatórios  |  Retenção simulada' 27 65 900
$sub.ForeColor=[System.Drawing.Color]::FromArgb(75,85,99)
$form.Controls.Add($sub)
$tabs=New-Object System.Windows.Forms.TabControl
$tabs.Location=New-Object System.Drawing.Point(22,96)
$tabs.Size=New-Object System.Drawing.Size(980,550)
$tabs.Anchor='Top,Bottom,Left,Right'
$form.Controls.Add($tabs)
$tabReg=New-Object System.Windows.Forms.TabPage
$tabReg.Text='Registrar backup'
$tabReg.BackColor=[System.Drawing.Color]::White
$tabReport=New-Object System.Windows.Forms.TabPage
$tabReport.Text='Relatórios'
$tabReport.BackColor=[System.Drawing.Color]::White
$tabRetention=New-Object System.Windows.Forms.TabPage
$tabRetention.Text='Retenção (simulação)'
$tabRetention.BackColor=[System.Drawing.Color]::White
$tabs.TabPages.AddRange([System.Windows.Forms.TabPage[]]@($tabReg,$tabReport,$tabRetention))

# Cadastro: nome, data, identificador, localidade e metadados. Sem backup real.
$tabReg.Controls.Add((New-UiLabel 'Localidade de laboratório' 24 30 240))
$cSite=New-UiCombo -Choices @($config.sites) -X 265 -Y 26
$tabReg.Controls.Add($cSite)
$tabReg.Controls.Add((New-UiLabel 'Componente' 24 82))
$cComponent=New-UiCombo -Choices @($config.components) -X 265 -Y 78
$tabReg.Controls.Add($cComponent)
$tabReg.Controls.Add((New-UiLabel 'Tipo de backup' 24 134))
$cType=New-UiCombo -Choices @('Local','Remoto') -X 265 -Y 130
$tabReg.Controls.Add($cType)
$tabReg.Controls.Add((New-UiLabel 'Formato' 24 186))
$cFormat=New-UiCombo -Choices @('Total','Parcial') -X 265 -Y 182
$tabReg.Controls.Add($cFormat)
$tabReg.Controls.Add((New-UiLabel 'Data do backup' 24 238))
$cDate=New-Object System.Windows.Forms.DateTimePicker
$cDate.Location=New-Object System.Drawing.Point(265,234)
$cDate.Size=New-Object System.Drawing.Size(230,27)
$cDate.Format='Custom'; $cDate.CustomFormat='dd/MM/yyyy'
$tabReg.Controls.Add($cDate)
$tabReg.Controls.Add((New-UiLabel 'Chamado de referência' 24 290 230))
$cTicket=New-Object System.Windows.Forms.TextBox
$cTicket.Location=New-Object System.Drawing.Point(265,286)
$cTicket.Size=New-Object System.Drawing.Size(230,27)
$cTicket.Text='LAB-NEW'
$tabReg.Controls.Add($cTicket)
$tabReg.Controls.Add((New-UiLabel 'Observações' 520 30 400))
$cNotes=New-Object System.Windows.Forms.TextBox
$cNotes.Location=New-Object System.Drawing.Point(520,60)
$cNotes.Size=New-Object System.Drawing.Size(400,160)
$cNotes.Anchor='Top,Left,Right'
$cNotes.Multiline=$true
$cNotes.Text='Demonstração local, sem dados reais.'
$tabReg.Controls.Add($cNotes)
$bPreview=New-UiButton 'Pré-visualizar' 520 240 180
$tabReg.Controls.Add($bPreview)
$bSave=New-UiButton 'Salvar metadados LAB' 713 240 208
$bSave.Enabled=[bool]$EnableLabWrites
$tabReg.Controls.Add($bSave)
$regResult=New-UiLabel '' 24 352 895
$regResult.Size=New-Object System.Drawing.Size(895,110)
$regResult.AutoEllipsis=$true
$tabReg.Controls.Add($regResult)
$regHelp=New-UiLabel 'Modo padrão: não grava, não copia backups e não apaga arquivos. Ative -EnableLabWrites somente para gravar um JSON local de teste.' 24 475 910
$regHelp.ForeColor=[System.Drawing.Color]::DarkOrange
$regHelp.Size=New-Object System.Drawing.Size(915,40)
$tabReg.Controls.Add($regHelp)

function Get-UiEntry {
    New-BackupEntry -Configuration $config -Site $cSite.Text -Component $cComponent.Text -Type $cType.Text `
      -Format $cFormat.Text -BackupDate $cDate.Value -Ticket $cTicket.Text -Notes $cNotes.Text
}
$bPreview.Add_Click({
    try {
        $entry=Get-UiEntry
        $path=Get-BackupDestination -Configuration $config -Entry $entry
        $regResult.Text="Prévia (não gravada):`r`nID: $($entry.Id)`r`nDestino lógico: $path"
    }
    catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Validação','OK','Warning') | Out-Null }
})
$bSave.Add_Click({
    try {
        $confirm=[System.Windows.Forms.MessageBox]::Show('Salvar somente metadados fictícios em lab-data/records.json? Nenhum backup real será feito.','Confirmar laboratório','YesNo','Question')
        if($confirm -ne [System.Windows.Forms.DialogResult]::Yes){return}
        $entry=Get-UiEntry
        $result=Save-LabBackupEntry -Configuration $config -Entry $entry -Apply -ConfirmEnvironment LAB
        $regResult.Text="Registro local salvo: $($result.Entry.Id)`r`nDestino planejado: $($result.Destination)"
        [System.Windows.Forms.MessageBox]::Show('Metadados registrados em JSON local.','Sucesso','OK','Information') | Out-Null
    }
    catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro','OK','Error') | Out-Null }
})

# Consulta: dados fictícios + registros gravados localmente (opcional).
$tabReport.Controls.Add((New-UiLabel 'Localidade' 20 22 120))
$rSite=New-UiCombo -Choices (@('Todas') + @($config.sites)) -X 120 -Y 18 -W 190
$tabReport.Controls.Add($rSite)
$tabReport.Controls.Add((New-UiLabel 'De' 340 22 35))
$rFrom=New-Object System.Windows.Forms.DateTimePicker
$rFrom.Location=New-Object System.Drawing.Point(380,18)
$rFrom.Size=New-Object System.Drawing.Size(140,27)
$rFrom.Format='Custom'; $rFrom.CustomFormat='dd/MM/yyyy'; $rFrom.Value=(Get-Date).AddYears(-5)
$tabReport.Controls.Add($rFrom)
$tabReport.Controls.Add((New-UiLabel 'Até' 540 22 45))
$rTo=New-Object System.Windows.Forms.DateTimePicker
$rTo.Location=New-Object System.Drawing.Point(585,18)
$rTo.Size=New-Object System.Drawing.Size(140,27)
$rTo.Format='Custom'; $rTo.CustomFormat='dd/MM/yyyy'; $rTo.Value=Get-Date
$tabReport.Controls.Add($rTo)
$rSearch=New-UiButton 'Buscar' 744 13 180
$tabReport.Controls.Add($rSearch)
$rGrid=New-UiGrid 20 70 900 335
$tabReport.Controls.Add($rGrid)
$rCsv=New-UiButton 'Exportar CSV' 20 426 165
$rHtml=New-UiButton 'Exportar HTML/PDF' 200 426 195
$tabReport.Controls.Add($rCsv)
$tabReport.Controls.Add($rHtml)
$rCount=New-UiLabel '' 416 435 500
$tabReport.Controls.Add($rCount)
$script:reportRows=@()
function Refresh-BackupReport {
    $items=@(Get-BackupEntries -Configuration $config)
    $script:reportRows=@(Get-BackupReport -Entries $items -StartDate $rFrom.Value -EndDate $rTo.Value -Site $rSite.Text)
    $cols=@('Site','Component','Type','Format','BackupDate','Ticket','Operator')
    $rGrid.DataSource=New-UiTable -Columns $cols -Rows $script:reportRows
    $headers=@{Site='Localidade';Component='Componente';Type='Tipo';Format='Formato';BackupDate='Data do backup';Ticket='Chamado';Operator='Responsável'}
    foreach($key in $headers.Keys){$rGrid.Columns[$key].HeaderText=$headers[$key]}
    $rCount.Text="$($script:reportRows.Count) registro(s) encontrados"
}
$rSearch.Add_Click({try{Refresh-BackupReport}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Filtro','OK','Warning') | Out-Null}})
$rCsv.Add_Click({
    if($script:reportRows.Count -eq 0){[System.Windows.Forms.MessageBox]::Show('Sem registros para exportação.') | Out-Null;return}
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter='CSV (*.csv)|*.csv';$dlg.FileName='relatorio-backups.csv'
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        try{ $null=Export-BackupCsv -Entries $script:reportRows -Path $dlg.FileName
             [System.Windows.Forms.MessageBox]::Show('CSV exportado.') | Out-Null }
        catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro','OK','Error') | Out-Null}
    }
})
$rHtml.Add_Click({
    if($script:reportRows.Count -eq 0){[System.Windows.Forms.MessageBox]::Show('Sem registros para exportação.') | Out-Null;return}
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter='HTML (*.html)|*.html';$dlg.FileName='relatorio-backups.html'
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        try{ $html=ConvertTo-BackupHtmlReport -Entries $script:reportRows
             [System.IO.File]::WriteAllText($dlg.FileName,$html,[System.Text.UTF8Encoding]::new($false))
             [System.Windows.Forms.MessageBox]::Show('HTML exportado. Abra no navegador e use Imprimir > Salvar como PDF.') | Out-Null }
        catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro','OK','Error') | Out-Null}
    }
})

# Retenção: sem Remove-Item ou execução de exclusões.
$retTitle=New-UiLabel 'Planejamento para manter os 3 registros mais recentes por site, componente e formato.' 20 20 920
$retTitle.Size=New-Object System.Drawing.Size(920,28)
$tabRetention.Controls.Add($retTitle)
$retGrid=New-UiGrid 20 85 900 325
$tabRetention.Controls.Add($retGrid)
$retRefresh=New-UiButton 'Atualizar simulação' 20 431 200
$tabRetention.Controls.Add($retRefresh)
$retCount=New-UiLabel '' 245 440 650
$tabRetention.Controls.Add($retCount)
$retWarn=New-UiLabel 'Nenhum arquivo ou diretório será apagado: registros antigos são apenas sinalizados para revisão.' 20 484 915
$retWarn.ForeColor=[System.Drawing.Color]::DarkOrange
$retWarn.Size=New-Object System.Drawing.Size(915,28)
$tabRetention.Controls.Add($retWarn)
function Refresh-Retention {
    $entries=@(Get-BackupEntries -Configuration $config)
    $retRows=@(Get-BackupRetentionPreview -Entries $entries -Keep 3)
    $retGrid.DataSource=New-UiTable -Columns @('Site','Component','Format','BackupDate','Result') -Rows $retRows
    $headers=@{Site='Localidade';Component='Componente';Format='Formato';BackupDate='Data do backup';Result='Resultado'}
    foreach($key in $headers.Keys){$retGrid.Columns[$key].HeaderText=$headers[$key]}
    $review=@($retRows | Where-Object { $_.Result -ne 'Manter' })
    $retCount.Text="$($retRows.Count) registros analisados | $($review.Count) em revisão | 0 exclusões"
}
$retRefresh.Add_Click({try{Refresh-Retention}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro','OK','Error') | Out-Null}})

$footer=New-UiLabel 'LAB / DEMO  •  Sem conexão corporativa  •  Nenhuma exclusão automática' 27 663 950
$footer.Anchor='Bottom,Left,Right'
$footer.ForeColor=[System.Drawing.Color]::FromArgb(93,104,117)
$form.Controls.Add($footer)
Refresh-BackupReport
Refresh-Retention
[void]$form.ShowDialog()
$form.Dispose()
