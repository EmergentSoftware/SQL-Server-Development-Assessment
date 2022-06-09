---
title: Table Conventions
permalink: best-practices-and-potential-findings/table-conventions
parent: Best Practices & Potential Findings
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

TPC & TPH do not follow normal form. 

- See [Not Normalizing Tables](#not-normalizing-tables).

[Back to top](#top)

---

## Using Entity Attribute Value
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Using+Entity+Attribute+Value)

The [Entity–Attribute–Value (EAV) model ](https://en.wikipedia.org/wiki/Entity%E2%80%93attribute%E2%80%93value_model) falls victim to the [Inner-platform effect](https://en.wikipedia.org/wiki/Inner-platform_effect).

The inner-platform effect is the tendency of software architects to create a system so customizable as to become a replica, and often a poor replica, of the software development platform they are using. This is generally inefficient and such systems are often considered to be examples of an [anti-pattern](https://en.wikipedia.org/wiki/Anti-pattern).

In the database world, developers are sometimes tempted to bypass the SQL Server relations database, for example by storing everything in one big table with three columns labelled EntityId, Key, and Value. While this entity-attribute-value model allows the developer to break out from the structure imposed by a SQL Server database, it loses out on all the benefits, since all of the work that could be done efficiently by the SQL Server relational database is forced onto the application instead. Queries become much more convoluted, the indexes and query optimizer can no longer work effectively, and data validity constraints are not enforced. Performance and maintainability can be extremely poor.

**Use Case Exceptions**

Data that meets the following criteria might be okay to use the EAV pattern at the discretion of the software or database architect.
- The definition of the data is highly dynamic and is likely to change numerous times of the course of the development and/or life of the application.
- The data has no intrinsic value outside the context of the application itself.
- The data will not be materialized in models but simply passed through the application layers as key value pairs.

Examples of valid use cases that meet this criteria are:
- Application user preferences
- User interface styling & custom layouts
- Saved user interface state
- Front-end application configuration

Another use case exception for utilizing an EAV model in a database is where the attributes are user defined and a developer will not have control over them.

Another use case exception for utilizing an EAV model is for something like a multiple product (entity) type shopping cart. Where each specific product (entity) type has its own list of attributes. If the product (entity) catalog only sells a manageable number of product different types the attributes, the attributes should be materialized as physical columns in the table schema. This type of EAV model will have diminishing returns for performance with more data housed in the database. Caching this type of EAV model will allow for a larger data set as to lessen the chance of performance issues. Ensure this is communicated to the stakeholders.

**Basic table model for a product catalog that supports multiple product types**

```sql
CREATE TABLE dbo.Attribute (
    AttributeId   int           IDENTITY(1, 1) NOT NULL
   ,AttributeName nvarchar(100) NOT NULL
   ,CONSTRAINT Attribute_AttributeId PRIMARY KEY CLUSTERED (AttributeId ASC)
);

/* Insert values like "Size", "Color" */


CREATE TABLE dbo.AttributeTerm (
    AttributeTermId int           IDENTITY(1, 1) NOT NULL
   ,AttributeId     int           NOT NULL CONSTRAINT AttributeTerm_Attribute FOREIGN KEY REFERENCES dbo.Attribute (AttributeId)
   ,TermName        nvarchar(100) NOT NULL
   ,CONSTRAINT AttributeTerm_AttributeTermId PRIMARY KEY CLUSTERED (AttributeTermId ASC)
);

/* Insert values like "Small", "Large", "Red", "Green" */


CREATE TABLE dbo.Product (
    ProductId          int           IDENTITY(1, 1) NOT NULL
   ,ProductName        nvarchar(200) NOT NULL
   ,ProductSlug        nvarchar(400) NOT NULL
   ,ProductDescription nvarchar(MAX) NULL
   ,CONSTRAINT Product_ProductId PRIMARY KEY CLUSTERED (ProductId ASC)
   ,CONSTRAINT Product_ProductName UNIQUE NONCLUSTERED (ProductName ASC)
   ,CONSTRAINT Product_ProductSlug UNIQUE NONCLUSTERED (ProductSlug ASC)
);

/* Insert values like "Shirt", "Pants" */


CREATE TABLE dbo.ProductItem (
    ProductItemId int            IDENTITY(1, 1) NOT NULL
   ,ProductId     int            NOT NULL CONSTRAINT ProductItem_Product FOREIGN KEY REFERENCES dbo.Product (ProductId)
   ,UPC           varchar(12)    NULL
   ,RegularPrice  decimal(18, 2) NOT NULL
   ,SalePrice     decimal(18, 2) NULL
   ,CONSTRAINT ProductItem_ProductItemId PRIMARY KEY CLUSTERED (ProductItemId ASC)
);

/* Insert values product UPC codes and prices */


CREATE TABLE dbo.ProductVariant (
    ProductVariantId int IDENTITY(1, 1) NOT NULL
   ,ProductItemId    int NOT NULL CONSTRAINT ProductVariant_ProductItem FOREIGN KEY REFERENCES dbo.ProductItem (ProductItemId)
   ,AttributeTermId  int NOT NULL CONSTRAINT ProductVariant_AttributeTerm FOREIGN KEY REFERENCES dbo.AttributeTerm (AttributeTermId)
   ,CONSTRAINT ProductVariant_ProductVariantId PRIMARY KEY CLUSTERED (ProductVariantId ASC)
);

/* Insert values that link Shirt or Pants product items to the attributes available for sale */
```

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

## Nullable Columns with No Non-Null Records
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/192)

If the row data in the table does not contain any ```NULL``` values you should assess setting the column to not 'Allow Nulls'.

Null-ness does more than constraining the data, it factors in on performace optimizer decisions.

For data warehouses do not allow ```NULL``` values for dimensional tables. You can create a -1 identifier with the value of [UNKNOWN]. This helps business analysts who might not understand the difference between INNER and OUTER JOINs exclude data in their TSQL queries.

### Nullable Columns and JOIN Elimination

If a column has a foreign key and nullable, it will not be trusted and ```JOIN``` Elimination will not occur, forcing your query to perform more query operations than needed.

This execution plan shows how ```JOIN``` elimination works. There is a foreign key on the column and the column does not allow null. There is only one index operation in the execution plan. SQL Server is able to eliminate JOINs because it "trusts" the data relationship.

- See [Untrusted Foreign Key](#untrusted-foreign-key)

![Non-SARGable Scan vs. SARGable Seek](../Images/JOIN_Elimination_NOT_NULL.png)

This execution plan shows ```JOIN``` elimination has not occurred. While there is a foreign key on the column, the column allows null. There are two index operations and a merge operation causing SQL Server to perform more work.

![Non-SARGable Scan vs. SARGable Seek](../Images/JOIN_Elimination_NULL.png)


[Back to top](#top)

---

## Column Named ????Id But No Foreign Key Exists
**Potential Finding:** <a name="column-named-id-but-no-fk-exists"/>Column Named ????Id But No FK Exists<br/>
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/43)

In most cases, columns with the name ????Id that are not the primary key should have a foreign key relationship to another table.

You will not get JOIN Eliminations without a foreign key and a column that allows NULLs.

- See [Nullable Columns and JOIN Elimination](#nullable-columns-and-join-elimination) 

[Back to top](#top)

---

## NULL or NOT NULL option is not specified in CREATE or DECLARE TABLE
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=NULL+or+NOT+NULL+option+is+not+specified+in+CREATE+or+DECLARE+TABLE)

You should always explicitly define ``NULL`` or ``NOT NULL`` for columns when creating or declaring a table. The default of allowing NULLs can be changed with the database setting ``ANSI_NULL_DFLT_ON``.

[Back to top](#top)

---

## Unique Constraint or Unique Indexes Usage
**Potential Finding:** <a name="using-unique-constraint-instead-of-unique-indexes"/>Using Unique Constraint Instead of Unique Indexes<br/>
**Check Id:** 30

Create unique indexes instead of unique constraints (unique key). Doing so removes a dependency of a unique key to the unique index that is created automatically and tightly coupled.

**Instead of:** ```CONSTRAINT AddressType_AddressTypeName_Unique UNIQUE (AddressTypeName)```

**Use:** ```INDEX AddressType_AddressTypeName UNIQUE NONCLUSTERED (AddressTypeName)```

In some table design cases you might need to create uniqueness for one or more columns. This could be for a natural [composite] key or to ensure a person can only have one phone number and phone type combination.

There is no functional or performance difference between a unique constraint (unique key) and a unique index. With both you get a unique index, but with a unique constraint (unique key) the 'Ignore Duplicate Keys' and 'Re-compute statistics' index creation options are not available.

The only possible benefit of a unique constraint (unique key) has over a unique index is to emphasize the purpose of the index and is displayed in the SSMS (SQL Server Management Studio) table 'Keys' folder in the 'Object Explorer' side pane.

- See [Naming Constraint Usage](/SQL-Server-Development-Assessment/best-practices-and-potential-findings/naming-conventions#naming-constraint-usage)

[Back to top](#top)

---

## More Than 5 Indexes
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/49)

Your table might be over indexed. The more you have the less performant insert, update & deletes are. A general rule of thumb is 5 indexes on a table.

A general rule is to aim for 5 indexes per table, with around 5 columns or less on each index. This is not a set-in-stone rule, but if you go beyond the general rule you should ensure you are only creating indexes that are required for the SQL Server query workload. If you have a read-only database, there will be no inserts, updates, or deletes to maintain on all those indexes.

You or your DBA should implement an index tuning strategy like below.

1. **Dedupe** - reduce overlapping indexes
2. **Eliminate** - unused indexes
3. **Add** - badly needed missing indexes
4. **Tune** - indexes for specific queries
5. **Heap** - usually need clustered indexes

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

## Filter Columns Not In Index Definition
**Check Id:** [None yet, click here to add the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Filter+Columns+Not+In+Index+Definition)

Add the filtered columns in the ```INCLUDE()``` on your index so your queries do not need to perform a key lookup. By including the filtered columns, SQL Server generates statistics on the columns.

**Instead Of:**

```sql
CREATE NONCLUSTERED INDEX Account_Greater_Than_Half_Million
    ON dbo.Account (AccountName, AccountId)
    WHERE Balance > 500000;
```

**Do This:**

```sql
CREATE NONCLUSTERED INDEX Account_Greater_Than_Half_Million
    ON dbo.Account (AccountName, AccountId)
    INCLUDE (Balance)
    WHERE Balance > 500000;
```

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

## uniqueidentifier in a Clustered Index
**Check Id:** 22

``uniqueidentifier/guid`` columns should not be in a clustered index. Even NEWSEQUENTIALID() should not be used in a clustered index. The sequential ``uniqueidentifier/guid`` is based on the SQL Server's MAC address. When an Availability Group fails over the next ``uniqueidentifier/guid`` will not be sequential anymore.

SQL Server will bad page split and fragment an index when a new record is inserted instead of being inserting on the last page using standard best practices for index maintenance. The clustered index will become fragmented because of randomness of ``uniqueidentifier/guid``. Index maintenance set to the default fill factor of 0 (packed 100%) will force bad page splits.

A use case for when you can use ``uniqueidentifier/guid`` as a primary key & clustered index, is when there are separate systems and merging rows would be difficult. The uniqueness of ``uniqueidentifier/guid`` simplifies the data movements.

DBAs have historically not implemented ``uniqueidentifier/guid`` as primary keys and/or clustered indexes. The traditional index maintenance jobs would keep the ``uniqueidentifier/guid`` indexes in a perpetual state of fragmentation causing bad page splits, which is an expensive process.

A new index maintenance strategy is to name these ``uniqueidentifier/guid`` indexes with the ending "*_INDEX_REBUILD_ONLY" and create a customized index maintenance plan. One job step will perform the standard index maintenance ignoring the ``uniqueidentifier/guid`` indexes and another job step will only perform an index rebuild, skipping index reorganizations. [Ola Hallengren maintenance scripts](https://ola.hallengren.com/) is recommended.

These ``uniqueidentifier/guid`` indexes should be created and rebuilt with a custom fill factor to account for at least a weeks' worth of data. This is not a "set it, and forget it" maintenance plan and will need some looking after.

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

## uniqueidentifier For Primary Key
**Check Id:** 8

Using ``uniqueidentifier/guid`` as primary keys causes issues with SQL Server databases. ``uniqueidentifier/guid`` are unnecessarily wide (4x wider than an INT).

``uniqueidentifiers/guids`` are not user friendly when working with data. PersonId = 2684 is more user friendly then PersonId = 0B7964BB-81C8-EB11-83EC-A182CB70C3ED.

![uniqueidentifier For Primary Key](../Images/UNIQUEIDENTIFIER_For_Primary_Key.png)


A use case for when you can use ``uniqueidentifier/guid`` as primary keys, is when there are separate systems and merging rows would be difficult. The uniqueness of ``uniqueidentifier/guid`` simplifies the data movements.

- See [uniqueidentifier in a Clustered Index](#uniqueidentifier-in-a-clustered-index)

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