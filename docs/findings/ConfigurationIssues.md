---
title: Configuration Issues
permalink: best-practices-and-potential-findings/configuration-issues
parent: Best Practices & Potential Findings
nav_order: 6
layout: default
---

# Configuration Issues
{: .no_toc }
These checks are for configurations to the SQL Server.

---

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

[Back to top](#top)

---

<a name="54"/><a name="use-code-retry-logic-to-handle-transient-errors"/>

## Not Using Code Retry Logic for Transient Errors
**Check Id:** 54 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Use+Code+Retry+Logic+to+Handle+Transient+Errors)

It is best practice to implement client code to mitigate connection errors and transient errors that your client application encounters when communicating with a SQL Server (On-premises SQL Server, Azure SQL Database, Azure SQL Managed Instance and Azure Synapse Analytics).

SQL Server might be in the process of shifting hardware resources  to better load-balance or fail over in a HA/DR (High Availability / Disaster Recover). When this occurs there will be a time normally 60 seconds where your app might have issues with connecting to the database.

Applications that connect to a SQL Server should be built to expect these transient errors. To handle them, implement retry logic in their code instead of surfacing them to users as application errors.

.NET 4.6.1 or later (or .NET Core) can use the [.NET SqlConnection parameters for connection retry](https://docs.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-connectivity-issues#net-sqlconnection-parameters-for-connection-retry). 

Ensure you are using the failover group name or availability group listener name in your connection string. The SQL Server name should not be something like 'SQL01'. This indicates you are connecting directly to a specific SQL Server instance instead of a group of SQL Servers.

- See [Troubleshoot transient connection errors in SQL Database and SQL Managed Instance](https://docs.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-connectivity-issues)

[Back to top](#top)

---

<a name="55"/><a name="do-not-grant-an-application-user-the-db_owner-role"/>

## Application User Granted db_owner Role
**Check Id:** 55 [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Do+Not+Grant+an+Application+User+the+db_owner+Role)

You will want to give an account or process only those privileges which are essential to perform its intended function. Start your development with the app user account only a member of the db_reader, db_writer and db_executor roles.

When a vulnerability is found in the code, service or operating system the "Principle of least privilege" lessens the blast radius of damage caused by hackers and malware.

- See [Principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege)

[Back to top](#top)

---

<a name="56"/><a name="use-the-query-execution-defaults"/>

## Not Using Query Execution Defaults
**Check Id:** 56 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Not+Using+Query+Execution+Defaults)

There are query execution defaults included in SSMS (SQL Server Management Studio) and Visual Studio. These defaults must be maintained or overridden at the connection or session level if needed. If the defaults are not consistently used certain TSQL script, stored procedures or functions might not behave as developed.

When dealing with indexes on computed columns and indexed views, four of these defaults (```ANSI_NULLS```, ```ANSI_PADDING```, ```ANSI_WARNINGS```, and ```QUOTED_IDENTIFIER```) must be set to ``ON``. These defaults are among seven ```SET``` options that must be assigned the required values when you are creating and changing indexes on computed columns and indexed views.

The other three ```SET``` options are ```ARITHABORT (ON)```, ```CONCAT_NULL_YIELDS_NULL (ON)```, and ```NUMERIC_ROUNDABORT (OFF)```. For more information about the required ```SET``` option settings with indexed views and indexes on computed columns, see [Considerations When You Use the SET Statement](https://docs.microsoft.com/en-us/sql/t-sql/statements/set-statements-transact-sql#considerations-when-you-use-the-set-statements).

It is not best practice to modify these query execution settings at the SQL Server level.

### SSMS (SQL Server Management Studio) and Visual Studio Settings

In SSMS (SQL Server Management Studio) and Visual Studio these 5 ANSI execution settings are on by default: QUOTED_IDENTIFIER, ANSI_PADDING, ANSI_WARNINGS, ANSI_NULLS, ANSI_NULL_DFLT_ON

These 2 advanced execution settings are on by default: ARITHABORT, CONCAT_NULL_YIELDS_NULL

### Visual Studio Database Projects

Visual Studio database projects should be setup with the 7 query execution SET defaults (Project Settings > ‘Database Settings’ button). If there have been publish database objects without these query execution defaults, they will need to be updated. It is possible to check the “Ignore quoted identifiers” and “Ignore ANSI Nulls” under the ‘Advanced’ button when manually publishing the database project.

- See [SET Statements](https://docs.microsoft.com/en-us/sql/t-sql/statements/set-statements-transact-sql)
- Source [SET ANSI_DEFAULTS (Transact-SQL)](https://docs.microsoft.com/en-us/sql/t-sql/statements/set-ansi-defaults-transact-sql)


[Back to top](#top)

---

<a name="57"/><a name="the-application-user-should-be-a-contained-user"/>

## Application User is not a Contained User
**Check Id:** 57 [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=The+Application+User+should+be+a+Contained+User)

Users that only access one database should generally be created as contained users which means they don't have a SQL Server "login" and are not found as users in the master database. This makes the database portable by not requiring a link to a SQL Server Login. A database with contained users can be restored to your development SQL Server or a migration event needs to occur in production to a different SQL Server.

- See [Contained Database Users - Making Your Database Portable](https://docs.microsoft.com/en-us/sql/relational-databases/security/contained-database-users-making-your-database-portable?view=sql-server-ver15)

[Back to top](#top)

---

<a name="58"/><a name="all-database-objects-should-be-owned-by-dbo"/>

## Object Not Owned by dbo
**Check Id:** 58 [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=All+Database+Objects+Should+be+Owned+by+dbo)

It simplifies object management with dbo owning all the database objects. You will need to transfer ownership of objects before an account can be deleted.

[Back to top](#top)

---

<a name="59"/><a name="the-database-compatibility-level-should-match-the-sql-server-version"/>

## Database Compatibility Level is Lower Than the SQL Server
**Check Id:** 59 [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=The+Database+Compatibility+Level+Should+Match+the+SQL+Server+Version)

The database compatibility level lower than the SQL Server it is running on.

There might be query optimization your are not getting running on an older database compatibility level. You might also introduce issues with a more modern database compatibility level.

[Back to top](#top)

---
<a name="158"/>

## Connection String Not Scalable
**Check Id:** 158 [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Connection+String+Not+Scalable)

Application connection strings should be set up to be scalable. 3 different connection strings are recommended.

In the beginning, all three connection strings below will have the same content – they will all point to your production database server. When you need to scale, though, the production DBA can use different techniques to scale out each of those tiers.

1. **Writes with Real-Time Reads**
   - This connection is hard to scale, so keep the number of queries here to a minimum.  
   - Treat this like a valuable resource.
   - Functions like inserting or modifing database rows, then redirecting or displaying the data directly afterwards would fall into the use case pattern. Determine if it is necessary to redirect to a display UI, or just notify the user of the action. In high usage databases, performing additional database queries could consume resources unnecessarly.
   - Indicate on the connection string `ApplicationIntent=ReadWrite`.
     - See [Specifying Application Intent](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/sqlclient-support-for-high-availability-disaster-recovery#specifying-application-intent)
   - Determine the `MultiSubnetFailover` property of `True` or `False`
     - See [Connecting With MultiSubnetFailover](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/sqlclient-support-for-high-availability-disaster-recovery#connecting-with-multisubnetfailover)
2. **No Writes with Reads That Can Tolerate Data Older Than 15 Seconds**
   - This connection string has more options to scale out. This is where the majority of queries should go.
   - Think of this as the default connection string.
   - Indicate on the connection string `ApplicationIntent=ReadOnly`.
     - See [Specifying Application Intent](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/sqlclient-support-for-high-availability-disaster-recovery#specifying-application-intent)
   - Determine the `MultiSubnetFailover` property of `True` or `False`
     - See [Connecting With MultiSubnetFailover](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/sqlclient-support-for-high-availability-disaster-recovery#connecting-with-multisubnetfailover)
3. **No Writes with Reads That Can Tolerate Data Older Than Several Hours**
   - This connection is for operational reporting, and not to be confused with analytical reporting aggregations like `SUM()`, `COUNT()`, `AVG()`, ... reporting. True analytical reporting should be performed in a system like a data warehouse or Online Analytical Arocessing (OLAP) system.
   - Queries of these types utilize higher amounts of CPU and storage Input/Output.
   - Stakeholders will eventually have to decide whether to prioritize near-real-time data for reports at the expense of slowing down production, or to separate these resource-intensive queries to a data source with a longer delay.
   - Indicate on the connection string `ApplicationIntent=ReadOnly`.
     - See [Specifying Application Intent](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/sqlclient-support-for-high-availability-disaster-recovery#specifying-application-intent)
   - Determine the `MultiSubnetFailover` property of `True` or `False`
     - See [Connecting With MultiSubnetFailover](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/sqlclient-support-for-high-availability-disaster-recovery#connecting-with-multisubnetfailover)


- See [Not Using Code Retry Logic for Transient Errors](/SQL-Server-Development-Assessment/best-practices-and-potential-findings/configuration-issues#54)



[Back to top](#top)

---
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>