SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Database collation]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    Declare @Output VarChar(max)
    Set @Output = ''

    Select  @Output = @Output + 'Warning: Collation conflict between user database and TempDB' + Char(13) + Char(10)
    Where   DatabasePropertyEx('TempDB', 'Collation') <> DatabasePropertyEx(db_name(), 'Collation')

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'For more information:  '
                          + 'https://github.com/red-gate/SQLCop/wiki/Database-collation'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End
END;
GO
