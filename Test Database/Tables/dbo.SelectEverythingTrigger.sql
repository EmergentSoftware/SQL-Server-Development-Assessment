CREATE TABLE [dbo].[SelectEverythingTrigger]
(
[SelectEverythingTriggerId] [int] NOT NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SelectEverythingTriggerAfter]
   ON  [dbo].[SelectEverythingTrigger]
   AFTER INSERT
AS 
BEGIN
	SET NOCOUNT ON;

    SELECT * FROM dbo.SelectEverythingTrigger

END
GO
ALTER TABLE [dbo].[SelectEverythingTrigger] ADD CONSTRAINT [PK_SelectEverythingTrigger] PRIMARY KEY CLUSTERED  ([SelectEverythingTriggerId]) ON [PRIMARY]
GO
