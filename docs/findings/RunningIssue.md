---
title: Running Issue
permalink: findings/running-issue
parent: Findings
nav_order: 7
layout: default
---

# Running Issues

These are some issues you might run into when running [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Assess/master/sp_Develop.sql).


## Some Checks Skipped
**Check Id:** 26

We skipped some checks that are not currently possible, relevant, or practical for the SQL Server [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Assess/master/sp_Develop.sql) is running against. This could be due to the SQL Server version/edition or the database compatibility level.



## Skipped non-readable AG secondary databases
You are running this on an AG secondary, and some of your databases are configured as non-readable when this is a secondary node.



## sp_Develop is Over 6 Months Old
**Check Id:** 16

There most likely been some new checks and fixes performed within the last 6 months - time to go download the current one.



## Ran on a Non-Readable Availability Group Secondary Databases
**Check Id:** 17

You are running this on an AG secondary, and some of your databases are configured as non-readable when this is a secondary node. To analyze those databases, run [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Assess/master/sp_Develop.sql) on the primary, or on a readable secondary.

 
## Ran Against 50+ Databases Without @BringThePain = 1
**Check Id:** 18

Running [sp_Develop](https://raw.githubusercontent.com/EmergentSoftware/SQL-Server-Assess/master/sp_Develop.sql) on a server with 50+ databases may cause temporary insanity for the server and/or user. If you're sure you want to do this, run again with the parameter @BringThePain = 1.



<br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br />