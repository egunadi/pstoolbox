IF EXISTS(SELECT * FROM sys.procedures WHERE name = 'ctk_get_processed_reports')
  DROP PROCEDURE dbo.ctk_get_processed_reports;
GO

CREATE PROCEDURE dbo.ctk_get_processed_reports
  @i_company VARCHAR(10),
  @i_startdate DATETIME,
  @i_enddate DATETIME
AS
SET NOCOUNT ON;
SET XACT_ABORT ON;

SELECT DISTINCT
  d.FILESPEC AS [FileName], 
  REPLACE(d.FOLDERTOKENNAME, 'DOC_', '') AS [SubDirectory]
FROM dbo.ctk_EXPORT_QUEUE AS q
  INNER JOIN [10.0.0.217].[MEDICAL].[dbo].[CLDOCS] AS d
    ON q.APPTNO = d.APPTNO
    AND q.ACCOUNT = d.ACCOUNT
    AND q.COMPANY = d.COMPANY
WHERE q.TSTAMPENTER >= @i_startdate
  AND q.TSTAMPENTER < @i_enddate
  AND q.COMPANY = @i_company;
GO

GRANT EXECUTE ON dbo.ctk_get_processed_reports TO MWUSER;
GO
