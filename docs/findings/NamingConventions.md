---
title: Naming Conventions
permalink: findings/naming-conventions
parent: Findings
nav_order: 1
layout: default
---

# Naming Conventions
{: .no_toc }
The purpose of naming and style convention allows you and others to identify the type and purpose of database objects. Our goal is to create legible, concise and consistent names for our database objects.

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

## Naming Foreign Key Relationships
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/160)

No need to use the "FX_" prefix in foreign key relationships. See [Using Prefix in Name](/SQL-Server-Development-Assessment/findings/naming-conventions#using-prefix-in-name)

Use the format of "[FOREIGN-KEY-TABLE]_[PRIMARY-KEY-TABLE]" in most cases. This gives you a quick view of the tables that are involved in the relationship. The first table named depends on the second table named.

**Example:** "Invoice_Product"

In cases where there are multiple foreign key relationships to one primary key table like Address, Date, Time, ... your foreign key relationship name should include the context of the relationship.
 
**Example:** "Invoice_ShippingAddress" or "Invoice_BillingAddress"

In a more rare case when not referencing the primary key of the primary key table you should use the format of "[FOREIGN-KEY-TABLE]_[CHILD-COLUMN]_[PRIMARY-KEY-TABLE]_[PARENT-COLUMN]".

**Example:** "Invoice_ProductCode_Product_ProductCode"


[Back to top](#top)

---

## Using System-Generated Object Names
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/42)

Create logical names and do not let SQL Server name objects.

If you do not specify an object name SQL Server will create one for you. This causes issues when comparing different environments that would have differently generated names.

```sql
CREATE TABLE dbo.TableName (
    TableNameId INT         NOT NULL PRIMARY KEY                           /* This creates a primary key with a name like "PK__TableNam__38F491856B661278" */
   ,SpecialCode CHAR(1)     NOT NULL CHECK (SpecialCode IN ('A', 'B', 'C'))/* This creates a SpecialCode constraint with a name like "CK__TableName__Speci__49C3F6B7" */
   ,SomeName    VARCHAR(50) NOT NULL DEFAULT ('')                          /* This creates a SomeName default constraint with a name like "DF__TableName__SomeN__4AB81AF0" */
);

/* Drop the bad version of the table */
DROP TABLE dbo.TableName;

/* Create a better version of the table with actual constraint names */
CREATE TABLE dbo.TableName (
    TableNameId INT         NOT NULL CONSTRAINT TableNameId PRIMARY KEY
   ,SpecialCode CHAR(1)     NOT NULL CONSTRAINT SpecialCodeInList CHECK (SpecialCode IN ('A', 'B', 'C'))
   ,SomeName    VARCHAR(50) NOT NULL CONSTRAINT SomeNameEmpty DEFAULT ('')
);
```

[Back to top](#top)

---

## Concatenating Two Table Names
**Check Id:** 13

Avoid, where possible, concatenating two table names together to create the name of a relationship (junction, intersection, many-to-many) table when there is already a word to describe the relationship. e.g. use "Subscription" instead of "NewspaperReader".

When a word does not exist to describe the relationship use "Table1Table2" with no underscores.

[Back to top](#top)

---

## Variable Naming
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/74)

In addition to the general naming standards regarding no special characters, no spaces, and limited use of abbreviations and acronyms, common sense should prevail in naming variables; variable names should be meaningful and natural.

All variables must begin with the "@" symbol. Do not use "@@" to prefix a variable as this signifies a SQL Server system global variable and will affect performance.

All variables should be written in PascalCase, e.g. "@FirstName" or "@City" or "@SiteId".

Variable names should contain only letters and numbers. No special characters or spaces should be used.

[Back to top](#top)

---

## Stored Procedures & Function Naming
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/75)

Stored procedures and functions should be named so they can be ordered by the table/business entity (ObjectAction) they perform a database operation on, and adding the database activity "Get, Update, Insert, Upsert, Delete, Merge" as a suffix, e.g., ("ProductGet" or "OrderUpdate").

[Back to top](#top)

---

## Using ID for Primary Key Column Name
**Check Id:** 7

For columns that are the primary key for a table and uniquely identify each record in the table, the name should be [TableName] + "Id" (e.g. On the Make table, the primary key column would be "MakeId"). 

Though "MakeId" conveys no more information about the field than Make.Id and is a far wordier implementation, it is still preferable to "Id".

Naming a primary key column "Id" is also "bad" when you query from several tables you will need to rename the "Id" columns so you can distinguish them in result set.

With different column names in joins masks errors.

```sql
/* This has an error that is not obvious at first sight */

SELECT
    C.Name
   ,M.Id AS MakeId
FROM
    Car              AS C
    INNER JOIN Make  AS MK ON C.Id  = MK.MakeId
    INNER JOIN Model AS MD ON MD.Id = C.ModelId
    INNER JOIN Color AS CL ON MK.Id = C.ColorId;

/* now you can see MK.MakeId does not equal C.ColorId in the last table join */

SELECT
    C.Name
   ,M.MakeId
FROM
    Car              AS C
    INNER JOIN Make  AS MK ON C.MakeId   = MK.MakeId
    INNER JOIN Model AS MD ON MD.ModelId = C.ModelId
    INNER JOIN Color AS CL ON MK.MakeId  = C.ColorId;
```

[Back to top](#top)

---

## Not Naming Foreign Key Column the Same as Parent Table
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/76)

Foreign key columns should have the exact same name as they do in the parent table where the column is the primary. For example, in the Customer table the primary key column might be "CustomerId". In an Order table where the customer id is kept, it would also be "CustomerId".

There is one exception to this rule, which is when you have more than one foreign key column per table referencing the same primary key column in another table. In this situation, it is helpful to add a descriptor before the column name. An example of this is if you had an Address table. You might have a Person table with foreign key columns like HomeAddressId, WorkAddressId, MailingAddressId, or ShippingAddressId.

This check combined with check [Using ID for Primary Key Column Name](#using-id-for-primary-key-column-name) makes for much more readable SQL:

```sql
SELECT
     F.FileName
FROM
     dbo.File AS F 
     INNER JOIN dbo.Directory AS D ON F.FileID = D.FileID
```

whereas this has a lot of repeating and confusing information: 

```sql
SELECT 
     F.FileName
FROM
     dbo.File AS F
     INNER JOIN dbo.Directory AS D ON F.ID = D.FileId
```

[Back to top](#top)

---

## Using Plural in Name
**Check Id:** 1

Table and view names should be singular, for example, "Customer" instead of "Customers". This rule is applicable because tables are patterns for storing an entity as a record – they are analogous to Classes serving up class instances. And if for no other reason than readability, you avoid errors due to the pluralization of English nouns in the process of database development. For instance, activity becomes activities, ox becomes oxen, person becomes people or persons, alumnus becomes alumni, while data remains data.

If writing code for a data integration and the source is plural keep the staging/integration tables the same as the source so there is no confusion.


[Back to top](#top)

---

## Using Prefix in Name
**Check Id:** 2

Never use a descriptive prefix such as tbl_. This 'reverse-Hungarian' notation has never been a standard for SQL and clashes with SQL Server's naming conventions. Some system procedures and functions were given prefixes "sp_", "fn_", "xp_" or "dt_" to signify that they were "special" and should be searched for in the master database first. 

The use of the tbl_prefix for a table, often called "tibbling", came from databases imported from Access when SQL Server was first introduced. Unfortunately, this was an access convention inherited from Visual Basic, a loosely typed language. 

SQL Server is a strongly typed language. There is never a doubt what type of object something is in SQL Server if you know its name, schema and database, because its type is there in sys.objects: Also it is obvious from the usage. Columns can be easily identified as such and character columns would have to be checked for length in the Object Browser anyway or Intellisense tool-tip hover in SQL Server Management Studio.

Do not prefix your columns with "fld_", "col_", "f_", "u_" as it should be obvious in SQL statements which items are columns (before or after the FROM clause). Do not use a data type prefix for the column either, for example, "IntCustomerId" for a numeric type or "VcName" for a VARCHAR type.

[Back to top](#top)

---

## Using Prefix in Index Name
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/72)

No need for prefixing (PK_, IX_, UK_, UX_) your index names.

* Names should be "Column1_Column2_Column3" 
* Names should indicate if there are included columns with "Column1_Column2_Column3_Includes"

See [Using Prefix in Name](/SQL-Server-Development-Assessment/findings/naming-conventions#using-prefix-in-name)

[Back to top](#top)

---

## Not Using PascalCase
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/77)

For all parts of the table name, including prefixes, use Pascal Case. `PascalCase` also reduces the need for underscores to visually separate words in names.

[Back to top](#top)

---

## Using Reserved Words in Name
**Check Id:** 4

Using reserved words makes code more difficult to read, can cause problems to code formatters, and can cause errors when writing code.

[Reserved Keywords](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/reserved-keywords-transact-sql)

[Back to top](#top)

---

## Including Special Characters in Name
**Check Id:** 5

Special characters should not be used in names. Using PascalCase for your table name allows for the upper-case letter to denote the first letter of a new word or name. Thus, there is no need to do so with an underscore character. Do not use numbers in your table names either. This usually points to a poorly designed data model or irregularly-partitioned tables. Do not use spaces in your table names either. While most database systems can handle names that include spaces, systems such as SQL Server require you to add brackets around the name when referencing it (like [table name] for example) which goes against the rule of keeping things as short and simple as possible.

[Back to top](#top)

---

## Including Numbers in Table Name
**Check Id:** 11

Beware of numbers in any object names, especially table names. It normally flags up clumsy denormalization where data is embedded in the name, as in "Year2017", "Year2018" etc. Usually the significance of the numbers is obvious to the perpetrator, but not to the maintainers of the system.

It is far better to use partitions than to create dated tables such as Invoice2018, Invoice2019, etc. If old data is no longer used, archive the data, store only aggregations, or both.

[Back to top](#top)

---

## Column Named Same as Table
**Check Id:** 12

Do not give a table the same name as one of its columns.

[Back to top](#top)

---

## Using Abbreviation
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/78)

Avoid using abbreviation if possible. Use "Account" instead of "Acct" and "Hour" instead of "Hr". Not everyone will always agree with you on what your abbreviations stand for - and - this makes it simple to read and understand for both developers and non-developers.

```
Acct, AP, AR, Hr, Rpt, Assoc, Desc
```

[Back to top](#top)

---

## Non-Affirmative Boolean Name Use
**Check Id:** [None yet, click here to view the issue](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/79)

Bit columns should be given affirmative boolean names like "IsDeletedFlag", "HasPermissionFlag", or "IsValidFlag" so that the meaning of the data in the column is not ambiguous; negative boolean names are harder to read when checking values in T-SQL because of double-negatives (e.g. "Not IsNotDeleted"). 

[Back to top](#top)

---

## Column Naming
**Check Id:** 14

- Avoid repeating the table name except for:
  - **Table Primary Key:** A table primary key should include the table name and Id (e.g. PersonId) [See Using ID for Primary Key Column Name](#using-id-for-primary-key-column-name)
  - **Natural Common Words:** PatientNumber, PurchaseOrderNumber, DriversLicenseNumber
  - **Generic Names:** When using generic names like "Number", "Name", "Description" & "Code" you can use repeat the table name
    - Instead use "AccountNumber", "AddressTypeName", "ProductDescription" & "StateCode"
    - SELECT queries will need aliases when two tables use generic columns like "Name"
- Use singular, not plural
- Choose a name to reflect precisely what is contained in the attribute
- Use abbreviations rarely in attribute names. If your organization has a TPS "thing" that is commonly used and referred to in general conversation as a TPS, you might use this abbreviation
  - **Pronounced abbreviations:** It is better to use a natural abbreviation like id instead of identifier
- End the name with a suffix that denotes general usage. These suffixes are not data types that are used in Hungarian notations. There can be names where a suffix would not apply
  - Invoice**Id** is the identity of the invoice record
  - Part**Number** is an alternate key
  - Start**Date** is the date something started
  - RowCreate**Time** is the date and time something was created
  - RowLastUpdate**Time** is the date and time something was modified
  - Line**Amount** is a currency amount not dependent on the data type like DECIMAL(19, 4)
  - Group**Name** is the text string not dependent on the data type like VARCHAR() or NVARCHAR()
  - State**Code** indicates the short form of something
  - IsDeleted**Flag** indicates a status
  - Unit**Price**

[Back to top](#top)
