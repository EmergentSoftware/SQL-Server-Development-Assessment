CREATE TABLE [dbo].[TriggerUse]
(
[TriggerId] [int] NOT NULL,
[SomeValue] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE TRIGGER [dbo].[Reminder1]
   ON  [dbo].[TriggerUse]
   AFTER INSERT,UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    RAISERROR ('Notify Customer Relations', 16, 10)

END
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE TRIGGER [dbo].[tr_LowCredit]
ON [dbo].[TriggerUse]
AFTER INSERT
AS
IF (ROWCOUNT_BIG() = 0) RETURN;
IF EXISTS (
    SELECT 1 WHERE 1=2
)
BEGIN
    RAISERROR('A vendor''s credit rating is too low to accept new purchase orders.', 16, 1);
    ROLLBACK TRANSACTION;
    RETURN;
END;
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE TRIGGER [dbo].[trReminder2]
ON [dbo].[TriggerUse]
AFTER INSERT, UPDATE
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    RAISERROR('Notify Vendor Relations', 16, 10);

END;
GO
ALTER TABLE [dbo].[TriggerUse] ADD CONSTRAINT [PK_TriggerUse] PRIMARY KEY CLUSTERED  ([TriggerId]) ON [PRIMARY]
GO
