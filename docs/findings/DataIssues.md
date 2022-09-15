---
title: Data Issues
permalink: best-practices-and-potential-findings/data-issues
parent: Best Practices & Potential Findings
nav_order: 5
layout: default
---

# Data Issues
{: .no_toc }
Checks for data issues.

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

## Do not use Placeholder Rows 
**Potential Finding:** <a name="using-placeholder-rows"/>Using Placeholder Rows<br/>
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Using+Placeholder+Rows)

A placeholder is an empty row/record that is created to hold the place of possible future data in the row that may or may not be necessary.

While placeholder rows do not violate database normalization rules, it is not considered a best practice to create "empty" rows. Row data should only be created when it is materialized. If the row data does not exists, it should not be inserted. If the row data is removed, the row should be hard or soft deleted. Empty rows are not free, there is overhead space allocated with placeholder rows, which can impact performance.

 Having the unnecessary placeholder rows can muddy queries that now would need to include ```IS NOT NULL``` or ```LEN(PhoneNumber) > 0``` to exclude these placeholder rows on other queries.

[Back to top](#top)

---
## Data Should be Encrypted if Compliance Dictates
**Potential Finding:** <a name="unencrypted-data"/>Unencrypted Data<br/>
**Check Id:** 27

The table column returned for this check might have unencrypted data that you might want to have encrypted for best practices or industry specific compliance. You will need to determine if the data needs to be protected at rest, in transit or both.

**With SQL Server you have a couple choices to implement hashing or encryption**

- [SQL Server Always Encrypt](https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-database-engine)
- [SQL Server Transparent Data Encryption (TDE)](https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption)
- You could develop your own or utilize a development framework pattern to implement a custom one-way hashing, hashing with salting or encryption using AES-128, AES-192, AES-256.


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