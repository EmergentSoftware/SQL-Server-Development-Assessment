---
title: Data Issues
permalink: findings/data-issues
parent: Findings
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

## Unencrypted Data
**Check Id:** 28

The table column returned for this check might have unencrypted data that you might want to have encrypted for best practices or industry specific compliance. You will need to determine if the data needs to be protected at rest, in transit or both.

**With SQL Server you have a couple choices to implement hashing or encryption**

- [SQL Server Always Encrypt](https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/always-encrypted-database-engine)
- [SQL Server Transparent Data Encryption (TDE)](https://docs.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption)
- You could develop your own or utilize a development framework pattern to implement a custom one-way hashing, hashing with salting or encryption using AES-128, AES-192, AES-256.


[Back to top](#top)

---
</br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br></br>
