$logdate = Get-Date -Format "yyyy-MM-dd HH:mm:00"
$path = "/Users/egunadi/Git/mi-core-sql-v77/_changelog.xml"

#Append template
$include =            "   <logentry>`r`n"
$include = $include + "      <scripts>`r`n"
$include = $include + "         <script>mscreate.sql</script>`r`n"
$include = $include + "         <script>pv77.sql</script>`r`n"
$include = $include + "      </scripts>`r`n"
$include = $include + "      <logdate>" + $logdate + "</logdate>`r`n"
$include = $include + "      <logkey>[]</logkey>`r`n"
$include = $include + "      <description></description>`r`n"
$include = $include + "   </logentry>"

$filecontent = Get-Content -Path $path
$filecontent[3] += "`n" + $include
Add-Content -Path $path -Value $template
Set-Content -Path $path -Value $filecontent



<# initial attempt to use a separate template file

$logdate = Get-Date -Format "yyyy-MM-dd HH:mm:00"
# Write-Host $logdate
$template = Get-Content -Path /Users/egunadi/Documents/tmp2.xml
# select-string -Path /Users/egunadi/Documents/tmp2.xml -Pattern '\d\d\d\d-\d\d\-\d\d\s\d\d:\d\d:\d\d'
# Write-Host $template[5]
$template[5] = $template[5] -replace "\d\d\d\d-\d\d\-\d\d\s\d\d:\d\d:\d\d", $logdate
Set-Content -Path /Users/egunadi/Documents/tmp2.xml -Value $template

#>
