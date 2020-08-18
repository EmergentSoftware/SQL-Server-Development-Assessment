# SQL-Server-Assess Overview
SQL-Server-Assess sp_Develop can be used by database developers, software developers and for performing database code (smell) reviews.

This lists the database development best practice checks and naming conventions checks for the stored procedure named sp_Developer.

## Install Instructions

It is recommend installing this stored procedures in the master database for full SQL Servers, but if you want to use another one, that's totally fine. 

On Azure SQL Server you will need to install this stored procedure in the user database.

## Usage Instructions

After installing the stored procedure open SSMS and run in the database you wish to check for database development best practices.

```sql
EXECUTE dbo.sp_Developer
```

[Check out the parameter section for more options](#Parameter-Explanations)

## Parameter Explanations

|Parameter|Details|
|--|--|
|@DatabaseName|Defaults to current DB if not specified|
|@GetAllDatabases|Runs checks across all of the databases on the server instead of just your current database context. Does not work on Azure SQL Server.|
|@IgnoreCheckIds|Comma-delimited list of check ids you want to skip|
|@IgnoreDatabases|Comma-delimited list of databases you want to skip|
|@BringThePain |If you’ve got more than 50 databases on the server, this only works if you also pass in @BringThePain = 1, because it’s gonna be slow.|
|@OutputType|TABLE = table<br/>COUNT = row with number found<br/>MARKDOWN = bulleted list<br/>XML = table output as XML<br/>NONE = none|
|@OutputXMLasNVARCHAR|Set to 1 if you like your XML out as NVARCHAR.|
|@Debug|Default 0. When 1, we print out messages of what we're doing in the messages tab of SSMS. When 2, we print out the dynamic SQL query of the check.|
|@Version|Output variable to check the version number.|
|@VersionDate|Output variable to check the version date.|
|@VersionCheckMode|Will set the version output variables and return without running the stored procedure.|
