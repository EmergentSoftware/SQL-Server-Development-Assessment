---
title: Results Explanations
permalink: results-explanations
nav_order: 4
layout: default
---

## sp_Develop Results Explanations

After running [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Assess/master/sp_Develop.sql) the 'Results' tab will contain the checks findings.

![sp_Develop Results](../images/sp_Develop_Results.png)

The findings results are order by DatabaseName, SchemaName, ObjectName, ObjectType, FindingGroup, Finding. This allows you to review all the checks for an object at the same time.

#### Column Results Details

|Column Name|Details|
|--|--|
|DatabaseName|Can be run for multiple databases so this will show you the database with the potential issue|
|SchemaName|This is the schema for the object that might have an issue|
|ObjectName|This can be anything from user tables, views stored procedures, functions, …|
|FindingGroup|The high level grouping for the check<br/> - Naming Conventions<br/>- Table Conventions<br/>- Data Type Conventions<br/>- SQL Code Development<br/>- Data Issue<br/>- Configuration Issue<br/>- Running Issues|
|Finding|The specific potential issue we the check is looking for|
|Details|Additional details about the potential issue. This does not go into in-depth details of the potential issue but should give you a heads up of what to look for.|
|URL|Copy and paste this link into a browser to view the README.md write up for the potential issue|
|SkipCheckTSQL|In this column you will find a generated TSQL script INSERT |
|Priority|The lower the number the more severe the potential issue is to address|
|CheckId|Every check is uniquely numbered|

