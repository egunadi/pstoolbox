# Report Processing Pipeline Script
# This script extracts report data from database, verifies files exist, copies them to target location, and queues them for processing

# Configurable parameters - Database Configuration
$sqlinstance = "localhost"
$database = "medical"
# Set to customer Name when installing the script
$customer = "{Customer Name}"
# Set to Customer Care Setting when installing the script
$caresetting = "{Customer Care Setting}"

# Configurable parameters - File Path Configuration
$source_path = "D:\SourceReports"
$target_path = "D:\TargetReports"
$export_path = "D:\ReportExports"

# Configurable parameters - Stored Procedure Names
$extract_proc = "dbo.get_processed_reports"
$queue_proc = "dbo.queue_reports"

# Input Validation and Path Verification
Write-Output "Starting input validation and path verification..."

# Validate required configuration parameters
Write-Output "Validating configuration parameters..."

# Database connection parameter validation
if ([string]::IsNullOrWhiteSpace($sqlinstance)) {
    Write-Error "SQL instance parameter is required but not provided"
    [System.Environment]::Exit(1)
}

if ([string]::IsNullOrWhiteSpace($database)) {
    Write-Error "Database parameter is required but not provided"
    [System.Environment]::Exit(1)
}

if ([string]::IsNullOrWhiteSpace($customer) -or $customer -eq "{Customer Name}") {
    Write-Error "Customer parameter is required but not configured. Please set a valid customer name."
    [System.Environment]::Exit(1)
}

if ([string]::IsNullOrWhiteSpace($caresetting) -or $caresetting -eq "{Customer Care Setting}") {
    Write-Error "Care setting parameter is required but not configured. Please set a valid care setting."
    [System.Environment]::Exit(1)
}

# Stored procedure name validation
if ([string]::IsNullOrWhiteSpace($extract_proc)) {
    Write-Error "Extract stored procedure name is required but not provided"
    [System.Environment]::Exit(1)
}

if ([string]::IsNullOrWhiteSpace($queue_proc)) {
    Write-Error "Queue stored procedure name is required but not provided"
    [System.Environment]::Exit(1)
}

Write-Output "✓ Configuration parameters validated successfully"

# File path validation and setup
Write-Output "Validating and setting up file paths..."

# Validate that source path exists before processing
if ([string]::IsNullOrWhiteSpace($source_path)) {
    Write-Error "Source path parameter is required but not provided"
    [System.Environment]::Exit(1)
}

if (-not (Test-Path -Path $source_path -PathType Container)) {
    Write-Error "Source path does not exist: $source_path. Please ensure the source directory exists before running the script."
    [System.Environment]::Exit(1)
}

Write-Output "✓ Source path validated: $source_path"

# Validate target path parameter and create if it doesn't exist
if ([string]::IsNullOrWhiteSpace($target_path)) {
    Write-Error "Target path parameter is required but not provided"
    [System.Environment]::Exit(1)
}

try {
    if (-not (Test-Path -Path $target_path -PathType Container)) {
        Write-Output "Target path does not exist, creating: $target_path"
        New-Item -ItemType Directory -Path $target_path -Force | Out-Null
        Write-Output "✓ Target path created successfully: $target_path"
    } else {
        Write-Output "✓ Target path validated: $target_path"
    }
}
catch {
    Write-Error "Failed to create target path '$target_path': $($_.Exception.Message)"
    [System.Environment]::Exit(1)
}

# Validate export path parameter and create if it doesn't exist
if ([string]::IsNullOrWhiteSpace($export_path)) {
    Write-Error "Export path parameter is required but not provided"
    [System.Environment]::Exit(1)
}

try {
    if (-not (Test-Path -Path $export_path -PathType Container)) {
        Write-Output "Export path does not exist, creating: $export_path"
        New-Item -ItemType Directory -Path $export_path -Force | Out-Null
        Write-Output "✓ Export path created successfully: $export_path"
    } else {
        Write-Output "✓ Export path validated: $export_path"
    }
}
catch {
    Write-Error "Failed to create export path '$export_path': $($_.Exception.Message)"
    [System.Environment]::Exit(1)
}

Write-Output "✓ All input validation and path verification completed successfully"
Write-Output ""

# File System Utility Functions

# Function to check if source file exists using Test-Path with enhanced error handling
function Test-SourceFileExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        # Handle network path issues with retry logic
        $retryCount = 0
        $maxRetries = 3
        $retryDelay = 2
        
        do {
            try {
                return Test-Path -Path $FilePath -PathType Leaf
            }
            catch [System.UnauthorizedAccessException] {
                Write-Warning "Access denied checking file: $FilePath (Attempt $($retryCount + 1)/$maxRetries)"
                if ($retryCount -eq $maxRetries - 1) { throw }
            }
            catch [System.IO.IOException] {
                Write-Warning "I/O error checking file: $FilePath (Attempt $($retryCount + 1)/$maxRetries)"
                if ($retryCount -eq $maxRetries - 1) { throw }
            }
            catch [System.Net.NetworkInformation.NetworkInformationException] {
                Write-Warning "Network error checking file: $FilePath (Attempt $($retryCount + 1)/$maxRetries)"
                if ($retryCount -eq $maxRetries - 1) { throw }
            }
            
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Output "Retrying file existence check in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        } while ($retryCount -lt $maxRetries)
    }
    catch {
        Write-Warning "Failed to check file existence for '$FilePath': $($_.Exception.Message)"
        return $false
    }
}

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
    
    try {
        # Handle network path issues with retry logic
        $retryCount = 0
        $maxRetries = 3
        $retryDelay = 2
        
        do {
            try {
                return Test-Path -Path $FilePath -PathType Leaf
            }
            catch [System.UnauthorizedAccessException] {
                Write-Warning "Access denied checking target file: $FilePath (Attempt $($retryCount + 1)/$maxRetries)"
                if ($retryCount -eq $maxRetries - 1) { throw }
            }
            catch [System.IO.IOException] {
                Write-Warning "I/O error checking target file: $FilePath (Attempt $($retryCount + 1)/$maxRetries)"
                if ($retryCount -eq $maxRetries - 1) { throw }
            }
            catch [System.Net.NetworkInformation.NetworkInformationException] {
                Write-Warning "Network error checking target file: $FilePath (Attempt $($retryCount + 1)/$maxRetries)"
                if ($retryCount -eq $maxRetries - 1) { throw }
            }
            
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Output "Retrying target file existence check in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        } while ($retryCount -lt $maxRetries)
    }
    catch {
        Write-Warning "Failed to check target file existence for '$FilePath': $($_.Exception.Message)"
        return $false
    }
}

# Function to create directory using New-Item with -Force parameter
function New-DirectoryIfNotExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath
    )
    
    try {
        if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
            New-Item -ItemType Directory -Path $DirectoryPath -Force | Out-Null
            Write-Output "Created directory: $DirectoryPath"
            $script:directories_created++
            return $true
        }
        return $true
    }
    catch {
        Write-Warning "Failed to create directory '$DirectoryPath': $($_.Exception.Message)"
        $script:directory_creation_failed++
        $script:general_errors += "Directory creation failed: $DirectoryPath - $($_.Exception.Message)"
        return $false
    }
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
    
    $maxRetries = 3
    $retryDelay = 5
    $retryCount = 0
    
    do {
        try {
            # Check if file is locked before attempting copy
            $fileStream = $null
            try {
                $fileStream = [System.IO.File]::Open($SourcePath, 'Open', 'Read', 'None')
                $fileStream.Close()
            }
            catch [System.IO.IOException] {
                if ($_.Exception.Message -like "*being used by another process*") {
                    throw [System.IO.IOException]::new("File is locked by another process: $SourcePath")
                }
                throw
            }
            finally {
                if ($fileStream) { $fileStream.Dispose() }
            }
            
            # Attempt the file copy
            Copy-Item -Path $SourcePath -Destination $TargetPath -Force -ErrorAction Stop
            Write-Output "  ✓ Successfully copied: $(Split-Path -Leaf $SourcePath)"
            return $true
        }
        catch [System.UnauthorizedAccessException] {
            $errorType = "Permission Denied"
            $errorMsg = "Access denied copying file - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath"
            Write-Warning "  ✗ $errorType (Attempt $($retryCount + 1)/$maxRetries): $errorMsg"
            
            if ($retryCount -eq $maxRetries - 1) {
                $script:copy_errors += "$errorType - $errorMsg"
                return $false
            }
        }
        catch [System.IO.DirectoryNotFoundException] {
            $errorType = "Directory Not Found"
            $errorMsg = "Directory not found copying file - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath"
            Write-Warning "  ✗ $errorType: $errorMsg"
            $script:copy_errors += "$errorType - $errorMsg"
            return $false
        }
        catch [System.IO.FileNotFoundException] {
            $errorType = "File Not Found"
            $errorMsg = "Source file not found - Report ID: $ReportId, Source: $SourcePath"
            Write-Warning "  ✗ $errorType: $errorMsg"
            $script:copy_errors += "$errorType - $errorMsg"
            return $false
        }
        catch [System.IO.IOException] {
            $errorType = "I/O Error"
            if ($_.Exception.Message -like "*being used by another process*") {
                $errorType = "File Locked"
                $errorMsg = "File is locked by another process - Report ID: $ReportId, Source: $SourcePath"
            }
            elseif ($_.Exception.Message -like "*network*" -or $_.Exception.Message -like "*UNC*") {
                $errorType = "Network Error"
                $errorMsg = "Network path issue copying file - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath, Error: $($_.Exception.Message)"
            }
            else {
                $errorMsg = "I/O error copying file - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath, Error: $($_.Exception.Message)"
            }
            
            Write-Warning "  ✗ $errorType (Attempt $($retryCount + 1)/$maxRetries): $errorMsg"
            
            if ($retryCount -eq $maxRetries - 1) {
                $script:copy_errors += "$errorType - $errorMsg"
                return $false
            }
        }
        catch [System.Net.NetworkInformation.NetworkInformationException] {
            $errorType = "Network Connection Error"
            $errorMsg = "Network connection error copying file - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath, Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $errorType (Attempt $($retryCount + 1)/$maxRetries): $errorMsg"
            
            if ($retryCount -eq $maxRetries - 1) {
                $script:copy_errors += "$errorType - $errorMsg"
                return $false
            }
        }
        catch [System.ArgumentException] {
            $errorType = "Invalid Path"
            $errorMsg = "Invalid file path - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath, Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $errorType: $errorMsg"
            $script:copy_errors += "$errorType - $errorMsg"
            return $false
        }
        catch {
            $errorType = "Unexpected Error"
            $errorMsg = "Unexpected error copying file - Report ID: $ReportId, Source: $SourcePath, Target: $TargetPath, Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $errorType (Attempt $($retryCount + 1)/$maxRetries): $errorMsg"
            
            if ($retryCount -eq $maxRetries - 1) {
                $script:copy_errors += "$errorType - $errorMsg"
                return $false
            }
        }
        
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Output "  → Retrying copy operation in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
            # Increase delay for subsequent retries
            $retryDelay += 2
        }
    } while ($retryCount -lt $maxRetries)
    
    return $false
}

# Database connection and error handling foundation
try {
    # Database connection setup following exportRwtMetrics.ps1 pattern with TrustServerCertificate
    Write-Output "Connecting to database: $sqlinstance\$database"
    $server = Connect-DbaInstance -SqlInstance $sqlinstance -TrustServerCertificate
    Write-Output "Database connection established successfully"
}
catch {
    $errormsg = $_.Exception.GetBaseException()
    Write-Error "Failed to connect to database: $errormsg"
    [System.Environment]::Exit(1)
}

# Set up PSDefaultParameterValues for consistent error handling and database operations
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['*-Dba*:SqlInstance'] = $server
$PSDefaultParameterValues['*-Dba*:Database'] = $database
$PSDefaultParameterValues['Select-Object:Property'] = "*"
$PSDefaultParameterValues['Select-Object:ExcludeProperty'] = "RowError", "RowState", "Table", "ItemArray", "HasErrors"

# Generate timestamp for file naming
$date_time = Get-Date -Format yyyyMMddHHmm

# Initialize comprehensive counters for tracking all operations
$total_reports = 0
$files_found = 0
$files_verified = 0
$files_copied = 0
$files_skipped = 0
$files_failed = 0
$files_missing = 0
$directories_created = 0
$directory_creation_failed = 0
$reports_queued = 0
$copy_errors = @()
$verification_errors = @()
$general_errors = @()

# Enhanced error categorization counters
$permission_errors = 0
$network_errors = 0
$file_locked_errors = 0
$path_errors = 0
$io_errors = 0
$unexpected_errors = 0

# Initialize timing for performance tracking
$pipeline_start_time = Get-Date

# Main processing with try-catch structure for critical database operations
try {
    Write-Output "Starting report processing pipeline at $(Get-Date)"
    
    # Task 3: Implement report data extraction and CSV export
    Write-Output "Extracting report data from database..."
    
    try {
        # Execute the extract stored procedure with parameterized query support
        $extract_file_path = $export_path + "\processedReports." + $date_time + ".csv"
        Write-Output "Executing stored procedure: $extract_proc"
        Write-Output "Parameters: Customer=$customer, CareSettings=$caresetting"
        
        $report_data = Invoke-DbaQuery -Query "exec $extract_proc @i_customer=@customer, @i_caresetting=@caresetting" `
            -SqlParameters @{ customer=$customer; caresetting=$caresetting } |
            Select-Object
        
        # Export results to CSV with timestamp naming convention
        $report_data | Export-Csv -Path $extract_file_path -NoTypeInformation
        $total_reports = $report_data.Count
        
        Write-Output "Successfully extracted $total_reports reports to: $extract_file_path"
    }
    catch {
        $errormsg = $_.Exception.GetBaseException()
        Write-Error "Failed to execute report extraction stored procedure '$extract_proc': $errormsg"
        [System.Environment]::Exit(1)
    }
    
    # Task 5: Implement file verification and logging with enhanced error handling
    Write-Output "Starting file verification process..."
    Write-Output "Checking existence of $total_reports report files in source location: $source_path"
    
    # Create loop to process each report from the extracted CSV data with continue-on-error logic
    foreach ($report in $report_data) {
        try {
            # Build the full source file path using the utility function
            $source_file_path = Build-FilePath -BasePath $source_path -SubDirectory $report.SubDirectory -FileName $report.FileName
            
            Write-Output "Checking file: Report ID $($report.ReportId) - $($report.FileName) in subdirectory '$($report.SubDirectory)'"
            
            # Add file existence verification for each report in source location with enhanced error handling
            $fileExists = Test-SourceFileExists -FilePath $source_file_path
            
            if ($fileExists) {
                $files_found++
                $files_verified++
                Write-Output "✓ File verified: $source_file_path"
            }
            else {
                $files_missing++
                # Implement logging for missing files using Write-Warning with specific details
                Write-Warning "✗ File not found: Report ID $($report.ReportId), File: $($report.FileName), Expected path: $source_file_path"
                $verification_errors += "Missing file - Report ID: $($report.ReportId), Path: $source_file_path"
            }
        }
        catch [System.ArgumentException] {
            $files_missing++
            $error_msg = "Invalid path format - Report ID: $($report.ReportId), File: $($report.FileName), Path: $source_file_path"
            Write-Warning "✗ $error_msg"
            $verification_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch [System.UnauthorizedAccessException] {
            $files_missing++
            $error_msg = "Access denied - Report ID: $($report.ReportId), File: $($report.FileName), Path: $source_file_path"
            Write-Warning "✗ $error_msg"
            $verification_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch [System.IO.IOException] {
            $files_missing++
            $error_msg = "I/O error verifying file - Report ID: $($report.ReportId), File: $($report.FileName), Path: $source_file_path, Error: $($_.Exception.Message)"
            Write-Warning "✗ $error_msg"
            $verification_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch [System.Net.NetworkInformation.NetworkInformationException] {
            $files_missing++
            $error_msg = "Network error verifying file - Report ID: $($report.ReportId), File: $($report.FileName), Path: $source_file_path, Error: $($_.Exception.Message)"
            Write-Warning "✗ $error_msg"
            $verification_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch {
            $files_missing++
            $error_msg = "Unexpected error verifying file - Report ID: $($report.ReportId), File: $($report.FileName), Path: $source_file_path, Error: $($_.Exception.Message)"
            Write-Warning "✗ $error_msg"
            $verification_errors += $error_msg
            # Continue processing remaining files even on unexpected errors
            continue
        }
    }
    
    Write-Output "File verification completed:"
    Write-Output "  - Files found and verified: $files_verified"
    Write-Output "  - Files missing or failed verification: $files_missing"
    Write-Output "  - Total verification errors: $($verification_errors.Count)"
    
    # Task 6: Implement file copying with efficiency checks and enhanced error handling
    Write-Output "Starting file copying process..."
    Write-Output "Target location: $target_path"
    
    # Process each report for copying operations with continue-on-error logic
    foreach ($report in $report_data) {
        try {
            # Build the full source and target file paths
            $source_file_path = Build-FilePath -BasePath $source_path -SubDirectory $report.SubDirectory -FileName $report.FileName
            $target_file_path = Build-FilePath -BasePath $target_path -SubDirectory $report.SubDirectory -FileName $report.FileName
            
            Write-Output "Processing copy operation: Report ID $($report.ReportId) - $($report.FileName)"
            
            # Only proceed if source file exists (from verification step)
            $sourceExists = Test-SourceFileExists -FilePath $source_file_path
            
            if ($sourceExists) {
                
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
            }
            else {
                # File doesn't exist in source, already logged in verification step
                $files_failed++
                Write-Output "  ✗ Skipped copy - source file not found (logged in verification phase)"
            }
        }
        catch [System.ArgumentException] {
            $files_failed++
            $error_msg = "Invalid path in copy operation - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $copy_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch [System.UnauthorizedAccessException] {
            $files_failed++
            $error_msg = "Access denied in copy operation - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $copy_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch [System.IO.IOException] {
            $files_failed++
            $error_msg = "I/O error in copy operation - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $copy_errors += $error_msg
            # Continue processing remaining files
            continue
        }
        catch [System.Net.NetworkInformation.NetworkInformationException] {
            $files_failed++
            $error_msg = "Network error in copy operation - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $copy_errors += $error_msg
            # Continue processing remaining files
            continue
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
    
    Write-Output "File copying phase completed:"
    Write-Output "  - Files successfully copied: $files_copied"
    Write-Output "  - Files skipped (already exist): $files_skipped"
    Write-Output "  - Files failed to copy: $files_failed"
    Write-Output "  - Copy operation errors: $($copy_errors.Count)"
    
    # Task 7: Implement report queuing functionality
    Write-Output "Starting report queuing process..."
    
    # Create list of successfully processed reports for queuing with enhanced error handling
    $successfully_processed_reports = @()
    
    Write-Output "Identifying successfully processed reports for queuing..."
    foreach ($report in $report_data) {
        try {
            # Build the target file path to check if report was successfully processed
            $target_file_path = Build-FilePath -BasePath $target_path -SubDirectory $report.SubDirectory -FileName $report.FileName
            
            # Add to queuing list if file exists in target location (either copied or already existed)
            $targetExists = Test-TargetFileExists -FilePath $target_file_path
            
            if ($targetExists) {
                $successfully_processed_reports += $report
                Write-Output "  ✓ Report ready for queuing: ID $($report.ReportId) - $($report.FileName)"
            }
            else {
                Write-Output "  ✗ Report not available for queuing: ID $($report.ReportId) - $($report.FileName) (file not in target location)"
            }
        }
        catch [System.ArgumentException] {
            $error_msg = "Invalid path checking report for queuing - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $general_errors += $error_msg
            # Continue processing remaining reports
            continue
        }
        catch [System.UnauthorizedAccessException] {
            $error_msg = "Access denied checking report for queuing - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $general_errors += $error_msg
            # Continue processing remaining reports
            continue
        }
        catch [System.IO.IOException] {
            $error_msg = "I/O error checking report for queuing - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $general_errors += $error_msg
            # Continue processing remaining reports
            continue
        }
        catch [System.Net.NetworkInformation.NetworkInformationException] {
            $error_msg = "Network error checking report for queuing - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $general_errors += $error_msg
            # Continue processing remaining reports
            continue
        }
        catch {
            $error_msg = "Unexpected error checking report for queuing - Report ID: $($report.ReportId), File: $($report.FileName), Error: $($_.Exception.Message)"
            Write-Warning "  ✗ $error_msg"
            $general_errors += $error_msg
            # Continue processing remaining reports even on unexpected errors
            continue
        }
    }
    
    Write-Output "Queue preparation completed:"
    Write-Output "  - Reports ready for queuing: $($successfully_processed_reports.Count)"
    Write-Output "  - Reports not available for queuing: $($total_reports - $successfully_processed_reports.Count)"
    
    # Implement second stored procedure execution for report queuing
    if ($successfully_processed_reports.Count -gt 0) {
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
            # Include error handling for queuing failures with appropriate exit codes
            $errormsg = $_.Exception.GetBaseException()
            $error_msg = "Queuing failed - Stored procedure: $queue_proc, Customer: $customer, CareSettings: $caresetting, Error: $errormsg"
            Write-Error $error_msg
            $general_errors += $error_msg
            Write-Output "✗ Reports were copied but could not be queued - this may cause data inconsistency"
            [System.Environment]::Exit(1)
        }
    }
    else {
        Write-Output "⚠ No reports to queue - all file operations failed or no reports were processed"
    }
    
    $pipeline_end_time = Get-Date
    $pipeline_duration = $pipeline_end_time - $pipeline_start_time
    Write-Output "Report processing pipeline completed successfully at $pipeline_end_time"
    Write-Output "Total pipeline execution time: $($pipeline_duration.ToString('hh\:mm\:ss'))"
}
catch {
    $pipeline_end_time = Get-Date
    $pipeline_duration = $pipeline_end_time - $pipeline_start_time
    $errormsg = $_.Exception.GetBaseException()
    
    $critical_error = "Critical pipeline failure - Error: $errormsg, Time: $($pipeline_end_time.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Error $critical_error
    $general_errors += $critical_error
    
    Write-Output ""
    Write-Output "=================================================================="
    Write-Output "                    PIPELINE FAILURE SUMMARY"
    Write-Output "=================================================================="
    Write-Output "Pipeline failed at: $($pipeline_end_time.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output "Execution duration before failure: $($pipeline_duration.ToString('hh\:mm\:ss'))"
    Write-Output "Critical error: $errormsg"
    Write-Output "=================================================================="
    
    [System.Environment]::Exit(1)
}

# Comprehensive final summary reporting
Write-Output ""
Write-Output "=================================================================="
Write-Output "                    PIPELINE EXECUTION SUMMARY"
Write-Output "=================================================================="
Write-Output ""

# Execution timing information
Write-Output "Execution Details:"
Write-Output "  Start Time: $($pipeline_start_time.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output "  End Time: $($pipeline_end_time.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output "  Duration: $($pipeline_duration.ToString('hh\:mm\:ss'))"
Write-Output ""

# Database and configuration summary
Write-Output "Configuration:"
Write-Output "  SQL Instance: $sqlinstance"
Write-Output "  Database: $database"
Write-Output "  Customer: $customer"
Write-Output "  Care Setting: $caresetting"
Write-Output "  Source Path: $source_path"
Write-Output "  Target Path: $target_path"
Write-Output "  Export Path: $export_path"
Write-Output ""

# Overall processing statistics
Write-Output "Processing Statistics:"
Write-Output "  Total Reports Extracted: $total_reports"
Write-Output "  Files Found in Source: $files_found"
Write-Output "  Files Missing from Source: $files_missing"
Write-Output "  Files Successfully Copied: $files_copied"
Write-Output "  Files Skipped (Already Exist): $files_skipped"
Write-Output "  Files Failed to Copy: $files_failed"
Write-Output "  Reports Successfully Queued: $reports_queued"
Write-Output ""

# Infrastructure operations
Write-Output "Infrastructure Operations:"
Write-Output "  Directories Created: $directories_created"
Write-Output "  Directory Creation Failures: $directory_creation_failed"
Write-Output ""

# Success/failure analysis
$total_successful = $files_copied + $files_skipped
$total_failed = $files_failed + $files_missing
$success_rate = if ($total_reports -gt 0) { [math]::Round(($total_successful / $total_reports) * 100, 2) } else { 0 }

Write-Output "Success Analysis:"
Write-Output "  Total Successful Operations: $total_successful"
Write-Output "  Total Failed Operations: $total_failed"
Write-Output "  Success Rate: $success_rate%"
Write-Output ""

# Error summary with enhanced categorization
$total_errors = $verification_errors.Count + $copy_errors.Count + $general_errors.Count

# Count error types from error messages for better categorization
$permission_errors = ($verification_errors + $copy_errors + $general_errors | Where-Object { $_ -like "*Permission Denied*" -or $_ -like "*Access denied*" }).Count
$network_errors = ($verification_errors + $copy_errors + $general_errors | Where-Object { $_ -like "*Network*" -or $_ -like "*UNC*" }).Count
$file_locked_errors = ($verification_errors + $copy_errors + $general_errors | Where-Object { $_ -like "*File Locked*" -or $_ -like "*being used by another process*" }).Count
$path_errors = ($verification_errors + $copy_errors + $general_errors | Where-Object { $_ -like "*Invalid Path*" -or $_ -like "*Directory Not Found*" -or $_ -like "*File Not Found*" }).Count
$io_errors = ($verification_errors + $copy_errors + $general_errors | Where-Object { $_ -like "*I/O Error*" }).Count
$unexpected_errors = ($verification_errors + $copy_errors + $general_errors | Where-Object { $_ -like "*Unexpected Error*" }).Count

Write-Output "Error Summary:"
Write-Output "  Total Errors Encountered: $total_errors"
Write-Output "  Verification Errors: $($verification_errors.Count)"
Write-Output "  Copy Operation Errors: $($copy_errors.Count)"
Write-Output "  General/System Errors: $($general_errors.Count)"
Write-Output ""
Write-Output "Error Type Breakdown:"
Write-Output "  Permission/Access Denied: $permission_errors"
Write-Output "  Network/UNC Path Issues: $network_errors"
Write-Output "  File Locked/In Use: $file_locked_errors"
Write-Output "  Path/File Not Found: $path_errors"
Write-Output "  I/O Errors: $io_errors"
Write-Output "  Unexpected Errors: $unexpected_errors"

# Detailed error reporting if errors occurred
if ($total_errors -gt 0) {
    Write-Output ""
    Write-Output "Detailed Error Report:"
    Write-Output "====================="
    
    if ($verification_errors.Count -gt 0) {
        Write-Output ""
        Write-Output "File Verification Errors ($($verification_errors.Count)):"
        for ($i = 0; $i -lt $verification_errors.Count; $i++) {
            Write-Output "  $($i + 1). $($verification_errors[$i])"
        }
    }
    
    if ($copy_errors.Count -gt 0) {
        Write-Output ""
        Write-Output "File Copy Errors ($($copy_errors.Count)):"
        for ($i = 0; $i -lt $copy_errors.Count; $i++) {
            Write-Output "  $($i + 1). $($copy_errors[$i])"
        }
    }
    
    if ($general_errors.Count -gt 0) {
        Write-Output ""
        Write-Output "General/System Errors ($($general_errors.Count)):"
        for ($i = 0; $i -lt $general_errors.Count; $i++) {
            Write-Output "  $($i + 1). $($general_errors[$i])"
        }
    }
    
    # Add recovery recommendations based on error types
    if ($total_errors -gt 0) {
        Write-Output ""
        Write-Output "Recovery Recommendations:"
        Write-Output "========================"
        
        if ($permission_errors -gt 0) {
            Write-Output "• Permission Errors ($permission_errors): Check file/folder permissions and run with appropriate privileges"
        }
        
        if ($network_errors -gt 0) {
            Write-Output "• Network Errors ($network_errors): Verify network connectivity and UNC path accessibility"
        }
        
        if ($file_locked_errors -gt 0) {
            Write-Output "• File Locked Errors ($file_locked_errors): Close applications using the files or wait for processes to complete"
        }
        
        if ($path_errors -gt 0) {
            Write-Output "• Path Errors ($path_errors): Verify source and target paths exist and are accessible"
        }
        
        if ($io_errors -gt 0) {
            Write-Output "• I/O Errors ($io_errors): Check disk space, file system integrity, and hardware connectivity"
        }
        
        if ($unexpected_errors -gt 0) {
            Write-Output "• Unexpected Errors ($unexpected_errors): Review detailed error log above for specific issues"
        }
        
        Write-Output ""
        Write-Output "Note: The script uses retry logic for transient errors (network, I/O, file locking)"
        Write-Output "      and continues processing remaining files when individual operations fail."
    }
}

Write-Output ""
Write-Output "=================================================================="

# Final status determination
if ($total_errors -eq 0 -and $reports_queued -eq $total_reports) {
    Write-Output "PIPELINE STATUS: ✓ COMPLETED SUCCESSFULLY - All reports processed without errors"
    $exit_code = 0
}
elseif ($reports_queued -gt 0) {
    Write-Output "PIPELINE STATUS: ⚠ COMPLETED WITH WARNINGS - Some reports processed successfully, some failed"
    $exit_code = 0
}
else {
    Write-Output "PIPELINE STATUS: ✗ FAILED - No reports were successfully processed and queued"
    $exit_code = 1
}

Write-Output "=================================================================="

# Exit with appropriate code based on pipeline results
[System.Environment]::Exit($exit_code)