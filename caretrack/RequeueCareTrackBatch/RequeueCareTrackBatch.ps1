# RequeueCareTrackBatch.ps1

# --- Config: DB ---
$sqlinstance = 'localhost'
$database    = 'medical'
$company     = 'MAIN'

# Batch window (yyyymmdd)
$startdate = (Get-Date -Year 2025 -Month 7 -Day 1 ).ToString('yyyyMMdd')
$enddate   = (Get-Date -Year 2025 -Month 7 -Day 31).ToString('yyyyMMdd')

# --- Config: Paths ---
$source_path = '\\10.0.0.216\records\MAIN\NATIVE'
$target_path = 'C:\MEDINFO\RECORDS\MAIN\NATIVE'
$export_path = 'C:\MIINTERFACE\CareTrack\Auxilliaries'

# --- Connect ---
$server = Connect-DbaInstance -SqlInstance $sqlinstance -TrustServerCertificate

# --- Config: dbatools ---
# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['*-Dba*:SqlInstance'] = $server
$PSDefaultParameterValues['*-Dba*:Database'] = $database
$PSDefaultParameterValues['Select-Object:Property'] = "*"
$PSDefaultParameterValues['Select-Object:ExcludeProperty'] = "RowError", "RowState", "Table", "ItemArray", "HasErrors"

# --- Helpers ---
function Build-Path {
  param(
    [string]$Base,
    [string]$Sub,
    [string]$Name
  )
  # Normalize nulls and trim slashes
  $s = ([string]$Sub) -replace '^[\\/]+|[\\/]+$',''
  $baseWithSub = $( if ($s) { Join-Path -Path $Base -ChildPath $s } else { $Base } )
  if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
  Join-Path -Path $baseWithSub -ChildPath $Name
}

# --- Extract to CSV ---
$date = Get-Date -Format 'yyyyMMddHHmm'
$csv = Join-Path $export_path "processedReports.$date.csv"

try {
  $report_data = Invoke-DbaQuery -SqlInstance $server -Database $database `
    -Query "exec dbo.ctk_get_processed_reports @i_company=@company, @i_startdate=@startdate, @i_enddate=@enddate" `
    -SqlParameters @{ company=$company; startdate=$startdate; enddate=$enddate }
}
catch {
    $errormsg = $_.Exception.GetBaseException()
    Write-Output "There was an error - $errormsg"
    [System.Environment]::Exit(1)
}

if (-not $report_data) { Write-Output 'No rows returned; nothing to do.'; return }

$report_data | Export-Csv -Path $csv -NoTypeInformation
Write-Output "Exported: $csv"

# --- Copy if missing ---
foreach ($r in $report_data) {
  # Defensive: guard against null/blank columns
  $subdir = [string]$r.SubDirectory
  $fname  = [string]$r.FileName
  if ([string]::IsNullOrWhiteSpace($fname)) { continue }

  $src = Build-Path -Base $source_path -Sub $subdir -Name $fname
  $dst = Build-Path -Base $target_path -Sub $subdir -Name $fname
  if (-not $src -or -not $dst) { continue }

  if (Test-Path -LiteralPath $dst -PathType Leaf) { continue }
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }

    # Ensure destination directory exists (avoid Split-Path ambiguity)
    $dstDir = [System.IO.Path]::GetDirectoryName([string]$dst)
    if (-not [string]::IsNullOrWhiteSpace($dstDir) -and
        -not (Test-Path -LiteralPath $dstDir -PathType Container)) {
      New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

  Copy-Item -LiteralPath $src -Destination $dst -Force
}

# --- Queue (relies on company/date-range in the proc) ---
try {
  Invoke-DbaQuery -SqlInstance $server -Database $database `
    -Query "exec dbo.ctk_requeue_reports @i_company=@company, @i_startdate=@startdate, @i_enddate=@enddate" `
    -SqlParameters @{ company=$company; startdate=$startdate; enddate=$enddate }
}
catch {
  $errormsg = $_.Exception.GetBaseException()
  Write-Output "There was an error - $errormsg"
  [System.Environment]::Exit(1)
}

Write-Output 'Done.'
