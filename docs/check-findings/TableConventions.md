---
title: Table Conventions
permalink: findings/table-conventions
parent: Findings
nav_order: 2
layout: default
---

# Table Conventions

Table design matters because it is essential for building software applications that are scalable and capable of performing during high workload.

## Column Named ????Id But No FK Exists
**Check Id:** [NONE YET]

We found a column following the naming convention of ????Id and is not the PK but no FK exists, you might be missing a relationship to a parent table.

## More Than 5 Indexes
**Check Id:** [NONE YET]

Your table might be over indexed.

## Less than 2 Indexes
**Check Id:** [NONE YET]

Your table might be under indexed.

## Disabled Index
**Check Id:** [NONE YET]

An index rebuild or reorganization will enabled disabled indexes. It is now best practices to delete instead of disable if not needed.

## Leftover Fake Index
**Check Id:** [NONE YET]

The Index Tuning Wizard and Database Tuning Advisor create fake indexes, then getting a new execution plan for a query. These fake indexes stay behind sometimes.

To fix the issue `DROP` the indexes.

There are better ways to performance tune than using the wizards.

## Column Has a Different Collation Than Database
**Check Id:** [NONE YET]

This could cause issues if the code is not aware of different collations and does include features to work with them correctly.

## Low Index Fill-Factor
**Check Id:** [NONE YET]

The default fill factor is (100 or 0) for SQL Server. This check is alerting you to a fill factor of 80% or lower.

Best practice is to ONLY use a low fill factor on indexes where you know you need it. Setting a low fill factor on too many indexes will hurt your performance:

- Wasted space in storage
- Wasted space in memory (and therefore greater memory churn)
- More IO, and with it higher CPU usage

Review indexes diagnosed with low fill factor. Check how much they’re written to. Look at the keys and determine whether insert and update patterns are likely to cause page splits.


## Untrusted Foreign Key
**Check Id:** [NONE YET]

SQL Server is not going to use untrusted constraints to compile a better execution plan.

You might have disabled a constraint instead of dropping and recreating it for bulk loading data. This is fine, as long as your remember to enable it correctly.

```sql
ALTER TABLE dbo.TableName WITH CHECK CHECK CONSTRAINT ConstraintName;
GO
```

The `CHECK CHECK` syntax is correct. The 1st `CHECK` is the end of `WITH CHECK` statement. The 2nd `CHECK` is the start of the `CHECK CONSTRAINT` clause to enable the constraint

## UNIQUEIDENTIFIER in a Clustered Index
**Check Id:** 22

UNIQUEIDENTIFIER/GUID columns should not be in a clustered index. Even NEWSEQUENTIALID() should not be used in a clustered index. The sequential UNIQUEIDENTIFIER is based on the SQL Server's MAC address. When an Availability Group fails over the next UNIQUEIDENTIFIER will not be sequential anymore.

SQL Server will page bad page splits when a new record is inserted instead of being inserting on the last page. The clustered index will become fragmented because of randomness of UNIQUEIDENTIFIER.



## Missing Index for Foreign Key
**Check Id:** 21

Each foreign key in your table should be included in an index. Start off with an index on just the foreign key column if you have no workload to tune a multi-column index. There is a real good chance the indexes will be used when queries join on the parent table.



## Missing Primary Key
**Check Id:** 20

Every table should have some column (or set of columns) that uniquely identifies one and only one row. It makes it much easier to maintain the data.



## UNIQUEIDENTIFIER For Primary Key
**Check Id:** 8

Using UNIQUEIDENTIFIER/GUID as primary keys causes issues with SQL Server databases. Non-sequential GUID cause page splits and perform 200% worse than the INT data type. UNIQUEIDENTIFIER are unnecessarily wide (4x wider than an INT).



## Wide Table
**Check Id:** 3

Do you have more than 20 columns? You might be treating this table like a spreadsheet. You might need to redesign your table schema.



## Heap
**Check Id:** 6

Add a clustered index.

SQL Server storage is built around the clustered index as a fundamental part of the data storage and retrieval engine. The data itself is stored with the clustered key. All this makes having an appropriate clustered index a vital part of database design. The places where a table without a clustered index is preferable are rare; which is why a missing clustered index is a common code smell in database design.

A 'table' without a clustered index is a heap, which is a particularly bad idea when its data is usually returned in an aggregated form, or in a sorted order. Paradoxically, though, it can be rather good for implementing a log or a ‘staging’ table used for bulk inserts, since it is read very infrequently, and there is less overhead in writing to it. 

A table with a non-clustered index, but without a clustered index can sometimes perform well even though the index must reference individual rows via a Row Identifier rather than a more meaningful clustered index. The arrangement can be effective for a table that isn’t often updated if the table is always accessed by a non-clustered index and there is no good candidate for a clustered index.

Heaps have performance issues like table scans, forward fetches.