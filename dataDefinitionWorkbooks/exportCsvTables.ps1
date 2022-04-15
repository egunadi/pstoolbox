$query = "SELECT 
	  [MeasureIdentifier]
	, [Version]
	, [QualityDataElement]
	, [CodeSystem]
	, [Concept]
	, [table]
	, [field]
	, [filter]
	, [note]
	, [ConceptDescription]
FROM [dbo].[cms002v9] 
ORDER BY 
      CONVERT(INT,[MeasureIdentifier]) ASC
    , [QualityDataElement]
    , [CodeSystem]
    , [Concept]"

Invoke-DbaQuery -SqlInstance EBENGUNADI255E\MSSQLSERVER01 -Query $query -Database medical | Export-CSV \\Mac\Home\Desktop\cms002v9.csv