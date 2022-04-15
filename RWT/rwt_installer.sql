-- [ONC RWT Metrics v1.0]
-- 04.07.2022

/********************************************************/
/*    C   O   N   F   I   D   E   N   T   I   A   L     */
/********************************************************/
/*    This file is a Trade Secret of Medinformatix Inc. */
/*    This file is not to be made public to persons     */
/*    not explicitly authorized to view this document   */
/*    by contract or End-User-License Agreement         */
/*                                                      */
/*    (C) Copyright 2006-2022                           */
/*                                   Medinformatix Inc. */
/*                                                      */
/********************************************************/

/*
This script returns data used to measure Real World Use of specific MI functions/features by company.  A subsequent report will use the combined results from all participating customers.
1.  For each measure sum the company numbers
2.  On the "RxCreate" Measure: Sum the count for Variables Null and '0' as non-schedule drugs and sum the count for variables '1-9' as schedule drugs
3.  Performance score for the "RxRenewals" measure:  Sum count for variables 'S','V','Y' as denominator (all renewals sent) and SUM count of variables 'V','Y' numerator (renewals with acknowledgement from the pharmacy)
4.  Performance score for Measure "CCDASent": sum count for variable 'processed' as Numerator; sum count for variable 'dispatched' as Denominator
5.  Performance score for Measure "EXPORT of 1 Pt":  Sum count for variable 'failed' as numerator; sum count for variable 'completed' as denominator
6.  Performance score for Measure "BATCH %":  Sum count of Variable 'failed' as numerator; sum count for variable 'completed' as denominator
*/

IF EXISTS(SELECT * FROM sys.procedures WHERE name = 'rwt_getmetrics')
  DROP PROCEDURE dbo.rwt_getmetrics;
GO

CREATE PROCEDURE dbo.rwt_getmetrics
  @i_customer VARCHAR(50), 
  @i_caresetting VARCHAR(50),
  @i_startdate DATETIME
AS
SET NOCOUNT ON;

DECLARE @_startdate1 DATETIME,
        @_enddate DATETIME;

SET @_enddate = dateadd(month, 3, @i_startdate); --calculates 90 day period from @i_startdate
SET @_startDate1 = dateadd(month, -9, @i_startdate); --for PHR data export, date range is 1 year

SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'RxCreate' AS [Measure],
       'Controlled Substance Schedule' AS [VariableType],
       csasched AS [Variable],
       COUNT(company) AS [Count]
FROM dbo.CLRXHIST
WHERE source = 'I'
      AND pharmacytranid LIKE '%-%'
      AND rxdate >= @i_startdate
      AND rxdate <= @_enddate
GROUP BY company,
         csasched

UNION ALL
/*This query returns how many electronic RX required a change after the doctor sent the original RX - Pulled from NCRxChangeDetail as the source*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       d.company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'RxChange' AS [Measure],
       'Reason for Change' AS [VariableType],
       ChangeRequest AS [Variable],
       COUNT(*) AS [Count]
FROM dbo.NCRxChangeDetail AS D
  LEFT JOIN dbo.CLRXHIST AS R
    ON D.OriginalTransactionGuid = r.pharmacytranid
WHERE ReceivedTimestamp BETWEEN @i_startdate AND @_enddate
GROUP BY d.company,
         changerequest

UNION ALL
/*This query returns how many electronic Rx were cancelled during the 90-day window. - Pulled from NCRxCancelStatus as the source 

This Table is NOT company specific, thus it is comprehensive and includes all companies in a single database

No Optional Value for this query */
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       'All companies' AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'RxCancel' AS [Measure],
       '' AS [VariableType],
       '' AS [Variable],
       COUNT(ID) AS [Count]
FROM dbo.NCRxCancelStatus
WHERE LastUpdate BETWEEN @i_startdate AND @_enddate

UNION ALL
/*this query returns multiple variables indicating status of renewal request.   See note "3" above for calculation instructions.  (Variable 'X' is not processed or handled by non-electronic means) - Pulled from CLRXRENEWALX as the source 

*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'RxRenewals' AS [Measure],
       'Transmission Status' AS [VariableType],
       [status] AS [Variable],
       COUNT([Status]) AS [Count]
FROM dbo.CLRXRENEWALX
WHERE xacdate >= @i_startdate
      AND xacdate <= @_enddate
      AND [status] NOT IN ( 'X' )
GROUP BY company,
         [status]

UNION ALL
/*This query returns the number of CCDA sent from MI PHR. Pulled from CLDOCS as Source.- For this script the execute statement needs to include the following variables: [startdate] and [enddate] */
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'CCDACreate' AS [Measure],
       '' AS [VariableType],
       '' AS [Variable],
       COUNT(company) AS [Count]
FROM dbo.CLDOCS
WHERE chartdisplayname IN (
                            SELECT Parameter
                            FROM dbo.zSettingsApps
                            WHERE setting LIKE 'CCDChartDiscExport'
                          )
      AND filespec like '%.HTML'                
      AND createdate >= @i_startdate
      AND createdate <= @_enddate
GROUP BY company

UNION ALL
/*This query returns the number of messages sent from PHR outbound - Pulled from zEmailLog as source 

/*results come back as
dispatched
processed*/

*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'CCDASent' AS [Measure],
       'Updox Export Status' AS [VariableType],
       mdnStatus AS [Variable],
       COUNT(mdnStatus) AS [Count]
FROM dbo.zEmailLog
  INNER JOIN dbo.zEmailMdnStatus
    ON zEmailLog.zEmailMessageID = zEmailMdnStatus.EmailID
WHERE entrydate BETWEEN @i_startdate AND @_enddate
GROUP BY company,
         mdnStatus

UNION ALL
/*This query returns the number of CCDA received via PHR - Pulled from CLDOCS as source. For this script the execute statement needs to include the following variables: [startdate] and [enddate],  */
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'CCDASave' AS [Measure],
       '' AS [VariableType],
       '' AS [Variable],
       COUNT(company) AS [Count]
FROM dbo.CLDOCS
WHERE chartdisplayname IN (
                            SELECT Parameter
                            FROM dbo.zSettingsApps
                            WHERE setting LIKE 'CCDChartDisc'
                          )
      AND createdate BETWEEN @i_startdate AND @_enddate
      AND status <> 'D'
      AND filespec LIKE '%.html'
GROUP BY company

UNION ALL
/*This query returns the number of medications reconciled via the PHR in a 90 day period*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       COMPANY AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Medications Reconcilation' AS [Measure],
       'Order Description' AS [VariableType],
       ODESC AS [Variable],
       COUNT(ODESC) AS [Count]
FROM dbo.CLORDER
WHERE ORDERDATE >= @i_startdate
      AND ORDERDATE <= @_enddate
      AND ODESC = 'Medications Reconciliation'
      AND OMEMO = 'from C-CDA'
      AND STATUS <> 'D'
GROUP BY COMPANY,
         ODESC

UNION ALL
/*This query returns the number of allergies reconciled via the PHR in a 90 day period*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       COMPANY AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Allergies Reconcilation' AS [Measure],
       'Order Description' AS [VariableType],
       ODESC AS [Variable],
       COUNT(ODESC) AS [Count]
FROM dbo.CLORDER
WHERE ORDERDATE >= @i_startdate
      AND ORDERDATE <= @_enddate
      AND ODESC = 'Allergies Reconciliation'
      AND OMEMO = 'from C-CDA'
      AND STATUS <> 'D'
GROUP BY COMPANY,
         ODESC

UNION ALL
/*This query returns the number of diagnosis reconciled via the PHR in a 90 day period*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       COMPANY AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Problems Reconcilation' AS [Measure],
       'Order Description' AS [VariableType],
       ODESC AS [Variable],
       COUNT(ODESC) AS [Count]
FROM dbo.CLORDER
WHERE ORDERDATE >= @i_startdate
      AND ORDERDATE <= @_enddate
      AND ODESC IN ( 'Problems Reconciliation' )
      AND OMEMO = 'from C-CDA'
      AND STATUS <> 'D'
GROUP BY COMPANY,
         ODESC

UNION ALL
/*This query returns exported CCDA by a single patient as a single transction*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       e.Company AS [Company],
       CONVERT(date, @_startdate1) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Export of 1 pt' AS [Measure],
       'Export Status' AS [VariableType],
       e.StatusCode AS [Variable],
       COUNT(e.StatusCode)
FROM CCDA.JobExport AS E
  INNER JOIN CCDA.JobLog AS L
    ON E.JobLogID = L.JobLogID
WHERE ExportedDate BETWEEN @_startdate1 AND @_enddate
GROUP BY l.JobLogID,
         l.StatusCode,
         e.StatusCode,
         Company
HAVING COUNT(l.JobLogID) = 1

/*This query returns the count of completed, failed or canceled exported patient greater than or equal to 2*/
UNION ALL
/* potential answer are:L.StatusCode and E.StatusCode:

Batch: Completed; CCDA sent: Failed  -- All batch members compiled correctly, Not all records exported
Batch: Completed; CCDA sent: Completed  -- Batch compiled and exported correctly
Batch: Failed; CCDA sent: Failed --Batch members did not compile correctly, records did not export
Batch: Failed; CCDA sent: Completed -- Batch compile failed, Those batch members that compiled exported correctly
See step 6 at top of script for instructions               
*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       e.Company AS [Company],
       CONVERT(date, @_startdate1) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'batch :' + l.StatusCode AS [Measure],
     'Export Status' AS [VariableType],
       e.StatusCode AS [Variable],
       COUNT(l.StatusCode) AS [Count]
FROM CCDA.JobExport AS E
  INNER JOIN CCDA.JobLog AS L
    ON E.JobLogID = L.JobLogID
WHERE ExportedDate BETWEEN @_startdate1 AND @_enddate
GROUP BY l.JobLogID,
         l.StatusCode,
         e.statusCode,
         Company
HAVING COUNT(l.JobLogID) >= 2

/*  No longer needed as Drummond  understand the query above will contain required data*/
UNION ALL
/*This query returns the number of restricted CCDA sent from MI PHR. Pulled from CLDOCS as Source.- For this script the execute statement needs to include the following variables: [startdate] and [enddate]  */
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'CCDARestrictedCreated' AS [Measure],
       '' AS [VariableType],
       '' AS [Variable],
       COUNT(company) AS [Count]
FROM dbo.CLDOCS
WHERE chartdisplayname IN (
                            SELECT Parameter
                            FROM dbo.zSettingsApps
                            WHERE setting LIKE 'CCDRestrictedChartDiscExport'
                          )
      AND status <> 'D'
      AND filespec LIKE '%.html'
      AND createdate
      BETWEEN @i_startdate AND @_enddate
GROUP BY company

UNION ALL
/* This query returns the number of restricted CCDA recieved from MI PHR. Pulled from CLDOCS as Source.- For this script the execute statement needs to include the following variables: [startdate] and [enddate] 

*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'CCDARestrictedReceived' AS [Measure],
       '' AS [VariableType],
       '' AS [Variable],
       COUNT(company) AS [Count]
FROM dbo.CLDOCS
WHERE chartdisplayname IN (
                            SELECT Parameter
                            FROM dbo.zSettingsApps
                            WHERE setting LIKE 'CCDRestrictedChartDisc'
                          )
      AND status <> 'D'
      AND filespec LIKE '%.html'
      AND createdate
      BETWEEN @i_startdate AND @_enddate
GROUP BY COMPANY

UNION ALL
/*This is a duplicative selection from above as all restricted summaries are sequestered */
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'RestrictedReceived' AS [Measure],
       '' AS [VariableType],
       '' AS [Variable],
       COUNT(company) AS [Count]
FROM dbo.CLDOCS
WHERE chartdisplayname IN (
                            SELECT Parameter
                            FROM dbo.zSettingsApps
                            WHERE setting LIKE 'CCDRestrictedChartDisc'
                          )
      AND createdate
      BETWEEN @i_startdate AND @_enddate
      AND status <> 'D'
      AND filespec LIKE '%.html'
GROUP BY COMPANY

UNION ALL
/* This query looks at how many CDA are viewed from Patient Portal - 

pulled from WPUSERACTIVITY as the source */
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Portal View' AS [Measure],
       'Action Code' AS [VariableType],
       actioncode AS [Variable],
       COUNT(actioncode) AS [Count]
FROM dbo.WPUSERACTIVITY
WHERE timestamp >= @i_startdate
      AND timestamp <= @_enddate
      AND actioncode IN ( 'VW_CCD' )
GROUP BY company,
         actioncode

UNION ALL
/*This query looks at how many CDA are downloaded from Patient Portal

pulled from WPUSERACTIVITY as the source*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Portal Download' AS [Measure],
       'Action Code' AS [VariableType],
       actioncode AS [Variable],
       COUNT(actioncode) AS [Count]
FROM dbo.WPUSERACTIVITY
WHERE timestamp >= @i_startdate
      AND timestamp <= @_enddate
      AND actioncode IN ( 'DL_CCDZ' )
GROUP BY company,
         actioncode

UNION ALL
/*This query looks at how many CDA are unsecure from Patient Portal

pulled from WPUSERACTIVITY as the source*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Portal Xmit Unencrypt' AS [Measure],
     'Action' AS [VariableType],
       actioncode AS [Variable],
       COUNT(actioncode) AS [Count]
FROM dbo.WPUSERACTIVITY
WHERE timestamp >= @i_startdate
      AND timestamp <= @_enddate
      AND actioncode = 'EM_CCD'
GROUP BY company,
         actioncode

UNION ALL
/*This query looks at how many CDA are secure from Patient Portal -pulled from WPUSERACTIVITY as the source*/
SELECT @i_customer AS [Customer],
       @i_caresetting AS [CareSetting],
       company AS [Company],
       CONVERT(date, @i_startdate) AS [StartDate],
       CONVERT(date, @_enddate) AS [EndDate],
       'Portal Xmit Encrypt' AS [Measure],
       'Action Code' AS [VariableType],
       actioncode AS [Variable],
       COUNT(actioncode) AS [Count]
FROM dbo.WPUSERACTIVITY
WHERE timestamp >= @i_startdate
      AND timestamp <= @_enddate
      AND actioncode IN ( 'DM_CCD' )
GROUP BY company,
         actioncode;
GO

GRANT EXECUTE ON dbo.rwt_getmetrics TO MWUSER;
GO
