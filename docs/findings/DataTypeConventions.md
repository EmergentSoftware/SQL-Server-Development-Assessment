---
title: Data Type Conventions
permalink: best-practices-and-potential-findings/data-type-conventions
parent: Best Practices & Potential Findings
nav_order: 3
layout: default
---

# Data Type Conventions
{: .no_toc }
Poor data type choices can have significant impact on a database design and performance. A best practice is to right size the data type by understanding the data.

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

<a name="61"/><a name="columns-named-the-same-have-different-data-types"/>

## Columns and Parameters or Variables Used in JOINs and WHERE Clauses Should Have the Same Data Type
**Check Id:** 61 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Columns+and+Parameters+or+Variables+Used+in+JOINs+and+WHERE+Clauses+Should+Have+the+Same+Data+Type)

There are two situations where this is going to hurt performance. When you have a mismatch of data types in a JOIN and a WHERE clause. SQL Server will need to convert one of them to match the others data type. This is called implicit conversion.

**What will it hurt**

- Indexes will not be used correctly
- Missing index requests will not be logged in the DMV
- Extra CPU cycles are going to be required for the conversion

[Back to top](#top)

---

<a name="62"/><a name="do-not-use-deprecated-data-type"/>

## Using of Deprecated Data Type
**Check Id:** 62 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Do+not+use+Deprecated+Data+Type)

- Do not use the deprecated data types below.
  - ``text``
  - ``ntext``
  - ``image``
  - ``timestamp``

There is no good reason to use ``text`` or ``ntext``. They were a flawed attempt at BLOB storage and are there only for backward compatibility. Likewise, the WRITETEXT, UPDATETEXT and READTEXT statements are also deprecated. All this complexity has been replaced by the ``varchar(MAX)`` and ``nvarchar(MAX)`` data types, which work with all of SQL Server’s string functions.

[Back to top](#top)

---

<a name="63"/><a name="use-nvarchar128-when-storing-database-object-names"/>

## Does not match sysname Column data type
**Check Id:** 63 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Not+Using+Semicolon+THROW)

Use `nvarchar(128)` when storing database object names.

`sysname` is a special data type used for database objects like database names, table names, column names, et cetera. When you need to store database, table or column names in a table use nvarchar(128).

- See [Microsoft docs](https://docs.microsoft.com/en-us/previous-versions/sql/sql-server-2008/ms191240(v=sql.100)?redirectedfrom=MSDN#:~:text=The%20sysname%20data%20type%20is%20used%20for%20table%20columns%2C%20variables%2C%20and%20stored%20procedure%20parameters%20that%20store%20object%20names.)

[Back to top](#top)

---

<a name="64"/><a name="email-address-column"/>

## An Email Address Column Must not Exceed 254 Characters
**Check Id:** 64 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=An+Email+Address+Column+Must+not+Exceed+254+Characters)

An email address column should be set to ``nvarchar(254)`` to leave 2 characters for <> if needed.

[There is a restriction in RFC 2821 on the length of an address in MAIL and RCPT commands of 254 characters. Since addresses that do not fit in those fields are not normally useful, the upper limit on address lengths should normally be considered to be 254.](https://www.rfc-editor.org/errata_search.php?rfc=3696&eid=1690#:~:text=there%20is%20a%20restriction%20in%20RFC%202821%20on%20the%20length%20of%20an%0A%20%20%20address%20in%20MAIL%20and%20RCPT%20commands%20of%20254%20characters.%20%20Since%20addresses%0A%20%20%20that%20do%20not%20fit%20in%20those%20fields%20are%20not%20normally%20useful%2C%20the%20upper%0A%20%20%20limit%20on%20address%20lengths%20should%20normally%20be%20considered%20to%20be%20254.)

This was accepted by the IETF following [submitted erratum](https://www.rfc-editor.org/errata_search.php?rfc=3696&eid=1690). The original version of RFC 3696 described 320 as the maximum length, but John Klensin subsequently accepted an incorrect value, since a Path is defined as ```Path = "<" [ A-d-l ":" ] Mailbox ">"```

[Back to top](#top)

---

<a name="65"/><a name="url-column"/>

## A URL Column Must not Exceed 2083 Characters
**Check Id:** 65 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=A+URL+Column+Must+not+Exceed+2083+Characters)

A URL column should be set to ```nvarchar(2083)```.

RFC 2616, "Hypertext Transfer Protocol -- HTTP/1.1," does not specify any requirement for URL length. A web server will should return [RFC 7231, section 6.5.12: 414 URI Too Long](https://datatracker.ietf.org/doc/html/rfc7231#section-6.5.12)

The Internet Explorer browser has the shortest allowed URL max length in the address bar at 2083 characters. 

- See [URL or URI Naming](/SQL-Server-Development-Assessment/best-practices-and-potential-findings/naming-conventions#url-or-uri-naming)

#### Use Case Exception
If your application requires larger than 2083 characters, ensure the users are not utilizing IE and increase the nvarchar length.

- See [Maximum URL length is 2,083 characters in Internet Explorer](https://support.microsoft.com/en-us/topic/maximum-url-length-is-2-083-characters-in-internet-explorer-174e7c8a-6666-f4e0-6fd6-908b53c12246)


[Back to top](#top)

---

<a name="66"/><a name="do-not-overuse-nvarcharmax-for-columns"/>

## Overuse of (n)varchar(MAX)
**Check Id:** 66 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Do+not+Overuse+(n)varchar(MAX)+for+Columns)

You might be overusing ``(n)varchar(MAX)`` on your table.

``(n)varchar(MAX)`` columns can be included in an index but not as a key. Queries will not be able to perform an index seek on this column. 

``(n)varchar(MAX)`` should only every be used if the size of the field is known to be over 8K for ``varchar`` and 4K for ``nvarchar``

Since SQL Server 2016 if the size of the cell is < 8K characters for ``varchar(MAX)`` it will be treated as Row data. If > 8K it will be treated as a Large Object (LOB) for storage purposes.

[Back to top](#top)

---

<a name="67"/><a name="use-bit-for-boolean-columns"/>

## Boolean Column Not Using bit
**Check Id:** 67 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Use+bit+for+Boolean+Columns)

Use the ``bit`` data type for boolean columns. These columns will have names like IsSpecialSaleFlag.

[Back to top](#top)

---

<a name="68"/><a name="only-use-the-float-and-real-data-types-for-scientific-use-cases"/>

## Using float or real
**Check Id:** 68 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Only+use+the+float+and+real+Data+Types+for+Scientific+Use+Cases)

Only use the `float` and `real` data types for scientific use cases.

The ``float`` (8 byte) and ``real`` (4 byte) data types are suitable only for specialist scientific use since they are approximate types with an enormous range (-1.79E+308 to -2.23E-308, 0 and 2.23E-308 to 1.79E+308, in the case of ``float``). Any other use needs to be regarded as suspect, and a ``float`` or ``real`` used as a key or found in an index needs to be investigated. The ``decimal`` type is an exact data type and has an impressive range from -10^38+1 through 10^38-1. Although it requires more storage than the ``float`` or ``real`` types, it is generally a better choice.

[Back to top](#top)

---

<a name="69"/><a name="do-not-use-the-sql_variant-data-type"/>

## Using sql_variant
**Check Id:** 69 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Do+not+use+the+sql_variant+Data+Type)

Do not use the sql_variant data type.

The ``sql_variant`` type is not your typical data type. It stores values from a number of different data types and is used internally by SQL Server. It is hard to imagine a valid use in a relational database. It cannot be returned to an application via ODBC except as binary data, and it isn’t supported in Microsoft Azure SQL Database.

[Back to top](#top)

---

<a name="10"/><a name="avoid-user-defined-data-types-whenever-possible"/>

## Using User-Defined Data Type
**Check Id:** 10

Avoid user-defined data types whenever possible.

User-defined data types should be avoided whenever possible. They are an added processing overhead whose functionality could typically be accomplished more efficiently with simple data type variables, table variables, temporary tables, or JSON.


[Back to top](#top)

---

<a name="70"/><a name="use-the-datetimeoffset-data-type-when-time-zone-awareness-is-needed"/>

## Using datetime Instead of datetimeoffset
**Check Id:** 70 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Use+the+datetimeoffset+Data+Type+When+Time+Zone+Awareness+is+Needed)

Use the `datetimeoffset` data type when time zone awareness is needed.

``datetimeoffset`` defines a date that is combined with a time of a day that has time zone awareness and is based on a 24-hour clock. This allows you to use ``datetimeoffset AT TIME ZONE [timezonename]`` to convert the datetime to a local time zone. 

Use this query to see all the timezone names:

```sql
SELECT * FROM sys.time_zone_info
```

[Back to top](#top)

---

<a name="70"/><a name="use-the-date-data-type-when-time-values-are-not-required-or-the-smalldatetime-data-type-when-precision-of-minute-is-acceptable"/>

## Using datetime or datetime2 Instead of date
**Check Id:** 70 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Use+the+date+Data+Type+When+Time+Values+are+not+Required+or+the+smalldatetime+Data+Type+when+Precision+of+Minute+is+Acceptable)

Use the `date` data type when time values are not required or the `smalldatetime` data type when precision of minute is acceptable.

Even with data storage being so cheap, a saving in a data type adds up and makes comparison and calculation easier. When appropriate, use the ``date`` or ``smalldatetime`` type. Narrow tables perform better and use less resources.

[Back to top](#top)

---

<a name="71"/><a name="use-the-time-data-type-when-date-values-are-not-required-or-the-smalldatetime-data-type-when-precision-of-minute-is-acceptable"/>

## Using datetime or datetime2 Instead of time
**Check Id:** 71 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Use+the+time+Data+Type+When+Date+Values+are+not+Required+or+the+smalldatetime+Data+Type+when+Precision+of+Minute+is+Acceptable)

Use the `time` data type when date values are not required or the `smalldatetime` data type when precision of minute is acceptable.

Being frugal with memory is important for large tables, not only to save space but also to reduce I/O activity during access. When appropriate, use the ``time`` or ``smalldatetime`` type. Queries too are generally simpler on the appropriate data type.

[Back to top](#top)

---

<a name="28"/><a name="use-the-decimal-data-type-instead-of-the-money-data-type"/>

## Using money Data Type
**Potential Finding:** <a name="using-money-data-type"/><br/>
**Check Id:** 28

Use the decimal Data Type Instead of the money Data Type

The ``money`` data type confuses the storage of data values with their display, though it clearly suggests, by its name, the sort of data held. Use ``decimal(19, 4)`` instead. It is proprietary to SQL Server. 

``money`` has limited precision (the underlying type is a ``bigint`` or in the case of ``smallmoney`` an ``int``) so you can unintentionally get a loss of precision due to roundoff errors. While simple addition or subtraction is fine, more complicated calculations that can be done for financial reports can show errors. 

Although the ``money`` data type generally takes less storage and takes less bandwidth when sent over networks, it is generally far better to use a data type such as the ``decimal(19, 4)`` type that is less likely to suffer from rounding errors or scale overflow.


[Back to top](#top)

---

<a name="72"/><a name="use-the-nvarchar-data-type-instead-the-varchar-data-type-for-unicode-data"/>

## Using varchar Instead of nvarchar for Unicode Data
**Check Id:** 72 [Not implemented yet. Click here to add the issue if you want to develop and create a pull request.](https://github.com/EmergentSoftware/SQL-Server-Development-Assessment/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=Use+the+nvarchar+Data+Type+Instead+the+varchar+Data+Type+for+Unicode+Data)

Use the `nvarchar` data type instead the `varchar` data type for unicode values.

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