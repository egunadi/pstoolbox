$sourceFilePath =  "\\Mac\Home\Documents\Reporting\auxiliaries\2021\CLECQMVALUESET\vsac_data\bindingParameter\"

$sourceFileName = "bps_cms_20200507.xlsx"

$scratchRoot = "\\Mac\Home\Documents\Reporting\auxiliaries\2021\CLECQMVALUESET\vsac_data\scratch_2021\"

# Windows Only, MS Office must be installed
#############################################
#Open Excel Application Object
$objExcel = New-Object -ComObject Excel.Application;

#Open Excel Workbook
$workBook = $objExcel.WorkBooks.Open($sourceFilePath + $sourceFileName)

#Get count of number of worksheets in workbook
$workSheetCount = $workBook.WorkSheets.Count

#Loop through each worksheet then save worksheet as csv.
for ($i = 1; $i -le $workSheetCount; $i++) {
  $worksheet = $workBook.WorkSheets($i)

  $filename = $scratchRoot + "temp\" + "intermediary_bindingParameter-" + $worksheet.Name

  $worksheet.SaveAs($filename,23)
}

$objExcel.Quit()
while( [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel)){}
