---
title: Data Type Conventions
permalink: data-type-conventions
parent: Findings
nav_order: 3
layout: default
---

# Data Type Conventions

Poor data type choices can have significant impact on a database design and performance. A best practice is to right size the data type by understanding of the data.

## Columns Named the Same Have Different Data Types
**Check Id:** [NONE YET]

There are two situations where this is going to hurt performance. When you have a mismatch of data types in a JOIN and a WHERE clause. SQL Server will need to convert one of them to match the others data type. This is called implicit conversion.

**What will it hurt**

- Indexes will not be used correctly
- Missing index requests will not be logged in the DMV
- Extra CPU cycles are going to be required for the conversion


## Using of Deprecated Data Type
**Check Id:** [NONE YET]

- Use of deprecated data types such as TEXT/NTEXT
- There is no good reason to use TEXT or NTEXT. They were a flawed attempt at BLOB storage and are there only for backward compatibility. Likewise, the WRITETEXT, UPDATETEXT and READTEXT statements are also deprecated. All this complexity has been replaced by the VARCHAR(MAX) and NVARCHAR(MAX) data types, which work with all of SQL Server’s string functions.

## Email Address Column
**Check Id:** [NONE YET]

An email address column should be set to NVARCHAR(254) to leave 2 characters for <> if needed.

## URL Column
**Check Id:** [NONE YET]

A URL column should be set to NVARCHAR(2083).

## Overuse of (N)VARCHAR(MAX)
**Check Id:** [NONE YET]

You might be overusing (N)VARCHAR(MAX) on your table.

(N)VARCHAR(MAX) columns can be included in an index but not as a key. Queries will not be able to perform an index seek on this column. 

(N)VARCHAR(MAX) should only every be used if the size of the field is known to be over [8K for VARCHAR | 4K for NVARCHAR]

Since SQL Server 2016 if the size of the cell is < 8K characters for VARCHAR(MAX) it will be treated as Row data. If > 8K it will be treated as a Large Object (LOB) for storage purposes.

## Boolean Column Not Using BIT
**Check Id:** [NONE YET]

Use the `BIT` data type for boolean columns. These columns will have names like IsSpecialSaleFlag. 

## Using FLOAT or REAL
**Check Id:** [NONE YET]

The FLOAT (8 byte) and REAL (4 byte) data types are suitable only for specialist scientific use since they are approximate types with an enormous range (-1.79E+308 to -2.23E-308, 0 and 2.23E-308 to 1.79E+308, in the case of FLOAT). Any other use needs to be regarded as suspect, and a FLOAT or REAL used as a key or found in an index needs to be investigated. The DECIMAL type is an exact data type and has an impressive range from -10^38+1 through 10^38-1. Although it requires more storage than the FLOAT or REAL types, it is generally a better choice.

## Using SQL_VARIANT
**Check Id:** [NONE YET]

The SQL_VARIANT type is not your typical data type. It stores values from a number of different data types and is used internally by SQL Server. It is hard to imagine a valid use in a relational database. It cannot be returned to an application via ODBC except as binary data, and it isn’t supported in Microsoft Azure SQL Database.

## Using User-Defined Data Type
**Check Id:** 10

User-defined data types should be avoided whenever possible. They are an added processing overhead whose functionality could typically be accomplished more efficiently with simple data type variables, table variables, or temporary tables.



## Using DATETIME Instead of DATETIMEOFFSET
**Check Id:** [NONE YET]

DATETIMEOFFSET defines a date that is combined with a time of a day that has time zone awareness and is based on a 24-hour clock. This allows you to use "DATETIMEOFFSET AT TIME ZONE [timezonename]" to convert the datetime to a local time zone. 

Use this query to see all the timezone names:

```sql
SELECT * FROM sys.time_zone_info
```



## Using DATETIME or DATETIME2 Instead of DATE
**Check Id:** [NONE YET]

Even with data storage being so cheap, a saving in a data type adds up and makes comparison and calculation easier. When appropriate, use the DATE or SMALLDATETIME type. Narrow tables perform better and use less resources.



## Using DATETIME or DATETIME2 Instead of TIME
**Check Id:** [NONE YET]

Being frugal with memory is important for large tables, not only to save space but also to reduce I/O activity during access. When appropriate, use the TIME or SMALLDATETIME type. Queries too are generally simpler on the appropriate data type.



## Using MONEY Data Type
**Check Id:** 28

The MONEY data type confuses the storage of data values with their display, though it clearly suggests, by its name, the sort of data held. Use DECIMAL(19, 4) instead. It is proprietary to SQL Server. 

MONEY has limited precision (the underlying type is a BIGINT or in the case of SMALLMONEY an INT) so you can unintentionally get a loss of precision due to roundoff errors. While simple addition or subtraction is fine, more complicated calculations that can be done for financial reports can show errors. 

Although the MONEY data type generally takes less storage and takes less bandwidth when sent over networks, it is generally far better to use a data type such as the DECIMAL(19, 4) type that is less likely to suffer from rounding errors or scale overflow.


## Using VARCHAR Instead of NVARCHAR for Unicode Data
**Check Id:** [NONE YET]

You can't require everyone to stop using national characters or accents any more. Names are likely to have accents in them if spelled properly, and international addresses and language strings will almost certainly have accents and national characters that can’t be represented by 8-bit ASCII!

**Column names to check:**
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