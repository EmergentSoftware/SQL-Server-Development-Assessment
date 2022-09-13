IF OBJECT_ID('dbo.sp_Develop') IS NULL
    BEGIN
        EXEC dbo.sp_executesql @stmt = N'CREATE PROCEDURE dbo.sp_Develop AS BEGIN SET NOCOUNT ON; END';
    END;
GO

ALTER PROCEDURE dbo.sp_Develop
    @DatabaseName      nvarchar(128) = NULL /*Defaults to current DB if not specified*/
   ,@GetAllDatabases   bit           = 0
   ,@BringThePain      bit           = 0
   ,@SkipCheckServer   nvarchar(128) = NULL
   ,@SkipCheckDatabase nvarchar(128) = NULL
   ,@SkipCheckSchema   nvarchar(128) = NULL
   ,@SkipCheckTable    nvarchar(128) = NULL
   ,@OutputType        varchar(20)   = 'TABLE'
   ,@ShowSummary       bit           = 0
   ,@PriorityOrHigher  varchar(8)    = NULL /* Critical, High, Medium, Low, or NULL */
   ,@RunCheckIds       varchar(MAX)  = NULL /* Pass a comma delimited list of CheckIds like 1,2,3 if you only need a limited number of checks to run */
   ,@Debug             int           = 0
   ,@Version           varchar(30)   = NULL OUTPUT
   ,@VersionDate       datetime      = NULL OUTPUT
   ,@VersionCheckMode  bit           = 0
WITH RECOMPILE
AS
    BEGIN
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
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
        ** All other copyrights for sp_Develop are held by Emergent Software, LLC as described below.
        ** 
        ** Copyright (c) 2022 Emergent Software, LLC
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

        /**********************************************************************************************************************
	    ** Declare some varibles
	    **********************************************************************************************************************/

        DECLARE
            @LineFeed            nvarchar(5)
           ,@NumDatabases        int
           ,@Message             nvarchar(4000)
           ,@StringToExecute     nvarchar(MAX)
           ,@ScriptVersionName   nvarchar(50)
           ,@ErrorSeverity       int
           ,@ErrorState          int
           ,@DatabaseId          int
           ,@CheckId             int
           ,@FindingGroup        varchar(100)
           ,@Finding             varchar(200)
           ,@URLBase             varchar(120)
           ,@URLSkipChecks       varchar(100)
           ,@URLAnchor           varchar(400)
           ,@Priority            int
           ,@ProductVersion      nvarchar(128)
           ,@ProductVersionMajor decimal(10, 2)
           ,@ProductVersionMinor decimal(10, 2);


        /**********************************************************************************************************************
	    ** Setting some varibles
	    **********************************************************************************************************************/

        SET @Version = '1.6.0';
        SET @VersionDate = '20220908';
        SET @URLBase = 'https://emergentsoftware.github.io/SQL-Server-Development-Assessment/best-practices-and-potential-findings/';
        SET @URLSkipChecks = 'https://emergentsoftware.github.io/SQL-Server-Development-Assessment/how-to-skip-checks';
        SET @OutputType = UPPER(@OutputType);
        SET @LineFeed = CHAR(13) + CHAR(10);
        SET @ScriptVersionName = N'sp_Develop v' + @Version + N' - ' + DATENAME(MONTH, @VersionDate) + N' ' + RIGHT('0' + DATENAME(DAY, @VersionDate), 2) + N', ' + DATENAME(YEAR, @VersionDate);
        SET @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));
        SET @ProductVersionMajor = SUBSTRING(@ProductVersion, 1, CHARINDEX('.', @ProductVersion) + 1);
        SET @ProductVersionMinor = PARSENAME(CONVERT(varchar(32), @ProductVersion), 2);

        IF @VersionCheckMode = 1
            BEGIN
                RETURN;
            END;

        IF @Debug IN (1, 2)
            BEGIN
                RAISERROR(N'Starting run. %s', 0, 1, @ScriptVersionName) WITH NOWAIT;
            END;

        /**********************************************************************************************************************
	    ** We start by creating #Finding. It's a temp table that will store all of the results from our checks. 
	    ** Throughout the rest of this stored procedure, we're running a series of checks looking for issues inside the 
	    ** database. When we find a problem, we insert rows into #Finding. At the end, we return these results to the 
	    ** end user.
	    ** 
	    ** #Finding has a CheckId field, but there's no Check table. As we do checks, we insert data into this table,
	    ** and we manually put in the CheckId.		
	    ** 
	    ** Create other temp tables
	    **********************************************************************************************************************/
        IF OBJECT_ID('tempdb..#Finding') IS NOT NULL
            BEGIN
                DROP TABLE #Finding;
            END;

        CREATE TABLE #Finding (
            DeveloperResultsId int            IDENTITY(1, 1) NOT NULL
           ,CheckId            int            NOT NULL DEFAULT-1
           ,Database_Id        int            NOT NULL DEFAULT-1
           ,DatabaseName       nvarchar(128)  NOT NULL DEFAULT N''
           ,Priority           int            NOT NULL DEFAULT-1
           ,FindingGroup       varchar(100)   NOT NULL
           ,Finding            varchar(200)   NOT NULL
           ,URL                varchar(2047)  NOT NULL
           ,Details            nvarchar(4000) NOT NULL
           ,Schema_Id          int            NOT NULL DEFAULT-1
           ,SchemaName         nvarchar(128)  NULL DEFAULT N''
           ,Object_Id          int            NOT NULL DEFAULT-1
           ,ObjectName         nvarchar(128)  NOT NULL DEFAULT N''
           ,ObjectType         nvarchar(60)   NOT NULL DEFAULT N''
        );

        IF OBJECT_ID('tempdb..#DatabaseList') IS NOT NULL
            BEGIN
                DROP TABLE #DatabaseList;
            END;

        CREATE TABLE #DatabaseList (
            DatabaseName                          nvarchar(256) NOT NULL
           ,secondary_role_allow_connections_desc nvarchar(50)  NULL DEFAULT 'YES'
        );

        IF OBJECT_ID('tempdb..#DatabaseIgnore') IS NOT NULL
            BEGIN
                DROP TABLE #DatabaseIgnore;
            END;

        CREATE TABLE #DatabaseIgnore (DatabaseName nvarchar(128) NOT NULL, Reason nvarchar(100) NOT NULL);

        IF OBJECT_ID('tempdb..#SkipCheck') IS NOT NULL
            BEGIN
                DROP TABLE #SkipCheck;
            END;

        CREATE TABLE #SkipCheck (
            ServerName   nvarchar(128) NULL
           ,DatabaseName nvarchar(128) NULL
           ,SchemaName   nvarchar(128) NULL
           ,ObjectName   nvarchar(128) NULL
           ,CheckId      int           NULL
        );

        CREATE CLUSTERED INDEX CheckId_DatabaseName ON #SkipCheck (CheckId, DatabaseName);

        /**********************************************************************************************************************
        ** Skip Checks or Run Checks
        **********************************************************************************************************************/
        /* If there is a value then skip all other checks except what is passed in */
        IF @RunCheckIds IS NOT NULL
            BEGIN

                /* Create temporary table to store the RunCheckIds rows */
                IF OBJECT_ID('tempdb..#RunCheckIds') IS NOT NULL
                    BEGIN
                        DROP TABLE #RunCheckIds;
                    END;
                CREATE TABLE #RunCheckIds (CheckId int NOT NULL);

                INSERT INTO #RunCheckIds (CheckId)
                SELECT
                    CheckId = CheckIds.value('.', 'BIGINT')
                FROM (
                    SELECT
                        CheckId = CAST('<Items><item>' + REPLACE(@RunCheckIds, ',', '</item><item>') + '</item></Items> ' AS xml)
                )                                             AS CheckIdsXML
                     CROSS APPLY CheckId.nodes('/Items/item') AS C(CheckIds);

                /* Create temporary table to store the PossibleCheckIds */
                IF OBJECT_ID('tempdb..#PossibleCheckIds') IS NOT NULL
                    BEGIN
                        DROP TABLE #PossibleCheckIds;
                    END;
                CREATE TABLE #PossibleCheckIds (CheckId int NOT NULL);

                INSERT INTO #PossibleCheckIds (CheckId)
                SELECT TOP (10000)
                    CheckId = ROW_NUMBER() OVER (ORDER BY O1.object_id)
                FROM
                    sys.objects            AS O1
                    CROSS JOIN sys.objects AS O2;

                INSERT INTO #SkipCheck (ServerName, DatabaseName, SchemaName, ObjectName, CheckId)
                SELECT NULL, NULL, NULL, NULL, CheckId FROM #PossibleCheckIds
                EXCEPT
                SELECT NULL, NULL, NULL, NULL, CheckId FROM #RunCheckIds
                ORDER BY
                    CheckId ASC;

            END;
        ELSE
            BEGIN

                IF (@SkipCheckTable IS NOT NULL AND RTRIM(LTRIM(@SkipCheckTable)) <> '')
                AND (@SkipCheckSchema IS NOT NULL AND RTRIM(LTRIM(@SkipCheckSchema)) <> '')
                AND (@SkipCheckDatabase IS NOT NULL AND RTRIM(LTRIM(@SkipCheckDatabase)) <> '')
                    BEGIN

                        IF @Debug IN (1, 2)
                            RAISERROR('Inserting SkipChecks', 0, 1) WITH NOWAIT;

                        SET @StringToExecute = N'
				INSERT INTO
                    #SkipCheck(ServerName, DatabaseName, SchemaName, ObjectName, CheckId)
                SELECT
                    SK.ServerName
                   ,SK.DatabaseName
                   ,SK.SchemaName
                   ,SK.ObjectName
                   ,SK.CheckId
                FROM '  ;

                        IF LTRIM(RTRIM(@SkipCheckServer)) <> ''
                            BEGIN
                                SET @StringToExecute = @StringToExecute + QUOTENAME(@SkipCheckServer) + N'.';
                            END;

                        SET @StringToExecute = @StringToExecute + QUOTENAME(@SkipCheckDatabase) + N'.' + QUOTENAME(@SkipCheckSchema) + N'.' + QUOTENAME(@SkipCheckTable) + N' AS SK
                WHERE
                    SK.ServerName IS NULL
                    OR SK.ServerName = SERVERPROPERTY(''ServerName'')
                GROUP BY
                    SK.ServerName
                   ,SK.DatabaseName
                   ,SK.SchemaName
                   ,SK.ObjectName
                   ,SK.CheckId
                OPTION (RECOMPILE);';

                        EXEC sys.sp_executesql @stmt = @StringToExecute;
                        IF @Debug = 2
                        AND @StringToExecute IS NOT NULL
                            PRINT @StringToExecute;

                        /* Check if we should be running checks on this server, exit out if not. */
                        IF EXISTS (
                            SELECT
                                *
                            FROM
                                #SkipCheck AS SC
                            WHERE
                                SC.ServerName = SERVERPROPERTY('ServerName')
                            AND SC.DatabaseName IS NULL
                            AND SC.ObjectName IS NULL
                        )
                            BEGIN
                                IF @Debug IN (1, 2)
                                    RAISERROR('The SQL Server is marked to be skipped', 0, 1) WITH NOWAIT;
                                RETURN;
                            END;

                        IF @Debug IN (1, 2)
                            RAISERROR('The SQL Server is not marked to be skipped', 0, 1) WITH NOWAIT;
                    END;



















            END;

        /**********************************************************************************************************************
	    ** Skip checks for specific SQL Servers
	    **********************************************************************************************************************/

        /* If the server is Amazon RDS, skip checks that it doesn't allow */
        IF LEFT(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS varchar(8000)), 8) = 'EC2AMAZ-'
        AND LEFT(CAST(SERVERPROPERTY('MachineName') AS varchar(8000)), 8) = 'EC2AMAZ-'
        AND LEFT(CAST(SERVERPROPERTY('ServerName') AS varchar(8000)), 8) = 'EC2AMAZ-'
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
                /* INSERT INTO #SkipCheck (CheckId) VALUES (?); */

                /* Let them know we are skipping checks */
                INSERT INTO #Finding (CheckId, FindingGroup, Finding, URL, Details)
                SELECT
                    CheckID      = 26
                   ,FindingGroup = 'Running Issues'
                   ,Finding      = 'Some Checks Skipped'
                   ,URL          = @URLBase + 'running-issues#some-checks-skipped'
                   ,Details      = 'Amazon RDS detected, so we skipped some checks that are not currently possible, relevant, or practical there.';
            END;

        /* If the server is Express Edition, skip checks that it doesn't allow */
        IF CAST(SERVERPROPERTY('Edition') AS nvarchar(1000)) LIKE N'%Express%'
            BEGIN
                /* Check to skip go here */
                /* INSERT INTO #SkipCheck (CheckId) VALUES (?); */

                /* Let them know we are skipping checks */
                INSERT INTO #Finding (CheckId, FindingGroup, Finding, URL, Details)
                SELECT
                    CheckID      = 26
                   ,FindingGroup = 'Running Issues'
                   ,Finding      = 'Some Checks Skipped'
                   ,URL          = @URLBase + 'running-issues#some-checks-skipped'
                   ,Details      = 'Express Edition detected, so we skipped some checks that are not currently possible, relevant, or practical there.';
            END;


        /* If the server is an Azure Managed Instance, skip checks that it doesn't allow */
        IF SERVERPROPERTY('EngineEdition') = 8
            BEGIN
                /* Check to skip go here */
                /* INSERT INTO #SkipCheck (CheckId) VALUES (?); */

                /* Let them know we are skipping checks */
                INSERT INTO #Finding (CheckId, FindingGroup, Finding, URL, Details)
                SELECT
                    CheckID      = 26
                   ,FindingGroup = 'Running Issues'
                   ,Finding      = 'Some Checks Skipped'
                   ,URL          = @URLBase + 'running-issues#some-checks-skipped'
                   ,Details      = 'Managed Instance detected, so we skipped some checks that are not currently possible, relevant, or practical there.';
            END;

        /**********************************************************************************************************************
	    ** What databases are we going to ignore?
	    **********************************************************************************************************************/
        INSERT INTO #DatabaseIgnore (DatabaseName, Reason)
        SELECT
            SC.DatabaseName
           ,N'Included in skip checks'
        FROM
            #SkipCheck AS SC
        WHERE
            (SC.ServerName = SERVERPROPERTY('ServerName') OR SC.ServerName IS NULL)
        AND SC.ObjectName IS NULL
        AND SC.CheckId IS NULL
        AND SC.DatabaseName IS NOT NULL
        OPTION (RECOMPILE);

        /**********************************************************************************************************************
	    ** What databases are we going to check?
	    **********************************************************************************************************************/
        IF @GetAllDatabases = 1
            BEGIN
                INSERT INTO #DatabaseList (DatabaseName)
                SELECT
                    DB_NAME(database_id)
                FROM
                    sys.databases
                WHERE
                    user_access_desc = N'MULTI_USER'
                AND state_desc       = N'ONLINE'
                AND database_id      > 4
                AND DB_NAME(database_id)NOT LIKE N'ReportServer%' /* SQL Server Reporting Services */
                AND DB_NAME(database_id)NOT LIKE N'rdsadmin%' /* Amazon RDS default database */
                AND DB_NAME(database_id) NOT IN (N'DWQueue', N'DWDiagnostics', N'DWConfiguration') /* PolyBase databases do not need to be checked */
                AND DB_NAME(database_id) NOT IN (N'SSISDB') /* SQL Server Integration Services */
                AND is_distributor   = 0
                OPTION (RECOMPILE);

                /* Skip non-readable databases in an AG */
                IF EXISTS (
                    SELECT
                        *
                    FROM
                        sys.all_objects            AS O
                        INNER JOIN sys.all_columns AS C
                            ON O.object_id = C.object_id
                            AND O.name     = 'dm_hadr_availability_replica_states'
                            AND C.name     = 'role_desc'
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
                                secondary_role_allow_connections_desc = N'NO'
                        )
                            BEGIN
                                /**********************************************************************************************************************/
                                SELECT
                                    @CheckId      = 17
                                   ,@Priority     = 1
                                   ,@FindingGroup = 'Running Issues'
                                   ,@Finding      = 'You are running this on an AG secondary, and some of your databases are configured as non-readable when this is a secondary node.'
                                   ,@URLAnchor    = 'running-issues#ran-on-a-non-readable-availability-group-secondary-databases';
                                /**********************************************************************************************************************/
                                INSERT INTO #Finding (CheckId, FindingGroup, Finding, URL, Priority, Details)
                                SELECT
                                    CheckId      = @CheckId
                                   ,FindingGroup = @FindingGroup
                                   ,Finding      = @Finding
                                   ,URL          = @URLBase + @URLAnchor
                                   ,Priority     = @Priority
                                   ,Details      = N'To analyze those databases, run sp_Develop on the primary, or on a readable secondary.';

                            END;
                    END;
            END;
        ELSE
            BEGIN
                INSERT INTO #DatabaseList (DatabaseName)
                SELECT
                    CASE WHEN @DatabaseName IS NULL OR @DatabaseName = N'' THEN DB_NAME()ELSE @DatabaseName END;
            END;

        SET @NumDatabases = (
            SELECT
                COUNT(*)
            FROM
                #DatabaseList                   AS DL
                LEFT OUTER JOIN #DatabaseIgnore AS I
                    ON DL.DatabaseName = I.DatabaseName
            WHERE
                COALESCE(DL.secondary_role_allow_connections_desc, 'OK') <> 'NO'
            AND I.DatabaseName IS NULL
        );
        SET @Message = N'Number of databases to examine: ' + CAST(@NumDatabases AS nvarchar(50));
        IF @Debug IN (1, 2)
            RAISERROR(@Message, 0, 1) WITH NOWAIT;

        /**********************************************************************************************************************/
        SELECT
            @CheckId      = 18
           ,@Priority     = 1
           ,@FindingGroup = 'Running Issues'
           ,@Finding      = 'Ran Against 50+ Databases Without @BringThePain = 1'
           ,@URLAnchor    = 'running-issues#ran-against-50-databases-without-bringthepain--1';
        /**********************************************************************************************************************/
        BEGIN TRY
            IF @NumDatabases >= 50
            AND @BringThePain <> 1
                BEGIN

                    INSERT #Finding (CheckId, FindingGroup, Finding, URL, Priority, Details)
                    SELECT
                        CheckId      = @CheckId
                       ,FindingGroup = @FindingGroup
                       ,Finding      = @Finding
                       ,URL          = @URLBase + @URLAnchor
                       ,Priority     = @Priority
                       ,Details      = N'You''re trying to run sp_Develop on a server with ' + CAST(@NumDatabases AS nvarchar(50)) + ' databases. If you''re sure you want to do this, run again with the parameter @BringThePain = 1.';
                    IF (@OutputType <> 'NONE')
                        BEGIN

                            SELECT
                                DR.DatabaseName
                               ,DR.SchemaName
                               ,DR.ObjectName
                               ,DR.ObjectType
                               ,DR.FindingGroup
                               ,DR.Finding
                               ,DR.Details
                               ,DR.URL
                               ,DR.CheckId
                               ,DR.Database_Id
                               ,DR.Schema_Id
                               ,DR.Object_Id
                               ,DR.Priority
                            FROM
                                #Finding AS DR
                            ORDER BY
                                DR.Priority
                               ,DR.DatabaseName
                               ,DR.SchemaName
                               ,DR.ObjectName
                               ,DR.FindingGroup
                               ,DR.Finding
                            OPTION (RECOMPILE);

                            RAISERROR('Running sp_Develop on a server with 50+ databases may cause temporary insanity for the server', 12, 1);
                        END;

                    RETURN;

                END;
        END TRY
        BEGIN CATCH
            RAISERROR(N'Failure to execute due to number of databases.', 0, 1) WITH NOWAIT;

            SELECT
                @Message       = ERROR_MESSAGE()
               ,@ErrorSeverity = ERROR_SEVERITY()
               ,@ErrorState    = ERROR_STATE();

            RAISERROR(@Message, @ErrorSeverity, @ErrorState);

            WHILE @@TRANCOUNT > 0
            ROLLBACK;

            RETURN;
        END CATCH;

        /**********************************************************************************************************************/
        SELECT
            @CheckId      = 16
           ,@Priority     = 1
           ,@FindingGroup = 'Running Issues'
           ,@Finding      = 'sp_Develop is Over 6 Months Old'
           ,@URLAnchor    = 'running-issues#sp_develop-is-over-6-months-old';
        /**********************************************************************************************************************/
        IF NOT EXISTS (
            SELECT
                1
            FROM
                #SkipCheck AS SC
            WHERE
                SC.CheckId = @CheckId
            AND SC.ObjectName IS NULL
        )
        AND DATEDIFF(MONTH, @VersionDate, GETDATE()) > 6
            BEGIN

                IF @Debug IN (1, 2)
                    RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

                INSERT #Finding (CheckId, FindingGroup, Finding, URL, Priority, Details)
                SELECT
                    CheckId      = @CheckId
                   ,FindingGroup = @FindingGroup
                   ,Finding      = @Finding
                   ,URL          = @URLBase + @URLAnchor
                   ,Priority     = @Priority
                   ,Details      = N'There most likely been some new checks and fixes performed within the last 6 months - time to go download the current one.';

            END;

        /**********************************************************************************************************************
	    ** Starting loop through databases
	    **********************************************************************************************************************/
        IF @Debug IN (1, 2)
            RAISERROR(N'Starting loop through databases', 0, 1) WITH NOWAIT;

        DECLARE database_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                DL.DatabaseName
            FROM
                #DatabaseList                   AS DL
                LEFT OUTER JOIN #DatabaseIgnore AS I
                    ON DL.DatabaseName = I.DatabaseName
            WHERE
                COALESCE(DL.secondary_role_allow_connections_desc, 'OK') <> 'NO'
            AND I.DatabaseName IS NULL
            OPTION (RECOMPILE);

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
                    name             = @DatabaseName
                AND user_access_desc = 'MULTI_USER'
                AND state_desc       = 'ONLINE'
                OPTION (RECOMPILE);

                /**********************************************************************************************************************
                **  ██████ ██   ██ ███████  ██████ ██   ██ ███████     ███████ ████████  █████  ██████  ████████
                ** ██      ██   ██ ██      ██      ██  ██  ██          ██         ██    ██   ██ ██   ██    ██    
                ** ██      ███████ █████   ██      █████   ███████     ███████    ██    ███████ ██████     ██    
                ** ██      ██   ██ ██      ██      ██  ██       ██          ██    ██    ██   ██ ██   ██    ██    
                **  ██████ ██   ██ ███████  ██████ ██   ██ ███████     ███████    ██    ██   ██ ██   ██    ██  
		        **********************************************************************************************************************/
		        -- SQL Prompt formatting off
		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 1
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Using Plural in Names'
		           ,@URLAnchor     = 'naming-conventions#using-plural-in-name';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'			
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = O.object_id
				           ,ObjectName    = O.name
				           ,ObjectType    = O.type_desc
				           ,Details       = N''Table and view names should be singular. NOTE: This could be a false-positive for names that do end with S.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        O.type IN (''U'', ''V'')
					        AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 1) = ''S''
					        AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 2) <> ''SS''
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 4) NOT IN (''news'', ''plus'', ''thus'', ''goes'', ''bars'', ''axis'', ''bias'', ''iris'', ''kris'', ''nous'', ''osis'', ''itis'', ''tics'', ''opus'')
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 5) NOT IN (''means'', ''shoes'', ''focus'', ''basis'', ''virus'', ''bonus'', ''specs'', ''acres'', ''atlas'', ''corps'', ''lotus'', ''oasis'', ''wages'', ''twins'', ''alias'', ''minus'', ''flies'', ''genus'', ''maths'', ''locus'', ''penis'', ''nexus'', ''fries'', ''fetus'', ''sinus'', ''kudos'', ''lupus'', ''elves'', ''lexis'', ''virus'', ''ethos'', ''gauss'', ''feces'', ''mucus'', ''trics'', ''eaves'')
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 6) NOT IN (''status'', ''series'', ''campus'', ''comics'', ''tennis'', ''census'', ''leaves'', ''crisis'', ''basics'', ''canvas'', ''thesis'', ''radius'', ''stylus'', ''chorus'', ''genius'', ''circus'', ''corpus'', ''organs'', ''citrus'', ''debris'', ''exodus'', ''cosmos'', ''cactus'', ''nerves'', ''crises'', ''annals'', ''caucus'', ''theses'', ''fungus'', ''scrubs'', ''praxis'', ''rabies'', ''discus'', ''madras'', ''mantis'', ''hiatus'', ''cirrus'', ''shears'', ''egress'', ''pelvis'', ''cleats'', ''nimbus'', ''testis'', ''pharos'', ''plexus'', ''thymus'', ''sepsis'', ''civics'', ''haggis'', ''slacks'', ''walrus'', ''bowels'', ''adonis'', ''crocus'', ''gallus'', ''hubris'', ''litmus'', ''duress'', ''pathos'', ''chives'', ''ruckus'', ''stasis'', ''throes'', ''hooves'', ''tarsus'', ''hummus'', ''callus'', ''missus'', ''oodles'', ''animus'', ''vitals'', ''khakis'', ''soleus'', ''dermis'', ''precis'', ''thrips'', ''tallis'', ''fracas'', ''estrus'', ''reales'', ''typhus'', ''fundus'', ''clevis'', ''sulcus'', ''coleus'', ''rumpus'', ''boreas'', ''coitus'', ''chinos'', ''nomics'', ''rectus'')
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 7) NOT IN (''species'', ''clothes'', ''siemens'', ''glasses'', ''grounds'', ''collins'', ''genesis'', ''surplus'', ''chassis'', ''indices'', ''shelves'', ''nucleus'', ''incubus'', ''goggles'', ''innings'', ''manners'', ''thieves'', ''heavens'', ''marquis'', ''summons'', ''octopus'', ''nemesis'', ''arrears'', ''omnibus'', ''phonics'', ''stratus'', ''tropics'', ''impetus'', ''modulus'', ''bellows'', ''alumnus'', ''tetanus'', ''withers'', ''funnies'', ''trellis'', ''papyrus'', ''follies'', ''dwarves'', ''cumulus'', ''thermos'', ''cyclops'', ''forceps'', ''chamois'', ''laurels'', ''gallows'', ''greaves'', ''isthmus'', ''helices'', ''scabies'', ''ascites'', ''sheaves'', ''annulus'', ''triceps'', ''challis'', ''arbutus'', ''kinesis'', ''rickets'', ''rooibos'', ''innards'', ''humerus'', ''phallus'', ''rhombus'', ''calamus'', ''autobus'', ''varices'', ''tigress'')
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 8) NOT IN (''analysis'', ''diabetes'', ''emphasis'', ''overseas'', ''premises'', ''precious'', ''synopsis'', ''proceeds'', ''quarters'', ''finances'', ''asbestos'', ''potatoes'', ''syllabus'', ''calculus'', ''trousers'', ''cannabis'', ''matrices'', ''upstairs'', ''scissors'', ''stimulus'', ''vertices'', ''dialysis'', ''emeritus'', ''nautilus'', ''aerobics'', ''bacillus'', ''pancreas'', ''checkers'', ''terminus'', ''auspices'', ''shingles'', ''avionics'', ''hibiscus'', ''confines'', ''syphilis'', ''colossus'', ''buttocks'', ''knuckles'', ''sundries'', ''synopses'', ''dominoes'', ''knickers'', ''platypus'', ''platypus'', ''tinnitus'', ''clematis'', ''synapses'', ''whiskers'', ''shambles'', ''eugenics'', ''vortices'', ''exegesis'', ''ellipsis'', ''durables'', ''emphases'', ''couscous'', ''ellipses'', ''thalamus'', ''meniscus'', ''acanthus'', ''leotards'', ''entrails'', ''polemics'', ''fatigues'', ''cryonics'', ''caduceus'', ''thrombus'', ''pruritus'', ''nuptials'', ''bronchus'', ''subgenus'')
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 9) NOT IN (''religious'', ''amenities'', ''consensus'', ''thesaurus'', ''conscious'', ''apparatus'', ''backwards'', ''billiards'', ''psoriasis'', ''asparagus'', ''paralysis'', ''esophagus'', ''pertussis'', ''acropolis'', ''chrysalis'', ''narcissus'', ''ephemeris'', ''syntheses'', ''catharsis'', ''mnemonics'', ''verdigris'', ''sartorius'', ''ambergris'', ''nucleolus'', ''gladiolus'')
                            AND RIGHT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 10) NOT IN (''sunglasses'', ''binoculars'', ''gymnastics'', ''prospectus'', ''phosphorus'', ''appendices'', ''metropolis'', ''aesthetics'', ''hypotheses'', ''downstairs'', ''geophysics'', ''rendezvous'', ''mosquitoes'', ''eucalyptus'', ''hydraulics'', ''proteomics'', ''hydrolysis'', ''metastasis'', ''cretaceous'', ''spectacles'', ''metastases'', ''kinematics'', ''eurythmics'', ''portcullis'', ''rhinoceros'', ''underpants'', ''biogenesis'', ''prostheses'', ''pneumatics'', ''astragalus'', ''urinalysis'', ''ballistics'', ''chemotaxis'', ''acrobatics'', ''glycolysis'', ''strabismus'', ''hemostasis'', ''dialectics'', ''catechesis'', ''laryngitis'')
					        AND O.NAME NOT IN (''sysdiagrams'', ''database_firewall_rules'')
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 29
		           ,@Priority      = 30
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Using Unique Constraint Instead of Unique Indexes'
		           ,@URLAnchor     = 'table-conventions#using-unique-constraint-instead-of-unique-indexes';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'			
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = O.object_id
				           ,ObjectName    = O.name
				           ,ObjectType    = O.type_desc
				           ,Details       = N''Using Unique Constraint Instead of Unique Indexes''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        O.type IN (''UQ'')
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 14
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Column Naming'
		           ,@URLAnchor     = 'naming-conventions#column-naming';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'			
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON T.object_id = C.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        C.name COLLATE SQL_Latin1_General_CP1_CI_AS LIKE ''%'' + T.name COLLATE SQL_Latin1_General_CP1_CI_AS + ''%''
					        AND C.name NOT IN (''InvoiceDate'', ''InvoiceNumber'', ''PartNumber'', ''CustomerNumber'', ''GroupName'', ''StateCode'', ''PhoneNumber'')
					        AND C.name COLLATE SQL_Latin1_General_CP1_CI_AS <> T.name COLLATE SQL_Latin1_General_CP1_CI_AS + ''Id''
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

			        SET @StringToExecute = N'			
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = C.object_id
				           ,ObjectName    = T.name + ''.'' + C.name
				           ,ObjectType    = ''COLUMN''
				           ,Details       = N''When using generic names you should prefix the class word with a modifier like the table name if appropriate.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON T.object_id = C.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        C.name COLLATE SQL_Latin1_General_CP1_CI_AS IN (''name'', ''description'', ''comment'', ''code'', ''type'', ''status'', ''date'', ''time'', ''key'', ''value'', ''term'', ''class'', ''style'', ''segment'', ''default'', ''primary'', ''deleted'', ''active'', ''inactive'', ''permission'', ''locked'', ''number'', ''amount'', ''total'', ''quantity'', ''weight'', ''percent'', ''rate'', ''cost'', ''price'', ''balance'', ''average'', ''discount'', ''limit'', ''due'', ''fee'', ''fine'', ''stamp'', ''flag'', ''slug'', ''level'', ''url'', ''email'', ''address'', ''subject'', ''body'', ''alias'', ''state'', ''format'', ''group'')
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 2
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Using Prefix in Name'
		           ,@URLAnchor     = 'naming-conventions#using-prefix-in-name';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
                           ,Priority      = CASE WHEN O.type_desc COLLATE SQL_Latin1_General_CP1_CI_AS LIKE ''%constraint%'' THEN 30 ELSE ' + CAST(@Priority AS NVARCHAR(MAX)) + N' END
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = O.object_id
				           ,ObjectName    = O.name
				           ,ObjectType    = O.type_desc
				           ,Details       = N''Never use a prefix such as tbl, sp, vw in names.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
                            O.name COLLATE SQL_Latin1_General_CP1_CI_AS NOT IN (''sp_Develop'', ''spCRUDGen'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'', ''fn_diagramobjects'', ''sp_WhoIsActive'', ''sp_HumanEvents'', ''sp_BlitzWho'', ''sp_BlitzCache'', ''sp_BlitzFirst'', ''sp_BlitzIndex'', ''sp_BlitzInMemoryOLTP'', ''sp_BlitzLock'', ''sp_BlitzQueryStore'', ''sp_PressureDetector'', ''sp_QuickieStore'')
					        AND (
		                            LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 6) IN (''covix_'', ''ncldx_'', ''clidx_'')
                                    OR LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 5) IN (''pknc_'', ''ncak_'', ''clix_'', ''_dta_'')
                                    OR LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 4) IN (''tab_'', ''pkc_'', ''idx_'', ''cak_'', ''unq_'', ''chk_'', ''ftx_'', ''gis_'', ''usp_'', ''trg_'')
			                        OR LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 3) IN (''tbl'', ''sp_'', ''xp_'', ''dt_'', ''fn_'', ''tr_'', ''usp'', ''usr'', ''uc_'', ''nk_'', ''ak_'', ''nc_'', ''ix_'', ''ux_'', ''uk_'', ''fk_'', ''uq_'', ''df_'')
			                        OR LEFT(O.name COLLATE SQL_Latin1_General_CP1_CI_AS, 2) IN (''tb'', ''t_'', ''vw'', ''fn'', ''p_'', ''f_'')
							        OR O.name LIKE ''[v][A-Z]%'' COLLATE Latin1_General_BIN
							        OR O.name LIKE ''[t][A-Z]%'' COLLATE Latin1_General_BIN
							        OR O.name LIKE ''[s][p][A-Z]%'' COLLATE Latin1_General_BIN
							        OR O.name LIKE ''[t][r][A-Z]%'' COLLATE Latin1_General_BIN
						        )
                        OPTION (RECOMPILE);';
                        
			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		
			        /* Find Table Columns */

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T ON C.object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        LEFT(C.name COLLATE SQL_Latin1_General_CP1_CI_AS, 4) IN (''fld_'', ''col_'')
					        OR LEFT(C.name COLLATE SQL_Latin1_General_CP1_CI_AS, 2) IN (''u_'', ''c_'')
					        OR C.name LIKE ''[f][A-Z]%'' COLLATE Latin1_General_BIN
					        OR C.name LIKE ''[c][A-Z]%'' COLLATE Latin1_General_BIN
					        OR C.name LIKE ''[u][A-Z]%'' COLLATE Latin1_General_BIN
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
                    
			        /* Find User-Defined Data Types */

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON T.schema_id = S.schema_id
				        WHERE
					        T.is_user_defined = 1
					        AND (
						         LEFT(T.name COLLATE SQL_Latin1_General_CP1_CI_AS, 3) IN (''ud_'')
						         OR T.name LIKE ''[u][d][A-Z]%'' COLLATE Latin1_General_BIN
						         )
                        OPTION (RECOMPILE);';

				        EXEC sys.sp_executesql @stmt = @StringToExecute;
				        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 5
		           ,@Priority      = 5
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Including Special Characters in Name'
		           ,@URLAnchor     = 'naming-conventions#including-special-characters-in-name';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        O.type_desc NOT IN (''DEFAULT_CONSTRAINT'', ''FOREIGN_KEY_CONSTRAINT'', ''PRIMARY_KEY_CONSTRAINT'', ''INTERNAL_TABLE'', ''CHECK_CONSTRAINT'', ''UNIQUE_CONSTRAINT'', ''SQL_INLINE_TABLE_VALUED_FUNCTION'', ''TYPE_TABLE'', ''SEQUENCE_OBJECT'')
					        AND O.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'', ''database_firewall_rules'', ''sp_Develop'', ''sp_WhoIsActive'', ''__EFMigrationsHistory'')
					        AND (
						        O.name LIKE ''%[^A-Z0-9@$#]%'' COLLATE Latin1_General_CI_AI /* contains illegal characters */
						        OR O.name NOT LIKE ''[A-Z]%'' COLLATE Latin1_General_CI_AI /* doesn''t start with a character */
						        )
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 13
		           ,@Priority      = 50
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Concatenating Two Table Names'
		           ,@URLAnchor     = 'naming-conventions#including-special-characters-in-name';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        )          AS C ON T.name = C.DoubleName
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 11
		           ,@Priority      = 30
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Including Numbers in Table Name'
		           ,@URLAnchor     = 'naming-conventions#including-numbers-in-table-name';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					        AND T.name LIKE ''%[0-9][0-9]%'' COLLATE Latin1_General_CI_AI /* contains more than one adjacent number */
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;
		
		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 12
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Column Named Same as Table'
		           ,@URLAnchor     = 'naming-conventions#column-named-same-as-table';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON C.object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        C.name = T.name
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;
		
		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 4
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Using Reserved Words in Name'
		           ,@URLAnchor     = 'naming-conventions#using-reserved-words-in-name';
		        /**********************************************************************************************************************/

		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
						
			        /* SQL Server and Azure SQL Data Warehouse Reserved Keywords */
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
					        INNER JOIN (
						        SELECT ''ADD'' UNION SELECT ''EXTERNAL'' UNION SELECT ''PROCEDURE'' UNION SELECT ''ALL'' UNION SELECT ''FETCH'' UNION SELECT ''PUBLIC'' UNION SELECT ''ALTER'' UNION SELECT ''FILE'' UNION SELECT ''RAISERROR'' UNION SELECT ''AND'' UNION SELECT ''FILLFACTOR'' UNION SELECT ''READ'' UNION SELECT ''ANY'' UNION SELECT ''FOR'' UNION SELECT ''READTEXT'' UNION SELECT ''AS'' UNION SELECT ''FOREIGN'' UNION SELECT ''RECONFIGURE'' UNION SELECT ''ASC'' UNION SELECT ''FREETEXT'' UNION SELECT ''REFERENCES'' UNION SELECT ''AUTHORIZATION'' UNION SELECT ''FREETEXTTABLE'' UNION SELECT ''REPLICATION'' UNION SELECT ''BACKUP'' UNION SELECT ''FROM'' UNION SELECT ''RESTORE'' UNION SELECT ''BEGIN'' UNION SELECT ''FULL'' UNION SELECT ''RESTRICT'' UNION SELECT ''BETWEEN'' UNION SELECT ''FUNCTION'' UNION SELECT ''RETURN'' UNION SELECT ''BREAK'' UNION SELECT ''GOTO'' UNION SELECT ''REVERT'' UNION SELECT ''BROWSE'' UNION SELECT ''GRANT'' UNION SELECT ''REVOKE'' UNION SELECT ''BULK'' UNION SELECT ''GROUP'' UNION SELECT ''RIGHT'' UNION SELECT ''BY'' UNION SELECT ''HAVING'' UNION SELECT ''ROLLBACK'' UNION SELECT ''CASCADE'' UNION SELECT ''HOLDLOCK'' UNION SELECT ''ROWCOUNT'' UNION SELECT ''CASE'' UNION SELECT ''IDENTITY'' UNION SELECT ''ROWGUIDCOL'' UNION SELECT ''CHECK'' UNION SELECT ''IDENTITY_INSERT'' UNION SELECT ''RULE'' UNION SELECT ''CHECKPOINT'' UNION SELECT ''IDENTITYCOL'' UNION SELECT ''SAVE'' UNION SELECT ''CLOSE'' UNION SELECT ''IF'' UNION SELECT ''SCHEMA'' UNION SELECT ''CLUSTERED'' UNION SELECT ''IN'' UNION SELECT ''SECURITYAUDIT'' UNION SELECT ''COALESCE'' UNION SELECT ''INDEX'' UNION SELECT ''SELECT'' UNION SELECT ''COLLATE'' UNION SELECT ''INNER'' UNION SELECT ''SEMANTICKEYPHRASETABLE'' UNION SELECT ''COLUMN'' UNION SELECT ''INSERT'' UNION SELECT ''SEMANTICSIMILARITYDETAILSTABLE'' UNION SELECT ''COMMIT'' UNION SELECT ''INTERSECT'' UNION SELECT ''SEMANTICSIMILARITYTABLE'' UNION SELECT ''COMPUTE'' UNION SELECT ''INTO'' UNION SELECT ''SESSION_USER'' UNION SELECT ''CONSTRAINT'' UNION SELECT ''IS'' UNION SELECT ''SET'' UNION SELECT ''CONTAINS'' UNION SELECT ''JOIN'' UNION SELECT ''SETUSER'' UNION SELECT ''CONTAINSTABLE'' UNION SELECT ''KEY'' UNION SELECT ''SHUTDOWN'' UNION SELECT ''CONTINUE'' UNION SELECT ''KILL'' UNION SELECT ''SOME'' UNION SELECT ''CONVERT'' UNION SELECT ''LEFT'' UNION SELECT ''STATISTICS'' UNION SELECT ''CREATE'' UNION SELECT ''LIKE'' UNION SELECT ''SYSTEM_USER'' UNION SELECT ''CROSS'' UNION SELECT ''LINENO'' UNION SELECT ''TABLE'' UNION SELECT ''CURRENT'' UNION SELECT ''LOAD'' UNION SELECT ''TABLESAMPLE'' UNION SELECT ''CURRENT_DATE'' UNION SELECT ''MERGE'' UNION SELECT ''TEXTSIZE'' UNION SELECT ''CURRENT_TIME'' UNION SELECT ''NATIONAL'' UNION SELECT ''THEN'' UNION SELECT ''CURRENT_TIMESTAMP'' UNION SELECT ''NOCHECK'' UNION SELECT ''TO'' UNION SELECT ''CURRENT_USER'' UNION SELECT ''NONCLUSTERED'' UNION SELECT ''TOP'' UNION SELECT ''CURSOR'' UNION SELECT ''NOT'' UNION SELECT ''TRAN'' UNION SELECT ''DATABASE'' UNION SELECT ''NULL'' UNION SELECT ''TRANSACTION'' UNION SELECT ''DBCC'' UNION SELECT ''NULLIF'' UNION SELECT ''TRIGGER'' UNION SELECT ''DEALLOCATE'' UNION SELECT ''OF'' UNION SELECT ''TRUNCATE'' UNION SELECT ''DECLARE'' UNION SELECT ''OFF'' UNION SELECT ''TRY_CONVERT'' UNION SELECT ''DEFAULT'' UNION SELECT ''OFFSETS'' UNION SELECT ''TSEQUAL'' UNION SELECT ''DELETE'' UNION SELECT ''ON'' UNION SELECT ''UNION'' UNION SELECT ''DENY'' UNION SELECT ''OPEN'' UNION SELECT ''UNIQUE'' UNION SELECT ''DESC'' UNION SELECT ''OPENDATASOURCE'' UNION SELECT ''UNPIVOT'' UNION SELECT ''DISK'' UNION SELECT ''OPENQUERY'' UNION SELECT ''UPDATE'' UNION SELECT ''DISTINCT'' UNION SELECT ''OPENROWSET'' UNION SELECT ''UPDATETEXT'' UNION SELECT ''DISTRIBUTED'' UNION SELECT ''OPENXML'' UNION SELECT ''USE'' UNION SELECT ''DOUBLE'' UNION SELECT ''OPTION'' UNION SELECT ''USER'' UNION SELECT ''DROP'' UNION SELECT ''OR'' UNION SELECT ''VALUES'' UNION SELECT ''DUMP'' UNION SELECT ''ORDER'' UNION SELECT ''VARYING'' UNION SELECT ''ELSE'' UNION SELECT ''OUTER'' UNION SELECT ''VIEW'' UNION SELECT ''END'' UNION SELECT ''OVER'' UNION SELECT ''WAITFOR'' UNION SELECT ''ERRLVL'' UNION SELECT ''PERCENT'' UNION SELECT ''WHEN'' UNION SELECT ''ESCAPE'' UNION SELECT ''PIVOT'' UNION SELECT ''WHERE'' UNION SELECT ''EXCEPT'' UNION SELECT ''PLAN'' UNION SELECT ''WHILE'' UNION SELECT ''EXEC'' UNION SELECT ''PRECISION'' UNION SELECT ''WITH'' UNION SELECT ''EXECUTE'' UNION SELECT ''PRIMARY'' UNION SELECT ''WITHIN GROUP'' UNION SELECT ''EXISTS'' UNION SELECT ''PRINT'' UNION SELECT ''WRITETEXT'' UNION SELECT ''EXIT'' UNION SELECT ''PROC'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        ) AS reserved (word) ON O.name = reserved.word
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

			        /* ODBC Reserved Keywords */
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
					        INNER JOIN (
						        SELECT ''ABSOLUTE'' UNION SELECT ''EXEC'' UNION SELECT ''OVERLAPS'' UNION SELECT ''ACTION'' UNION SELECT ''EXECUTE'' UNION SELECT ''PAD'' UNION SELECT ''ADA'' UNION SELECT ''EXISTS'' UNION SELECT ''PARTIAL'' UNION SELECT ''ADD'' UNION SELECT ''EXTERNAL'' UNION SELECT ''PASCAL'' UNION SELECT ''ALL'' UNION SELECT ''EXTRACT'' UNION SELECT ''POSITION'' UNION SELECT ''ALLOCATE'' UNION SELECT ''FALSE'' UNION SELECT ''PRECISION'' UNION SELECT ''ALTER'' UNION SELECT ''FETCH'' UNION SELECT ''PREPARE'' UNION SELECT ''AND'' UNION SELECT ''FIRST'' UNION SELECT ''PRESERVE'' UNION SELECT ''ANY'' UNION SELECT ''FLOAT'' UNION SELECT ''PRIMARY'' UNION SELECT ''ARE'' UNION SELECT ''FOR'' UNION SELECT ''PRIOR'' UNION SELECT ''AS'' UNION SELECT ''FOREIGN'' UNION SELECT ''PRIVILEGES'' UNION SELECT ''ASC'' UNION SELECT ''FORTRAN'' UNION SELECT ''PROCEDURE'' UNION SELECT ''ASSERTION'' UNION SELECT ''FOUND'' UNION SELECT ''PUBLIC'' UNION SELECT ''AT'' UNION SELECT ''FROM'' UNION SELECT ''READ'' UNION SELECT ''AUTHORIZATION'' UNION SELECT ''FULL'' UNION SELECT ''REAL'' UNION SELECT ''AVG'' UNION SELECT ''GET'' UNION SELECT ''REFERENCES'' UNION SELECT ''BEGIN'' UNION SELECT ''GLOBAL'' UNION SELECT ''RELATIVE'' UNION SELECT ''BETWEEN'' UNION SELECT ''GO'' UNION SELECT ''RESTRICT'' UNION SELECT ''BIT'' UNION SELECT ''GOTO'' UNION SELECT ''REVOKE'' UNION SELECT ''BIT_LENGTH'' UNION SELECT ''GRANT'' UNION SELECT ''RIGHT'' UNION SELECT ''BOTH'' UNION SELECT ''GROUP'' UNION SELECT ''ROLLBACK'' UNION SELECT ''BY'' UNION SELECT ''HAVING'' UNION SELECT ''ROWS'' UNION SELECT ''CASCADE'' UNION SELECT ''HOUR'' UNION SELECT ''SCHEMA'' UNION SELECT ''CASCADED'' UNION SELECT ''IDENTITY'' UNION SELECT ''SCROLL'' UNION SELECT ''CASE'' UNION SELECT ''IMMEDIATE'' UNION SELECT ''SECOND'' UNION SELECT ''CAST'' UNION SELECT ''IN'' UNION SELECT ''SECTION'' UNION SELECT ''CATALOG'' UNION SELECT ''INCLUDE'' UNION SELECT ''SELECT'' UNION SELECT ''CHAR'' UNION SELECT ''INDEX'' UNION SELECT ''SESSION'' UNION SELECT ''CHAR_LENGTH'' UNION SELECT ''INDICATOR'' UNION SELECT ''SESSION_USER'' UNION SELECT ''CHARACTER'' UNION SELECT ''INITIALLY'' UNION SELECT ''SET'' UNION SELECT ''CHARACTER_LENGTH'' UNION SELECT ''INNER'' UNION SELECT ''SIZE'' UNION SELECT ''CHECK'' UNION SELECT ''INPUT'' UNION SELECT ''SMALLINT'' UNION SELECT ''CLOSE'' UNION SELECT ''INSENSITIVE'' UNION SELECT ''SOME'' UNION SELECT ''COALESCE'' UNION SELECT ''INSERT'' UNION SELECT ''SPACE'' UNION SELECT ''COLLATE'' UNION SELECT ''INT'' UNION SELECT ''SQL'' UNION SELECT ''COLLATION'' UNION SELECT ''INTEGER'' UNION SELECT ''SQLCA'' UNION SELECT ''COLUMN'' UNION SELECT ''INTERSECT'' UNION SELECT ''SQLCODE'' UNION SELECT ''COMMIT'' UNION SELECT ''INTERVAL'' UNION SELECT ''SQLERROR'' UNION SELECT ''CONNECT'' UNION SELECT ''INTO'' UNION SELECT ''SQLSTATE'' UNION SELECT ''CONNECTION'' UNION SELECT ''IS'' UNION SELECT ''SQLWARNING'' UNION SELECT ''CONSTRAINT'' UNION SELECT ''ISOLATION'' UNION SELECT ''SUBSTRING'' UNION SELECT ''CONSTRAINTS'' UNION SELECT ''JOIN'' UNION SELECT ''SUM'' UNION SELECT ''CONTINUE'' UNION SELECT ''KEY'' UNION SELECT ''SYSTEM_USER'' UNION SELECT ''CONVERT'' UNION SELECT ''LANGUAGE'' UNION SELECT ''TABLE'' UNION SELECT ''CORRESPONDING'' UNION SELECT ''LAST'' UNION SELECT ''TEMPORARY'' UNION SELECT ''COUNT'' UNION SELECT ''LEADING'' UNION SELECT ''THEN'' UNION SELECT ''CREATE'' UNION SELECT ''LEFT'' UNION SELECT ''TIME'' UNION SELECT ''CROSS'' UNION SELECT ''LEVEL'' UNION SELECT ''TIMESTAMP'' UNION SELECT ''CURRENT'' UNION SELECT ''LIKE'' UNION SELECT ''TIMEZONE_HOUR'' UNION SELECT ''CURRENT_DATE'' UNION SELECT ''LOCAL'' UNION SELECT ''TIMEZONE_MINUTE'' UNION SELECT ''CURRENT_TIME'' UNION SELECT ''LOWER'' UNION SELECT ''TO'' UNION SELECT ''CURRENT_TIMESTAMP'' UNION SELECT ''MATCH'' UNION SELECT ''TRAILING'' UNION SELECT ''CURRENT_USER'' UNION SELECT ''MAX'' UNION SELECT ''TRANSACTION'' UNION SELECT ''CURSOR'' UNION SELECT ''MIN'' UNION SELECT ''TRANSLATE'' UNION SELECT ''DATE'' UNION SELECT ''MINUTE'' UNION SELECT ''TRANSLATION'' UNION SELECT ''DAY'' UNION SELECT ''MODULE'' UNION SELECT ''TRIM'' UNION SELECT ''DEALLOCATE'' UNION SELECT ''MONTH'' UNION SELECT ''TRUE'' UNION SELECT ''DEC'' UNION SELECT ''NAMES'' UNION SELECT ''UNION'' UNION SELECT ''DECIMAL'' UNION SELECT ''NATIONAL'' UNION SELECT ''UNIQUE'' UNION SELECT ''DECLARE'' UNION SELECT ''NATURAL'' UNION SELECT ''UNKNOWN'' UNION SELECT ''DEFAULT'' UNION SELECT ''NCHAR'' UNION SELECT ''UPDATE'' UNION SELECT ''DEFERRABLE'' UNION SELECT ''NEXT'' UNION SELECT ''UPPER'' UNION SELECT ''DEFERRED'' UNION SELECT ''NO'' UNION SELECT ''USAGE'' UNION SELECT ''DELETE'' UNION SELECT ''NONE'' UNION SELECT ''USER'' UNION SELECT ''DESC'' UNION SELECT ''NOT'' UNION SELECT ''USING'' UNION SELECT ''DESCRIBE'' UNION SELECT ''NULL'' UNION SELECT ''VALUE'' UNION SELECT ''DESCRIPTOR'' UNION SELECT ''NULLIF'' UNION SELECT ''VALUES'' UNION SELECT ''DIAGNOSTICS'' UNION SELECT ''NUMERIC'' UNION SELECT ''VARCHAR'' UNION SELECT ''DISCONNECT'' UNION SELECT ''OCTET_LENGTH'' UNION SELECT ''VARYING'' UNION SELECT ''DISTINCT'' UNION SELECT ''OF'' UNION SELECT ''VIEW'' UNION SELECT ''DOMAIN'' UNION SELECT ''ON'' UNION SELECT ''WHEN'' UNION SELECT ''DOUBLE'' UNION SELECT ''ONLY'' UNION SELECT ''WHENEVER'' UNION SELECT ''DROP'' UNION SELECT ''OPEN'' UNION SELECT ''WHERE'' UNION SELECT ''ELSE'' UNION SELECT ''OPTION'' UNION SELECT ''WITH'' UNION SELECT ''END'' UNION SELECT ''OR'' UNION SELECT ''WORK'' UNION SELECT ''END-EXEC'' UNION SELECT ''ORDER'' UNION SELECT ''WRITE'' UNION SELECT ''ESCAPE'' UNION SELECT ''OUTER'' UNION SELECT ''YEAR'' UNION SELECT ''EXCEPT'' UNION SELECT ''OUTPUT'' UNION SELECT ''ZONE'' UNION SELECT ''EXCEPTION'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        ) AS reserved (word) ON O.name = reserved.word
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			
			        /* Future Reserved Keywords */
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
					        INNER JOIN (
						        SELECT ''ABSOLUTE'' UNION SELECT ''HOST'' UNION SELECT ''RELATIVE'' UNION SELECT ''ACTION'' UNION SELECT ''HOUR'' UNION SELECT ''RELEASE'' UNION SELECT ''ADMIN'' UNION SELECT ''IGNORE'' UNION SELECT ''RESULT'' UNION SELECT ''AFTER'' UNION SELECT ''IMMEDIATE'' UNION SELECT ''RETURNS'' UNION SELECT ''AGGREGATE'' UNION SELECT ''INDICATOR'' UNION SELECT ''ROLE'' UNION SELECT ''ALIAS'' UNION SELECT ''INITIALIZE'' UNION SELECT ''ROLLUP'' UNION SELECT ''ALLOCATE'' UNION SELECT ''INITIALLY'' UNION SELECT ''ROUTINE'' UNION SELECT ''ARE'' UNION SELECT ''INOUT'' UNION SELECT ''ROW'' UNION SELECT ''ARRAY'' UNION SELECT ''INPUT'' UNION SELECT ''ROWS'' UNION SELECT ''ASENSITIVE'' UNION SELECT ''INT'' UNION SELECT ''SAVEPOINT'' UNION SELECT ''ASSERTION'' UNION SELECT ''INTEGER'' UNION SELECT ''SCROLL'' UNION SELECT ''ASYMMETRIC'' UNION SELECT ''INTERSECTION'' UNION SELECT ''SCOPE'' UNION SELECT ''AT'' UNION SELECT ''INTERVAL'' UNION SELECT ''SEARCH'' UNION SELECT ''ATOMIC'' UNION SELECT ''ISOLATION'' UNION SELECT ''SECOND'' UNION SELECT ''BEFORE'' UNION SELECT ''ITERATE'' UNION SELECT ''SECTION'' UNION SELECT ''BINARY'' UNION SELECT ''LANGUAGE'' UNION SELECT ''SENSITIVE'' UNION SELECT ''BIT'' UNION SELECT ''LARGE'' UNION SELECT ''SEQUENCE'' UNION SELECT ''BLOB'' UNION SELECT ''LAST'' UNION SELECT ''SESSION'' UNION SELECT ''BOOLEAN'' UNION SELECT ''LATERAL'' UNION SELECT ''SETS'' UNION SELECT ''BOTH'' UNION SELECT ''LEADING'' UNION SELECT ''SIMILAR'' UNION SELECT ''BREADTH'' UNION SELECT ''LESS'' UNION SELECT ''SIZE'' UNION SELECT ''CALL'' UNION SELECT ''LEVEL'' UNION SELECT ''SMALLINT'' UNION SELECT ''CALLED'' UNION SELECT ''LIKE_REGEX'' UNION SELECT ''SPACE'' UNION SELECT ''CARDINALITY'' UNION SELECT ''LIMIT'' UNION SELECT ''SPECIFIC'' UNION SELECT ''CASCADED'' UNION SELECT ''LN'' UNION SELECT ''SPECIFICTYPE'' UNION SELECT ''CAST'' UNION SELECT ''LOCAL'' UNION SELECT ''SQL'' UNION SELECT ''CATALOG'' UNION SELECT ''LOCALTIME'' UNION SELECT ''SQLEXCEPTION'' UNION SELECT ''CHAR'' UNION SELECT ''LOCALTIMESTAMP'' UNION SELECT ''SQLSTATE'' UNION SELECT ''CHARACTER'' UNION SELECT ''LOCATOR'' UNION SELECT ''SQLWARNING'' UNION SELECT ''CLASS'' UNION SELECT ''MAP'' UNION SELECT ''START'' UNION SELECT ''CLOB'' UNION SELECT ''MATCH'' UNION SELECT ''STATE'' UNION SELECT ''COLLATION'' UNION SELECT ''MEMBER'' UNION SELECT ''STATEMENT'' UNION SELECT ''COLLECT'' UNION SELECT ''METHOD'' UNION SELECT ''STATIC'' UNION SELECT ''COMPLETION'' UNION SELECT ''MINUTE'' UNION SELECT ''STDDEV_POP'' UNION SELECT ''CONDITION'' UNION SELECT ''MOD'' UNION SELECT ''STDDEV_SAMP'' UNION SELECT ''CONNECT'' UNION SELECT ''MODIFIES'' UNION SELECT ''STRUCTURE'' UNION SELECT ''CONNECTION'' UNION SELECT ''MODIFY'' UNION SELECT ''SUBMULTISET'' UNION SELECT ''CONSTRAINTS'' UNION SELECT ''MODULE'' UNION SELECT ''SUBSTRING_REGEX'' UNION SELECT ''CONSTRUCTOR'' UNION SELECT ''MONTH'' UNION SELECT ''SYMMETRIC'' UNION SELECT ''CORR'' UNION SELECT ''MULTISET'' UNION SELECT ''SYSTEM'' UNION SELECT ''CORRESPONDING'' UNION SELECT ''NAMES'' UNION SELECT ''TEMPORARY'' UNION SELECT ''COVAR_POP'' UNION SELECT ''NATURAL'' UNION SELECT ''TERMINATE'' UNION SELECT ''COVAR_SAMP'' UNION SELECT ''NCHAR'' UNION SELECT ''THAN'' UNION SELECT ''CUBE'' UNION SELECT ''NCLOB'' UNION SELECT ''TIME'' UNION SELECT ''CUME_DIST'' UNION SELECT ''NEW'' UNION SELECT ''TIMESTAMP'' UNION SELECT ''CURRENT_CATALOG'' UNION SELECT ''NEXT'' UNION SELECT ''TIMEZONE_HOUR'' UNION SELECT ''CURRENT_DEFAULT_TRANSFORM_GROUP'' UNION SELECT ''NO'' UNION SELECT ''TIMEZONE_MINUTE'' UNION SELECT ''CURRENT_PATH'' UNION SELECT ''NONE'' UNION SELECT ''TRAILING'' UNION SELECT ''CURRENT_ROLE'' UNION SELECT ''NORMALIZE'' UNION SELECT ''TRANSLATE_REGEX'' UNION SELECT ''CURRENT_SCHEMA'' UNION SELECT ''NUMERIC'' UNION SELECT ''TRANSLATION'' UNION SELECT ''CURRENT_TRANSFORM_GROUP_FOR_TYPE'' UNION SELECT ''OBJECT'' UNION SELECT ''TREAT'' UNION SELECT ''CYCLE'' UNION SELECT ''OCCURRENCES_REGEX'' UNION SELECT ''TRUE'' UNION SELECT ''DATA'' UNION SELECT ''OLD'' UNION SELECT ''UESCAPE'' UNION SELECT ''DATE'' UNION SELECT ''ONLY'' UNION SELECT ''UNDER'' UNION SELECT ''DAY'' UNION SELECT ''OPERATION'' UNION SELECT ''UNKNOWN'' UNION SELECT ''DEC'' UNION SELECT ''ORDINALITY'' UNION SELECT ''UNNEST'' UNION SELECT ''DECIMAL'' UNION SELECT ''OUT'' UNION SELECT ''USAGE'' UNION SELECT ''DEFERRABLE'' UNION SELECT ''OVERLAY'' UNION SELECT ''USING'' UNION SELECT ''DEFERRED'' UNION SELECT ''OUTPUT'' UNION SELECT ''VALUE'' UNION SELECT ''DEPTH'' UNION SELECT ''PAD'' UNION SELECT ''VAR_POP'' UNION SELECT ''DEREF'' UNION SELECT ''PARAMETER'' UNION SELECT ''VAR_SAMP'' UNION SELECT ''DESCRIBE'' UNION SELECT ''PARAMETERS'' UNION SELECT ''VARCHAR'' UNION SELECT ''DESCRIPTOR'' UNION SELECT ''PARTIAL'' UNION SELECT ''VARIABLE'' UNION SELECT ''DESTROY'' UNION SELECT ''PARTITION'' UNION SELECT ''WHENEVER'' UNION SELECT ''DESTRUCTOR'' UNION SELECT ''PATH'' UNION SELECT ''WIDTH_BUCKET'' UNION SELECT ''DETERMINISTIC'' UNION SELECT ''POSTFIX'' UNION SELECT ''WITHOUT'' UNION SELECT ''DICTIONARY'' UNION SELECT ''PREFIX'' UNION SELECT ''WINDOW'' UNION SELECT ''DIAGNOSTICS'' UNION SELECT ''PREORDER'' UNION SELECT ''WITHIN'' UNION SELECT ''DISCONNECT'' UNION SELECT ''PREPARE'' UNION SELECT ''WORK'' UNION SELECT ''DOMAIN'' UNION SELECT ''PERCENT_RANK'' UNION SELECT ''WRITE'' UNION SELECT ''DYNAMIC'' UNION SELECT ''PERCENTILE_CONT'' UNION SELECT ''XMLAGG'' UNION SELECT ''EACH'' UNION SELECT ''PERCENTILE_DISC'' UNION SELECT ''XMLATTRIBUTES'' UNION SELECT ''ELEMENT'' UNION SELECT ''POSITION_REGEX'' UNION SELECT ''XMLBINARY'' UNION SELECT ''END-EXEC'' UNION SELECT ''PRESERVE'' UNION SELECT ''XMLCAST'' UNION SELECT ''EQUALS'' UNION SELECT ''PRIOR'' UNION SELECT ''XMLCOMMENT'' UNION SELECT ''EVERY'' UNION SELECT ''PRIVILEGES'' UNION SELECT ''XMLCONCAT'' UNION SELECT ''EXCEPTION'' UNION SELECT ''RANGE'' UNION SELECT ''XMLDOCUMENT'' UNION SELECT ''FALSE'' UNION SELECT ''READS'' UNION SELECT ''XMLELEMENT'' UNION SELECT ''FILTER'' UNION SELECT ''REAL'' UNION SELECT ''XMLEXISTS'' UNION SELECT ''FIRST'' UNION SELECT ''RECURSIVE'' UNION SELECT ''XMLFOREST'' UNION SELECT ''FLOAT'' UNION SELECT ''REF'' UNION SELECT ''XMLITERATE'' UNION SELECT ''FOUND'' UNION SELECT ''REFERENCING'' UNION SELECT ''XMLNAMESPACES'' UNION SELECT ''FREE'' UNION SELECT ''REGR_AVGX'' UNION SELECT ''XMLPARSE'' UNION SELECT ''FULLTEXTTABLE'' UNION SELECT ''REGR_AVGY'' UNION SELECT ''XMLPI'' UNION SELECT ''FUSION'' UNION SELECT ''REGR_COUNT'' UNION SELECT ''XMLQUERY'' UNION SELECT ''GENERAL'' UNION SELECT ''REGR_INTERCEPT'' UNION SELECT ''XMLSERIALIZE'' UNION SELECT ''GET'' UNION SELECT ''REGR_R2'' UNION SELECT ''XMLTABLE'' UNION SELECT ''GLOBAL'' UNION SELECT ''REGR_SLOPE'' UNION SELECT ''XMLTEXT'' UNION SELECT ''GO'' UNION SELECT ''REGR_SXX'' UNION SELECT ''XMLVALIDATE'' UNION SELECT ''GROUPING'' UNION SELECT ''REGR_SXY'' UNION SELECT ''YEAR'' UNION SELECT ''HOLD'' UNION SELECT ''REGR_SYY'' UNION SELECT ''ZONE'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        ) AS reserved (word) ON O.name = reserved.word
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 3
		           ,@Priority      = 40
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Wide Table'
		           ,@URLAnchor     = 'table-conventions#wide-table';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON T.object_id = O.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        T.max_column_id_used > 20
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 6
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Heap'
		           ,@URLAnchor     = 'table-conventions#heap';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T ON I.object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON T.object_id = O.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        I.type = 0
					        AND O.name NOT IN (''__SchemaSnapshot'')
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 30
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'System Versioned Temporal Tables are not Compressed'
		           ,@URLAnchor     = 'table-conventions#System-Versioned-Temporal-Tables-are-not-Compressed';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = O.object_id
				           ,ObjectName    = O.name
				           ,ObjectType    = O.type_desc
				           ,Details       = N''By default, the history table is PAGE compressed, this one is not. Visit the URL column for a script to correct this issue.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.partitions AS P
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON I.object_id = P.object_id AND I.index_id = P.index_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON I.object_id = O.object_id
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON O.object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        T.temporal_type    = 1 /* HISTORY_TABLE */
					    AND I.type             <> 5 /* CLUSTERED */
                        AND P.data_compression <> 2 /* Not Page compressed, which is the default for system-versioned temporal tables */
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 31
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Column Named ????Id But No Foreign Key Exists'
		           ,@URLAnchor     = 'table-conventions#column-named-id-but-no-foreign-key-exists';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = C.object_id
				           ,ObjectName    = T.name + ''.'' + C.name
				           ,ObjectType    = ''COLUMN''
				           ,Details       = N''In most cases, columns with the name ????Id that are not the primary key should have a foreign key relationship to another table.''
                        FROM
                            ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON T.object_id = C.object_id
                        WHERE
                            T.type          = ''U''
                        AND T.temporal_type <> 1
                        AND C.name LIKE ''%id''
                        AND NOT EXISTS (
                            SELECT
                                *
                            FROM
                                ' + QUOTENAME(@DatabaseName) + N'.sys.tables                   AS T2
                                INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes       AS I2  ON T2.object_id  = I2.object_id AND I2.is_primary_key = 1
                                INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns AS IC2 ON IC2.object_id = I2.object_id AND IC2.index_id      = I2.index_id
                                INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns       AS C2  ON I2.object_id  = C2.object_id AND C2.column_id      = IC2.column_id
                            WHERE
                                C2.object_id = C.object_id
                            AND C2.column_id = C.column_id
                        )
                        AND NOT EXISTS (
                            SELECT
                                *
                            FROM
                                ' + QUOTENAME(@DatabaseName) + N'.sys.foreign_key_columns AS FKC
                            WHERE
                                FKC.parent_object_id = C.object_id
                            AND FKC.parent_column_id = C.column_id
                        )
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 32
		           ,@Priority      = 30
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'More Than 5 Indexes'
		           ,@URLAnchor     = 'table-conventions#more-than-5-indexes';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = T.name
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''Your table might be over indexed. The more you have the less performant insert, update & deletes are. A general rule of thumb is 5 indexes on a table.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON T.object_id = I.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        T.type = ''U''
					    AND I.type <> 0
                        GROUP BY
                            S.schema_id
                           ,S.name
                           ,T.object_id
                           ,T.name
                        HAVING
                            COUNT(*) > 5
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 33
		           ,@Priority      = 30
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Less than 2 Indexes'
		           ,@URLAnchor     = 'table-conventions#less-than-2-indexes';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = T.name
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''Your table might be under indexed. Would an index on any other column make your queries go faster?''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON T.object_id = I.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        T.type = ''U''
					    AND I.type <> 0
                        GROUP BY
                            S.schema_id
                           ,S.name
                           ,T.object_id
                           ,T.name
                        HAVING
                            COUNT(*) < 2
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 34
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Disabled Index'
		           ,@URLAnchor     = 'table-conventions#disabled-index';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = I.name
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''An index rebuild or reorganization will enabled disabled indexes. It is now best practices to delete instead of disable if not needed.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON T.object_id = I.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        T.type        = ''U''
					    AND I.is_disabled = 1
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 35
		           ,@Priority      = 30
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Leftover Fake Index'
		           ,@URLAnchor     = 'table-conventions#leftover-fake-index';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = I.name
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''The Index Tuning Wizard and Database Tuning Advisor create fake indexes, then getting a new execution plan for a query. These fake indexes stay behind sometimes.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON T.object_id = I.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        T.type            = ''U''
					    AND I.is_hypothetical = 1
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 37
		           ,@Priority      = 30
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Low Index Fill-Factor'
		           ,@URLAnchor     = 'table-conventions#low-index-fill-factor';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = I.name
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''Best practice is to ONLY use a low fill factor (80% or lower) on indexes where you know you need it. Setting a low fill factor on too many indexes will hurt your performance.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.indexes            AS I
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON I.object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
				        WHERE
					        I.fill_factor < 80
					    AND I.fill_factor <> 0
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 38
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Untrusted Foreign Key'
		           ,@URLAnchor     = 'table-conventions#untrusted-foreign-key';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = T.name + ''.'' + C.name
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''The foreign key is not trusted - meaning, it was disabled, data was changed, and then the constraint was enabled again. Simply enabling the constraint is not enough for the optimizer to use this constraint - we have to alter the table using the WITH CHECK CHECK CONSTRAINT parameter.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.foreign_keys       AS C
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON C.parent_object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id        = S.schema_id
				        WHERE
					        C.is_not_trusted         = 1
					    AND C.is_not_for_replication = 0
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 39
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Untrusted Check Constraints'
		           ,@URLAnchor     = 'table-conventions#untrusted-check-constraint';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = T.name + ''.'' + C.name                           
				           ,ObjectType    = ''USER_TABLE''
				           ,Details       = N''The check constraint is not trusted - meaning, it was disabled, data was changed, and then the constraint was enabled again. Simply enabling the constraint is not enough for the optimizer to use this constraint - we have to alter the table using the WITH CHECK CHECK CONSTRAINT parameter.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.check_constraints  AS C
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON C.parent_object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id         = S.schema_id
				        WHERE
					        C.is_not_trusted         = 1
					    AND C.is_not_for_replication = 0
                        AND C.is_disabled            = 0
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 36
		           ,@Priority      = 10
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Column Has a Different Collation Than Database'
		           ,@URLAnchor     = 'table-conventions#column-has-a-different-collation-than-database';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = T.object_id
				           ,ObjectName    = C.name
				           ,ObjectType    = ''COLUMN''
				           ,Details       = N''This could cause issues if the code is not aware of different collations and does include features to work with them correctly.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.tables             AS T
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON T.object_id = C.object_id
				        WHERE
					        T.type           = ''U''
					    AND C.collation_name <> SERVERPROPERTY(N''Collation'')
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 7
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Naming Conventions'
		           ,@Finding       = 'Using ID for Primary Key Column Name'
		           ,@URLAnchor     = 'naming-conventions#using-id-for-primary-key-column-name';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns AS IC ON I.object_id  = IC.object_id AND I.index_id  = IC.index_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns       AS C  ON IC.object_id = C.object_id  AND IC.column_id = C.column_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables        AS T  ON C.object_id  = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON T.schema_id  = S.schema_id
				        WHERE
					        I.is_primary_key  = 1
					        AND C.name COLLATE SQL_Latin1_General_CP1_CI_AS = ''id''
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 8
		           ,@Priority      = 5
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'UNIQUEIDENTIFIER For Primary Key'
		           ,@URLAnchor     = 'table-conventions#uniqueidentifier-for-primary-key';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns AS IC ON I.object_id     = IC.object_id   AND I.index_id   = IC.index_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns       AS C  ON IC.object_id    = C.object_id    AND IC.column_id = C.column_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types         AS TP ON C.user_type_id = TP.user_type_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables        AS T  ON C.object_id     = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON T.schema_id     = S.schema_id
				        WHERE
					        I.is_primary_key   = 1
					        AND T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					        AND C.user_type_id = 36
                        OPTION (RECOMPILE);';

				        EXEC sys.sp_executesql @stmt = @StringToExecute;
				        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 22
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'UNIQUEIDENTIFIER in a Clustered Index'
		           ,@URLAnchor     = 'table-conventions#uniqueidentifier-in-a-clustered-index';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
		
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON IC.object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id  = S.schema_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON IC.object_id = C.object_id
												           AND IC.column_id = C.column_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes AS I ON IC.object_id = I.object_id
												           AND IC.index_id  = I.index_id
				        WHERE
					        T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					        AND C.system_type_id = 36
					        AND I.type_desc  = ''CLUSTERED''
                        OPTION (RECOMPILE);';

				        EXEC sys.sp_executesql @stmt = @StringToExecute;
				        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 21
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Missing Index for Foreign Key'
		           ,@URLAnchor     = 'table-conventions#missing-index-for-foreign-key';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
		
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas             AS S   ON FK.schema_id         = S.schema_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables              AS T   ON FK.parent_object_id  = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.foreign_key_columns AS FKC ON FK.object_id         = FKC.constraint_object_id
					        LEFT OUTER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.index_columns  AS IC  ON FKC.parent_object_id = IC.object_id
																			             AND IC.column_id   = FKC.parent_column_id
																			             AND IC.key_ordinal = FKC.constraint_column_id
				        WHERE
					        IC.object_id IS NULL
                        OPTION (RECOMPILE);';

				        EXEC sys.sp_executesql @stmt = @StringToExecute;
				        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 20
		           ,@Priority      = 5
		           ,@FindingGroup  = 'Table Conventions'
		           ,@Finding       = 'Missing Primary Key'
		           ,@URLAnchor     = 'table-conventions#missing-primary-key';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
		
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S ON T.schema_id = S.schema_id
					        LEFT OUTER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.indexes  AS I ON T.object_id = I.object_id AND I.is_primary_key = 1
				        WHERE
				            T.name NOT IN (''__RefactorLog'', ''__MigrationLog'', ''__MigrationLogCurrent'', ''__SchemaSnapshot'', ''__SchemaSnapshotDateDefault'', ''fn_diagramobjects'', ''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'')
					        AND I.object_id IS NULL
                            AND T.temporal_type <> 1
                        OPTION (RECOMPILE);';

				        EXEC sys.sp_executesql @stmt = @StringToExecute;
				        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
			        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 10
		           ,@Priority      = 20
		           ,@FindingGroup  = 'Data Type Conventions'
		           ,@Finding       = 'Using User-Defined Data Type'
		           ,@URLAnchor     = 'data-type-conventions#using-user-defined-data-type';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas       AS S  ON T.schema_id = S.schema_id
				        WHERE
					        T.is_user_defined = 1
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 25
		           ,@Priority      = 1
		           ,@FindingGroup  = 'SQL Code Development'
		           ,@Finding       = 'Scalar Function Is Not Inlineable'
		           ,@URLAnchor     = 'sql-code-conventions#scalar-function-is-not-inlineable';
		        /**********************************************************************************************************************/	
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
			        AND EXISTS(SELECT * FROM sys.databases WHERE compatibility_level >= 150 AND database_id = @DatabaseId)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON SM.object_id = O.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id  = S.schema_id
				        WHERE
					        O.type               = ''FN''
					        AND SM.is_inlineable = 0
                        OPTION (RECOMPILE);'
			
			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 24
		           ,@Priority      = 5
		           ,@FindingGroup  = 'SQL Code Development'
		           ,@Finding       = 'Using User-Defined Scalar Function'
		           ,@URLAnchor     = 'sql-code-conventions#using-user-defined-scalar-function';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
			        AND EXISTS(SELECT * FROM sys.databases WHERE compatibility_level < 150 AND database_id = @DatabaseId)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        O.type = ''FN''
                            AND O.name NOT IN (''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'', ''fn_diagramobjects'', ''sp_Develop'', ''sp_WhoIsActive'')
                        OPTION (RECOMPILE);'
			
			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 23
		           ,@Priority      = 1
		           ,@FindingGroup  = 'SQL Code Development'
		           ,@Finding       = 'Using SELECT *'
		           ,@URLAnchor     = 'sql-code-conventions#using-select-';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON SM.object_id           = O.object_id
					        LEFT OUTER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables AS T ON O.parent_object_id = T.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id            = S.schema_id
				        WHERE
					        SM.definition LIKE ''%SELECT%*%'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        AND SM.definition NOT LIKE ''%IF%EXISTS%(%SELECT%*%'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        AND SM.definition NOT LIKE ''%COUNT%(%*%)%'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        AND SM.definition NOT LIKE ''%SELECT%=%*%'' COLLATE SQL_Latin1_General_CP1_CI_AS
					        AND SM.definition NOT LIKE ''%SELECT%[0-9]%[*]%[0-9]%''
                        OPTION (RECOMPILE);'

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 9
		           ,@Priority      = 1
		           ,@FindingGroup  = 'SQL Code Development'
		           ,@Finding       = 'Using Hardcoded Database Name Reference'
		           ,@URLAnchor     = 'sql-code-conventions#using-hardcoded-database-name-reference';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON SM.object_id = O.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        PATINDEX(''%FROM%'' + ''' + @DatabaseName + N''' + ''.%.%'' COLLATE SQL_Latin1_General_CP1_CI_AS, SM.definition COLLATE SQL_Latin1_General_CP1_CI_AS) > 0
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 19
		           ,@Priority      = 5
		           ,@FindingGroup  = 'SQL Code Development'
		           ,@Finding       = 'Not Using SET NOCOUNT ON in Stored Procedure or Trigger'
		           ,@URLAnchor     = 'sql-code-conventions#not-using-set-nocount-on-in-stored-procedure-or-trigger';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        /* Trigger */
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas     AS S  ON T.schema_id  = S.schema_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.triggers    AS TR ON T.object_id  = TR.parent_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.sql_modules AS M  ON TR.object_id = M.object_id
				        WHERE
					        (M.definition NOT LIKE ''%SET NOCOUNT ON%'' COLLATE SQL_Latin1_General_CP1_CI_AS
                            AND M.definition NOT LIKE ''%SET NOCOUNT, XACT_ABORT ON%'' COLLATE SQL_Latin1_General_CP1_CI_AS)
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

			        /* Stored Procedure */
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON SM.object_id = O.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        O.type IN (''P'')
                            AND O.name NOT IN (''sp_alterdiagram'', ''sp_creatediagram'', ''sp_dropdiagram'', ''sp_helpdiagramdefinition'', ''sp_helpdiagrams'', ''sp_renamediagram'', ''sp_upgraddiagrams'', ''fn_diagramobjects'', ''sp_Develop'', ''sp_WhoIsActive'')
					        AND (SM.definition NOT LIKE ''%SET NOCOUNT ON%'' COLLATE SQL_Latin1_General_CP1_CI_AS
                            AND SM.definition NOT LIKE ''%SET NOCOUNT, XACT_ABORT ON%'' COLLATE SQL_Latin1_General_CP1_CI_AS)
                        OPTION (RECOMPILE);'

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 15
		           ,@Priority      = 1
		           ,@FindingGroup  = 'SQL Code Development'
		           ,@Finding       = 'Using NOLOCK (READ UNCOMMITTED)'
		           ,@URLAnchor     = 'sql-code-conventions#using-nolock-read-uncommitted';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
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
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O ON SM.object_id = O.object_id
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
				        WHERE
					        O.name NOT IN (''sp_Develop'', ''sp_WhoIsActive'')
					        AND (
						        PATINDEX(''%(%NOLOCK%)%'', SM.definition COLLATE SQL_Latin1_General_CP1_CI_AS) > 0
						        OR PATINDEX(''%(%READUNCOMMITTED%)%'', SM.definition COLLATE SQL_Latin1_General_CP1_CI_AS) > 0
						        OR PATINDEX(''%READ UNCOMMITTED%'', SM.definition COLLATE SQL_Latin1_General_CP1_CI_AS) > 0
					        )
                        OPTION (RECOMPILE);';

			        EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;
		        END;

		        /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 27
		           ,@Priority      = 1
		           ,@FindingGroup  = 'Data Issues'
		           ,@Finding       = 'Unencrypted Data'
		           ,@URLAnchor     = 'data-issues#unencrypted-data';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;

                    IF OBJECT_ID('tempdb..#TableList') IS NOT NULL
                        BEGIN
                            DROP TABLE #TableList;
                        END;

                    CREATE TABLE #TableList (
                        TableListId          INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY
                       ,object_id            INT           NOT NULL
                       ,schema_id            INT           NOT NULL
                       ,SchemaName           NVARCHAR(128) NOT NULL
                       ,TableName            NVARCHAR(128) NOT NULL
                       ,ColumnName           NVARCHAR(128) NOT NULL
                       ,StandardColumnLength INT           NOT NULL
                       ,MinimumColumnLength  INT           NOT NULL DEFAULT (0)
                       ,encryption_type      INT           NULL DEFAULT (0) /* 0 = Unknown | 1 = Deterministic encryption | 2 = Randomized encryption | NULL = None */
                       ,IsProcessedFlag      BIT           NOT NULL DEFAULT (0)
                    );

                    CREATE NONCLUSTERED INDEX object_id ON #TableList (object_id);
                    CREATE NONCLUSTERED INDEX IsProcessedFlag ON #TableList (IsProcessedFlag);

			        SET @StringToExecute = N'
                        INSERT INTO
                            #TableList (object_id, Schema_Id, SchemaName, TableName, ColumnName, StandardColumnLength)
                        SELECT
                            object_id            = C.object_id
                           ,schema_id            = S.schema_id
                           ,SchemaName           = S.name
                           ,TableName            = T.name
                           ,ColumnName           = C.name
                           ,StandardColumnLength = CASE
                                                       WHEN C.name LIKE ''%password%'' COLLATE SQL_Latin1_General_CP1_CI_AS THEN 15
                                                       WHEN C.name LIKE ''%creditcard%'' COLLATE SQL_Latin1_General_CP1_CI_AS THEN 16
                                                       WHEN C.name LIKE ''%ssn%'' OR C.name LIKE ''%socialsecuritynumber%'' COLLATE SQL_Latin1_General_CP1_CI_AS THEN 11
                                                       WHEN C.name LIKE ''%passport%'' COLLATE SQL_Latin1_General_CP1_CI_AS THEN 9
                                                       WHEN C.name LIKE ''%dll%'' OR C.name LIKE ''%license%'' COLLATE SQL_Latin1_General_CP1_CI_AS THEN 15
                                                       ELSE 15
                                                   END
                        FROM
                            ' + QUOTENAME(@DatabaseName) + N'.sys.columns            AS C
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.tables  AS T ON C.object_id = T.object_id
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON T.schema_id = S.schema_id
                        WHERE (
                            C.name LIKE ''%password%''
                            AND C.name NOT LIKE ''%date%''
                            AND C.name NOT LIKE ''%config%''
                            AND C.name NOT LIKE ''%complexity%''
                            AND C.name NOT LIKE ''%expir%''
                            AND C.name NOT LIKE ''%flag%''
                            AND C.name NOT LIKE ''%last%''
                            AND C.name NOT LIKE ''%failed%''
                            AND C.name NOT LIKE ''%max%''
                            AND C.name NOT LIKE ''%min%''
                            AND C.name NOT LIKE ''%length%''
                            AND C.name NOT LIKE ''%requir%''                            
                            AND C.name NOT LIKE ''%count%''
                            AND C.name NOT LIKE ''%salt%''
                            AND C.name <> ''is_password_protected'' COLLATE SQL_Latin1_General_CP1_CI_AS
                        )
                            OR ((C.name LIKE ''%creditcard%'' OR C.name LIKE ''%ccn%'')
                                AND C.name NOT LIKE ''%token%''
                                AND C.name NOT LIKE ''%approv%''
                                AND C.name NOT LIKE ''%code%''
                                AND C.name <> ''creditcardid''
                                COLLATE SQL_Latin1_General_CP1_CI_AS
                            )
                            OR (C.name = ''ssn'' OR C.name = ''socialsecuritynumber'' COLLATE SQL_Latin1_General_CP1_CI_AS)
                            OR (C.name LIKE ''%passport%'' COLLATE SQL_Latin1_General_CP1_CI_AS)
                            OR (C.name LIKE ''dll'' COLLATE SQL_Latin1_General_CP1_CI_AS)
                            OR (C.name LIKE ''%license%'' AND C.name NOT LIKE ''%count%'' COLLATE SQL_Latin1_General_CP1_CI_AS)
                        OPTION (RECOMPILE);'

                    EXEC sys.sp_executesql @stmt = @StringToExecute;
			        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

                    /* Check to see if the column length check for unencrypted data should be executed */
                    IF @BringThePain <> 1
                        BEGIN
                            INSERT INTO
                                #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
                            SELECT
					             CheckId       = @CheckId
				                ,Database_Id   = @DatabaseId
				                ,DatabaseName  = @DatabaseName
				                ,FindingGroup  = @FindingGroup
				                ,Finding       = @Finding
				                ,URL           = @URLBase + @URLAnchor
				                ,Priority      = @Priority
				                ,Schema_Id     = TL.schema_id
				                ,SchemaName    = TL.SchemaName
				                ,Object_Id     = TL.object_id
				                ,ObjectName    = TL.TableName + '.' + TL.ColumnName
				                ,ObjectType    = 'COLUMN'
				                ,Details       = N'The column might have unencrypted data that you might want to have encrypted. To execute the length check use the parameter @BringThePain = 1.'
                            FROM
                                #TableList AS TL
                            OPTION (RECOMPILE)
                        END
                    ELSE
                        BEGIN
                            /* Edition Check for Available Feature */
                            IF ((@ProductVersionMajor >= 14) /* Any Edition SQL Server 2017+ */
                                OR (@ProductVersionMajor >= 13 AND @@VERSION LIKE '%Enterprise Edition%') /* Enterprise Edition SQL Server 2016+ */
                                OR (
                                    @ProductVersionMajor = 13
                                    AND @ProductVersionMinor >= 4001
                                    AND @@VERSION LIKE '%Standard Edition%'
                                ) /* Standard Edition 2016 SP1+*/
                            )
                                BEGIN
                                    /* Find columns that are using Always Encrypt */
        			                SET @StringToExecute = N'
                                        UPDATE
                                            TL
                                        SET
                                            encryption_type = C.encryption_type
                                            ,IsProcessedFlag = 1
                                        FROM
                                            ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C
                                            INNER JOIN #TableList   AS TL ON C.object_id = TL.object_id
                                        WHERE
                                            C.encryption_type IS NOT NULL
                                        OPTION (RECOMPILE);'

                                    EXEC sys.sp_executesql @stmt = @StringToExecute;
			                        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

                                END;

                            /* Loop through #TableList to figure out if the non-Always Encrypt columns have some sort of hashing or encryption */

                            DECLARE
                                @TableListId   INT
                               ,@SchemaName    NVARCHAR(128)
                               ,@TableName     NVARCHAR(128)
                               ,@ColumnName    NVARCHAR(128);

                            WHILE EXISTS (SELECT * FROM #TableList WHERE IsProcessedFlag = 0 AND encryption_type = 0)
                                BEGIN
                                    SELECT TOP (1)
                                           @TableListId   = TL.TableListId
                                          ,@SchemaName    = TL.SchemaName
                                          ,@TableName     = TL.TableName
                                          ,@ColumnName    = TL.ColumnName
                                    FROM
                                        #TableList AS TL
                                    WHERE
                                        TL.IsProcessedFlag = 0
                                    ORDER BY
                                        TL.TableListId
                                    OPTION (RECOMPILE);

                                    SET @StringToExecute = N'
			                            UPDATE
				                            TL
			                            SET
				                             TL.MinimumColumnLength = ISNULL(T.MinimumColumnLength, 0)
				                            ,TL.encryption_type     = NULL
			                            FROM
				                            #TableList AS TL
			                            CROSS JOIN (
						                            SELECT
							                            MinimumColumnLength = MIN(LEN(' + QUOTENAME(@ColumnName) + N'))
						                            FROM
							                            ' + QUOTENAME(@DatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N'
                                                    WHERE
                                                        ' + QUOTENAME(@ColumnName) + N' IS NOT NULL
                                                ) AS T
			                            WHERE
				                            TL.TableListId = ' + CAST(@TableListId AS NVARCHAR(MAX)) + N'
                                        OPTION (RECOMPILE);';

                                    EXEC sys.sp_executesql @stmt = @StringToExecute;
			                        IF @Debug = 2 AND @StringToExecute IS NOT NULL PRINT @StringToExecute;

                                    UPDATE
                                        #TableList
                                    SET
                                        IsProcessedFlag = 1
                                    WHERE
                                        TableListId = @TableListId
                                    OPTION (RECOMPILE);
                                END;

                            /* Find columns with potential unencrypted data */			        
                            INSERT INTO
                                #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
                            SELECT
					             CheckId       = @CheckId
				                ,Database_Id   = @DatabaseId
				                ,DatabaseName  = @DatabaseName
				                ,FindingGroup  = @FindingGroup
				                ,Finding       = @Finding
				                ,URL           = @URLBase + @URLAnchor
				                ,Priority      = @Priority
				                ,Schema_Id     = TL.schema_id
				                ,SchemaName    = TL.SchemaName
				                ,Object_Id     = TL.object_id
				                ,ObjectName    = TL.TableName + '.' + TL.ColumnName
				                ,ObjectType    = 'COLUMN'
				                ,Details       = N'The column might have unencrypted data that you might want to have encrypted.'
                            FROM
                                #TableList AS TL
                            WHERE
                                TL.encryption_type IS NULL
                                AND TL.MinimumColumnLength <= TL.StandardColumnLength * 1.3 /* The "* 1.3" is allowing a 30% buffer above standard column length to look for encryption/hashing. */
                            OPTION (RECOMPILE);

                        END

                    DROP TABLE #TableList;
			       
		        END;

                /**********************************************************************************************************************/
		        SELECT
			        @CheckId       = 28
		           ,@Priority      = 5
		           ,@FindingGroup  = 'Data Type Conventions'
		           ,@Finding       = 'Using MONEY data type'
		           ,@URLAnchor     = 'data-type-conventions#using-money-data-type';
		        /**********************************************************************************************************************/
		        IF NOT EXISTS (SELECT 1 FROM #SkipCheck AS SC WHERE SC.CheckId = @CheckId AND SC.ObjectName IS NULL)
		        BEGIN
			        IF @Debug IN (1, 2) RAISERROR(N'Running CheckId [%d]', 0, 1, @CheckId) WITH NOWAIT;
			
			        SET @StringToExecute = N'
				        INSERT INTO
					        #Finding (CheckId, Database_Id, DatabaseName, FindingGroup, Finding, URL, Priority, Schema_Id, SchemaName, Object_Id, ObjectName, ObjectType, Details)
				        SELECT
					        CheckId       = ' + CAST(@CheckId AS NVARCHAR(MAX)) + N'
				           ,Database_Id   = ' + CAST(@DatabaseId AS NVARCHAR(MAX)) + N'
				           ,DatabaseName  = ''' + CAST(@DatabaseName AS NVARCHAR(MAX)) + N'''
				           ,FindingGroup  = ''' + CAST(@FindingGroup AS NVARCHAR(MAX)) + N'''
				           ,Finding       = ''' + CAST(@Finding AS NVARCHAR(MAX)) + N'''
				           ,URL           = ''' + CAST(@URLBase + @URLAnchor AS NVARCHAR(MAX)) + N'''
				           ,Priority      = ' + CAST(@Priority AS NVARCHAR(MAX)) + N'
				           ,Schema_Id     = S.schema_id
				           ,SchemaName    = S.name
				           ,Object_Id     = O.object_id
				           ,ObjectName    = O.name + ''.'' + C.Name
				           ,ObjectType    = ''COLUMN''
				           ,Details       = N''This column uses the '' + UPPER(T.name) + N'' data type, which has limited precision and can lead to roundoff errors. Consider using DECIMAL(19, 4) instead.''
				        FROM
					        ' + QUOTENAME(@DatabaseName) + N'.sys.objects AS O
					        INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.schemas AS S ON O.schema_id = S.schema_id
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.columns AS C ON O.object_id = C.object_id
                            INNER JOIN ' + QUOTENAME(@DatabaseName) + N'.sys.types   AS T ON C.user_type_id = T.user_type_id
				        WHERE
					        T.name IN (''money'', ''smallmoney'')
                        OPTION (RECOMPILE);';

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
	    ** After populating the #Finding table, time to dump it out.
	    **********************************************************************************************************************/
        DECLARE @Separator AS char(1);
        IF @OutputType = 'RSV'
            SET @Separator = CHAR(31);
        ELSE
            SET @Separator = ',';

        IF @OutputType = 'COUNT'
            BEGIN
                SELECT Warnings = COUNT(*)FROM #Finding
                OPTION (RECOMPILE);
            END;
        ELSE IF @OutputType IN ('CSV', 'RSV')
            BEGIN
                    -- SQL Prompt formatting off
                     SELECT
                         Result =
                            COALESCE(F.DatabaseName, '(N/A)') + @Separator +
                            COALESCE(F.SchemaName, '(N/A)') + @Separator +
                            COALESCE(F.ObjectName, '(N/A)') + @Separator +
                            COALESCE(F.ObjectType, '(N/A)') + @Separator +
                            COALESCE(F.FindingGroup, '(N/A)') + @Separator +
                            COALESCE(F.Finding, '(N/A)') + @Separator +
                            COALESCE(F.Details, '(N/A)') + @Separator +
                            COALESCE(F.URL, '(N/A)') + @Separator +                            
                            CAST(F.Priority AS NVARCHAR(100)) + @Separator +
                            CAST(F.CheckId AS NVARCHAR(100))
                     FROM
                         #Finding AS F
                     ORDER BY
                         F.DatabaseName
                        ,F.SchemaName
                        ,F.ObjectName
                        ,F.ObjectType
                        ,F.FindingGroup
                        ,F.Finding
                    OPTION (RECOMPILE);
                    -- SQL Prompt formatting on
            END;
        ELSE IF @OutputType = 'XML'
            BEGIN
                SELECT
                    F.DatabaseName
                   ,F.SchemaName
                   ,F.ObjectName
                   ,F.ObjectType
                   ,F.FindingGroup
                   ,F.Finding
                   ,F.Details
                   ,F.URL
                   ,SkipCheckTSQL = ISNULL('INSERT INTO ' + @SkipCheckSchema + '.' + @SkipCheckTable + ' (ServerName, DatabaseName, SchemaName, ObjectName, CheckId) VALUES (N''' + CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)) + ''', N''' + F.DatabaseName + ''', N''' + F.SchemaName + ''', N''' + F.ObjectName + ''', ' + CAST(F.CheckId AS nvarchar(50)) + ');', @URLSkipChecks)
                   ,F.Priority
                   ,F.CheckId
                FROM
                    #Finding AS F
                ORDER BY
                    F.DatabaseName
                   ,F.SchemaName
                   ,F.ObjectName
                   ,F.ObjectType
                   ,F.FindingGroup
                   ,F.Finding
                FOR XML PATH('Finding'), ROOT('sp_Develop_Output')
                OPTION (RECOMPILE);
            END;
        ELSE IF @OutputType <> 'NONE'
            BEGIN
                SELECT
                    Priority       = CASE WHEN F.Priority = 1
                                              THEN 'Critical'
                                         WHEN F.Priority = 5
                                             THEN 'High'
                                         WHEN F.Priority = 10
                                             THEN 'High'
                                         WHEN F.Priority = 20
                                             THEN 'Medium'
                                         WHEN F.Priority = 30
                                             THEN 'Low'
                                         WHEN F.Priority = 40
                                             THEN 'Low'
                                         WHEN F.Priority = 50
                                             THEN 'Low'
                                         ELSE 'Unknown'
                                     END /*Critical, High, Medium, and Low */
                   ,F.DatabaseName
                   ,F.SchemaName
                   ,F.ObjectName
                   ,F.ObjectType
                   ,F.FindingGroup
                   ,F.Finding
                   ,F.Details
                   ,F.URL
                   ,SkipCheckTSQL  = ISNULL('INSERT INTO ' + @SkipCheckSchema + '.' + @SkipCheckTable + ' (ServerName, DatabaseName, SchemaName, ObjectName, CheckId) VALUES (N''' + CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)) + ''', N''' + F.DatabaseName + ''', N''' + F.SchemaName + ''', N''' + F.ObjectName + ''', ' + CAST(F.CheckId AS nvarchar(50)) + ');', @URLSkipChecks)
                   ,F.CheckId
                   ,PriorityNumber = F.Priority
                FROM
                    #Finding AS F
                WHERE
                    NOT EXISTS (
                    SELECT
                        SC.ServerName
                       ,SC.DatabaseName
                       ,SC.ObjectName
                       ,SC.CheckId
                    FROM
                        #SkipCheck AS SC
                    WHERE
                        (SC.SchemaName = F.SchemaName OR SC.SchemaName IS NULL)
                    AND SC.ObjectName  = F.ObjectName
                    AND SC.CheckId     = F.CheckId
                )
                AND NOT EXISTS (
                    SELECT
                        SC.ServerName
                       ,SC.DatabaseName
                       ,SC.ObjectName
                       ,SC.CheckId
                    FROM
                        #SkipCheck AS SC
                    WHERE
                        (SC.SchemaName = F.SchemaName OR SC.SchemaName IS NULL)
                    AND SC.ObjectName  = F.ObjectName
                    AND SC.CheckId IS NULL
                )
                AND NOT EXISTS (
                    SELECT
                        SC.ServerName
                       ,SC.DatabaseName
                       ,SC.ObjectName
                       ,SC.CheckId
                    FROM
                        #SkipCheck AS SC
                    WHERE
                        (SC.SchemaName = F.SchemaName)
                    AND SC.ObjectName IS NULL
                    AND SC.CheckId IS NULL
                )
                --AND F.Priority <= 10
                AND F.Priority <= CASE WHEN @PriorityOrHigher IS NULL
                                           THEN 2147483647
                                      ELSE CASE @PriorityOrHigher
                                               WHEN 'Critical'
                                                   THEN 1
                                               WHEN 'High'
                                                   THEN 10
                                               WHEN 'Medium'
                                                   THEN 20
                                               WHEN 'Low'
                                                   THEN 50
                                               ELSE 2147483647
                                           END
                                  END
                ORDER BY
                    F.DatabaseName
                   ,F.SchemaName
                   ,F.ObjectName
                   ,F.ObjectType
                   ,F.FindingGroup
                   ,F.Finding
                OPTION (RECOMPILE);
            END;

        IF @ShowSummary = 1
            BEGIN
                SELECT
                    FindingGroup     = F.FindingGroup
                   ,Finding          = F.Finding
                   ,NumberOfFindings = COUNT_BIG(*)
                FROM
                    #Finding AS F
                GROUP BY
                    F.FindingGroup
                   ,F.Finding
                ORDER BY
                    F.FindingGroup
                   ,F.Finding
                OPTION (RECOMPILE);
            END;

        DROP TABLE #Finding;

    END;
