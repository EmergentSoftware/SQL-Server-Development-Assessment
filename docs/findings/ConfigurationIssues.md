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

