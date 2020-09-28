---
title: Test Database Install
permalink: test-database-install
nav_order: 7
layout: default
---

# Test Database Install

The [Test Database](https://github.com/EmergentSoftware/SQL-Server-Assess/tree/master/Test%20Database) folder contains the RedGate SQL Source Control. Use this database for creating and testing checks. If you are not going to be developing [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Assess/master/sp_Develop.sql) checks you can skip this page.

SQL Server 2008+ is supported. You can script out the test database and downgrade schema features like `DATETIME2` that is not supported. SQL Server Developer editions are now free, go [download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) and install the latest version for development.

## Quick Steps to Setup and Use:

1. Create new database 'spDevelopTest' and select in Object Browser
2. Open Redgate SQL Source Control in SQL Server Management Studio
3. Click 'Setup' tab
4. Select 'Link to my source control system' and click 'Next'
5. Browser to '..\Test Database' cloned folder and click 'Link'
6. Click 'Get latest' tab
7. Pull or refresh if required and click 'Apply changes' button
8. Develop objects to use when you create a new check
9. Click 'Commit' tab
10. Select objects to be pulled back into the branch, add comment, click the 'Commit' button and click the 'Push' button
11. **Note:** there are exclude filters setup for invalid objects created in the post script. Do not check these objects back into the branch.


## Redgate SQL Source Control Documentation

- [Getting Started ](https://documentation.red-gate.com/soc7/getting-started)
- [Link to Git](https://documentation.red-gate.com/soc7/linking-to-source-control/link-to-git)

[Sharing development app settings](development-app-settings){: .btn .btn-purple }
[View on GitHub](https://github.com/EmergentSoftware/SQL-Server-Assess){: .btn }