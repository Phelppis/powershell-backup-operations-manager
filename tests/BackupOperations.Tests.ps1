BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\BackupOperations.psm1') -Force
    $script:configPath=Join-Path $PSScriptRoot '..\examples\config.sample.json'
    $script:cfg=Read-BackupConfiguration -Path $script:configPath
    $script:demo=@(Get-SampleBackupEntries)
}
Describe 'Configuracao generica e isolamento do laboratorio' {
    It 'carrega o exemplo sanitizado' {
        $script:cfg.environment | Should -Be 'LAB'
        @($script:cfg.sites).Count | Should -Be 4
    }
    It 'recusa ambiente de producao' {
        $raw=Get-Content -LiteralPath $script:configPath -Raw
        $p=Join-Path $TestDrive 'production.json'
        [System.IO.File]::WriteAllText($p, $raw.Replace('"LAB"','"PROD"'))
        { Read-BackupConfiguration -Path $p } | Should -Throw
    }
    It 'recusa escapes para fora do repositorio' {
        { Resolve-BackupLabPath -RelativePath '..\outside\secret.txt' } | Should -Throw
        { Resolve-BackupLabPath -RelativePath '\\server\share' } | Should -Throw
        { Resolve-BackupLabPath -RelativePath 'C:\internal\backup' } | Should -Throw
    }
    It 'recusa localidade com nome nao parametrizado' {
        { New-BackupEntry -Configuration $script:cfg -Site '..\REAL' -Component 'Banco' -Type Local -Format Total -BackupDate (Get-Date) } | Should -Throw
    }
}
Describe 'Registro e planejamento' {
    It 'cria ID e destino somente dentro do laboratorio' {
        $e=New-BackupEntry -Configuration $script:cfg -Site LAB-NORTE -Component Banco -Type Local -Format Total -BackupDate ([datetime]'2026-11-07')
        $p=Get-BackupDestination -Configuration $script:cfg -Entry $e
        $e.Id | Should -Match '^[a-f0-9-]{36}$'
        $p | Should -Match 'lab-storage'
        $p | Should -Match '20261107'
        $p | Should -Not -Match '^\\\\'
    }
    It 'bloqueia gravacao de metadados sem confirmacao' {
        $e=New-BackupEntry -Configuration $script:cfg -Site LAB-NORTE -Component Banco -Type Local -Format Total -BackupDate (Get-Date)
        { Save-LabBackupEntry -Configuration $script:cfg -Entry $e -Apply } | Should -Throw
    }
    It 'nao escreve quando apenas visualiza' {
        $e=New-BackupEntry -Configuration $script:cfg -Site LAB-NORTE -Component Banco -Type Local -Format Total -BackupDate (Get-Date)
        $r=Save-LabBackupEntry -Configuration $script:cfg -Entry $e
        $r.Mode | Should -Be 'PREVIEW'
    }
    It 'faz retencao somente como plano, mantendo tres mais recentes por grupo' {
        $plan=@(Get-BackupRetentionPreview -Entries $script:demo -Keep 3)
        @($plan | Where-Object Result -eq 'Revisar (nao exclui)').Count | Should -Be 1
        ($plan | Where-Object Result -eq 'Revisar (nao exclui)' | Select-Object -First 1).BackupDate | Should -Be '2026-11-01'
    }
}
Describe 'Relatorios e seguranca de exportacao' {
    It 'filtra datas de forma inclusiva e localidade' {
        $rows=@(Get-BackupReport -Entries $script:demo -StartDate ([datetime]'2026-11-02') -EndDate ([datetime]'2026-11-03') -Site LAB-NORTE)
        $rows.Count | Should -Be 2
        @($rows | Where-Object Site -ne 'LAB-NORTE').Count | Should -Be 0
    }
    It 'escapa HTML fornecido pelo usuario' {
        $row=New-BackupEntry -Configuration $script:cfg -Site LAB-NORTE -Component Banco -Type Local -Format Total -BackupDate (Get-Date) -Notes '<script>alert(1)</script>'
        $html=ConvertTo-BackupHtmlReport -Entries @($row)
        $html | Should -Not -Match '<script>alert'
        $html | Should -Match '&lt;script&gt;'
    }
    It 'neutraliza formulas perigosas ao exportar CSV' {
        $row=New-BackupEntry -Configuration $script:cfg -Site LAB-NORTE -Component Banco -Type Local -Format Total -BackupDate (Get-Date) -Notes '=HYPERLINK("example")'
        $path=Join-Path $TestDrive 'test.csv'
        $null=Export-BackupCsv -Entries @($row) -Path $path
        $csv=Get-Content -LiteralPath $path -Raw
        $csv | Should -Match "'=HYPERLINK"
    }
}
Describe 'CLI e GUI em modo seguro' {
    It 'executa o relatório CLI sem parametros' {
        { & (Join-Path $PSScriptRoot '..\BackupOperations.ps1') | Out-Null } | Should -Not -Throw
    }
    It 'executa a retencao CLI sem excluir arquivos' {
        { & (Join-Path $PSScriptRoot '..\BackupOperations.ps1') -Action Retention | Out-Null } | Should -Not -Throw
    }
    It 'carrega a GUI em modo headless sem criar janela' {
        $preview=& (Join-Path $PSScriptRoot '..\gui\Start-BackupGui.ps1') -ValidateOnly
        $preview.Records | Should -BeGreaterThan 0
        $preview.WritesEnabled | Should -BeFalse
    }
}
