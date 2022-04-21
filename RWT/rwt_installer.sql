-- [ONC RWT Metrics v1.0]
-- 04.20.2022

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
  @i_enddate DATETIME
AS
SET NOCOUNT ON;

DECLARE @_startdate DATETIME,
        @_startdate1 DATETIME,
        @_sqlcmd NVARCHAR(MAX);

SET @_startdate = dateadd(month, -3, @i_enddate); --calculates 90 day period from @i_enddate
SET @_startDate1 = dateadd(month, -12, @i_enddate); --for PHR data export, date range is 1 year

SET @_sqlcmd = N'
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''RxCreate'' AS [Measure],
         ''Controlled Substance Schedule'' AS [VariableType],
         csasched AS [Variable],
         COUNT(company) AS [Count]
  FROM dbo.CLRXHIST
  WHERE source = ''I''
        AND pharmacytranid LIKE ''%-%''
        AND rxdate >= @_startdate
        AND rxdate <= @i_enddate
  GROUP BY company,
           csasched

  UNION ALL
  /*this query returns multiple variables indicating status of renewal request.   See note "3" above for calculation instructions.  (Variable ''X'' is not processed or handled by non-electronic means) - Pulled from CLRXRENEWALX as the source 

  */
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''RxRenewals'' AS [Measure],
         ''Transmission Status'' AS [VariableType],
         [status] AS [Variable],
         COUNT([Status]) AS [Count]
  FROM dbo.CLRXRENEWALX
  WHERE xacdate >= @_startdate
        AND xacdate <= @i_enddate
        AND [status] NOT IN ( ''X'' )
  GROUP BY company,
           [status]

  UNION ALL
  /*This query returns the number of CCDA sent from MI PHR. Pulled from CLDOCS as Source.- For this script the execute statement needs to include the following variables: [startdate] and [enddate] */
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''CCDACreate'' AS [Measure],
         '''' AS [VariableType],
         '''' AS [Variable],
         COUNT(company) AS [Count]
  FROM dbo.CLDOCS
  WHERE chartdisplayname IN (
                              SELECT Parameter
                              FROM dbo.zSettingsApps
                              WHERE setting LIKE ''CCDChartDiscExport''
                            )
        AND filespec like ''%.HTML''                
        AND createdate >= @_startdate
        AND createdate <= @i_enddate
  GROUP BY company

  UNION ALL
  /*This query returns the number of CCDA received via PHR - Pulled from CLDOCS as source. For this script the execute statement needs to include the following variables: [startdate] and [enddate],  */
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''CCDASave'' AS [Measure],
         '''' AS [VariableType],
         '''' AS [Variable],
         COUNT(company) AS [Count]
  FROM dbo.CLDOCS
  WHERE chartdisplayname IN (
                              SELECT Parameter
                              FROM dbo.zSettingsApps
                              WHERE setting LIKE ''CCDChartDisc''
                            )
        AND createdate BETWEEN @_startdate AND @i_enddate
        AND status <> ''D''
        AND filespec LIKE ''%.html''
  GROUP BY company

  UNION ALL
  /*This query returns the number of medications reconciled via the PHR in a 90 day period*/
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         COMPANY AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''Medications Reconcilation'' AS [Measure],
         ''Order Description'' AS [VariableType],
         ODESC AS [Variable],
         COUNT(ODESC) AS [Count]
  FROM dbo.CLORDER
  WHERE ORDERDATE >= @_startdate
        AND ORDERDATE <= @i_enddate
        AND ODESC = ''Medications Reconciliation''
        AND OMEMO = ''from C-CDA''
        AND STATUS <> ''D''
  GROUP BY COMPANY,
           ODESC

  UNION ALL
  /*This query returns the number of allergies reconciled via the PHR in a 90 day period*/
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         COMPANY AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''Allergies Reconcilation'' AS [Measure],
         ''Order Description'' AS [VariableType],
         ODESC AS [Variable],
         COUNT(ODESC) AS [Count]
  FROM dbo.CLORDER
  WHERE ORDERDATE >= @_startdate
        AND ORDERDATE <= @i_enddate
        AND ODESC = ''Allergies Reconciliation''
        AND OMEMO = ''from C-CDA''
        AND STATUS <> ''D''
  GROUP BY COMPANY,
           ODESC

  UNION ALL
  /*This query returns the number of diagnosis reconciled via the PHR in a 90 day period*/
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         COMPANY AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''Problems Reconcilation'' AS [Measure],
         ''Order Description'' AS [VariableType],
         ODESC AS [Variable],
         COUNT(ODESC) AS [Count]
  FROM dbo.CLORDER
  WHERE ORDERDATE >= @_startdate
        AND ORDERDATE <= @i_enddate
        AND ODESC IN ( ''Problems Reconciliation'' )
        AND OMEMO = ''from C-CDA''
        AND STATUS <> ''D''
  GROUP BY COMPANY,
           ODESC

  /*  No longer needed as Drummond  understand the query above will contain required data*/
  UNION ALL
  /*This query returns the number of restricted CCDA sent from MI PHR. Pulled from CLDOCS as Source.- For this script the execute statement needs to include the following variables: [startdate] and [enddate]  */
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''CCDARestrictedCreated'' AS [Measure],
         '''' AS [VariableType],
         '''' AS [Variable],
         COUNT(company) AS [Count]
  FROM dbo.CLDOCS
  WHERE chartdisplayname IN (
                              SELECT Parameter
                              FROM dbo.zSettingsApps
                              WHERE setting LIKE ''CCDRestrictedChartDiscExport''
                            )
        AND status <> ''D''
        AND filespec LIKE ''%.html''
        AND createdate
        BETWEEN @_startdate AND @i_enddate
  GROUP BY company

  UNION ALL
  /* This query returns the number of restricted CCDA recieved from MI PHR. Pulled from CLDOCS as Source.- For this script the execute statement needs to include the following variables: [startdate] and [enddate] 

  */
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''CCDARestrictedReceived'' AS [Measure],
         '''' AS [VariableType],
         '''' AS [Variable],
         COUNT(company) AS [Count]
  FROM dbo.CLDOCS
  WHERE chartdisplayname IN (
                              SELECT Parameter
                              FROM dbo.zSettingsApps
                              WHERE setting LIKE ''CCDRestrictedChartDisc''
                            )
        AND status <> ''D''
        AND filespec LIKE ''%.html''
        AND createdate
        BETWEEN @_startdate AND @i_enddate
  GROUP BY COMPANY

  UNION ALL
  /*This is a duplicative selection from above as all restricted summaries are sequestered */
  SELECT @i_customer AS [Customer],
         @i_caresetting AS [CareSetting],
         company AS [Company],
         CONVERT(date, @_startdate) AS [StartDate],
         CONVERT(date, @i_enddate) AS [EndDate],
         ''RestrictedReceived'' AS [Measure],
         '''' AS [VariableType],
         '''' AS [Variable],
         COUNT(company) AS [Count]
  FROM dbo.CLDOCS
  WHERE chartdisplayname IN (
                              SELECT Parameter
                              FROM dbo.zSettingsApps
                              WHERE setting LIKE ''CCDRestrictedChartDisc''
                            )
        AND createdate
        BETWEEN @_startdate AND @i_enddate
        AND status <> ''D''
        AND filespec LIKE ''%.html''
  GROUP BY COMPANY';

/****************************************/
/*    O   P   T   I   O   N   A   L     */
/****************************************/

IF EXISTS (SELECT * FROM sys.columns WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[zEmailLog]') AND name = 'zEmailMessageID')
  AND EXISTS (SELECT * FROM sys.columns WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[zEmailLog]') AND name = 'entrydate')
  SET @_sqlcmd = @_sqlcmd + N'
    UNION ALL
    /*This query returns the number of messages sent from PHR outbound - Pulled from zEmailLog as source 

    /*results come back as
    dispatched
    processed*/

    */
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           company AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''CCDASent'' AS [Measure],
           ''Updox Export Status'' AS [VariableType],
           mdnStatus AS [Variable],
           COUNT(mdnStatus) AS [Count]
    FROM dbo.zEmailLog
      INNER JOIN dbo.zEmailMdnStatus
        ON zEmailLog.zEmailMessageID = zEmailMdnStatus.EmailID
    WHERE entrydate BETWEEN @_startdate AND @i_enddate
    GROUP BY company,
             mdnStatus';

IF EXISTS (SELECT * FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'CCDA' AND name = 'JobExport' AND [type]='U')
  SET @_sqlcmd = @_sqlcmd + N'
    UNION ALL
    /*This query returns exported CCDA by a single patient as a single transction*/
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           e.Company AS [Company],
           CONVERT(date, @_startdate1) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''Export of 1 pt'' AS [Measure],
           ''Export Status'' AS [VariableType],
           e.StatusCode AS [Variable],
           COUNT(e.StatusCode)
    FROM CCDA.JobExport AS E
      INNER JOIN CCDA.JobLog AS L
        ON E.JobLogID = L.JobLogID
    WHERE ExportedDate BETWEEN @_startdate1 AND @i_enddate
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
           CONVERT(date, @i_enddate) AS [EndDate],
           ''batch :'' + l.StatusCode AS [Measure],
           ''Export Status'' AS [VariableType],
           e.StatusCode AS [Variable],
           COUNT(l.StatusCode) AS [Count]
    FROM CCDA.JobExport AS E
      INNER JOIN CCDA.JobLog AS L
        ON E.JobLogID = L.JobLogID
    WHERE ExportedDate BETWEEN @_startdate1 AND @i_enddate
    GROUP BY l.JobLogID,
             l.StatusCode,
             e.statusCode,
             Company
    HAVING COUNT(l.JobLogID) >= 2';

IF EXISTS (SELECT * FROM sys.tables WHERE name='WPUSERACTIVITY' AND [type]='U')
  SET @_sqlcmd = @_sqlcmd + N'
    UNION ALL
    /* This query looks at how many CDA are viewed from Patient Portal - 

    pulled from WPUSERACTIVITY as the source */
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           company AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''Portal View'' AS [Measure],
           ''Action Code'' AS [VariableType],
           actioncode AS [Variable],
           COUNT(actioncode) AS [Count]
    FROM dbo.WPUSERACTIVITY
    WHERE timestamp >= @_startdate
          AND timestamp <= @i_enddate
          AND actioncode IN ( ''VW_CCD'' )
    GROUP BY company,
             actioncode

    UNION ALL
    /*This query looks at how many CDA are downloaded from Patient Portal

    pulled from WPUSERACTIVITY as the source*/
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           company AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''Portal Download'' AS [Measure],
           ''Action Code'' AS [VariableType],
           actioncode AS [Variable],
           COUNT(actioncode) AS [Count]
    FROM dbo.WPUSERACTIVITY
    WHERE timestamp >= @_startdate
          AND timestamp <= @i_enddate
          AND actioncode IN ( ''DL_CCDZ'' )
    GROUP BY company,
             actioncode

    UNION ALL
    /*This query looks at how many CDA are unsecure from Patient Portal

    pulled from WPUSERACTIVITY as the source*/
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           company AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''Portal Xmit Unencrypt'' AS [Measure],
           ''Action'' AS [VariableType],
           actioncode AS [Variable],
           COUNT(actioncode) AS [Count]
    FROM dbo.WPUSERACTIVITY
    WHERE timestamp >= @_startdate
          AND timestamp <= @i_enddate
          AND actioncode = ''EM_CCD''
    GROUP BY company,
             actioncode

    UNION ALL
    /*This query looks at how many CDA are secure from Patient Portal -pulled from WPUSERACTIVITY as the source*/
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           company AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''Portal Xmit Encrypt'' AS [Measure],
           ''Action Code'' AS [VariableType],
           actioncode AS [Variable],
           COUNT(actioncode) AS [Count]
    FROM dbo.WPUSERACTIVITY
    WHERE timestamp >= @_startdate
          AND timestamp <= @i_enddate
          AND actioncode IN ( ''DM_CCD'' )
    GROUP BY company,
             actioncode';

IF EXISTS (SELECT * FROM sys.tables WHERE name='NCRxCancelStatus' AND [type]='U')
  SET @_sqlcmd = @_sqlcmd + N'
    UNION ALL
    /*This query returns how many electronic Rx were cancelled during the 90-day window. - Pulled from NCRxCancelStatus as the source 

    This Table is NOT company specific, thus it is comprehensive and includes all companies in a single database

    No Optional Value for this query */
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           ''All companies'' AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''RxCancel'' AS [Measure],
           '''' AS [VariableType],
           '''' AS [Variable],
           COUNT(ID) AS [Count]
    FROM dbo.NCRxCancelStatus
    WHERE LastUpdate BETWEEN @_startdate AND @i_enddate';

IF EXISTS (SELECT * FROM sys.tables WHERE name='NCRxChangeDetail' AND [type]='U')
  SET @_sqlcmd = @_sqlcmd + N'
    UNION ALL
    /*This query returns how many electronic RX required a change after the doctor sent the original RX - Pulled from NCRxChangeDetail as the source*/
    SELECT @i_customer AS [Customer],
           @i_caresetting AS [CareSetting],
           d.company AS [Company],
           CONVERT(date, @_startdate) AS [StartDate],
           CONVERT(date, @i_enddate) AS [EndDate],
           ''RxChange'' AS [Measure],
           ''Reason for Change'' AS [VariableType],
           ChangeRequest AS [Variable],
           COUNT(*) AS [Count]
    FROM dbo.NCRxChangeDetail AS D
      LEFT JOIN dbo.CLRXHIST AS R
        ON D.OriginalTransactionGuid = r.pharmacytranid
    WHERE ReceivedTimestamp BETWEEN @_startdate AND @i_enddate
    GROUP BY d.company,
             changerequest';

EXEC sp_executesql
  @stmt = @_sqlcmd,
  @params = N'@i_customer VARCHAR(50), 
              @i_caresetting VARCHAR(50),
              @_startdate DATETIME,
              @_startdate1 DATETIME,
              @i_enddate DATETIME',
  @i_customer = @i_customer,
  @i_caresetting = @i_caresetting,
  @_startdate = @_startdate,
  @_startdate1 = @_startdate1,
  @i_enddate = @i_enddate;
GO

GRANT EXECUTE ON dbo.rwt_getmetrics TO MWUSER;
GO
