SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Auto update statistics]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    Declare @Output VarChar(max)
    Set @Output = ''

    Select @Output = @Output + 'Database not set to Auto Update Statistics' + Char(13) + Char(10)
    Where  DatabaseProperty(db_name(), 'IsAutoUpdateStatistics') = 0

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'For more information:  '
                          + 'https://github.com/red-gate/SQLCop/wiki/Auto-update-statistics'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End
END;
GO
