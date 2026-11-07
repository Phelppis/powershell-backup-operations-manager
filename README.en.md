# Backup Operations Manager — English summary

A **generic, independent PowerShell portfolio project** for tracking backup metadata, organizing logical destinations, searching records, exporting CSV/HTML reports, and **previewing** retention rules without deleting any backup files.

- **WinForms GUI:** registration preview, date/site filters, local reports, retention preview.
- **CLI:** `./BackupOperations.ps1` lists demonstration records by default.
- **Storage:** fictional sample JSON, with optional explicit local JSON writes under `lab-data/`.
- **SQL Server:** an optional, localhost-only ADO.NET example using parameterized queries and integrated authentication. Never invoked by default.
- **Tests:** Pester and Windows PowerShell 5.1 smoke checks in GitHub Actions.

This is **not a backup engine**: it does not generate, restore, transfer, or delete database backups. All organization names, endpoints, and records are fictional. It is not production-ready.

To open the GUI on Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ".\gui\Start-BackupGui.ps1"
```

See the [Portuguese README](README.md) for full instructions, safety limits, and the optional local SQL lab.
