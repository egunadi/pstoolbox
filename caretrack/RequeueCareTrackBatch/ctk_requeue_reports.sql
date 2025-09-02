
IF EXISTS(SELECT * FROM sys.procedures WHERE name = 'ctk_requeue_reports')
  DROP PROCEDURE dbo.ctk_requeue_reports;
GO

CREATE PROCEDURE dbo.ctk_requeue_reports
  @i_company VARCHAR(10),
  @i_startdate DATETIME,
  @i_enddate DATETIME
AS
SET NOCOUNT ON;
SET XACT_ABORT ON;

UPDATE dbo.ctk_EXPORT_QUEUE 
  SET EXPORT_TYPE = 'CARETRACK' 
WHERE TSTAMPENTER >= @i_startdate
  AND TSTAMPENTER < @i_enddate
  AND COMPANY = @i_company;
GO

GRANT EXECUTE ON dbo.ctk_requeue_reports TO MWUSER;
GO
