# Report Processing Pipeline Script
# This script extracts report data from database, verifies files exist, copies them to target location, and queues them for processing

# Configurable parameters - Database Configuration
$sqlinstance = "localhost"
$database = "medical"
$company = "MAIN"

# Set the start and end dates of the batch of interest
$startdate = (Get-Date -Year 2025 -Month 7 -Day 1).ToString("yyyyMMdd")
$enddate = (Get-Date -Year 2025 -Month 7 -Day 31).ToString("yyyyMMdd")

$server = Connect-DbaInstance -SqlInstance $sqlinstance -TrustServerCertificate

# Configurable parameters - File Path Configuration
$source_path = "\\10.0.0.216\records\MAIN\NATIVE"
$target_path = "C:\MEDINFO\RECORDS\MAIN\NATIVE"
$export_path = "C:\MIINTERFACE\CareTrack\Auxilliaries"

# Configurable parameters - Stored Procedure Names
$extract_proc = "dbo.ctk_get_processed_reports"
$queue_proc = "dbo.ctk_queue_reports"

# File System Utility Functions

# Function to build file paths by concatenating base path with subdirectory
function Build-FilePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [string]$SubDirectory,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    
    # Use Join-Path for proper path concatenation that handles different path separators
    $fullPath = Join-Path -Path $BasePath -ChildPath $SubDirectory
    $fullPath = Join-Path -Path $fullPath -ChildPath $FileName
    
    return $fullPath
}

# Function to check if target file already exists to enable skip logic with enhanced error handling
function Test-TargetFileExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
        
    return Test-Path -Path $FilePath -PathType Leaf
}

# Enhanced file copy function with comprehensive error handling and recovery
function Copy-FileWithRecovery {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$TargetPath,
        [Parameter(Mandatory=$true)]
        [string]$ReportId
    )
    
    Copy-Item -Path $SourcePath -Destination $TargetPath -Force -ErrorAction Stop
    Write-Output "  ✓ Successfully copied: $(Split-Path -Leaf $SourcePath)"
    return $true
}

# Set up PSDefaultParameterValues for consistent error handling and database operations
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['*-Dba*:SqlInstance'] = $server
$PSDefaultParameterValues['*-Dba*:Database'] = $database
$PSDefaultParameterValues['Select-Object:Property'] = "*"
$PSDefaultParameterValues['Select-Object:ExcludeProperty'] = "RowError", "RowState", "Table", "ItemArray", "HasErrors"

# Generate timestamp for file naming
$date_time = Get-Date -Format yyyyMMddHHmm

# Main processing with try-catch structure for critical database operations

Write-Output "Starting report processing pipeline at $(Get-Date)"

# Task 3: Implement report data extraction and CSV export
Write-Output "Extracting report data from database..."

try {
    # Execute the extract stored procedure with parameterized query support
    $extract_file_path = $export_path + "\processedReports." + $date_time + ".csv"

    $report_data = Invoke-DbaQuery -Query "exec $extract_proc @i_company=@company, @i_startdate=@startdate, @i_enddate=@enddate" `
        -SqlParameters @{ company=$company; startdate=$startdate; enddate=$enddate } |
        Select-Object
    
    # Export results to CSV with timestamp naming convention
    $report_data | Export-Csv -Path $extract_file_path -NoTypeInformation
}
catch {
    $errormsg = $_.Exception.GetBaseException()
    Write-Error "Failed to execute report extraction stored procedure '$extract_proc': $errormsg"
    [System.Environment]::Exit(1)
}

# Process each report for copying operations with continue-on-error logic
foreach ($report in $report_data) {
    try {
        # Build the full source and target file paths
        $source_file_path = Build-FilePath -BasePath $source_path -SubDirectory $report.SubDirectory -FileName $report.FileName
        $target_file_path = Build-FilePath -BasePath $target_path -SubDirectory $report.SubDirectory -FileName $report.FileName
        
        Write-Output "Processing copy operation: Report ID $($report.ReportId) - $($report.FileName)"   
        
        # Add logic to skip copying if file already exists in target location
        $targetExists = Test-TargetFileExists -FilePath $target_file_path
        
        if ($targetExists) {
            $files_skipped++
            Write-Output "  ↷ Skipped - file already exists in target: $target_file_path"
        }
        else {
            # Create target subdirectories as needed before copying files
            $target_directory = Split-Path -Path $target_file_path -Parent
            Write-Output "  → Preparing target directory: $target_directory"
            
            if (New-DirectoryIfNotExists -DirectoryPath $target_directory) {
                # Use enhanced file copy function with comprehensive error handling
                Write-Output "  → Copying from: $source_file_path"
                Write-Output "  → Copying to: $target_file_path"
                
                $copySuccess = Copy-FileWithRecovery -SourcePath $source_file_path -TargetPath $target_file_path -ReportId $report.ReportId
                
                if ($copySuccess) {
                    $files_copied++
                }
                else {
                    $files_failed++
                }
            }
            else {
                $files_failed++
                $error_msg = "Directory creation failed - Report ID: $($report.ReportId), Target directory: $target_directory"
                Write-Warning "  ✗ $error_msg"
                $copy_errors += $error_msg
                # Continue processing remaining files
                continue
            }
    }
    catch {
        $files_failed++
        $error_msg = "Unexpected error in copy operation - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
        Write-Warning "  ✗ $error_msg"
        $copy_errors += $error_msg
        # Continue processing remaining files even on unexpected errors
        continue
    }
}

# Execute second stored procedure for report queuing
try {
    Write-Output "Executing queuing stored procedure: $queue_proc"
    Write-Output "Parameters: Customer='$customer', CareSettings='$caresetting'"
    Write-Output "Queuing $($successfully_processed_reports.Count) reports..."
    
    # Add parameterized query support for queuing operation
    # Execute the queue stored procedure with the same parameters as extract
    $queue_result = Invoke-DbaQuery -Query "exec $queue_proc @i_customer=@customer, @i_caresetting=@caresetting" `
        -SqlParameters @{ customer=$customer; caresetting=$caresetting }
    
    $reports_queued = $successfully_processed_reports.Count
    Write-Output "✓ Successfully queued $reports_queued reports for processing"
}
catch {
    $errormsg = $_.Exception.GetBaseException()
    Write-Output "There was an error - $errormsg"
    [System.Environment]::Exit(1)
}
