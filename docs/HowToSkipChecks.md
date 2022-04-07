---
title: How to Skip Checks
permalink: how-to-skip-checks
nav_order: 6
layout: default
---

# How to Skip sp_Develop Checks

Sometimes there are checks, databases or servers that you want to skip. For example, say a database is from a vendor and you are not responsible for the database development. 

Another use case for skipping checks is to indicate that you have acknowledged a potential issue and you are OK with it. You can skip that check for that specific object. Using [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Development-Assessment/master/sp_Develop.sql) with this pattern allows you to perform your database development and iteratively check for issues.

## Create a table to hold the list of checks you want to skip

Create this table in the database you are developing or in a database on a centralized SQL Server.

```sql
CREATE TABLE dbo.DevelopCheckToSkip (
    DevelopCheckToSkipId INT           IDENTITY(1, 1) NOT NULL
   ,ServerName            NVARCHAR(128) NULL
   ,DatabaseName          NVARCHAR(128) NULL
   ,SchemaName            NVARCHAR(128) NULL
   ,ObjectName            NVARCHAR(128) NULL
   ,CheckId               INT           NULL
   ,CONSTRAINT DevelopCheckToSkipId PRIMARY KEY CLUSTERED (DevelopCheckToSkipId ASC)
);
GO
```

## Checks to Skip

The CheckId column refers checks found in the [Findings](findings) section. You can also scroll to the right in the [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Development-Assessment/master/sp_Develop.sql) 'Results' tab and look at the 'CheckId' column to see the number of the one you want to skip. 

You can also copy the TSQL script in the 'SkipCheckTSQL' column found in the 'Results' tab to `INSERT` that record into your skip check table.

Refer to the example checks below and each comment for its use.

```sql
INSERT INTO
    dbo.DevelopCheckToSkip (ServerName, DatabaseName, SchemaName, ObjectName, CheckId)
VALUES
     (N'SQL2008', NULL, NULL, NULL, NULL)                             /* Skips all checks, for every database, on the SQL2008 SQL Server */
    ,(N'SQL2012', N'AdventureWorks2012', NULL, NULL, NULL)            /* Skips all checks, in the AdventureWorks2012 database, on the SQL2012 SQL Server */
    ,(N'SQL2017', N'AdventureWorks2017', N'dbo', N'fn_TPSTotal', NULL)/* Skips all checks, for the object named dbo.fn_TPSTotal, in the AdventureWorks2017 database, on the SQL2017 SQL Server */
    ,(N'SQL2019', N'Northwind', N'dbo', N'Order Details', 5)          /* Skips CheckId 5 (Including Special Characters in Name), for the object named dbo.[Order Details], in the Northwind database, on the SQL2019 SQL Server*/
    ,(NULL, N'AdventureWorks2017', NULL, NULL, NULL)                  /* Skips all checks, in the AdventureWorks2017 database, on every SQL Server */
    ,(NULL, NULL, N'DBA', NULL, NULL)                                 /* Skips all checks, in the DBA schema, on every SQL Server, in every database, for every object */
    ,(NULL, NULL, N'dbo', N'vPhone', NULL)                            /* Skips all checks, for the object named dbo.vPhone, in every database, on every SQL Server */
    ,(NULL, NULL, N'dbo', N'CustOrderHist', 19);                      /* Skips CheckId 19 (Not Using SET NOCOUNT ON in Stored Procedure or Trigger), for the object named dbo.CustOrderHist, in every database, on every SQL Server */
```

## How to Execute the Skip Checks

```sql
EXEC dbo.sp_Develop
   ,@SkipCheckDatabase = N'pubs'
   ,@SkipCheckSchema = N'dbo'
   ,@SkipCheckTable = N'DevelopCheckToSkip';
```

You can also centralize this skip check table by putting it in a central location, setting up a linked server pointing to your central location, and then using the @SkipChecksServer parameter:

```sql
EXEC dbo.sp_Develop
    @SkipCheckServer = N'ManagementServerName'
   ,@SkipCheckDatabase = N'pubs'
   ,@SkipCheckSchema = N'dbo'
   ,@SkipCheckTable = N'DevelopCheckToSkip';
```

[Tell me about the test database](test-database-install){: .btn .btn-purple }
[View on GitHub](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment){: .btn }