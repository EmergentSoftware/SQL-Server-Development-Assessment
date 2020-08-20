/**********************************************************************************************************************
** MIT License
** 
** Copyright for portions of sp_Develop are held by Brent Ozar Unlimited as part of project 
** SQL-Server-First-Responder-Kit and are provided under the MIT license: 
** https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/ 
**
** Copyright for portions of sp_Develop are held by Phil Factor (real name withheld) as part of project 
** SQLCodeSmells https://github.com/Phil-Factor/SQLCodeSmells
**
** All other copyrights for sp_Develop are held by 
** Emergent Software, LLC as described below.
** 
** Copyright (c) 2020 Emergent Software, LLC
** 
** Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
** documentation files (the "Software"), to deal in the Software without restriction, including without limitation the 
** rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to 
** permit persons to whom the Software is furnished to do so, subject to the following conditions:
** 
** The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
** Software.
** 
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
** WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS 
** OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
** OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
**********************************************************************************************************************/
CREATE OR ALTER PROCEDURE dbo.sp_Develop
    @DatabaseName        NVARCHAR(128) = NULL /*Defaults to current DB if not specified*/
   ,@GetAllDatabases     BIT           = 0
   ,@IgnoreDatabases     NVARCHAR(MAX) = NULL /* Comma-delimited list of databases you want to skip */
   ,@BringThePain        BIT           = 0
   ,@IgnoreCheckIds      NVARCHAR(MAX) = NULL /* Comma-delimited list of check ids you want to skip */
   ,@ShowRememberChecks  BIT           = 0
   ,@OutputType          VARCHAR(20)   = 'TABLE'
   ,@OutputXMLasNVARCHAR BIT           = 0
   ,@Debug               INT           = 0
   ,@Version             VARCHAR(30)   = NULL OUTPUT
   ,@VersionDate         DATETIME      = NULL OUTPUT
   ,@VersionCheckMode    BIT           = 0
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    /**********************************************************************************************************************
	** Declare some varibles	
	**********************************************************************************************************************/

    DECLARE
        @LineFeed          NVARCHAR(5)
       ,@NumDatabases      INT
       ,@Message           NVARCHAR(4000)
       ,@StringToExecute   NVARCHAR(MAX)
       ,@DatabaseToIgnore  NVARCHAR(MAX)
       ,@ChecksToIgnore    NVARCHAR(MAX)
       ,@ScriptVersionName NVARCHAR(50)
       ,@ErrorSeverity     INT
       ,@ErrorState        INT
       ,@DatabaseId        INT
       ,@CheckId           INT
       ,@FindingsGroup     VARCHAR(100)
       ,@Finding           VARCHAR(200)
       ,@URLBase           VARCHAR(100)
       ,@URLAnchor         VARCHAR(400)
       ,@Priority          INT;

    SET @Version = '0.88';
    SET @VersionDate = '20200820';
    SET @URLBase = 'https://github.com/EmergentSoftware/SQL-Server-Assess#';
    SET @OutputType = UPPER(@OutputType);
    SET @LineFeed = CHAR(13) + CHAR(10);
    SET @ScriptVersionName = N'sp_Develop v' + @Version + N' - ' + DATENAME(MONTH, @VersionDate) + N' ' + RIGHT('0' + DATENAME(DAY, @VersionDate), 2) + N', ' + DATENAME(YEAR, @VersionDate);

    IF @VersionCheckMode = 1 BEGIN
RETURN 0;
    END;

    IF @Debug IN (1, 2)
        RAISERROR(N'Starting run. %s', 0, 1, @ScriptVersionName) WITH NOWAIT;

    /**********************************************************************************************************************
	** We start by creating #DeveloperResults. It's a temp table that will store all of the results from our checks. 
	** Throughout the rest of this stored procedure, we're running a series of checks looking for issues inside the 
	** database. When we find a problem, we insert rows into #DeveloperResults. At the end, we return these results to the 
	** end user.
	** 
	** #DeveloperResults has a CheckId field, but there's no Check table. As we do checks, we insert data into this table,
	** and we manually put in the CheckId.		
	** 
	** Create other temp tables
	**********************************************************************************************************************/

    IF OBJECT_ID('tempdb..#DeveloperResults') IS NOT NULL
        DROP TABLE #DeveloperResults;
    CREATE TABLE #DeveloperResults (
        DeveloperResultsId INT            IDENTITY(1, 1) NOT NULL
       ,CheckId            INT            NOT NULL DEFAULT-1
       ,Database_Id        INT            NOT NULL DEFAULT-1
       ,DatabaseName       NVARCHAR(128)  NOT NULL DEFAULT N''
       ,Priority           INT            NOT NULL DEFAULT-1
       ,FindingsGroup      VARCHAR(100)   NOT NULL
       ,Finding            VARCHAR(200)   NOT NULL
       ,URL                VARCHAR(2047)  NOT NULL
       ,Details            NVARCHAR(4000) NOT NULL
       ,Schema_Id          INT            NOT NULL DEFAULT-1
       ,SchemaName         NVARCHAR(128)  NULL DEFAULT N''
       ,Object_Id          INT            NOT NULL DEFAULT-1
       ,ObjectName         NVARCHAR(128)  NOT NULL DEFAULT N''
       ,ObjectType         NVARCHAR(60)   NOT NULL DEFAULT N''
    );

    IF OBJECT_ID('tempdb..#DatabaseList') IS NOT NULL DROP TABLE #DatabaseList;
    CREATE TABLE #DatabaseList (
        DatabaseName                          NVARCHAR(256) NOT NULL
       ,secondary_role_allow_connections_desc NVARCHAR(50)  NULL DEFAULT 'YES'
    );

    IF OBJECT_ID('tempdb..#Ignore_Databases') IS NOT NULL
        DROP TABLE #Ignore_Databases;
    CREATE TABLE #Ignore_Databases (DatabaseName NVARCHAR(128) NOT NULL, Reason NVARCHAR(100) NOT NULL);

    IF OBJECT_ID('tempdb..#SkipChecks') IS NOT NULL DROP TABLE #SkipChecks;
    CREATE TABLE #SkipChecks (
        CheckId      INT           NOT NULL
       ,DatabaseName NVARCHAR(128) NULL
       ,ServerName   NVARCHAR(128) NULL
    );
    CREATE CLUSTERED INDEX CheckId_DatabaseName
    ON #SkipChecks (CheckId, DatabaseName);

    /**********************************************************************************************************************
	** What checks are we going to perform?
	**********************************************************************************************************************/
    IF @IgnoreCheckIds IS NOT NULL
       AND LEN(@IgnoreCheckIds) > 0
    BEGIN
        IF @Debug IN (1, 2)
            RAISERROR(N'Setting up filter to ignore databases', 0, 1) WITH NOWAIT;

        SET @ChecksToIgnore = N'';

        /* Do not use STRING_SPLIT(), we want this to work in SQL Servers before 2016 */
        WHILE LEN(@IgnoreCheckIds) > 0
        BEGIN
            IF PATINDEX('%,%', @IgnoreCheckIds) > 0
            BEGIN
                SET @ChecksToIgnore = SUBSTRING(@IgnoreCheckIds, 0, PATINDEX('%,%', @IgnoreCheckIds));

                INSERT INTO
                    #SkipChecks (CheckId, DatabaseName, ServerName)
                SELECT
                    CheckId      = LTRIM(RTRIM(@ChecksToIgnore))
                   ,DatabaseName = NULL
                   ,ServerName   = NULL
                OPTION (RECOMPILE);

                SET @IgnoreCheckIds = SUBSTRING(@IgnoreCheckIds, LEN(@ChecksToIgnore + ',') + 1, LEN(@IgnoreCheckIds));
            END;
            ELSE
            BEGIN
                SET @ChecksToIgnore = @IgnoreCheckIds;
                SET @IgnoreCheckIds = NULL;

                INSERT INTO
                    #SkipChecks (CheckId, DatabaseName, ServerName)
                SELECT
                    CheckId      = LTRIM(RTRIM(@ChecksToIgnore))
                   ,DatabaseName = NULL
                   ,ServerName   = NULL
                OPTION (RECOMPILE);
            END;
        END;
    END;


    /**********************************************************************************************************************
	** Skip checks for specific SQL Servers
	**********************************************************************************************************************/

    /* If the server is Amazon RDS, skip checks that it doesn't allow */
    IF LEFT(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS VARCHAR(8000)), 8) = 'EC2AMAZ-'
       AND LEFT(CAST(SERVERPROPERTY('MachineName') AS VARCHAR(8000)), 8) = 'EC2AMAZ-'
       AND LEFT(CAST(SERVERPROPERTY('ServerName') AS VARCHAR(8000)), 8) = 'EC2AMAZ-'
       AND DB_ID('rdsadmin') IS NOT NULL
       AND EXISTS (
        SELECT
            *
        FROM
            sys.all_objects
        WHERE
            name IN ('rds_startup_tasks', 'rds_help_revlogin', 'rds_hexadecimal', 'rds_failover_tracking', 'rds_database_tracking', 'rds_track_change')
    )
    BEGIN
        /* Check to skip go here */
        /* INSERT INTO #SkipChecks (CheckId) VALUES (?); */

        /* Let them know we are skipping checks */
        INSERT INTO
            #DeveloperResults (CheckId, FindingsGroup, Finding, URL, Details)
        SELECT
            CheckID       = 26
           ,FindingsGroup = 'Running Issues'
           ,Finding       = 'Some Checks Skipped'
           ,URL           = @URLBase + 'some-checks-skipped'
           ,Details       = 'Amazon RDS detected, so we skipped some checks that are not currently possible, relevant, or practical there.';
    END;

    /* If the server is Express Edition, skip checks that it doesn't allow */
    IF CAST(SERVERPROPERTY('Edition') AS NVARCHAR(1000)) LIKE N'%Express%'
    BEGIN
        /* Check to skip go here */
        /* INSERT INTO #SkipChecks (CheckId) VALUES (?); */

        /* Let them know we are skipping checks */
        INSERT INTO
            #DeveloperResults (CheckId, FindingsGroup, Finding, URL, Details)
        SELECT
            CheckID       = 26
           ,FindingsGroup = 'Running Issues'
           ,Finding       = 'Some Checks Skipped'
           ,URL           = @URLBase + 'some-checks-skipped'
           ,Details       = 'Express Edition detected, so we skipped some checks that are not currently possible, relevant, or practical there.';
    END;


    /* If the server is an Azure Managed Instance, skip checks that it doesn't allow */
    IF SERVERPROPERTY('EngineEdition') = 8
    BEGIN
        /* Check to skip go here */
        /* INSERT INTO #SkipChecks (CheckId) VALUES (?); */

        /* Let them know we are skipping checks */
        INSERT INTO
            #DeveloperResults (CheckId, FindingsGroup, Finding, URL, Details)
        SELECT
            CheckID       = 26
           ,FindingsGroup = 'Running Issues'
           ,Finding       = 'Some Checks Skipped'
           ,URL           = @URLBase + 'some-checks-skipped'
           ,Details       = 'Managed Instance detected, so we skipped some checks that are not currently possible, relevant, or practical there.';
    END;


    /**********************************************************************************************************************
	** What databases are we going to check?
	**********************************************************************************************************************/
    IF @GetAllDatabases = 1
    BEGIN
        INSERT INTO
            #DatabaseList (DatabaseName)
        SELECT
            DB_NAME(database_id)
        FROM
            sys.databases
        WHERE
            user_access_desc   = 'MULTI_USER'
            AND state_desc     = 'ONLINE'
            AND database_id    > 4
            AND DB_NAME(database_id)NOT LIKE 'ReportServer%' /* SQL Server Reporting Services */
            AND DB_NAME(database_id)NOT LIKE 'rdsadmin%' /* Amazon RDS default database */
            AND DB_NAME(database_id) NOT IN ('DWQueue', 'DWDiagnostics', 'DWConfiguration') /* PolyBase databases do not need to be checked */
            AND DB_NAME(database_id) NOT IN ('SSISDB') /* SQL Server Integration Services */
            AND is_distributor = 0
        OPTION (RECOMPILE);

        /* Skip non-readable databases in an AG */
        IF EXISTS (
            SELECT
                *
            FROM
                sys.all_objects            AS o
                INNER JOIN sys.all_columns AS c ON o.object_id = c.object_id
                                                   AND o.name  = 'dm_hadr_availability_replica_states'
                                                   AND c.name  = 'role_desc'
        )
        BEGIN

            SET @StringToExecute = N'
				UPDATE
					DL
				SET
					secondary_role_allow_connections_desc = ''NO''
				FROM
					#DatabaseList                                      AS DL
					INNER JOIN sys.databases                           AS D ON DL.DatabaseName = D.name
					INNER JOIN sys.dm_hadr_availability_replica_states AS RS ON D.replica_id   = RS.replica_id
					INNER JOIN sys.availability_replicas               AS R ON RS.replica_id   = R.replica_id
				WHERE
					RS.role_desc                                = ''SECONDARY''
					AND R.secondary_role_allow_connections_desc = ''NO''
				OPTION (RECOMPILE);';

            EXEC sys.sp_executesql @stmt = @StringToExecute;

            IF EXISTS (
                SELECT
                    *
                FROM
                    #DatabaseList
                WHERE
                    secondary_role_allow_connections_desc = 'NO'
            )
            BEGIN
                /**********************************************************************************************************************/
                SELECT
                    @CheckId       = 17
                   ,@Priority      = 10
                   ,@FindingsGroup = 'Running Issues'
                   ,@Finding       = 'You are running this on an AG secondary, and some of your databases are configured as non-readable when this is a secondary node.'
                   ,@URLAnchor     = 'ran-on-a-non-readable-availability-group-secondary-databases';
                /**********************************************************************************************************************/
                INSERT INTO
                    #DeveloperResults (CheckId, FindingsGroup, Finding, URL, Priority, Details)
                SELECT
                    CheckId       = @CheckId
                   ,FindingsGroup = @FindingsGroup
                   ,Finding       = @Finding
                   ,URL           = @URLBase + @URLAnchor
                   ,Priority      = @Priority
                   ,Details       = N'To analyze those databases, run sp_Develop on the primary, or on a readable secondary.';

            END;
        END;

        IF @IgnoreDatabases IS NOT NULL
           AND LEN(@IgnoreDatabases) > 0
        BEGIN
            IF @Debug IN (1, 2)
                RAISERROR(N'Setting up filter to ignore databases', 0, 1) WITH NOWAIT;

            SET @DatabaseToIgnore = N'';

            WHILE LEN(@IgnoreDatabases) > 0
            BEGIN
                IF PATINDEX('%,%', @IgnoreDatabases) > 0
                BEGIN
                    SET @DatabaseToIgnore = SUBSTRING(@IgnoreDatabases, 0, PATINDEX('%,%', @IgnoreDatabases));

                    INSERT INTO
                        #Ignore_Databases (DatabaseName, Reason)
                    SELECT
                        LTRIM(RTRIM(@DatabaseToIgnore))
                       ,'Specified in the @IgnoreDatabases parameter'
                    OPTION (RECOMPILE);

                    SET @IgnoreDatabases = SUBSTRING(@IgnoreDatabases, LEN(@DatabaseToIgnore + ',') + 1, LEN(@IgnoreDatabases));
                END;
                ELSE
                BEGIN
                    SET @DatabaseToIgnore = @IgnoreDatabases;
                    SET @IgnoreDatabases = NULL;

                    INSERT INTO
                        #Ignore_Databases (DatabaseName, Reason)
                    SELECT
                        LTRIM(RTRIM(@DatabaseToIgnore))
                       ,'Specified in the @IgnoreDatabases parameter'
                    OPTION (RECOMPILE);
                END;
            END;
        END;

    END;
    ELSE
    BEGIN
        INSERT INTO
            #DatabaseList (DatabaseName)
        SELECT
            CASE
                WHEN @DatabaseName IS NULL
                     OR @DatabaseName = N'' THEN
                    DB_NAME()
                ELSE
                    @DatabaseName
            END;
    END;

    SET @NumDatabases = (SELECT COUNT(*)FROM #DatabaseList);
    SET @Message = N'Number of databases to examine: ' + CAST(@NumDatabases AS NVARCHAR(50));
    IF @Debug IN (1, 2) RAISERROR(@Message, 0, 1) WITH NOWAIT;

    /**********************************************************************************************************************/
    SELECT
        @CheckId       = 18
       ,@Priority      = 10
       ,@FindingsGroup = 'Running Issues'
       ,@Finding       = 'Ran Against 50+ Databases Without @BringThePain = 1'
       ,@URLAnchor     = 'ran-against-50-databases-without-bringthepain--1';
    /**********************************************************************************************************************/
    BEGIN TRY
        IF @NumDatabases >= 50
           AND @BringThePain <> 1
        BEGIN

            INSERT
                #DeveloperResults (CheckId, FindingsGroup, Finding, URL, Priority, Details)
            SELECT
                CheckId       = @CheckId
               ,FindingsGroup = @FindingsGroup
               ,Finding       = @Finding
               ,URL           = @URLBase + @URLAnchor
               ,Priority      = @Priority
               ,Details       = N'You''re trying to run sp_Develop on a server with ' + CAST(@NumDatabases AS NVARCHAR(50)) + ' databases. If you''re sure you want to do this, run again with the parameter @BringThePain = 1.';
            IF (@OutputType <> 'NONE')
            BEGIN

                SELECT
                    DR.DatabaseName
                   ,DR.SchemaName
                   ,DR.ObjectName
                   ,DR.ObjectType
                   ,DR.FindingsGroup
                   ,DR.Finding
                   ,DR.Details
                   ,DR.URL
                   ,DR.CheckId
                   ,DR.Database_Id
                   ,DR.Schema_Id
                   ,DR.Object_Id
                   ,DR.Priority
                FROM
                    #DeveloperResults AS DR
                ORDER BY
                    DR.Priority
                   ,DR.DatabaseName
                   ,DR.SchemaName
                   ,DR.ObjectName
                   ,DR.FindingsGroup
                   ,DR.Finding;

                RAISERROR('Running sp_Develop on a server with 50+ databases may cause temporary insanity for the server', 12, 1);
            END;

            RETURN 0;

        END;
    END TRY
    BEGIN CATCH
        RAISERROR(N'Failure to execute due to number of databases.', 0, 1) WITH NOWAIT;

        SELECT
            @Message       = ERROR_MESSAGE()
           ,@ErrorSeverity = ERROR_SEVERITY()
           ,@ErrorState    = ERROR_STATE();

        RAISERROR(@Message, @ErrorSeverity, @ErrorState);

        WHILE @@trancount > 0
        ROLLBACK;

        RETURN 0;
    END CATCH;

    /**********************************************************************************************************************/
    SELECT
        @CheckId       = 16
       ,@Priority      = 10
       ,@FindingsGroup = 'Running Issues'
       ,@Finding       = 'sp_Develop is Over 6 Months Old'
       ,@URLAnchor     = 'sp_develop-is-over-6-months-old';
    /**********************************************************************************************************************/
    IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
       AND DATEDIFF(MONTH, @VersionDate, GETDATE()) > 6
    BEGIN

        IF @Debug IN (1, 2)
            RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

        INSERT
            #DeveloperResults (CheckId, FindingsGroup, Finding, URL, Priority, Details)
        SELECT
            CheckId       = @CheckId
           ,FindingsGroup = @FindingsGroup
           ,Finding       = @Finding
           ,URL           = @URLBase + @URLAnchor
           ,Priority      = @Priority
           ,Details       = N'There most likely been some new checks and fixes performed within the last 6 months - time to go download the current one.';

    END;

    /**********************************************************************************************************************
	** Return the remember check unless turned off. These are checks that cannot or are tough to create a script for but 
	** we still want to show as a best practice.
	**********************************************************************************************************************/
    IF @ShowRememberChecks = 1
    BEGIN
        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Naming Conventions
		** Finding:			Not Naming Foreign Key Column the Same as Parent Table
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 201 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Naming Conventions'
           ,Finding       = 'Not Naming Foreign Key Column the Same as Parent Table'
           ,URL           = @URLBase + 'not-naming-foreign-key-column-the-same-as-parent-table'
           ,Details       = N'REMEMBER: Name the foreign key column the same as the parent table.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Naming Conventions
		** Finding:			Not Using PascalCase
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 201 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Naming Conventions'
           ,Finding       = 'Not Using PascalCase'
           ,URL           = @URLBase + 'not-using-pascalcase'
           ,Details       = N'REMEMBER: Use PascalCase for databse object names.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Naming Conventions
		** Finding:			Using Abbreviation
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 201 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Naming Conventions'
           ,Finding       = 'Using Abbreviation'
           ,URL           = @URLBase + 'using-abbreviation'
           ,Details       = N'REMEMBER: Don''t use abbreviation. Use "Account" instead of "Acct"';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Naming Conventions
		** Finding:			Stored Procedures & Function Naming
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 201 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Naming Conventions'
           ,Finding       = 'Stored Procedures & Function Naming'
           ,URL           = @URLBase + 'stored-procedures--function-naming'
           ,Details       = N'REMEMBER: Stored procedures and functions should be named with ObjectAction. e.g. "ProductGet" or "OrderUpdate".)';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Naming Conventions
		** Finding:			Non-Affirmative Boolean Name Use
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 201 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Naming Conventions'
           ,Finding       = 'Non-Affirmative Boolean Name Use'
           ,URL           = @URLBase + 'non-affirmative-boolean-name-use'
           ,Details       = N'REMEMBER: Bit columns should be given affirmative boolean names like "IsDeleted", "HasPermission", or "IsValid".';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Data Type Conventions
		** Finding:			Using DATETIME Instead of DATETIMEOFFSET
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 202 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Data Type Conventions'
           ,Finding       = 'Using DATETIME Instead of DATETIMEOFFSET'
           ,URL           = @URLBase + 'using-datetime-instead-of-datetimeoffset'
           ,Details       = N'REMEMBER: DATETIMEOFFSET defines a date that is combined with a time of a day and time zone. This allows you to use "DATETIMEOFFSET AT TIME ZONE [timezonename]" to convert the datetime to a local timezone.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Data Type Conventions
		** Finding:			DATETIME or DATETIME2 Instead of DATE
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 202 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Data Type Conventions'
           ,Finding       = 'Using DATETIME or DATETIME2 Instead of DATE'
           ,URL           = @URLBase + 'using-datetime-or-datetime2-instead-of-date'
           ,Details       = N'REMEMBER: When appropriate, use the DATE or SMALLDATETIME type.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Data Type Conventions
		** Finding:			DATETIME or DATETIME2 Instead of TIME
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 202 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Data Type Conventions'
           ,Finding       = 'Using DATETIME or DATETIME2 Instead of TIME'
           ,URL           = @URLBase + 'using-datetime-or-datetime2-instead-of-time'
           ,Details       = N'REMEMBER: When appropriate, use the TIME or SMALLDATETIME type.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	Data Type Conventions
		** Finding:			Using VARCHAR Instead of NVARCHAR for Unicode Data
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 202 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'Data Type Conventions'
           ,Finding       = 'Using VARCHAR Instead of NVARCHAR for Unicode Data'
           ,URL           = @URLBase + 'using-varchar-instead-of-nvarchar-for-unicode-data'
           ,Details       = N'REMEMBER: NVARCHAR allows you to store names and addresses with accents and national characters that VARCHAR does not store.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	SQL Code Development
		** Finding:			Using BETWEEN for DATETIME Ranges
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 203 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'SQL Code Development'
           ,Finding       = 'Using BETWEEN for DATETIME Ranges'
           ,URL           = @URLBase + 'using-between-for-datetime-ranges'
           ,Details       = N'REMEMBER: You never get complete accuracy if you specify dates when using the BETWEEN logical operator with DATETIME values.';

        /**********************************************************************************************************************
		** Check Id:		[NONE YET]
		** Findings Group:	SQL Code Development
		** Finding:			Using Old Sybase JOIN Syntax
		**********************************************************************************************************************/
        INSERT INTO
            #DeveloperResults (Priority, FindingsGroup, Finding, URL, Details)
        SELECT
            PRIORITY      = 203 /* Use the same Priority for Findings Group and it will ORDER BY in the results */
           ,FindingsGroup = 'SQL Code Development'
           ,Finding       = 'Using Old Sybase JOIN Syntax'
           ,URL           = @URLBase + 'using-old-sybase-join-syntax'
           ,Details       = N'REMEMBER: Use the ANSI standards "<>, >=" & "INNER JOIN" instead of the deprecated Sybase join syntax: "=*, *=" & "JOIN".';

    END;

    /**********************************************************************************************************************
	** Starting loop through databases
	**********************************************************************************************************************/
    IF @Debug IN (1, 2)
        RAISERROR(N'Starting loop through databases', 0, 1) WITH NOWAIT;

    DECLARE database_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        dl.DatabaseName
    FROM
        #DatabaseList                     AS dl
        LEFT OUTER JOIN #Ignore_Databases AS i ON dl.DatabaseName = i.DatabaseName
    WHERE
        COALESCE(dl.secondary_role_allow_connections_desc, 'OK') <> 'NO'
        AND i.DatabaseName IS NULL;

    OPEN database_cursor;
    FETCH NEXT FROM database_cursor
    INTO
        @DatabaseName;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        IF @Debug IN (1, 2)
        BEGIN
            RAISERROR(@LineFeed, 0, 1) WITH NOWAIT;
            RAISERROR(@LineFeed, 0, 1) WITH NOWAIT;
            RAISERROR(@DatabaseName, 0, 1) WITH NOWAIT;
        END;

        SELECT
            @DatabaseId = database_id
        FROM
            sys.databases
        WHERE
            name                 = @DatabaseName
            AND user_access_desc = 'MULTI_USER'
            AND state_desc       = 'ONLINE';

        /**********************************************************************************************************************
		** Skip checks for specific database versions
		**********************************************************************************************************************/

        --/* Skip the checks that would break due to lesser than 2019 (150 database compatibility level). */
        --IF EXISTS (
        --    SELECT
        --        *
        --    FROM
        --        sys.databases
        --    WHERE
        --        compatibility_level < 150
        --        AND database_id     = @DatabaseId
        --)
        --BEGIN
        --    /* Check to skip go here */
        --    INSERT INTO #SkipChecks (CheckId) VALUES (25); /* Scalar Function Is Not Inlineable */

        --    /* Let them know we are skipping checks */
        --    INSERT INTO
        --        #DeveloperResults (CheckId, Database_Id, FindingsGroup, Finding, URL, Details)
        --    SELECT
        --        CheckID       = 26
        --       ,Database_Id   = @DatabaseId
        --       ,FindingsGroup = 'Running Issues'
        --       ,Finding       = 'Some Checks Skipped'
        --       ,URL           = 'some-checks-skipped'
        --       ,Details       = 'Since you have databases with compatibility_level < 150, we can not run some checks: SELECT * FROM sys.databases WHERE compatibility_level < 150';
        --END;

        /**********************************************************************************************************************
        **  ██████ ██   ██ ███████  ██████ ██   ██ ███████     ███████ ████████  █████  ██████  ████████
        ** ██      ██   ██ ██      ██      ██  ██  ██          ██         ██    ██   ██ ██   ██    ██    
        ** ██      ███████ █████   ██      █████   ███████     ███████    ██    ███████ ██████     ██    
        ** ██      ██   ██ ██      ██      ██  ██       ██          ██    ██    ██   ██ ██   ██    ██    
        **  ██████ ██   ██ ███████  ██████ ██   ██ ███████     ███████    ██    ██   ██ ██   ██    ██  
		** The remember/best practices check's are above the database_cursor.
		**********************************************************************************************************************/
		-- SQL Prompt formatting off

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 1
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Using Plural in Names'
		   ,@URLAnchor     = 'using-plural-in-name';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'			
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Table and view names should be singular''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.type IN (''U'', ''V'')
					AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AI, 1) = ''S''
					AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AI, 2) <> ''SS''
					AND O.NAME NOT IN (''sysdiagrams'', ''database_firewall_rules'');';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 14
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Column Naming'
		   ,@URLAnchor     = 'column-naming';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'			
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = C.object_id
				   ,ObjectName    = T.name + ''.'' + C.name
				   ,ObjectType    = ''COLUMN''
				   ,Details       = N''Avoid repeating the table name except where it is natural to do so.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON C.object_id = T.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = T.schema_id
				WHERE
					C.name COLLATE SQL_Latin1_General_CP1_CI_AI LIKE ''%'' + T.name COLLATE SQL_Latin1_General_CP1_CI_AI + ''%''
					AND C.name NOT IN (''InvoiceDate'', ''InvoiceNumber'', ''PartNumber'', ''CustomerNumber'', ''GroupName'', ''StateCode'', ''PhoneNumber'')
					AND C.name COLLATE SQL_Latin1_General_CP1_CI_AI <> T.name COLLATE SQL_Latin1_General_CP1_CI_AI + ''Id'';';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 2
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Using Prefix in Name'
		   ,@URLAnchor     = 'using-prefix-in-name';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Never use a prefix such as tbl, sp, vw in names.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.name NOT IN (''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'', ''fn_diagramobjects'', ''sp_Develop'', ''sp_WhoIsActive'')
					AND (
							LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AI, 4) IN (''tab_'')
							OR LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AI, 3) IN (''tbl'', ''sp_'', ''xp_'', ''dt_'', ''fn_'', ''tr_'', ''usp'', ''usr'')
							OR LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AI, 2) IN (''tb'', ''t_'', ''vw'', ''fn'')
							OR O.name LIKE ''[v][A-Z]%'' COLLATE Latin1_General_BIN
							OR O.name LIKE ''[t][A-Z]%'' COLLATE Latin1_General_BIN
							OR O.name LIKE ''[s][p][A-Z]%'' COLLATE Latin1_General_BIN
							OR O.name LIKE ''[t][r][A-Z]%'' COLLATE Latin1_General_BIN
						);';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		
			/* Find Table Columns */

			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = C.object_id
				   ,ObjectName    = T.name + ''.'' + C.name
				   ,ObjectType    = ''COLUMN''
				   ,Details       = N''Never use a prefix such as fld, col, u_, c_, ... in column names.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T ON T.object_id = C.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = T.schema_id
				WHERE
					LEFT(C.name COLLATE SQL_Latin1_General_CP1_CI_AI, 4) IN (''fld_'', ''col_'')
					OR LEFT(C.name COLLATE SQL_Latin1_General_CP1_CI_AI, 2) IN (''u_'', ''c_'')
					OR C.name LIKE ''[f][A-Z]%'' COLLATE Latin1_General_BIN
					OR C.name LIKE ''[c][A-Z]%'' COLLATE Latin1_General_BIN
					OR C.name LIKE ''[u][A-Z]%'' COLLATE Latin1_General_BIN;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

			/* Find User-Defined Data Types */

			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = T.user_type_id
				   ,ObjectName    = T.name
				   ,ObjectType    = ''USER-DEFINED DATA TYPE''
				   ,Details       = N''Never use a prefix such as ud_, ud, ... in user-defined data type names.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.types                    AS T
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON S.schema_id = T.schema_id
				WHERE
					T.is_user_defined = 1
					AND (
						 LEFT(T.name COLLATE SQL_Latin1_General_CP1_CI_AI, 3) IN (''ud_'')
						 OR T.name LIKE ''[u][d][A-Z]%'' COLLATE Latin1_General_BIN
						 );';

				EXEC sys.sp_executesql @stmt = @StringToExecute;
				IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 5
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Including Special Characters in Name'
		   ,@URLAnchor     = 'including-special-characters-in-name';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Special characters should not be used in names.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.type_desc NOT IN (''DEFAULT_CONSTRAINT'', ''FOREIGN_KEY_CONSTRAINT'', ''PRIMARY_KEY_CONSTRAINT'', ''INTERNAL_TABLE'', ''CHECK_CONSTRAINT'', ''UNIQUE_CONSTRAINT'', ''SQL_INLINE_TABLE_VALUED_FUNCTION'', ''TYPE_TABLE'', ''SEQUENCE_OBJECT'')
					AND O.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'', ''database_firewall_rules'', ''sp_Develop'', ''sp_WhoIsActive'')
					AND (
						O.name LIKE ''%[^A-Z0-9@$#]%'' COLLATE Latin1_General_CI_AI /* contains illegal characters */
						OR O.name NOT LIKE ''[A-Z]%'' COLLATE Latin1_General_CI_AI /* doesn''t start with a character */
						);';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 13
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Concatenating Two Table Names'
		   ,@URLAnchor     = 'including-special-characters-in-name';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = T.object_id
				   ,ObjectName    = T.name
				   ,ObjectType    = T.type_desc
				   ,Details       = N''Avoid, where possible, concatenating two table names together. Use "Subscription" instead of "NewspaperReader".''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T
					INNER JOIN (
						SELECT
							DoubleName = T1.name + T2.name
						FROM
							' + QUOTENAME(@DatabaseName) + N'.sys.tables                               AS T1
							CROSS JOIN (SELECT name FROM ' + QUOTENAME(@DatabaseName) + N'.sys.tables) AS T2
						GROUP BY
							T1.name + T2.name
					)          AS C ON C.DoubleName = T.name
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = T.schema_id;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 11
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Including Numbers in Table Name'
		   ,@URLAnchor     = 'including-numbers-in-table-name';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = T.object_id
				   ,ObjectName    = T.name
				   ,ObjectType    = T.type_desc
				   ,Details       = N''Including Numbers in Table Name.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = T.schema_id
				WHERE
					T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					AND T.name LIKE ''%[0-9][0-9]%'' COLLATE Latin1_General_CI_AI; /* contains more than one adjacent number */;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;
		
		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 12
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Column Named Same as Table'
		   ,@URLAnchor     = 'column-named-same-as-table';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = C.object_id
				   ,ObjectName    = T.name + ''.'' + C.name
				   ,ObjectType    = ''COLUMN''
				   ,Details       = N''Do not give a table the same name as one of its columns.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.columns            AS C
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON T.object_id = C.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = T.schema_id
				WHERE
					C.name = T.name;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;
		
		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 4
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Using Reserved Words in Name'
		   ,@URLAnchor     = 'using-reserved-words-in-name';
		/**********************************************************************************************************************/

		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
						
			/* SQL Server and Azure SQL Data Warehouse Reserved Keywords */
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Using SQL Server and Azure SQL Data Warehouse reserved keywords makes code more difficult to read, can cause problems to code formatters, and can cause errors when writing code.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
					INNER JOIN (
						VALUES (''ADD''), (''EXTERNAL''), (''PROCEDURE''), (''ALL''), (''FETCH''), (''PUBLIC''), (''ALTER''), (''FILE''), (''RAISERROR''), (''AND''), (''FILLFACTOR''), (''READ''), (''ANY''), (''FOR''), (''READTEXT''), (''AS''), (''FOREIGN''), (''RECONFIGURE''), (''ASC''), (''FREETEXT''), (''REFERENCES''), (''AUTHORIZATION''), (''FREETEXTTABLE''), (''REPLICATION''), (''BACKUP''), (''FROM''), (''RESTORE''), (''BEGIN''), (''FULL''), (''RESTRICT''), (''BETWEEN''), (''FUNCTION''), (''RETURN''), (''BREAK''), (''GOTO''), (''REVERT''), (''BROWSE''), (''GRANT''), (''REVOKE''), (''BULK''), (''GROUP''), (''RIGHT''), (''BY''), (''HAVING''), (''ROLLBACK''), (''CASCADE''), (''HOLDLOCK''), (''ROWCOUNT''), (''CASE''), (''IDENTITY''), (''ROWGUIDCOL''), (''CHECK''), (''IDENTITY_INSERT''), (''RULE''), (''CHECKPOINT''), (''IDENTITYCOL''), (''SAVE''), (''CLOSE''), (''IF''), (''SCHEMA''), (''CLUSTERED''), (''IN''), (''SECURITYAUDIT''), (''COALESCE''), (''INDEX''), (''SELECT''), (''COLLATE''), (''INNER''), (''SEMANTICKEYPHRASETABLE''), (''COLUMN''), (''INSERT''), (''SEMANTICSIMILARITYDETAILSTABLE''), (''COMMIT''), (''INTERSECT''), (''SEMANTICSIMILARITYTABLE''), (''COMPUTE''), (''INTO''), (''SESSION_USER''), (''CONSTRAINT''), (''IS''), (''SET''), (''CONTAINS''), (''JOIN''), (''SETUSER''), (''CONTAINSTABLE''), (''KEY''), (''SHUTDOWN''), (''CONTINUE''), (''KILL''), (''SOME''), (''CONVERT''), (''LEFT''), (''STATISTICS''), (''CREATE''), (''LIKE''), (''SYSTEM_USER''), (''CROSS''), (''LINENO''), (''TABLE''), (''CURRENT''), (''LOAD''), (''TABLESAMPLE''), (''CURRENT_DATE''), (''MERGE''), (''TEXTSIZE''), (''CURRENT_TIME''), (''NATIONAL''), (''THEN''), (''CURRENT_TIMESTAMP''), (''NOCHECK''), (''TO''), (''CURRENT_USER''), (''NONCLUSTERED''), (''TOP''), (''CURSOR''), (''NOT''), (''TRAN''), (''DATABASE''), (''NULL''), (''TRANSACTION''), (''DBCC''), (''NULLIF''), (''TRIGGER''), (''DEALLOCATE''), (''OF''), (''TRUNCATE''), (''DECLARE''), (''OFF''), (''TRY_CONVERT''), (''DEFAULT''), (''OFFSETS''), (''TSEQUAL''), (''DELETE''), (''ON''), (''UNION''), (''DENY''), (''OPEN''), (''UNIQUE''), (''DESC''), (''OPENDATASOURCE''), (''UNPIVOT''), (''DISK''), (''OPENQUERY''), (''UPDATE''), (''DISTINCT''), (''OPENROWSET''), (''UPDATETEXT''), (''DISTRIBUTED''), (''OPENXML''), (''USE''), (''DOUBLE''), (''OPTION''), (''USER''), (''DROP''), (''OR''), (''VALUES''), (''DUMP''), (''ORDER''), (''VARYING''), (''ELSE''), (''OUTER''), (''VIEW''), (''END''), (''OVER''), (''WAITFOR''), (''ERRLVL''), (''PERCENT''), (''WHEN''), (''ESCAPE''), (''PIVOT''), (''WHERE''), (''EXCEPT''), (''PLAN''), (''WHILE''), (''EXEC''), (''PRECISION''), (''WITH''), (''EXECUTE''), (''PRIMARY''), (''WITHIN GROUP''), (''EXISTS''), (''PRINT''), (''WRITETEXT''), (''EXIT''), (''PROC'')
					) AS reserved (word) ON reserved.word = O.name;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

			/* ODBC Reserved Keywords */
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Using ODBC reserved keywords makes code more difficult to read, can cause problems to code formatters, and can cause errors when writing code.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
					INNER JOIN (
						VALUES (''ABSOLUTE''), (''EXEC''), (''OVERLAPS''), (''ACTION''), (''EXECUTE''), (''PAD''), (''ADA''), (''EXISTS''), (''PARTIAL''), (''ADD''), (''EXTERNAL''), (''PASCAL''), (''ALL''), (''EXTRACT''), (''POSITION''), (''ALLOCATE''), (''FALSE''), (''PRECISION''), (''ALTER''), (''FETCH''), (''PREPARE''), (''AND''), (''FIRST''), (''PRESERVE''), (''ANY''), (''FLOAT''), (''PRIMARY''), (''ARE''), (''FOR''), (''PRIOR''), (''AS''), (''FOREIGN''), (''PRIVILEGES''), (''ASC''), (''FORTRAN''), (''PROCEDURE''), (''ASSERTION''), (''FOUND''), (''PUBLIC''), (''AT''), (''FROM''), (''READ''), (''AUTHORIZATION''), (''FULL''), (''REAL''), (''AVG''), (''GET''), (''REFERENCES''), (''BEGIN''), (''GLOBAL''), (''RELATIVE''), (''BETWEEN''), (''GO''), (''RESTRICT''), (''BIT''), (''GOTO''), (''REVOKE''), (''BIT_LENGTH''), (''GRANT''), (''RIGHT''), (''BOTH''), (''GROUP''), (''ROLLBACK''), (''BY''), (''HAVING''), (''ROWS''), (''CASCADE''), (''HOUR''), (''SCHEMA''), (''CASCADED''), (''IDENTITY''), (''SCROLL''), (''CASE''), (''IMMEDIATE''), (''SECOND''), (''CAST''), (''IN''), (''SECTION''), (''CATALOG''), (''INCLUDE''), (''SELECT''), (''CHAR''), (''INDEX''), (''SESSION''), (''CHAR_LENGTH''), (''INDICATOR''), (''SESSION_USER''), (''CHARACTER''), (''INITIALLY''), (''SET''), (''CHARACTER_LENGTH''), (''INNER''), (''SIZE''), (''CHECK''), (''INPUT''), (''SMALLINT''), (''CLOSE''), (''INSENSITIVE''), (''SOME''), (''COALESCE''), (''INSERT''), (''SPACE''), (''COLLATE''), (''INT''), (''SQL''), (''COLLATION''), (''INTEGER''), (''SQLCA''), (''COLUMN''), (''INTERSECT''), (''SQLCODE''), (''COMMIT''), (''INTERVAL''), (''SQLERROR''), (''CONNECT''), (''INTO''), (''SQLSTATE''), (''CONNECTION''), (''IS''), (''SQLWARNING''), (''CONSTRAINT''), (''ISOLATION''), (''SUBSTRING''), (''CONSTRAINTS''), (''JOIN''), (''SUM''), (''CONTINUE''), (''KEY''), (''SYSTEM_USER''), (''CONVERT''), (''LANGUAGE''), (''TABLE''), (''CORRESPONDING''), (''LAST''), (''TEMPORARY''), (''COUNT''), (''LEADING''), (''THEN''), (''CREATE''), (''LEFT''), (''TIME''), (''CROSS''), (''LEVEL''), (''TIMESTAMP''), (''CURRENT''), (''LIKE''), (''TIMEZONE_HOUR''), (''CURRENT_DATE''), (''LOCAL''), (''TIMEZONE_MINUTE''), (''CURRENT_TIME''), (''LOWER''), (''TO''), (''CURRENT_TIMESTAMP''), (''MATCH''), (''TRAILING''), (''CURRENT_USER''), (''MAX''), (''TRANSACTION''), (''CURSOR''), (''MIN''), (''TRANSLATE''), (''DATE''), (''MINUTE''), (''TRANSLATION''), (''DAY''), (''MODULE''), (''TRIM''), (''DEALLOCATE''), (''MONTH''), (''TRUE''), (''DEC''), (''NAMES''), (''UNION''), (''DECIMAL''), (''NATIONAL''), (''UNIQUE''), (''DECLARE''), (''NATURAL''), (''UNKNOWN''), (''DEFAULT''), (''NCHAR''), (''UPDATE''), (''DEFERRABLE''), (''NEXT''), (''UPPER''), (''DEFERRED''), (''NO''), (''USAGE''), (''DELETE''), (''NONE''), (''USER''), (''DESC''), (''NOT''), (''USING''), (''DESCRIBE''), (''NULL''), (''VALUE''), (''DESCRIPTOR''), (''NULLIF''), (''VALUES''), (''DIAGNOSTICS''), (''NUMERIC''), (''VARCHAR''), (''DISCONNECT''), (''OCTET_LENGTH''), (''VARYING''), (''DISTINCT''), (''OF''), (''VIEW''), (''DOMAIN''), (''ON''), (''WHEN''), (''DOUBLE''), (''ONLY''), (''WHENEVER''), (''DROP''), (''OPEN''), (''WHERE''), (''ELSE''), (''OPTION''), (''WITH''), (''END''), (''OR''), (''WORK''), (''END-EXEC''), (''ORDER''), (''WRITE''), (''ESCAPE''), (''OUTER''), (''YEAR''), (''EXCEPT''), (''OUTPUT''), (''ZONE''), (''EXCEPTION'')
					) AS reserved (word) ON reserved.word = O.name;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			
			/* Future Reserved Keywords */
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Using SQL Server Future reserved keywords makes code more difficult to read, can cause problems to code formatters, and can cause errors when writing code.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
					INNER JOIN (
						VALUES (''ABSOLUTE''), (''HOST''), (''RELATIVE''), (''ACTION''), (''HOUR''), (''RELEASE''), (''ADMIN''), (''IGNORE''), (''RESULT''), (''AFTER''), (''IMMEDIATE''), (''RETURNS''), (''AGGREGATE''), (''INDICATOR''), (''ROLE''), (''ALIAS''), (''INITIALIZE''), (''ROLLUP''), (''ALLOCATE''), (''INITIALLY''), (''ROUTINE''), (''ARE''), (''INOUT''), (''ROW''), (''ARRAY''), (''INPUT''), (''ROWS''), (''ASENSITIVE''), (''INT''), (''SAVEPOINT''), (''ASSERTION''), (''INTEGER''), (''SCROLL''), (''ASYMMETRIC''), (''INTERSECTION''), (''SCOPE''), (''AT''), (''INTERVAL''), (''SEARCH''), (''ATOMIC''), (''ISOLATION''), (''SECOND''), (''BEFORE''), (''ITERATE''), (''SECTION''), (''BINARY''), (''LANGUAGE''), (''SENSITIVE''), (''BIT''), (''LARGE''), (''SEQUENCE''), (''BLOB''), (''LAST''), (''SESSION''), (''BOOLEAN''), (''LATERAL''), (''SETS''), (''BOTH''), (''LEADING''), (''SIMILAR''), (''BREADTH''), (''LESS''), (''SIZE''), (''CALL''), (''LEVEL''), (''SMALLINT''), (''CALLED''), (''LIKE_REGEX''), (''SPACE''), (''CARDINALITY''), (''LIMIT''), (''SPECIFIC''), (''CASCADED''), (''LN''), (''SPECIFICTYPE''), (''CAST''), (''LOCAL''), (''SQL''), (''CATALOG''), (''LOCALTIME''), (''SQLEXCEPTION''), (''CHAR''), (''LOCALTIMESTAMP''), (''SQLSTATE''), (''CHARACTER''), (''LOCATOR''), (''SQLWARNING''), (''CLASS''), (''MAP''), (''START''), (''CLOB''), (''MATCH''), (''STATE''), (''COLLATION''), (''MEMBER''), (''STATEMENT''), (''COLLECT''), (''METHOD''), (''STATIC''), (''COMPLETION''), (''MINUTE''), (''STDDEV_POP''), (''CONDITION''), (''MOD''), (''STDDEV_SAMP''), (''CONNECT''), (''MODIFIES''), (''STRUCTURE''), (''CONNECTION''), (''MODIFY''), (''SUBMULTISET''), (''CONSTRAINTS''), (''MODULE''), (''SUBSTRING_REGEX''), (''CONSTRUCTOR''), (''MONTH''), (''SYMMETRIC''), (''CORR''), (''MULTISET''), (''SYSTEM''), (''CORRESPONDING''), (''NAMES''), (''TEMPORARY''), (''COVAR_POP''), (''NATURAL''), (''TERMINATE''), (''COVAR_SAMP''), (''NCHAR''), (''THAN''), (''CUBE''), (''NCLOB''), (''TIME''), (''CUME_DIST''), (''NEW''), (''TIMESTAMP''), (''CURRENT_CATALOG''), (''NEXT''), (''TIMEZONE_HOUR''), (''CURRENT_DEFAULT_TRANSFORM_GROUP''), (''NO''), (''TIMEZONE_MINUTE''), (''CURRENT_PATH''), (''NONE''), (''TRAILING''), (''CURRENT_ROLE''), (''NORMALIZE''), (''TRANSLATE_REGEX''), (''CURRENT_SCHEMA''), (''NUMERIC''), (''TRANSLATION''), (''CURRENT_TRANSFORM_GROUP_FOR_TYPE''), (''OBJECT''), (''TREAT''), (''CYCLE''), (''OCCURRENCES_REGEX''), (''TRUE''), (''DATA''), (''OLD''), (''UESCAPE''), (''DATE''), (''ONLY''), (''UNDER''), (''DAY''), (''OPERATION''), (''UNKNOWN''), (''DEC''), (''ORDINALITY''), (''UNNEST''), (''DECIMAL''), (''OUT''), (''USAGE''), (''DEFERRABLE''), (''OVERLAY''), (''USING''), (''DEFERRED''), (''OUTPUT''), (''VALUE''), (''DEPTH''), (''PAD''), (''VAR_POP''), (''DEREF''), (''PARAMETER''), (''VAR_SAMP''), (''DESCRIBE''), (''PARAMETERS''), (''VARCHAR''), (''DESCRIPTOR''), (''PARTIAL''), (''VARIABLE''), (''DESTROY''), (''PARTITION''), (''WHENEVER''), (''DESTRUCTOR''), (''PATH''), (''WIDTH_BUCKET''), (''DETERMINISTIC''), (''POSTFIX''), (''WITHOUT''), (''DICTIONARY''), (''PREFIX''), (''WINDOW''), (''DIAGNOSTICS''), (''PREORDER''), (''WITHIN''), (''DISCONNECT''), (''PREPARE''), (''WORK''), (''DOMAIN''), (''PERCENT_RANK''), (''WRITE''), (''DYNAMIC''), (''PERCENTILE_CONT''), (''XMLAGG''), (''EACH''), (''PERCENTILE_DISC''), (''XMLATTRIBUTES''), (''ELEMENT''), (''POSITION_REGEX''), (''XMLBINARY''), (''END-EXEC''), (''PRESERVE''), (''XMLCAST''), (''EQUALS''), (''PRIOR''), (''XMLCOMMENT''), (''EVERY''), (''PRIVILEGES''), (''XMLCONCAT''), (''EXCEPTION''), (''RANGE''), (''XMLDOCUMENT''), (''FALSE''), (''READS''), (''XMLELEMENT''), (''FILTER''), (''REAL''), (''XMLEXISTS''), (''FIRST''), (''RECURSIVE''), (''XMLFOREST''), (''FLOAT''), (''REF''), (''XMLITERATE''), (''FOUND''), (''REFERENCING''), (''XMLNAMESPACES''), (''FREE''), (''REGR_AVGX''), (''XMLPARSE''), (''FULLTEXTTABLE''), (''REGR_AVGY''), (''XMLPI''), (''FUSION''), (''REGR_COUNT''), (''XMLQUERY''), (''GENERAL''), (''REGR_INTERCEPT''), (''XMLSERIALIZE''), (''GET''), (''REGR_R2''), (''XMLTABLE''), (''GLOBAL''), (''REGR_SLOPE''), (''XMLTEXT''), (''GO''), (''REGR_SXX''), (''XMLVALIDATE''), (''GROUPING''), (''REGR_SXY''), (''YEAR''), (''HOLD''), (''REGR_SYY''), (''ZONE'')
					) AS reserved (word) ON reserved.word = O.name;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 3
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Table Conventions'
		   ,@Finding       = 'Wide Table'
		   ,@URLAnchor     = 'wide-table';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = CAST(T.max_column_id_used AS NVARCHAR(11)) + N'' columns. You might be treating this table like a spreadsheet. You might need to redesign your table schema.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = T.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					T.max_column_id_used > 20;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 6
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Table Conventions'
		   ,@Finding       = 'Heap'
		   ,@URLAnchor     = 'heap';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Add a clustered index if this is not a staging table for a data warehouse.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T ON T.object_id = I.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = T.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					I.type = 0
					AND O.name NOT IN (''__SchemaSnapshot'');';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 7
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Naming Conventions'
		   ,@Finding       = 'Using ID for Primary Key Column Name'
		   ,@URLAnchor     = 'using-id-for-primary-key-column-name';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = C.object_id
				   ,ObjectName    = T.name + ''.'' + C.name
				   ,ObjectType    = ''COLUMN''
				   ,Details       = N''Primary key column names should be [TableName] + "Id" (e.g. '' + T.name + N''Id)''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns AS IC ON I.object_id    = IC.object_id AND I.index_id = IC.index_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns       AS C ON IC.object_id    = C.object_id AND C.column_id = IC.column_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables        AS T ON T.object_id     = C.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S ON S.schema_id     = T.schema_id				
				WHERE
					I.is_primary_key  = 1
					AND C.name COLLATE SQL_Latin1_General_CP1_CI_AI = ''id'';';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 8
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Table Conventions'
		   ,@Finding       = 'UNIQUEIDENTIFIER For Primary Key'
		   ,@URLAnchor     = 'uniqueidentifier-for-primary-key';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = C.object_id
				   ,ObjectName    = T.name + ''.'' + C.name
				   ,ObjectType    = ''COLUMN''
				   ,Details       = N''Using UNIQUEIDENTIFIER/GUID as primary keys causes issues with SQL Server databases. Use an INT.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns AS IC ON I.object_id     = IC.object_id AND I.index_id = IC.index_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns       AS C  ON IC.object_id    = C.object_id AND C.column_id = IC.column_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types         AS TP ON TP.user_type_id = C.user_type_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables        AS T  ON T.object_id     = C.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON S.schema_id     = T.schema_id
				WHERE
					I.is_primary_key   = 1
					AND T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					AND C.user_type_id = 36;';

				EXEC sys.sp_executesql @stmt = @StringToExecute;
				IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			END;


--SET @StringToExecute = N'
--SELECT
--''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
--,*
--FROM
--    ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns      AS Ic
--    INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS tables ON tables.object_id = Ic.object_id
--    INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS c ON c.object_id           = Ic.object_id
--                                   AND c.column_id       = Ic.column_id
--    INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types   AS t ON t.system_type_id      = c.system_type_id
--    INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS i ON i.object_id           = Ic.object_id
--                                   AND i.index_id        = Ic.index_id
--WHERE
--    t.name          = ''uniqueidentifier''
--    AND i.type_desc = ''CLUSTERED'';

--'
--EXEC sys.sp_executesql @stmt = @StringToExecute;
--PRINT @StringToExecute;


		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 22
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Table Conventions'
		   ,@Finding       = 'UNIQUEIDENTIFIER in a Clustered Index'
		   ,@URLAnchor     = 'uniqueidentifier-in-a-clustered-index';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
		
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = IC.object_id
				   ,ObjectName    = T.name + ''.'' + C.name
				   ,ObjectType    = ''COLUMN''
				   ,Details       = N''UNIQUEIDENTIFIER/GUID columns should not be in a clustered index''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.index_columns      AS IC
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON T.object_id     = IC.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id     = T.schema_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON C.object_id     = IC.object_id
												   AND C.column_id = IC.column_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON I.object_id     = IC.object_id
												   AND I.index_id  = IC.index_id
				WHERE
					T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					AND C.system_type_id = 36
					AND I.type_desc  = ''CLUSTERED'';';

				EXEC sys.sp_executesql @stmt = @StringToExecute;
				IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 21
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Table Conventions'
		   ,@Finding       = 'Missing Index for Foreign Key'
		   ,@URLAnchor     = 'missing-index-for-foreign-key';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
		
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = FK.object_id
				   ,ObjectName    = T.name + ''.'' + FK.name
				   ,ObjectType    = FK.type_desc
				   ,Details       = N''Each foreign key in your table should be included in an index.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.foreign_keys                   AS FK
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas             AS S   ON S.schema_id                   = FK.schema_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables              AS T   ON T.object_id                   = FK.parent_object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.foreign_key_columns AS FKC ON FK.object_id                  = FKC.constraint_object_id
					LEFT OUTER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns  AS IC  ON IC.object_id                  = FKC.parent_object_id
																			     AND IC.column_id             = FKC.parent_column_id
																			     AND FKC.constraint_column_id = IC.key_ordinal
				WHERE					
					IC.object_id IS NULL;';

				EXEC sys.sp_executesql @stmt = @StringToExecute;
				IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 20
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Table Conventions'
		   ,@Finding       = 'Missing Primary Key'
		   ,@URLAnchor     = 'missing-primary-key';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
		
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = T.object_id
				   ,ObjectName    = T.name
				   ,ObjectType    = ''USER_TABLE''
				   ,Details       = N''Every table should have some column (or set of columns) that uniquely identifies one and only one row.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T					
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S ON S.schema_id = T.schema_id
					LEFT OUTER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes  AS I ON T.object_id = I.object_id AND I.is_primary_key = 1
				WHERE
				    T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					AND I.object_id IS NULL;';


				EXEC sys.sp_executesql @stmt = @StringToExecute;
				IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 10
		   ,@Priority      = 10
		   ,@FindingsGroup = 'Data Type Conventions'
		   ,@Finding       = 'Using User-Defined Data Type'
		   ,@URLAnchor     = 'using-user-defined-data-type';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = T.user_type_id
				   ,ObjectName    = T.name
				   ,ObjectType    = ''USER-DEFINED DATA TYPE''
				   ,Details       = N''User-defined data types should be avoided whenever possible.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.types                    AS T
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON S.schema_id = T.schema_id
				WHERE
					T.is_user_defined = 1;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 25
		   ,@Priority      = 10
		   ,@FindingsGroup = 'SQL Code Development'
		   ,@Finding       = 'Scalar Function Is Not Inlineable'
		   ,@URLAnchor     = 'scalar-function-is-not-inlineable';
		/**********************************************************************************************************************/	
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
			AND EXISTS(SELECT * FROM sys.databases WHERE compatibility_level >= 150 AND database_id = @DatabaseId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Your scalar function is not inlineable. You should make the function inlineable or inline the code manually.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules AS SM
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = SM.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.type               = ''FN''
					AND SM.is_inlineable = 0;'
			
			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 24
		   ,@Priority      = 10
		   ,@FindingsGroup = 'SQL Code Development'
		   ,@Finding       = 'Using User-Defined Scalar Function'
		   ,@URLAnchor     = 'using-user-defined-scalar-function';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
			AND EXISTS(SELECT * FROM sys.databases WHERE compatibility_level < 150 AND database_id = @DatabaseId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = O.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''You should inline your scalar function in SQL query. If your query requires scalar functions your should ensure they are being inlined.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.type = ''FN'';'
			
			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 23
		   ,@Priority      = 10
		   ,@FindingsGroup = 'SQL Code Development'
		   ,@Finding       = 'Using SELECT *'
		   ,@URLAnchor     = 'using-select-*';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = SM.object_id
				   ,ObjectName    = CASE O.type_desc
										WHEN ''SQL_TRIGGER'' THEN T.name + ''.'' + O.name
										ELSE O.name
									END
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Do not use the "SELECT *" in production code unless you have a good reason. Using "*" in math equations is OK.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules        AS SM
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = SM.object_id
					LEFT OUTER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T ON T.object_id = O.parent_object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					SM.definition LIKE ''%SELECT%*%'' COLLATE SQL_Latin1_General_CP1_CI_AI
					AND SM.definition NOT LIKE ''%IF%EXISTS%(%SELECT%*%'' COLLATE SQL_Latin1_General_CP1_CI_AI
					AND SM.definition NOT LIKE ''%COUNT%(%*%)%'' COLLATE SQL_Latin1_General_CP1_CI_AI
					AND SM.definition NOT LIKE ''%SELECT%=%*%'' COLLATE SQL_Latin1_General_CP1_CI_AI
					AND SM.definition NOT LIKE ''%SELECT%[0-9]%[*]%[0-9]%''
					--O.name LIKE ''[t][A-Z]%'' COLLATE Latin1_General_BIN;'
			
			/* TODO: Need better/more predicates. It is catching "2 * 3" math in columns  */

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 9
		   ,@Priority      = 10
		   ,@FindingsGroup = 'SQL Code Development'
		   ,@Finding       = 'Using Hardcoded Database Name Reference'
		   ,@URLAnchor     = 'using-hardcoded-database-name-reference';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = SM.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Use two-part instead three-part names for tables. You should use "'' + S.name + ''.TableName" instead of "' + @DatabaseName + N'.'' + S.name + ''.TableName" in the FROM clause.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules        AS SM
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = SM.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					PATINDEX(CONCAT(''%FROM%'', ''' + @DatabaseName + N''', ''.%.%'') COLLATE SQL_Latin1_General_CP1_CI_AI, SM.definition COLLATE SQL_Latin1_General_CP1_CI_AI) > 0;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 19
		   ,@Priority      = 10
		   ,@FindingsGroup = 'SQL Code Development'
		   ,@Finding       = 'Not Using SET NOCOUNT ON in Stored Procedure or Trigger'
		   ,@URLAnchor     = 'not-using-set-nocount-on-in-stored-procedure-or-trigger';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			/* Trigger */
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = TR.object_id
				   ,ObjectName    = T.name + ''.'' + TR.name
				   ,ObjectType    = ''SQL_TRIGGER''
				   ,Details       = N''Unless you need to return messages that give you the row count of each statement, you should SET NOCOUNT ON;.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.tables                 AS T
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas     AS S  ON S.schema_id  = T.schema_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.triggers    AS TR ON TR.parent_id = T.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules AS M  ON TR.object_id = M.object_id
				WHERE
					M.definition NOT LIKE ''%SET NOCOUNT ON%'' COLLATE SQL_Latin1_General_CP1_CI_AI;';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

			/* Stored Procedure */
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = SM.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''Unless you need to return messages that give you the row count of each statement, you should SET NOCOUNT ON;.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules        AS SM
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = SM.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.type IN (''P'')
					AND SM.definition NOT LIKE ''%SET NOCOUNT ON%'' COLLATE SQL_Latin1_General_CP1_CI_AI;'

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		/**********************************************************************************************************************/
		SELECT
			@CheckId       = 15
		   ,@Priority      = 10
		   ,@FindingsGroup = 'SQL Code Development'
		   ,@Finding       = 'Using NOLOCK (READ UNCOMMITTED)'
		   ,@URLAnchor     = 'using-nolock-read-uncommitted';
		/**********************************************************************************************************************/
		IF NOT EXISTS (SELECT 1 FROM #SkipChecks WHERE CheckId = @CheckId)
		BEGIN
			IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			SET @StringToExecute = N'
				INSERT INTO
					#DeveloperResults (CheckId, Database_Id, DatabaseName, FindingsGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				SELECT
					CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				   ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				   ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				   ,FindingsGroup = ''' + CAST(@FindingsGroup AS NVARCHAR(MAX)) + N'''
				   ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				   ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				   ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				   ,Schema_Id     = S.schema_id
				   ,SchemaName    = S.name
				   ,Object_Id     = SM.object_id
				   ,ObjectName    = O.name
				   ,ObjectType    = O.type_desc
				   ,Details       = N''NOLOCK does not mean your query does not take out a lock, it does not obey locks.''
				FROM
					' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules        AS SM
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON O.object_id = SM.object_id
					INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON S.schema_id = O.schema_id
				WHERE
					O.name NOT IN (''sp_Develop'', ''sp_WhoIsActive'')
					AND (
						PATINDEX(''%(%NOLOCK%)%'', SM.definition COLLATE SQL_Latin1_General_CP1_CI_AI) > 0
						OR PATINDEX(''%(%READUNCOMMITTED%)%'', SM.definition COLLATE SQL_Latin1_General_CP1_CI_AI) > 0
						OR PATINDEX(''%READ UNCOMMITTED%'', SM.definition COLLATE SQL_Latin1_General_CP1_CI_AI) > 0
					);';

			EXEC sys.sp_executesql @stmt = @StringToExecute;
			IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		END;

		-- SQL Prompt formatting on
        /**********************************************************************************************************************
		**  ██████ ██   ██ ███████  ██████ ██   ██ ███████     ███████ ███    ██ ██████  
		** ██      ██   ██ ██      ██      ██  ██  ██          ██      ████   ██ ██   ██ 
		** ██      ███████ █████   ██      █████   ███████     █████   ██ ██  ██ ██   ██ 
		** ██      ██   ██ ██      ██      ██  ██       ██     ██      ██  ██ ██ ██   ██ 
 		**  ██████ ██   ██ ███████  ██████ ██   ██ ███████     ███████ ██   ████ ██████ 
		**********************************************************************************************************************/

        FETCH NEXT FROM database_cursor
        INTO
            @DatabaseName;
    END;
    CLOSE database_cursor;
    DEALLOCATE database_cursor;

    /**********************************************************************************************************************
	** Output the results
	** After populating the #DeveloperResults table, time to dump it out.
	**********************************************************************************************************************/
    DECLARE @Separator AS CHAR(1);
    IF @OutputType = 'RSV' SET @Separator = CHAR(31);
    ELSE SET @Separator = ',';

    IF @OutputType = 'COUNT'
    BEGIN
        SELECT Warnings = COUNT(*)FROM #DeveloperResults;
    END;
    ELSE IF @OutputType IN ('CSV', 'RSV')
    BEGIN

        SELECT
            Result = CAST(Priority AS NVARCHAR(100)) + @Separator + CAST(CheckId AS NVARCHAR(100)) + @Separator + COALESCE(FindingsGroup, '(N/A)') + @Separator + COALESCE(Finding, '(N/A)') + @Separator + COALESCE(DatabaseName, '(N/A)') + @Separator + COALESCE(URL, '(N/A)') + @Separator + COALESCE(Details, '(N/A)')
        FROM
            #DeveloperResults
        ORDER BY
            Priority
           ,FindingsGroup
           ,Finding
           ,DatabaseName
           ,Details;
    END;
    ELSE IF @OutputXMLasNVARCHAR = 1
            AND @OutputType <> 'NONE'
    BEGIN
        SELECT
            Priority
           ,FindingsGroup
           ,Finding
           ,DatabaseName
           ,URL
           ,Details
           ,CheckId
        FROM
            #DeveloperResults
        ORDER BY
            Priority
           ,FindingsGroup
           ,Finding
           ,DatabaseName
           ,Details;
    END;
    ELSE IF @OutputType = 'MARKDOWN'
    BEGIN;
        WITH Results
          AS (
              SELECT
                  rownum = ROW_NUMBER() OVER (ORDER BY DR.Priority, DR.FindingsGroup, DR.Finding, DR.DatabaseName, DR.Details)
                 ,DR.DeveloperResultsId
                 ,DR.CheckId
                 ,DR.DatabaseName
                 ,DR.Priority
                 ,DR.FindingsGroup
                 ,DR.Finding
                 ,DR.URL
                 ,DR.Details
              FROM
                  #DeveloperResults AS DR
              WHERE
                  DR.Priority          > 0
                  AND DR.Priority      < 255
                  AND DR.FindingsGroup IS NOT NULL
                  AND DR.Finding IS NOT NULL
                  AND DR.FindingsGroup <> 'Security' /* Specifically excluding security checks for public exports */
          )
        SELECT
            CASE
                WHEN r.Priority <> COALESCE(rPrior.Priority, 0)
                     OR r.FindingsGroup <> rPrior.FindingsGroup THEN
                    @LineFeed + N'**Priority ' + CAST(COALESCE(r.Priority, N'') AS NVARCHAR(5)) + N': ' + COALESCE(r.FindingsGroup, N'') + N'**:' + @LineFeed + @LineFeed
                ELSE
                    N''
            END + CASE
                      WHEN r.Finding <> COALESCE(rPrior.Finding, N'')
                           AND r.Finding <> rNext.Finding THEN
                          N'- ' + COALESCE(r.Finding, N'') + N' ' + COALESCE(r.DatabaseName, N'') --+ N' - ' + COALESCE(r.Details, N'') + @LineFeed
                      WHEN r.Finding <> COALESCE(rPrior.Finding, N'')
                           AND r.Finding = rNext.Finding
                           AND r.Details = rNext.Details THEN
                          N'- ' + COALESCE(r.Finding, N'') + N' - ' + COALESCE(r.Details, N'') + @LineFeed + @LineFeed + N'    * ' + COALESCE(r.DatabaseName, N'') + @LineFeed
                      WHEN r.Finding <> COALESCE(rPrior.Finding, N'')
                           AND r.Finding = rNext.Finding THEN
                          N'- ' + COALESCE(r.Finding, N'') + @LineFeed + CASE
                                                                             WHEN r.DatabaseName IS NULL THEN
                                                                                 N''
                                                                             ELSE
                                                                                 N'    * ' + COALESCE(r.DatabaseName, N'')
                                                                         END + CASE
                                                                                   WHEN r.Details <> rPrior.Details THEN
                                                                                       N' - ' + COALESCE(r.Details, N'') + @LineFeed
                                                                                   ELSE
                                                                                       ''
                                                                               END
                      ELSE
                          CASE
                              WHEN r.DatabaseName IS NULL THEN
                                  N''
                              ELSE
                                  N'    * ' + COALESCE(r.DatabaseName, N'')
                          END + CASE
                                    WHEN r.Details <> rPrior.Details THEN
                                        N' - ' + COALESCE(r.Details, N'') + @LineFeed
                                    ELSE
                                        N'' + @LineFeed
                                END
                  END + @LineFeed
        FROM
            Results                 AS r
            LEFT OUTER JOIN Results AS rPrior ON r.rownum = rPrior.rownum + 1
            LEFT OUTER JOIN Results AS rNext ON r.rownum  = rNext.rownum - 1
        ORDER BY
            r.rownum
        FOR XML PATH(N'');
    END;
    ELSE IF @OutputType = 'XML'
    BEGIN
        SELECT
            Priority
           ,FindingsGroup
           ,Finding
           ,DatabaseName
           ,URL
           ,Details
           ,CheckId
        FROM
            #DeveloperResults
        ORDER BY
            Priority
           ,FindingsGroup
           ,Finding
           ,DatabaseName
           ,Details
        FOR XML PATH('Result'), ROOT('sp_Develop_Output');
    END;
    ELSE IF @OutputType <> 'NONE'
    BEGIN
        SELECT
            DR.DatabaseName
           ,DR.SchemaName
           ,DR.ObjectName
           ,DR.ObjectType
           ,DR.FindingsGroup
           ,DR.Finding
           ,DR.Details
           ,DR.URL
           ,DR.CheckId
           ,DR.Database_Id
           ,DR.Schema_Id
           ,DR.Object_Id
           ,DR.Priority
        FROM
            #DeveloperResults AS DR
        ORDER BY
            DR.Priority
           ,DR.DatabaseName
           ,DR.SchemaName
           ,DR.ObjectName
           ,DR.FindingsGroup
           ,DR.Finding;
    END;

    DROP TABLE #DeveloperResults;

END;
