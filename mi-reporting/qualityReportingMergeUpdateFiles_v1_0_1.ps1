# /Users/egunadi/Documents/Reporting/sql_logic
# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-object?view=powershell-7


# path of git repository
$gitRepositoryPath = "C:\Users\tcollins\Documents\Development\source control\BitBucket\mi-reporting-mips\mips"

# path of header file
$headerFile = $gitRepositoryPath + "\2019-QualityMeasure-Header.txt"

# path of measure file
$measureFile = $gitRepositoryPath + "\qualityMeasure-reportingYear-2019.sql"

# change path to git repository
Set-Location -Path $gitRepositoryPath


#get list of sql files
$files = Get-ChildItem -Path ($gitRepositoryPath + "\stored procs") -Filter "*.sql"


foreach ($file in $files) {
    if ($file.Name -notlike "processed_*.sql") {
        
        $fileConent = Get-Content -Path "$($gitRepositoryPath)\stored procs\$($file.Name)"

        #select first line from sql file, remove sql comment delimeter, append line to header file
        Add-Content -Path $headerFile -value (($fileConent | select -First 1).substring(2))

        #Append 4 new lines to provide sectioning
        $include = "`r`n`r`n`r`n`r`n-----------------------------------------------------------`r`n"
        $include = $include + "-- Date: $(Get-Date)`r`n"
        $include = $include + "-- Script Entry`r`n"
        $include = $include + "-----------------------------------------------------------`r`n"


        Add-Content -Path $measureFile -value $include
        Add-Content -Path $measureFile ($fileConent | select -Skip 1)
        
        #rename file.  prefix processed_ so file is not processed again.
        Rename-Item -Path "$($gitRepositoryPath)\stored procs\$($file.Name)" -NewName "$($gitRepositoryPath)\stored procs\processed_$($file.Name)"
    }
}


