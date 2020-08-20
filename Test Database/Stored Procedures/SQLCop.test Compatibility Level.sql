SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Compatibility Level]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    Declare @Output VarChar(max)
    Set @Output = ''

    Select @Output = @Output + name + Char(13) + Char(10)
    FROM   sys.databases
    WHERE  compatibility_level != 10 * CONVERT(Int, CONVERT(FLOAT, CONVERT(VARCHAR(3), SERVERPROPERTY('productversion'))))

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'For more information:  '
                          + 'https://github.com/red-gate/SQLCop/wiki/Compatibility-level'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End

END;
GO
