<#####################

Untitled1

#####################>

$sourceFilePath =  "\\Mac\Home\Documents\Reporting\auxiliaries\2021\CLECQMVALUESET\vsac_data\sortedByCMSID\"

$sourceFileName = "ep_ec_only_cms_20200507.xlsx"

$scratchRoot = "\\Mac\Home\Documents\Reporting\auxiliaries\2021\CLECQMVALUESET\vsac_data\scratch_2021\"

$tempTargetInterMediary =  "\\Mac\Home\Documents\Reporting\auxiliaries\2021\CLECQMVALUESET\vsac_data\scratch_2021\temp"

# Windows Only, MS Office must be installed
#############################################
#Open Excel Application Object
$objExcel = New-Object -ComObject Excel.Application;

#Open Excel Workbook
$workBook = $objExcel.WorkBooks.Open($sourceFilePath + $sourceFileName)

#Get count of number of worksheets in workbook
$workSheetCount = $workBook.WorkSheets.Count

#Loop through each worksheet, remove the first row, then save worksheet as csv.
for ($i = 1; $i -le $workSheetCount; $i++) {
  $worksheet = $workBook.WorkSheets($i)

  #delete first row of worksheet
  $worksheet.Cells.Item(1,1).EntireRow.Delete()

  $filename = $scratchRoot + "temp\" + "intermediary_ecqi-sortedByCMSID-" + $worksheet.Name

  $worksheet.SaveAs($filename,23)
}



<# Mac Testing

Install-Module ImportExcel

$workBook =  Import-Excel -Path ($sourceFilePath + $sourceFileName) -StartRow 2

# The issue here is that only one worksheet can be imported at a time
#>