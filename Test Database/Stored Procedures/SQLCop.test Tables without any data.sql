SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Tables without any data]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    DECLARE @Output VarChar(max)
    SET @Output = ''

    SELECT  @Output = @Output + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) + Char(13) + Char(10)
    FROM    sys.tables t JOIN sys.dm_db_partition_stats p ON t.object_id=p.object_id
    WHERE   SCHEMA_NAME(t.schema_id) <> 'tSQLt'
    AND     p.row_count = 0
    ORDER BY SCHEMA_NAME(t.schema_id), t.name

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'Empty tables in your database:'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End
END;
GO
