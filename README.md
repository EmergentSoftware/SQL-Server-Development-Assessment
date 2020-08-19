# SQL-Server-Assess Overview
SQL-Server-Assess sp_Develop can be used by database developers, software developers and for performing database code (smell) reviews.

This lists the database development best practice checks and naming conventions checks for the stored procedure named sp_Developer.

## Install Instructions

It is recommend installing this stored procedures in the master database for full SQL Servers, but if you want to use another one, that's totally fine. 

On Azure SQL Server you will need to install this stored procedure in the user database.

## Usage Instructions

After installing the stored procedure open SSMS and run in the database you wish to check for database development best practices.

```sql
EXECUTE dbo.sp_Developer
```

[Check out the parameter section for more options](#Parameter-Explanations)

## Parameter Explanations

|Parameter|Details|
|--|--|
|@DatabaseName|Defaults to current DB if not specified|
|@GetAllDatabases|Runs checks across all of the databases on the server instead of just your current database context. Does not work on Azure SQL Server.|
|@IgnoreCheckIds|Comma-delimited list of check ids you want to skip|
|@IgnoreDatabases|Comma-delimited list of databases you want to skip|
|@BringThePain |If you’ve got more than 50 databases on the server, this only works if you also pass in @BringThePain = 1, because it’s gonna be slow.|
|@OutputType|TABLE = table<br/>COUNT = row with number found<br/>MARKDOWN = bulleted list<br/>XML = table output as XML<br/>NONE = none|
|@OutputXMLasNVARCHAR|Set to 1 if you like your XML out as NVARCHAR.|
|@Debug|Default 0. When 1, we print out messages of what we're doing in the messages tab of SSMS. When 2, we print out the dynamic SQL query of the check.|
|@Version|Output variable to check the version number.|
|@VersionDate|Output variable to check the version date.|
|@VersionCheckMode|Will set the version output variables and return without running the stored procedure.|

---
[[_TOC_]]

---

# Current High Check Id

## Next Check Id: 27

# Naming Conventions

The purpose of naming and style convention allows you and others to identify the type and purpose of database objects. Our goal is to create legible, concise and consistent names for our database objects.

---

## Concatenating Two Table Names
**Check Id:** 13

Avoid, where possible, concatenating two table names together to create the name of a relationship (junction, intersection, many-to-many) table when there is already a word to describe the relationship. e.g. use "Subscription" instead of "NewspaperReader".

When a word does not exist to describe the relationship use "Table1Table2" with no underscores.

---

## Variable Naming
**Check Id:** [NONE YET]

In addition to the general naming standards regarding no special characters, no spaces, and limited use of abbreviations and acronyms, common sense should prevail in naming variables; variable names should be meaningful and natural.

All variables must begin with the "@" symbol. Do not use "@@" to prefix a variable as this signifies a SQL Server system global variable and will affect performance.

All variables should be written in PascalCase, e.g. "@FirstName" or "@City" or "@SiteId".

Variable names should contain only letters and numbers. No special characters or spaces should be used.

---

## Stored Procedures & Function Naming
**Check Id:** [NONE YET]

Stored procedures and functions should be named so they can be ordered by the table/business entity (ObjectAction) they perform a database operation on, and adding the database activity "Get, Update, Insert, Delete, Merge" as a suffix, e.g., ("ProductGet" or "OrderUpdate").

---

## Using ID for Primary Key Column Name
**Check Id:** 7

For columns that are the primary key for a table and uniquely identify each record in the table, the name should be [tableName] + "Id" (e.g. On the Make table, the primary key column would be "MakeId"). 

Though "MakeId" conveys no more information about the field than Make.Id and is a far wordier implementation, it is still preferable to "Id".

Naming a primary key column "Id" is also "bad" when you query from several tables you will need to rename the "Id" columns so you can distinguish them in resultset.

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

---

## Not Naming Foreign Key Column the Same as Parent Table
**Check Id:** [NONE YET]

Foreign key columns should have the exact same name as they do in the parent table where the column is the primary. For example, in the Customer table the primary key column might be "CustomerId". In an Order table where the customer id is kept, it would also be "CustomerId".

There is one exception to this rule, which is when you have more than one foreign key column per table referencing the same primary key column in another table. In this situation, it is helpful to add a descriptor before the column name. An example of this is if you had an Address table. You might have a Person table with foreign key columns like HomeAddressId, WorkAddressId, MailingAddressId, or ShippingAddressId.

This check combined with check [Using ID for Primary Key Column Name](#Using-ID-for-Primary-Key-Column-Name) makes for much more readable SQL:

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

---

## Using Plural in Name
**Check Id:** 1

Table and view names should be singular, for example, "Customer" instead of "Customers". This rule is applicable because tables are patterns for storing an entity as a record – they are analogous to Classes serving up class instances. And if for no other reason than readability, you avoid errors due to the pluralization of English nouns in the process of database development. For instance, activity becomes activities, ox becomes oxen, person becomes people or persons, alumnus becomes alumni, while data remains data.

If writing code for an data integration and the source is plural keep the staging/integration tables the same as the source so there is no confusion.

---

## Using Prefix in Name
**Check Id:** 2

Never use a descriptive prefix such as tbl_. This 'reverse-Hungarian' notation has never been a standard for SQL and clashes with SQL Server's naming conventions. Some system procedures and functions were given prefixes "sp_", "fn_", "xp_" or "dt_" to signify that they were "special" and should be searched for in the master database first. 

The use of the tbl_prefix for a table, often called "tibbling", came from databases imported from Access when SQL Server was first introduced. Unfortunately, this was an access convention inherited from Visual Basic, a loosely typed language. 

SQL Server is a strongly-typed language. There is never a doubt what type of object something is in SQL Server if you know its name, schema and database, because its type is there in sys.objects: Also it is obvious from the usage. Columns can be easily identified as such and character columns would have to be checked for length in the Object Browser anyway or Intellisense tooltip hover in SSMS.

Do not prefix your columns with "fld_", "col_", "f_", "u_" as it should be obvious in SQL statements which items are columns (before or after the FROM clause). Do not use a data type prefix for the column either, for example, "IntCustomerId" for a numeric type or "VcName" for a varchar type.

---

## Using Prefix in Index Name
**Check Id:** [NONE YET]

I cannot think of a reason to keep using a prefix (PK_, IX_, UK_, UX_) or table name in index names or constraints.

* Names should be "Column1_Column2_Column3" 
* Names should indicate if there are included columns with "Column1_Column2_Column3_Includes"

---

## Not Using PascalCase
**Check Id:** [NONE YET]

For all parts of the table name, including prefixes, use Pascal Case. PascalCase also reduces the need for underscores to visually separate words in names.

---

## Using Reserved Words in Name
**Check Id:** 4

Using reserved words makes code more difficult to read, can cause problems to code formatters, and can cause errors when writing code.

[Reserved Keywords](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/reserved-keywords-transact-sql)

---

## Including Special Characters in Name
**Check Id:** 5

Special characters should not be used in names. Using PascalCase for your table name allows for the upper-case letter to denote the first letter of a new word or name. Thus there is no need to do so with an underscore character. Do not use numbers in your table names either. This usually points to a poorly-designed data model or irregularly-partitioned tables. Do not use spaces in your table names either. While most database systems can handle names that include spaces, systems such as SQL Server require you to add brackets around the name when referencing it (like [table name] for example) which goes against the rule of keeping things as short and simple as possible.

---

## Including Numbers in Table Name
**Check Id:** 11

Beware of numbers in any object names, especially table names. It normally flags up clumsy denormalization where data is embedded in the name, as in "Year2017", "Year2018" etc. Usually the significance of the numbers is obvious to the perpetrator, but not to the maintainers of the system.

It is far better to use partitions than to create dated tables such as Invoice2018, Invoice2019, etc. If old data is no longer used, archive the data, store only aggregations, or both.

---

## Column Named Same as Table
**Check Id:** 12

Do not give a table the same name as one of its columns.

---

## Using Abbreviation
**Check Id:** [NONE YET]

Use "Account" instead of "Acct" and "Hour" instead of "Hr". Not everyone will always agree with you on what your abbreviations stand for - and - this makes it simple to read and understand for both developers and non-developers.

```
Acct, AP, AR, Hr, Rpt, Assoc, Desc
```

---

## Non-Affirmative Boolean Name Use
**Check Id:** [NONE YET]

Bit columns should be given affirmative boolean names like "IsDeletedFlag", "HasPermissionFlag", or "IsValidFlag" so that the meaning of the data in the column is not ambiguous; negative boolean names are harder to read when checking values in T-SQL because of double-negatives (e.g. "Not IsNotDeleted"). 

---

## Column Naming
**Check Id:** 14

- Avoid repeating the table name except where it is natural to do so. [The most common place where we include the table name is with some primary key column (e.g. PersonId)](#using-id-for-primary-key-column-name).
  - **Other Common Examples:** PatientNumber, PurchaseOrderNumber, DriversLicenseNumber
- Use singular, not plural.
- Choose a name to reflect precisely what is contained in the attribute.
- Use abbreviations rarely in attribute names. If your organization has a TPS "thing" that is commonly used and referred to in general conversation as a TPS, you might use this abbreviation.
  - **Pronounced abbreviations:** It is better to use a natural abbreviation like id instead of identifier.
- End the name with a suffix that denotes general usage. These suffixes are not data types that are used in Hungarian notations.
  - Invoice**Id** is the identity of the invoice record
  - Part**Number** is an alternate key
  - Start**Date** is the date something started
  - RowCreate**Time** is the date and time something was created
  - RowLastUpdate**Time** is the date and time something was modified
  - Line**Amount** is a currency amount not dependant on the data type like DECIMAL(19, 4)
  - Group**Name** is the text string not dependant on the data type like VARCHAR() or NVARCHAR()
  - State**Code** indicates the short form of something
  - OptIn**Flag** indicates a status
  - **Name** used to indicate a full name for something
  - **Quantity**
  - Unit**Price**
  - **Description**

---

# Table Conventions

Table design matters because it is essential for building software applications that are scalable and capable of performing during high workload.

---

## UNIQUEIDENTIFIER in a Clustered Index
**Check Id:** 22

UNIQUEIDENTIFIER/GUID columns should not be in a clustered index. Even NEWSEQUENTIALID() should not be used in a clustered index. The sequential UNIQUEIDENTIFIER is based on the SQL Server's MAC address. When an Availability Group fails over the next UNIQUEIDENTIFIER will not be sequential any more.

SQL Server will page bad page splits when a new record is inserted instead of being inserting on the last page. The clustered index will become fragmented because of randomness of UNIQUEIDENTIFIER.

---

## Missing Index for Foreign Key
**Check Id:** 21

Each foreign key in your table should be included in an index. Start off with an index on just the foreign key column if you have no workload to tune a multi-column index. There is a real good chance the indexes will be used when queries join on the parent table.

---

## Missing Primary Key
**Check Id:** 20

Every table should have some column (or set of columns) that uniquely identifies one and only one row. It makes it much easier to maintain the data.

---

## UNIQUEIDENTIFIER For Primary Key
**Check Id:** 8

Using UNIQUEIDENTIFIER/GUID as primary keys causes issues with SQL Server databases. Non-sequential GUID cause page splits and perform 200% worse than the INT data type. UNIQUEIDENTIFIER are unnecessarily wide (4x wider than an INT).

---

## Wide Table
**Check Id:** 3

Do you have more than 20 columns? You might be treating this table like a spreadsheet. You might need to redesign your table schema.

---

## Heap
**Check Id:** 6

Add a clustered index.

SQL Server storage is built around the clustered index as a fundamental part of the data storage and retrieval engine. The data itself is stored with the clustered key. All this makes having an appropriate clustered index a vital part of database design. The places where a table without a clustered index is preferable are rare; which is why a missing clustered index is a common code smell in database design.

A 'table' without a clustered index is actually a heap, which is a particularly bad idea when its data is usually returned in an aggregated form, or in a sorted order. Paradoxically, though, it can be rather good for implementing a log or a ‘staging’ table used for bulk inserts, since it is read very infrequently, and there is less overhead in writing to it. 

A table with a non-clustered index, but without a clustered index can sometimes perform well even though the index has to reference individual rows via a Row Identifier rather than a more meaningful clustered index. The arrangement can be effective for a table that isn’t often updated if the table is always accessed by a non-clustered index and there is no good candidate for a clustered index.

Heaps have performance issues like table scans, forward fetches.

---

# Data Type Conventions

Poor data type choices can have significant impact on a database design and performance. A best practice is to right size the data type by have an understanding of the data.

---

## Using User-Defined Data Type
**Check Id:** 10

User-defined data types should be avoided whenever possible. They are an added processing overhead whose functionality could typically be accomplished more efficiently with simple data type variables, table variables, or temporary tables.

---

## Using DATETIME Instead of DATETIMEOFFSET
**Check Id:** [NONE YET]

DATETIMEOFFSET defines a date that is combined with a time of a day that has time zone awareness and is based on a 24-hour clock. This allows you to use "DATETIMEOFFSET AT TIME ZONE [timezonename]" to convert the datetime to a local timezone. 

Use this query to see all the timezone names:

```sql
SELECT * FROM sys.time_zone_info
```

---

## Using DATETIME or DATETIME2 Instead of DATE
**Check Id:** [NONE YET]

Even with data storage being so cheap, a saving in a data type adds up and makes comparison and calculation easier. When appropriate, use the DATE or SMALLDATETIME type. Narrow tables perform better and use less resources.

---

## Using DATETIME or DATETIME2 Instead of TIME
**Check Id:** [NONE YET]

Being frugal with memory is important for large tables, not only to save space but also to reduce I/O activity during access. When appropriate, use the TIME or SMALLDATETIME type. Queries too are generally simpler on the appropriate data type.

---

## Using MONEY Data Type
**Check Id:** [NONE YET]

The MONEY data type confuses the storage of data values with their display, though it clearly suggests, by its name, the sort of data held. Use DECIMAL(19, 4) instead. It is proprietary to SQL Server. 

MONEY has limited precision (the underlying type is a BIGINT or in the case of SMALLMONEY an INT) so you can unintentionally get a loss of precision due to roundoff errors. While simple addition or subtraction is fine, more complicated calculations that can be done for financial reports can show errors. 

Although the MONEY data type generally takes less storage and takes less bandwidth when sent over networks, it is generally far better to use a data type such as the DECIMAL(19, 4) type that is less likely to suffer from rounding errors or scale overflow.

---
## Using VARCHAR Instead of NVARCHAR for Unicode Data
**Check Id:** [NONE YET]

You can't require everyone to stop using national characters or accents any more. Names are likely to have accents in them if spelled properly, and international addresses and language strings will almost certainly have accents and national characters that can’t be represented by 8-bit ASCII!

**Future columns to check:**
- FirstName
- MiddleName
- LastName
- FullName
- Suffix
- Title
- ContactName
- CompanyName
- OrganizationName
- BusinessName
- Line1
- Line2
- CityName
- TownName
- StateName
- ProvinceName

---

# SQL Code Development

T-SQL code must execute properly and performant. It must be readable, well laid out and it must be robust and resilient. It must not rely on deprecated features of SQL Server, or assume specific database settings.

---

## Scalar Function Is Not Inlineable
**Check Id:** 25

Your scalar function is not inlineable. This means it will perform poorly.

Review the [Inlineable scalar UDFs requirements](https://docs.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining?view=sql-server-ver15#inlineable-scalar-udfs-requirements) to determine what changes you can make so it can go inline. If you cannot you should inline your scalar function in SQL query. This means duplicate the code you would put in the scalar function in your SQL code. SQL Server 2019 & Azure SQL Database (150 database compatibility level) can inline some scalar functions. 

Microsoft has been removing (instead of fixing) the inlineablity of scalar functions with every cumulative update. If your query requires scalar functions your should ensure they are being inlined. [Reference: Inlineable scalar UDFs requirements](https://docs.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining?view=sql-server-ver15#inlineable-scalar-udfs-requirements)

**Run this query to check if your function is inlineable. (SQL Server 2019+ & Azure SQL Server)**
```sql
SELECT
    [Schema]     = SCHEMA_NAME(O.schema_id)
   ,Name         = O.name
   ,FunctionType = O.type_desc
   ,CreatedDate  = O.create_date
FROM
    sys.sql_modules        AS SM
    INNER JOIN sys.objects AS O ON O.object_id = SM.object_id
WHERE
    SM.is_inlineable = 1;
```

**Scalar UDFs typically end up performing poorly due to the following reasons:**

**Iterative invocation:** UDFs are invoked in an iterative manner, once per qualifying tuple. This incurs additional costs of repeated context switching due to function invocation. Especially, UDFs that execute Transact-SQL queries in their definition are severely affected.

**Lack of costing:** During optimization, only relational operators are costed, while scalar operators are not. Prior to the introduction of scalar UDFs, other scalar operators were generally cheap and did not require costing. A small CPU cost added for a scalar operation was enough. There are scenarios where the actual cost is significant, and yet still remains underrepresented.

**Interpreted execution:** UDFs are evaluated as a batch of statements, executed statement-by-statement. Each statement itself is compiled, and the compiled plan is cached. Although this caching strategy saves some time as it avoids recompilations, each statement executes in isolation. No cross-statement optimizations are carried out.

**Serial execution:** SQL Server does not allow intra-query parallelism in queries that invoke UDFs.

---

## Using User-Defined Scalar Function
**Check Id:** 24

You should inline your scalar function in SQL query. This means duplicate the code you would put in the scalar function in your SQL code. SQL Server 2019 & Azure SQL Database (150 database compatibility level) can inline some scalar functions. 

Microsoft has been removing (instead of fixing) the inlineablity of scalar functions with every cumulative update. If your query requires scalar functions your should ensure they are being inlined. [Reference: Inlineable scalar UDFs requirements](https://docs.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining?view=sql-server-ver15#inlineable-scalar-udfs-requirements)

**Run this query to check if your function is inlineable. (SQL Server 2019+ & Azure SQL Server)**
```sql
SELECT
    [Schema]     = SCHEMA_NAME(O.schema_id)
   ,Name         = O.name
   ,FunctionType = O.type_desc
   ,CreatedDate  = O.create_date
FROM
    sys.sql_modules        AS SM
    INNER JOIN sys.objects AS O ON O.object_id = SM.object_id
WHERE
    SM.is_inlineable = 1;
```

**Scalar UDFs typically end up performing poorly due to the following reasons:**

**Iterative invocation:** UDFs are invoked in an iterative manner, once per qualifying tuple. This incurs additional costs of repeated context switching due to function invocation. Especially, UDFs that execute Transact-SQL queries in their definition are severely affected.

**Lack of costing:** During optimization, only relational operators are costed, while scalar operators are not. Prior to the introduction of scalar UDFs, other scalar operators were generally cheap and did not require costing. A small CPU cost added for a scalar operation was enough. There are scenarios where the actual cost is significant, and yet still remains underrepresented.

**Interpreted execution:** UDFs are evaluated as a batch of statements, executed statement-by-statement. Each statement itself is compiled, and the compiled plan is cached. Although this caching strategy saves some time as it avoids recompilations, each statement executes in isolation. No cross-statement optimizations are carried out.

**Serial execution:** SQL Server does not allow intra-query parallelism in queries that invoke UDFs.

---

## Not Using SET NOCOUNT ON in Stored Procedure or Trigger
**Check Id:** 19

Unless you need to return messages that give you the row count of each statement, you should ```SET NOCOUNT ON;```. When you execute a query a message is returned to the app with the rowcount impacted by the SQL statement.

When ```SET NOCOUNT ON;``` is included at the top of the stored procedure and trigger it will suppress the "(1000 row affected)" message.

---

## Using NOLOCK (READ UNCOMMITTED)
**Check Id:** 15

Using "WITH (NOLOCK)", "WITH (READUNCOMMITTED)" and "TRANSACTION ISOLATION LEVEL READ UNCOMMITTED" does not mean your SELECT query does not take out a lock, it does not obey locks.

Can NOLOCK be used when the data is not changing? Nope. It has the same problems.

**Problems**
- You can see rows twice
- You can skip rows altogether
- You can see records that were never committed
- Your query can fail with an error "could not continue scan with nolock due to data movement"

These problems will cause non-reproducible errors. You might end up blaming the issue on user error which will not be accurate.

Only use NOLOCK when the application stakeholders understand the problems and approve of them occurring. Get their approval in writing to CYA.

**Alternatives**
- Index Tuning
- Use READ COMMITTED SNAPSHOT ISOLATION (RCSI).
  - On by default in Azure SQL Server databases, local SQL Servers should be checked for TempDB latency before enabling

---

## Not Using Table Alias
**Check Id:** [NONE YET]

Use aliases for your table names in most T-SQL statements; a useful convention is to make the alias out of the first or first two letters of each capitalized table name, e.g. “Site” becomes "S" and "SiteType" becomes “ST”.

---

## Not Using Column List For INSERT
**Check Id:** [NONE YET]

Always use a column list in your INSERT statements. This helps in avoiding problems when the table structure changes (like adding or dropping a column). 

```sql
INSERT INTO
    dbo.Person (PersonId, JobTitle, HiredOn, Gender)
SELECT
    PersonId     = 1
   ,JobTitle     = 'CEO'
   ,HiredOn      = '5/2/1971'
   ,Gender       = 'M';
````

---

## Not Using SQL Formatting
**Check Id:** [NONE YET]

SQL statements should be arranged in an easy-to-read manner. When statements are written all to one line or not broken into smaller easy-to-read chunks, more complicated statements are very hard to decipher.

Use one of the two RedGate SQL Prompt formatting styles "Emergent Style - Collapsed" or "Emergent Style - Expanded". If you edit T-SQL code that was in a one of the two styles, put the style back to its original style after you completed editing.

---

## Not Using NOCOUNT
**Check Id:** [NONE YET]

Use ```SET NOCOUNT ON;``` at the beginning of your SQL batches, stored procedures for report output and triggers in production environments, as this suppresses messages like '(1 row(s) affected)' after executing INSERT, UPDATE, DELETE and SELECT statements. This improves the performance of stored procedures by reducing network traffic.

```SET NOCOUNT ON;``` is a procedural level instructions and as such there is no need to include a corresponding ```SET NOCOUNT OFF;``` command as the last statement in the batch. 

```sql
CREATE OR ALTER PROCEDURE dbo.PersonInsert
    @PersonId INT
   ,@JobTitle NVARCHAR(100)
   ,@HiredOn  DATE
   ,@Gender   CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO
        dbo.Person (PersonId, JobTitle, HiredOn, Gender)
    SELECT 
        PersonId = @PersonId, 
        JobTitle = 'CEO', 
        HiredOn  = '5/2/1971', 
        Gender   = 'M';
END;
```

---

## Not Using Code Comments
**Check Id:** [NONE YET]

Important code blocks within stored procedures and functions should be commented. Brief functionality descriptions should be included where important or complicated processing is taking place.

Use block comments instead of single line comments in your T-SQL code. Single line comments that are copy and pasted when performance tuning make it difficult to know where the single line comment ends.


```sql
/*
  block comment 1 (use me)
  block comment 2 (use me)
*/

/* block comment (use me) */

-- single line comment (do not use me)
```


Stored procedures and functions should include at a minimum a header comment with a brief overview of the batches functionality and author information.

```sql
/**********************************************************************************************************************
** Author:      Your Name
** Created On:  1/22/20??
** Modified On: 8/5/20??
** Description: Description of what the query does goes here. Be specific and don't be afraid to say too much. More is 
                better every single time. Think about "what, when, where, how and why" when authoring a description.
**********************************************************************************************************************/

```


---

## Not Using Table Schema
**Check Id:** [NONE YET]

Prefix all table name with the table schema (in most cases "dbo."). This results in a performance gain as the optimizer does not have to perform a lookup on execution as well as minimizing ambiguities in your T-SQL.

By including the table schema, we avoid certain bugs, minimize the time the engine spends searching for the procedure, and help ensure that cached query plans for the procedures get reused.

---

## Using SELECT *
**Check Id:** 23

Do not use the ```SELECT *``` in production code unless you have a good reason, instead specify the field names and bring back only those fields you need; this optimizes query performance and eliminates the possibility of unexpected results when fields are added to a table.

```SELECT *``` in ```IF EXISTS``` statements are OK. "*" in math equations is OK.

Reasons not to use ```SELECT *```:
- **Unnecessary Input / Output** will need to read more SQL Server 8k pages than required
- **Increased Network Traffic** will take more bandwidth for more data
- **More Application Memory** will need more memory to hold more data
- **Dependency on Order of Columns on ResultSet** will mess up the order the columns are returned
- **Breaks Views While Adding New Columns to a Table** the view columns are created at the time of the view creation, you will need to refresh "sp_refreshview()"
- **Copying Data From One Table to Another** your SELECT * INTO table will break with new columns

---

## Using Hardcoded Database Name Reference
**Check Id:** 9

Use two-part instead three-part names for tables. You should use "dbo.Customer" instead of "DatabaseName.dbo.Customer" in the FROM clause.

It is common to need a database to operate under different names.

- In development, test, production environments
  - This allows the same code to execute if the database names are "CompanyName-Prod" or "CompanyName-Dev"
- When branching database code in source control
  - You might want to name a database after a feature branch on the same SQL Server instance.
- When building database code
  - To validate database objects compile from source, it is best to not have the database name hardcoded. If you use a hardcoded names you need to ensure that only one build server can run a build for that database instance.

--- 

## Using @@IDENTITY Instead of SCOPE_IDENTITY
**Check Id:** [NONE YET]

The generation of an IDENTITY value is not transactional, so in some circumstances, @@IDENTITY returns the wrong value and not the value from the row you just inserted. This is especially true when using triggers that insert data, depending on when the triggers fire. The SCOPE_IDENTITY function is safer because it always relates to the current batch (within the same scope). Also consider using the IDENT_CURRENT function, which returns the last IDENTITY value regardless of session or scope. The OUTPUT clause is a better and safer way of capturing identity values.

---
## Using BETWEEN for DATETIME Ranges
**Check Id:** [NONE YET]

You never get complete accuracy if you specify dates when using the BETWEEN logical operator with DATETIME values, due to the inclusion of both the date and time values in the range. 

The greater and less than code below will not have the same issue.

```sql
USE WideWorldImporters;
GO

UPDATE Sales.Orders SET PickingCompletedWhen = '2013-01-09 23:59:59.9999999' WHERE OrderId = 469

DECLARE
    @PickingCompletedWhenFrom DATETIME2(7) = '2013-01-09'
   ,@PickingCompletedWhenTo   DATETIME2(7) = '2013-01-09';

SELECT
    O.OrderID
   ,O.PickingCompletedWhen
FROM
    Sales.Orders AS O
WHERE
    O.PickingCompletedWhen     >= @PickingCompletedWhenFrom
    AND O.PickingCompletedWhen <= DATEADD(NANOSECOND, -1, DATEADD(DAY, 1, @PickingCompletedWhenTo))
ORDER BY
    O.PickingCompletedWhen DESC;
```

---
## Using Old Sybase JOIN Syntax
**Check Id:** [NONE YET]

The deprecated syntax (which includes defining the join condition in the WHERE clause) is not standard SQL and is more difficult to inspect and maintain. Parts of this syntax are completely unsupported in SQL Server 2012 or higher.

The "old style" Microsoft/Sybase JOIN style for SQL, which uses the =* and *= syntax, has been deprecated and is no longer used. Queries that use this syntax will fail when the database engine level is 10 (SQL Server 2008) or later (compatibility level 100). The ANSI-89 table citation list (FROM tableA, tableB) is still ISO standard for INNER JOINs only. 

Neither of these styles are worth using. It is always better to specify the type of join you require, INNER, LEFT OUTER, RIGHT OUTER, FULL OUTER and CROSS, which has been standard since ANSI SQL-92 was published. While you can choose any supported JOIN style, without affecting the query plan used by SQL Server, using the ANSI-standard syntax will make your code easier to understand, more consistent, and portable to other relational database systems.

---
## View Usage
**Check Id:** [NONE YET]

Ask yourself what you are gaining by creating a view.

View do not lend themselves to being deeply nested. Views that reference views are difficult to maintain.

- View Use Cases
  - Create a temporary indexed view for performance issues you cannot solve without changing T-SQL code
  - You need to retire a table and use a new table with similar data. Still should be a temporary use.
  - For security reasons to expose only a specific data to a database role.
  - Abstracting complicated base tables

* Views in views cause issues for development

---
## Invalid Objects
**Check Id:** [NONE YET]

This check found objects that were deleted, renamed. Use can also run "Find Invalid Objects" with RedGate SQL Prompt in SSMS.

Try running EXEC sp_refreshsqlmodule or sp_refreshview.

---

# Running Issues

---

## Some Checks Skipped
**Check Id:** 26

We skipped some checks that are not currently possible, relevant, or practical for the SQL Server sp_Developer is running against. This could be due to the SQL Server version/edition or the database compatibility level.

---

## Skipped non-readable AG secondary databases
You are running this on an AG secondary, and some of your databases are configured as non-readable when this is a secondary node.

---

## sp_Developer is Over 6 Months Old
**Check Id:** 16

There most likely been some new checks and fixes performed within the last 6 months - time to go download the current one.

---

## Ran on a Non-Readable Availability Group Secondary Databases
**Check Id:** 17

You are running this on an AG secondary, and some of your databases are configured as non-readable when this is a secondary node. To analyze those databases, run sp_Developer on the primary, or on a readable secondary.

--- 
## Ran Against 50+ Databases Without @BringThePain = 1
**Check Id:** 18

Running sp_Developer on a server with 50+ databases may cause temporary insanity for the server and/or user. If you're sure you want to do this, run again with the parameter @BringThePain = 1.

---

<br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br />