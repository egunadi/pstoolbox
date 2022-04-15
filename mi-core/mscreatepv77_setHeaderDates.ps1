$today = Get-Date -Format MM.dd.yyyy
Get-ChildItem -Path /Users/egunadi/Git/mi-core-sql-v77/* -Include mscreate.sql, pv77.sql | `
ForEach-Object {
    $filecontent = Get-Content -Path $_
    $filecontent[1] = $filecontent[1] -replace "\d\d\.\d\d\.\d\d\d\d", $today
    Set-Content $_.PSpath -Value $filecontent
}


<# initial attempt to update only 1 file

$today = Get-Date -Format MM.dd.yyyy
$filecontent = Get-Content -Path /Users/egunadi/Documents/tmp.sql
$filecontent[1] = $filecontent[1] -replace "\d\d\.\d\d\.\d\d\d\d", $today
Set-Content -Path /Users/egunadi/Documents/tmp.sql -Value $filecontent


Write-Host (Get-ChildItem -Path /Users/egunadi/Git/mi-core-sql-v77/* -Include mscreate.sql, pv77.sql)

#>
