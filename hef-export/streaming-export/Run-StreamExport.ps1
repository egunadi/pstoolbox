# Configurable parameters
$parent_path = "D:\MedinformatixHefExports"
$sqlinstance = "localhost"
$database = "medical"
$company = "MAIN"

$exportcmdlet = $parent_path + "\Export-StreamCsv.ps1"

# Wait until April to start exporting current year's data
if ((Get-Date).Month -lt 4)   
{
    $startyear = (Get-Date).Year-1
}
else
{
    $startyear = (Get-Date).Year
}
$datefrom = (Get-Date -Day 1 -Month 1 -Year $startyear).ToString("yyyyMMdd")
$dateto = (Get-Date -Day 31 -Month 12 -Year $startyear).ToString("yyyyMMdd")

# Ensure "Box Sync" and "Archive" directories exist
$date_time = Get-Date -Format yyyyMMddHHmm
$export_path = $parent_path + "\Box Sync"
$archive_path = $parent_path + "\Archive"
New-Item -Path $export_path -ItemType "directory" -Force
New-Item -Path $archive_path -ItemType "directory" -Force

# Archive last export
$new_archive = $archive_path + "\" + $date_time
New-Item -Path $new_archive -ItemType "directory" 
$last_export = $export_path + "\*.csv"
Move-Item -Path $last_export -Destination $new_archive

# Purge previous year's exports every April
if ((Get-Date).Month -eq 4)   
{
  $archive_path_files = $archive_path + "\*"
  Remove-Item -Path $archive_path_files -Recurse -Force
}

# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['Find-DbaStoredProcedure:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['Find-DbaStoredProcedure:Database'] = $database

# Run stored procs and output results as CSVs
$billent_path = $export_path + "\billingEntities." + $date_time + ".csv"
$billent_query = "exec dbo.hef_getbillingentities @i_company='" + $company + "'"
& $exportcmdlet -query $billent_query -exportpath $billent_path

$providers_path = $export_path + "\providers." + $date_time + ".csv"
$providers_query = "exec dbo.hef_getproviders @i_company='" + $company + "'"
& $exportcmdlet -query $providers_query -exportpath $providers_path

$patients_path = $export_path + "\patients." + $date_time + ".csv"
$patients_query = "exec dbo.hef_getpatients @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $patients_query -exportpath $patients_path
  
$encounters_path = $export_path + "\encounters." + $date_time + ".csv"
$encounters_query = "exec dbo.hef_getencounters @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $encounters_query -exportpath $encounters_path
  
$problems_path = $export_path + "\problems." + $date_time + ".csv"
$problems_query = "exec dbo.hef_getproblems @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $problems_query -exportpath $problems_path
  
$vitals_path = $export_path + "\vitals." + $date_time + ".csv"
$vitals_query = "exec dbo.hef_getvitals @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $vitals_query -exportpath $vitals_path
  
$allergies_path = $export_path + "\allergies." + $date_time + ".csv"
$allergies_query = "exec dbo.hef_getallergies @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $allergies_query -exportpath $allergies_path
  
$medications_path = $export_path + "\medications." + $date_time + ".csv"
$medications_query = "exec dbo.hef_getmedications @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $medications_query -exportpath $medications_path
  
$labs_path = $export_path + "\labs." + $date_time + ".csv"
$labs_query = "exec dbo.hef_getlabs @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $labs_query -exportpath $labs_path
  
$devices_path = $export_path + "\devices." + $date_time + ".csv"
$devices_query = "exec dbo.hef_getdevices @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $devices_query -exportpath $devices_path
  
$immunizations_path = $export_path + "\immunizations." + $date_time + ".csv"
$immunizations_query = "exec dbo.hef_getimmunizations @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $immunizations_query -exportpath $immunizations_path
  
$orders_path = $export_path + "\orders." + $date_time + ".csv"
$orders_query = "exec dbo.hef_getorders @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $orders_query -exportpath $orders_path

$physicalexam_visualacuity_path = $export_path + "\physicalexam_visualacuity." + $date_time + ".csv"
$physicalexam_visualacuity_query = "exec dbo.hef_getphysicalexam_visualacuity @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $physicalexam_visualacuity_query -exportpath $physicalexam_visualacuity_path

$procedures = Find-DbaStoredProcedure -Pattern hef_getdiagnosticstudy_measure143
if ($procedures.Name -contains 'hef_getdiagnosticstudy_measure143')
{
  $diagnosticstudy_measure143_path = $export_path + "\diagnosticstudy_measure143." + $date_time + ".csv"
  $diagnosticstudy_measure143_query = "exec dbo.hef_getdiagnosticstudy_measure143 @i_company='" + $company + `
    "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
  & $exportcmdlet -query $diagnosticstudy_measure143_query -exportpath $diagnosticstudy_measure143_path
}
  
$assessments_tobacco_path = $export_path + "\assessments_tobacco." + $date_time + ".csv"
$assessments_tobacco_query = "exec dbo.hef_getassessments_tobacco @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $assessments_tobacco_query -exportpath $assessments_tobacco_path

$pi_medicare_path = $export_path + "\pi_medicare." + $date_time + ".csv"
$pi_medicare_query = "exec dbo.midash_ACI_RESULTS_2020_HEF @dateStart='" + $datefrom + `
  "', @dateStop='" + $dateto + "'"
& $exportcmdlet -query $pi_medicare_query -exportpath $pi_medicare_path

$procedures = Find-DbaStoredProcedure -Pattern hef_getphysicalexam_eyeexam
if ($procedures.Name -contains 'hef_getphysicalexam_eyeexam')
{
  $physicalexam_eyeexam_path = $export_path + "\physicalexam_eyeexam." + $date_time + ".csv"
  $physicalexam_eyeexam_query = "exec dbo.hef_getphysicalexam_eyeexam @i_company='" + $company + `
    "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
  & $exportcmdlet -query $physicalexam_eyeexam_query -exportpath $physicalexam_eyeexam_path
}
