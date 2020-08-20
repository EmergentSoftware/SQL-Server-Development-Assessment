SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Procedures without SET NOCOUNT ON]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    Declare @Output VarChar(max)
    Set @Output = ''

    SELECT  @Output = @Output + Schema_Name(schema_id) + '.' + name + Char(13) + Char(10)
    From    sys.all_objects
    Where   Type = 'P'
            AND name Not In('sp_helpdiagrams','sp_upgraddiagrams','sp_creatediagram','testProcedures without SET NOCOUNT ON')
            And Object_Definition(Object_id) COLLATE SQL_LATIN1_GENERAL_CP1_CI_AI not Like '%SET NOCOUNT ON%'
            And is_ms_shipped = 0
            and schema_id <> Schema_id('tSQLt')
            and schema_id <> Schema_id('SQLCop')
    ORDER BY Schema_Name(schema_id) + '.' + name

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'For more information:  '
                          + 'https://github.com/red-gate/SQLCop/wiki/Procedures-without-set-nocount-on'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End

END;
GO
