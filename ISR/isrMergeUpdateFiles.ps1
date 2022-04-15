# path of git repository
$gitRepositoryPath = "/Users/egunadi/GitHub/mi-isr"

# path of install file
$installFile = $gitRepositoryPath + "/isr-reportingYear-2021.sql"

# change path to git repository
Set-Location -Path $gitRepositoryPath

#get list of sql files
$tables = Get-ChildItem -Path ($gitRepositoryPath + "/Tables") -Filter "*.sql"
$procs = Get-ChildItem -Path ($gitRepositoryPath + "/Stored Procedures") -Filter "*.sql"
$functions = Get-ChildItem -Path ($gitRepositoryPath + "/Functions") -Filter "*.sql"

foreach ($file in $tables) {
    if ($file.Name -notlike "processed_*.sql") {
        
        $fileContent = Get-Content -Path "$($gitRepositoryPath)/Tables/$($file.Name)"

        #Append 4 new lines to provide sectioning
        $include = "`n`n`n`n-----------------------------------------------------------`n"
        $include = $include + "-- Date: $(Get-Date)`n"
        $include = $include + "-- Script Entry`n"
        $include = $include + "-----------------------------------------------------------`n"

        Add-Content -Path $installFile -value $include
        Add-Content -Path $installFile -value $fileContent 
        
        #rename file.  prefix processed_ so file is not processed again.
        Rename-Item -Path "$($gitRepositoryPath)/Tables/$($file.Name)" -NewName "$($gitRepositoryPath)/Tables/processed_$($file.Name)"
    }
}

foreach ($file in $procs) {
    if ($file.Name -notlike "processed_*.sql") {
        
        $fileContent = Get-Content -Path "$($gitRepositoryPath)/Stored Procedures/$($file.Name)"

        #Append 4 new lines to provide sectioning
        $include = "`n`n`n`n-----------------------------------------------------------`n"
        $include = $include + "-- Date: $(Get-Date)`n"
        $include = $include + "-- Script Entry`n"
        $include = $include + "-----------------------------------------------------------`n"

        Add-Content -Path $installFile -value $include
        Add-Content -Path $installFile -value $fileContent 
        
        #rename file.  prefix processed_ so file is not processed again.
        Rename-Item -Path "$($gitRepositoryPath)/Stored Procedures/$($file.Name)" -NewName "$($gitRepositoryPath)/Stored Procedures/processed_$($file.Name)"
    }
}

foreach ($file in $functions) {
    if ($file.Name -notlike "processed_*.sql") {
        
        $fileContent = Get-Content -Path "$($gitRepositoryPath)/Functions/$($file.Name)"

        #Append 4 new lines to provide sectioning
        $include = "`n`n`n`n-----------------------------------------------------------`n"
        $include = $include + "-- Date: $(Get-Date)`n"
        $include = $include + "-- Script Entry`n"
        $include = $include + "-----------------------------------------------------------`n"

        Add-Content -Path $installFile -value $include
        Add-Content -Path $installFile -value $fileContent 
        
        #rename file.  prefix processed_ so file is not processed again.
        Rename-Item -Path "$($gitRepositoryPath)/Functions/$($file.Name)" -NewName "$($gitRepositoryPath)/Functions/processed_$($file.Name)"
    }
}
