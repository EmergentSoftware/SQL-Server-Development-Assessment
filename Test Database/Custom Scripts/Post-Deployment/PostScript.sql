/*
* Use this Post-Deployment script to perform tasks after the deployment of the project.
* Read more at https://www.red-gate.com/SOC7/post-deployment-script-help
*/
/* Create a table that we will delete so that we have an invalid object to test */
CREATE TABLE dbo.UseToExist (
    UseToExistId     INT         IDENTITY(1, 1) NOT NULL
   ,UseToExistColumn VARCHAR(30) NULL CONSTRAINT UseToExist_UseToExistId PRIMARY KEY CLUSTERED (UseToExistId)
);
GO

CREATE VIEW dbo.InvalidObject
AS
SELECT UTE.UseToExistId, UTE.UseToExistColumn FROM dbo.UseToExist AS UTE;
GO

CREATE PROCEDURE dbo.InvalidObjectList
AS
BEGIN
    SET NOCOUNT ON;

    SELECT UTE.UseToExistId, UTE.UseToExistColumn FROM dbo.UseToExist AS UTE;
END;
GO

DROP TABLE dbo.UseToExist;
GO

CREATE INDEX HypotheticalIndex_HypotheticalIndexValue
    ON dbo.HypotheticalIndex (HypotheticalIndexValue)
WITH (DROP_EXISTING = ON, STATISTICS_ONLY=1);
GO