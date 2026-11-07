#Requires -Version 5.1
# Optional SQL Server adapter. Localhost-only with Windows integrated authentication.
Set-StrictMode -Version Latest
function Open-BackupLabSqlConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration,[Parameter(Mandatory)][string]$ConfirmEnvironment)
    if ($ConfirmEnvironment -cne 'LAB' -or [string]$Configuration.environment -cne 'LAB') {
        throw 'Acesso SQL exige confirmacao explicita LAB.'
    }
    if ([string]$Configuration.sql.database -cne 'BackupPortfolioLab') {
        throw 'Esta amostra SQL so pode usar o banco BackupPortfolioLab.'
    }
    if ([string]$Configuration.sql.authentication -cne 'Windows') {
        throw 'Esta amostra suporta apenas autenticacao integrada do Windows.'
    }
    $server=[string]$Configuration.sql.server
    if ($server -notmatch '^(?:\.|localhost|127\.0\.0\.1)(?:\\[A-Za-z0-9_]+)?$') {
        throw 'Somente instancias locais de laboratorio sao permitidas neste exemplo.'
    }
    $builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder.DataSource=$server
    $builder.InitialCatalog='BackupPortfolioLab'
    $builder.IntegratedSecurity=$true
    $builder.ConnectTimeout=5
    $builder.Encrypt=$false # local lab only; never use this setting against remote/production.
    $connection=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    $connection.Open()
    return $connection
}
function Save-BackupLabSqlEntry {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration,[Parameter(Mandatory)]$Entry,[switch]$Apply,[string]$ConfirmEnvironment)
    if (-not $Apply) { throw 'O adapter SQL exige -Apply (nunca roda por padrao).' }
    $connection=Open-BackupLabSqlConnection -Configuration $Configuration -ConfirmEnvironment $ConfirmEnvironment
    try {
        $command=$connection.CreateCommand()
        try {
            $command.CommandText=@'
INSERT INTO dbo.BackupRecords
(Id, Site, Component, BackupType, [Format], BackupDate, Ticket, Notes, OperatorName, RegisteredAt)
VALUES (@Id, @Site, @Component, @BackupType, @Format, @BackupDate, @Ticket, @Notes, @OperatorName, @RegisteredAt)
'@
            $columns=@{
                Id=@([System.Data.SqlDbType]::UniqueIdentifier,([guid]$Entry.Id))
                Site=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Site)
                Component=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Component)
                BackupType=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Type)
                Format=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Format)
                BackupDate=@([System.Data.SqlDbType]::Date,([datetime]$Entry.BackupDate))
                Ticket=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Ticket)
                Notes=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Notes)
                OperatorName=@([System.Data.SqlDbType]::NVarChar,[string]$Entry.Operator)
                RegisteredAt=@([System.Data.SqlDbType]::DateTime2,([datetime]$Entry.RegisteredAt))
            }
            foreach($name in $columns.Keys){
                $item=$columns[$name]
                $param=$command.Parameters.Add('@'+$name,[System.Data.SqlDbType]$item[0])
                $param.Value=$item[1]
            }
            return $command.ExecuteNonQuery()
        }
        finally { $command.Dispose() }
    }
    finally { $connection.Dispose() }
}
Export-ModuleMember -Function Open-BackupLabSqlConnection,Save-BackupLabSqlEntry
