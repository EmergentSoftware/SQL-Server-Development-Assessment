SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [SQLCop].[test Service Account]
AS
BEGIN
    -- Written by George Mastros
    -- February 25, 2012

    SET NOCOUNT ON

    Declare @Output VarChar(max)
    Set @Output = ''

    --Declare a variable to hold the value
    DECLARE @ServiceAccount varchar(100)

    --Retrieve the Service account from registry
    EXECUTE master.dbo.xp_instance_regread
            N'HKEY_LOCAL_MACHINE',
            N'SYSTEM\CurrentControlSet\Services\MSSQLSERVER',
            N'ObjectName',
            @ServiceAccount OUTPUT,
            N'no_output'

    --Display the Service Account
    SELECT @Output = 'Service account set to LocalSystem'
    Where  @ServiceAccount = 'LocalSystem'

    If @Output > ''
        Begin
            Set @Output = Char(13) + Char(10)
                          + 'For more information:  '
                          + 'https://github.com/red-gate/SQLCop/wiki/Service-Account'
                          + Char(13) + Char(10)
                          + Char(13) + Char(10)
                          + @Output
            EXEC tSQLt.Fail @Output
        End

END;
GO
