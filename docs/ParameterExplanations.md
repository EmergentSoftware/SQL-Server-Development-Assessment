---
title: Parameter Explanations
permalink: parameter-explanations
nav_order: 5
layout: default
---

# sp_Develop Parameter Explanations

While you can run [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Development-Assessment/master/sp_Develop.sql) without any parameters there is more you can do with additional parameters.

|Parameter|Details|
|--|--|
|@DatabaseName|Defaults to current DB if not specified|
|@GetAllDatabases|When = 1, runs checks across all the databases on the server instead of just your current database context. Does not work on Azure SQL Server.|
|@BringThePain |If you’ve got more than 50 databases on the server, this only works if you also pass in @BringThePain = 1, because it’s gonna be slow.|
|@SkipCheckServer|The linked server name that stores the skip checks|
|@SkipCheckDatabase|The database that stores the skip checks|
|@SkipCheckSchema|The schema for the skip check table, when you pass in a value the SkipCheckTSQL column will be used|
|@SkipCheckTable|The table that stores the skip checks, when you pass in a value the SkipCheckTSQL column will be used|
|@OutputType|TABLE = table<br/>COUNT = row with number found<br/>MARKDOWN = bulleted list<br/>XML = table output as XML<br/>NONE = none|
|@ShowSummary|When = 1, a summary result set is outputted displaying a count of the findings based on the finding group and finding.|
|@PriorityOrHigher|When you specify [Critical, High, Medium, Low] for a value the result set will only findings with the matching priority level or higher.|
|@RunCheckIds|Specify a comma delimited list of CheckIds like 1,2,3 if you only need a limited number of checks to run.|
|@Debug|When = 1, we print out messages of what we're doing in the messages tab of SQL Server Management Studio. When 2, we print out the dynamic SQL query of the check.|
|@Version|Output variable to check the version number.|
|@VersionDate|Output variable to check the version date.|
|@VersionCheckMode|Will set the version output variables and return without running the stored procedure.|

[Why you would want to skip checks](how-to-skip-checks){: .btn .btn-purple }
[View on GitHub](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment){: .btn }