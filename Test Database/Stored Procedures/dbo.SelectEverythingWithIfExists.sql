SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[SelectEverythingWithIfExists]
AS
BEGIN
    SET NOCOUNT ON;

	/* This should not be caught by CheckId: 23 */
    IF EXISTS (
        SELECT
            *
        FROM
            sys.objects
    )
    BEGIN
        PRINT 'Stored procedure already exists';
    END;

END;
GO
