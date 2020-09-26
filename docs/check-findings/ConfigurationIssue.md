---
title: Configuration Issue
permalink: findings/configuration-issue
parent: Findings
nav_order: 6
layout: default
---

# Configuration Issue

## Object Not Owned by dbo
**Check Id:** [None yet, click here to ](https://github.com/EmergentSoftware/SQL-Server-Assess/issues/29)

Using dbo as the owner of all the database objects simplifies object management. dbo will always be a user in the database. If an object is owned by an account other than dbo, you must transfer ownership account needs to be deleted.

## Database Compatibility Level is Lower Than the SQL Server
**Check Id:** [NONE YET](GH-38)

The database compatibility level lower than the SQL Server it is running on.

There might be query optimization your are not getting running on an older database compatibility level. You might also introduce issues with a more modern database compatibility level.