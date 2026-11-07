/* Optional development SQL Server schema. Run only in a disposable local SQL instance. */
IF DB_ID(N'BackupPortfolioLab') IS NULL
BEGIN
    CREATE DATABASE [BackupPortfolioLab];
END;
GO
USE [BackupPortfolioLab];
GO
IF OBJECT_ID(N'dbo.BackupRecords',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BackupRecords
    (
        Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        Site NVARCHAR(40) NOT NULL,
        Component NVARCHAR(40) NOT NULL,
        BackupType NVARCHAR(10) NOT NULL,
        [Format] NVARCHAR(10) NOT NULL,
        BackupDate DATE NOT NULL,
        Ticket NVARCHAR(60) NOT NULL,
        Notes NVARCHAR(500) NOT NULL,
        OperatorName NVARCHAR(100) NOT NULL,
        RegisteredAt DATETIME2 NOT NULL
    );
    CREATE INDEX IX_BackupRecords_Site_BackupDate ON dbo.BackupRecords(Site, BackupDate DESC);
END;
GO
