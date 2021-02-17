---
title: Configuration Issues
permalink: findings/configuration-issues
parent: Findings
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

## Application User Granted db_owner Role
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/175)

You will want to give an account or process only those privileges which are essential to perform its intended function. Start your development with the app user account only a member of the db_reader, db_writer and db_executor roles.

When a vulnerability is found in the code, service or operating system the "Principle of least privilege" lessens the blast radius of damage cause by hackers and malware.

See [Principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege)

[Back to top](#top)

---

## Application User is not a Contained User
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/176)

Users that only access one database should generally be created as contained users which means they don't have a SQL Server "login" and are not found as users in the master database. This makes the database portable by not requiring a link to a SQL Server Login. A database with contained users can be restored to your development SQL Server or a migration event needs to occur in production to a different SQL Server.

See [Contained Database Users - Making Your Database Portable](https://docs.microsoft.com/en-us/sql/relational-databases/security/contained-database-users-making-your-database-portable?view=sql-server-ver15)

[Back to top](#top)

---

## Object Not Owned by dbo
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/29)

It simplifies object management with dbo owning all the database objects. You will need to transfer ownership of objects before an account can be deleted.

[Back to top](#top)

---

## Database Compatibility Level is Lower Than the SQL Server
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/38)

The database compatibility level lower than the SQL Server it is running on.

There might be query optimization your are not getting running on an older database compatibility level. You might also introduce issues with a more modern database compatibility level.

[Back to top](#top)

