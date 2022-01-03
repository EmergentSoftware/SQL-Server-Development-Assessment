---
title: Table Conventions
permalink: findings/table-conventions
parent: Findings
nav_order: 2
layout: default
---

# Table Conventions
{: .no_toc }
Table design matters because it is essential for building software applications that are scalable and capable of performing during high workload.

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

## Incorrect Inheritance Type
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Incorrect+Inheritance+Type)

Use the [Table Per Type (TPT)](https://entityframework.net/tpt) table design pattern.

The [Table Per Concrete (TPC)](https://entityframework.net/tpc) design is not good as it would have redundant data and no relationship between the sub tables. The redundant data would just be in multiple tables vs squished into one table with [Table Per Hierarchy (TPH)](https://entityframework.net/tph). TPC would help with the extra nullable columns compared to TPH.

TPC & TPH do not follow normal form. See [Not Normalizing Tables](#not-normalizing-tables).

[Back to top](#top)

---

## Incorrect Weak or Strong Table
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Incorrect+Weak+or+Strong+Table)

Use the proper weak or strong table type based on the entity.

A weak table is one that can only exist when owned by another table. For example: a 'Room' can only exist in a 'Building'.

An 'Address' is a strong table because it exists with or without a person or organization.

With an 'Address' table you would have a linking, or many-to-many table.

|ResidenceId|AddressTypeId|PersonId|AddressId|
|--|--|--|--|
|1|1|456|233|
|2|1|234|167|
|3|2|622|893|


A 'Phone Number' is a weak table because it generally does not exist without a person or organization.

With a 'Phone Number' table you would not use a linking table. The 'Phone Number' table would reference back to the person table.

|PersonId|FistName|LastName|
|--|--|--|
|1|Kevin|Martin|
|2|Han|Solo|
|3|Mace|Windu|

|PersonPhoneId|PhoneTypeId|PersonId|PhoneNumber|
|--|--|--|--|
|1|1|1|555-899-5543|
|2|1|2|(612) 233-2255|
|3|2|3|1+ (453) 556-9902|

A use case exception for using the proper weak or strong type is for security purposes. You might encounter a requirement for security that utilizing a linking table makes it impossible to have a discriminator to prevent read or modifications to a row.


[Back to top](#top)

---

## Column Named ????Id But No FK Exists
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/43)

We found a column following the naming convention of ????Id and is not the PK but no FK exists, you might be missing a relationship to a parent table.

[Back to top](#top)

---

## NULL or NOT NULL option is not specified in CREATE or DECLARE TABLE
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=NULL+or+NOT+NULL+option+is+not+specified+in+CREATE+or+DECLARE+TABLE)

You should always explicitly define ``NULL`` or ``NOT NULL`` for columns when creating or declaring a table. The default of allowing NULLs can be changed with the database setting ``ANSI_NULL_DFLT_ON``.

[Back to top](#top)

---

## More Than 5 Indexes
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/49)

Your table might be over indexed.

[Back to top](#top)

---

## Less than 2 Indexes
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/50)

Your table might be under indexed.

[Back to top](#top)

---

## Disabled Index
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/51)

An index rebuild or reorganization will enabled disabled indexes. It is now best practices to delete instead of disable if not needed.

[Back to top](#top)

---

## Leftover Fake Index
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/53)

The Index Tuning Wizard and Database Tuning Advisor create fake indexes, then getting a new execution plan for a query. These fake indexes stay behind sometimes.

To fix the issue `DROP` the indexes.

There are better ways to performance tune than using the wizards.

[Back to top](#top)

---

## Column Has a Different Collation Than Database
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/54)

This could cause issues if the code is not aware of different collations and does include features to work with them correctly.

[Back to top](#top)

---

## Low Index Fill-Factor
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/55)

The default fill factor is (100 or 0) for SQL Server. This check is alerting you to a fill factor of 80% or lower.

Best practice is to ONLY use a low fill factor on indexes where you know you need it. Setting a low fill factor on too many indexes will hurt your performance:

- Wasted space in storage
- Wasted space in memory (and therefore greater memory churn)
- More IO, and with it higher CPU usage

Review indexes diagnosed with low fill factor. Check how much they’re written to. Look at the keys and determine whether insert and update patterns are likely to cause page splits.

[Back to top](#top)

---

## Untrusted Foreign Key
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/59)

SQL Server is not going to use untrusted constraints to compile a better execution plan.

You might have disabled a constraint instead of dropping and recreating it for bulk loading data. This is fine, as long as your remember to enable it correctly.

```sql
ALTER TABLE dbo.TableName WITH CHECK CHECK CONSTRAINT ConstraintName;
GO
```

The `CHECK CHECK` syntax is correct. The 1st `CHECK` is the end of `WITH CHECK` statement. The 2nd `CHECK` is the start of the `CHECK CONSTRAINT` clause to enable the constraint

[Back to top](#top)

---

## UNIQUEIDENTIFIER in a Clustered Index
**Check Id:** 22

UNIQUEIDENTIFIER/GUID columns should not be in a clustered index. Even NEWSEQUENTIALID() should not be used in a clustered index. The sequential UNIQUEIDENTIFIER/GUID is based on the SQL Server's MAC address. When an Availability Group fails over the next UNIQUEIDENTIFIER/GUID will not be sequential anymore.

SQL Server will bad page split and fragment an index when a new record is inserted instead of being inserting on the last page using standard best practices for index maintenance. The clustered index will become fragmented because of randomness of UNIQUEIDENTIFIER/GUID. Index maintenance set to the default fill factor of 0 (packed 100%) will force bad page splits.

A use case for when you can use UNIQUEIDENTIFIER/GUID as a primary key & clustered index, is when there are separate systems and merging rows would be difficult. The uniqueness of UNIQUEIDENTIFIER/GUID simplifies the data movements.

DBAs have historically not implemented UNIQUEIDENTIFIER/GUID as primary keys and/or clustered indexes. The traditional index maintenance jobs would keep the UNIQUEIDENTIFIER/GUID indexes in a perpetual state of fragmentation causing bad page splits, which is an expensive process.

A new index maintenance strategy is to name these UNIQUEIDENTIFIER/GUID indexes with the ending "*_INDEX_REBUILD_ONLY" and create a customized index maintenance plan. One job step will perform the standard index maintenance ignoring the UNIQUEIDENTIFIER/GUID indexes and another job step will only perform an index rebuild, skipping index reorganizations. [Ola Hallengren maintenance scripts](https://ola.hallengren.com/) is recommended.

These UNIQUEIDENTIFIER/GUID indexes should be created and rebuilt with a custom fill factor to account for at least a weeks' worth of data. This is not a "set it, and forget it" maintenance plan and will need some looking after.

These are a 400 level tasks and please feel free to reach out to a DBA for assistance.

[Back to top](#top)

---

## Missing Index for Foreign Key
**Check Id:** 21

Each foreign key in your table should be included in an index. Start off with an index on just the foreign key column if you have no workload to tune a multi-column index. There is a real good chance the indexes will be used when queries join on the parent table.

[Back to top](#top)

---

## Missing Primary Key
**Check Id:** 20

Every table should have some column (or set of columns) that uniquely identifies one and only one row. It makes it much easier to maintain the data.

[Back to top](#top)

---

## UNIQUEIDENTIFIER For Primary Key
**Check Id:** 8

Using UNIQUEIDENTIFIER/GUID as primary keys causes issues with SQL Server databases. UNIQUEIDENTIFIER/GUID are unnecessarily wide (4x wider than an INT).

UNIQUEIDENTIFIERs/GUIDs are not user friendly when working with data. PersonId = 2684 is more user friendly then PersonId = 0B7964BB-81C8-EB11-83EC-A182CB70C3ED.

![UNIQUEIDENTIFIER For Primary Key](../Images/UNIQUEIDENTIFIER_For_Primary_Key.png)

A use case for when you can use UNIQUEIDENTIFIER/GUID as primary keys, is when there are separate systems and merging rows would be difficult. The uniqueness of UNIQUEIDENTIFIER/GUID simplifies the data movements.

See [UNIQUEIDENTIFIER in a Clustered Index for details](#uniqueidentifier-in-a-clustered-index)

[Back to top](#top)

---

## Wide Table
**Check Id:** 3

Do you have more than 20 columns? You might be treating this table like a spreadsheet. You might need to redesign your table schema.

[Back to top](#top)

---

## Heap
**Check Id:** 6

Add a clustered index.

SQL Server storage is built around the clustered index as a fundamental part of the data storage and retrieval engine. The data itself is stored with the clustered key. All this makes having an appropriate clustered index a vital part of database design. The places where a table without a clustered index is preferable are rare; which is why a missing clustered index is a common code smell in database design.

A 'table' without a clustered index is a heap, which is a particularly bad idea when its data is usually returned in an aggregated form, or in a sorted order. Paradoxically, though, it can be rather good for implementing a log or a ‘staging’ table used for bulk inserts, since it is read very infrequently, and there is less overhead in writing to it. 

A table with a non-clustered index, but without a clustered index can sometimes perform well even though the index must reference individual rows via a Row Identifier rather than a more meaningful clustered index. The arrangement can be effective for a table that isn’t often updated if the table is always accessed by a non-clustered index and there is no good candidate for a clustered index.

Heaps have performance issues like table scans, forward fetches.

[Back to top](#top)

---

## Not Normalizing Tables
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Not+Normalizing+Tables)

Normalizing tables is regarded as a best practice methodology for relational databases design. Relational database tables should be normalized to at least the [Boyce–Codd normal form (BCNF or 3.5NF)](https://en.wikipedia.org/wiki/Boyce%E2%80%93Codd_normal_form).

These normalizing principles are used to reduce data duplication, avoid data anomalies, ensure table relationship integrity, and make data management simplified.

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