SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Tables that start with tbl]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    DECLARE @Output VarChar(max)
    SET @Output = ''

    SELECT  @Output = @Output + TABLE_SCHEMA + '.' + TABLE_NAME + Char(13) + Char(10)
    From    INFORMATION_SCHEMA.TABLES
    WHERE   TABLE_TYPE = 'BASE TABLE'
            And TABLE_NAME COLLATE SQL_LATIN1_GENERAL_CP1_CI_AI LIKE 'tbl%'
            And TABLE_SCHEMA <> 'tSQLt'
    Order By TABLE_SCHEMA,TABLE_NAME

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'For more information:  '
                          + 'https://github.com/red-gate/SQLCop/wiki/Tables-that-start-with-tbl'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End
END;
GO
