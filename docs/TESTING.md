# Plano de testes manuais (Windows)

Este repositório usa exemplos fictícios. Nenhum comando abaixo gera ou elimina backups reais.

## 1. Preparação

Abra o **Windows PowerShell 5.1** na pasta do projeto (não cole o script em linhas isoladas):

```powershell
cd D:\Projetos\powershell-backup-operations-manager
$PSVersionTable.PSVersion
```

## 2. Teste rápido da CLI e do núcleo

```powershell
.\scripts\Smoke-Test.ps1
.\BackupOperations.ps1
.\BackupOperations.ps1 -Action Retention
```

**Esperado:** relatório de 6 entradas fictícias e 1 registro antigo sinalizado para revisão (sem remoção de arquivos).

## 3. Abrir e exercitar a GUI

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ".\gui\Start-BackupGui.ps1"
```

Na aba **Registrar backup**, gere uma prévia. Na aba **Relatórios**, procure `LAB-NORTE`, exporte CSV e HTML. Abra o HTML no navegador e use `Ctrl+P > Salvar como PDF`. Na aba **Retenção**, confira a simulação sem exclusões.

## 4. Opcional: gravação local de metadados

```powershell
.\BackupOperations.ps1 -Action Register -Site LAB-SUL -Component Aplicacao -Type Remoto -Format Parcial -Apply -ConfirmEnvironment LAB
```

Um JSON local deve ser criado em `lab-data/records.json`. Esta pasta está no `.gitignore` e não deve ser publicada. Os registros salvos aparecem no histórico da GUI após clicar em **Buscar**.

## 5. Testes automatizados

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester .\tests
.\scripts\Verify-PublicContent.ps1
```

O GitHub Actions executa os testes Pester e um smoke test no Windows PowerShell 5.1 após o push.

## Antes de publicar

- Confira `git status` e o histórico de commits.
- Confirme que `BackupForm.ps1` e quaisquer arquivos corporativos **não constam do repositório**.
- Não anexe logs, bases, `.bak`, arquivos com dados reais, capturas com nomes internos ou credenciais.
- Teste a GUI no Windows e, se aprovada, adicione uma captura limpa em `images/backup_preview.png`.
- Após modificar a interface, atualize a captura em `images/backup_preview.png` antes de divulgá-la. O `.gitignore` evita commits de exportações com nomes padrão, mas relatórios com nomes personalizados devem ser revisados manualmente.
