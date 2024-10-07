# Path to the CSV file
$csvFile = "C:\Temp\SourcesAndDestinations.csv"

# Import the CSV and assign it to the $sourcesAndDestinations variable
$sourcesAndDestinations = Import-Csv -Path $csvFile

# Define log directory
$logDir = "C:\Temp\Robocopy_Logs"
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Function to write messages to the log file
function Write-Log {
    param (
        [string]$logFile,
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp $message"
    
    # Append to the log file using UTF-8 encoding
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
}

# Function to compare two directories by file hashes and presence
function Compare-Directories {
    param (
        [string]$sourceDir,
        [string]$destDir,
        [string]$logFile
    )

    $sourceFiles = Get-ChildItem -Path $sourceDir -Recurse -File | Sort-Object FullName
    $destFiles = Get-ChildItem -Path $destDir -Recurse -File | Sort-Object FullName

    # Check if the number of files is different
    if ($sourceFiles.Count -ne $destFiles.Count) {
        Write-Log -logFile $logFile -message "File count mismatch between source and destination."
        Write-Output "File count mismatch between source and destination."
        return $false
    }

    # Compare each file's hash and existence
    foreach ($sourceFile in $sourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($sourceDir.Length).TrimStart('\')
        $destFile = Join-Path $destDir $relativePath

        if (-not (Test-Path -Path $destFile)) {
            Write-Log -logFile $logFile -message "File '$($sourceFile.FullName)' does not exist in the destination."
            Write-Output "File '$($sourceFile.FullName)' does not exist in the destination."
            return $false
        }

        # Compare file contents using hash
        $sourceHash = Get-FileHash -Path $sourceFile.FullName -Algorithm SHA256
        $destHash = Get-FileHash -Path $destFile -Algorithm SHA256

        if ($sourceHash.Hash -ne $destHash.Hash) {
            Write-Log -logFile $logFile -message "Hash mismatch: Source file '$($sourceFile.FullName)' and destination file '$destFile' are different."
            Write-Output "Hash mismatch: Source file '$($sourceFile.FullName)' and destination file '$destFile' are different."
            return $false
        }
    }

    Write-Log -logFile $logFile -message "All files match between source and destination."
    Write-Output "All files match between source and destination."
    return $true
}

# Function to process source and destination using Robocopy
function Process-SourceDestination {
    param (
        [string]$source,
        [string]$destination,
        [string]$logFile
    )

    Write-Output "Starting Robocopy process..."
    Write-Log -logFile $logFile -message "Starting Robocopy process..."

    # Robocopy parameters
    $robocopyParams = @(
        $source,
        $destination,
        '/E',           # Copy subdirectories, including empty ones
        '/DCOPY:DAT',   # Copy directory timestamps
        '/COPY:DAT',    # Copy file data, attributes, and timestamps
        '/R:3',         # Number of retries
        '/W:5',         # Wait time between retries
        '/MT:8',        # Use 8 threads for multi-threaded copying
        '/V',           # Produce verbose output log
        '/NP',          # No progress - don't display percentage copied
        '/NS',          # No size - don't log file sizes
        '/NC',          # No class - don't log file classes
        '/BYTES'        # Show file sizes in bytes
    )

    # Run Robocopy and capture its output
    $robocopyOutput = robocopy @robocopyParams | Out-String

    # Log Robocopy output without timestamps
    $robocopyOutput -split "`r`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -ne "") {
            Add-Content -Path $logFile -Value $line
        }
    }

    # Check Robocopy exit code
    $exitCode = $LASTEXITCODE
    $exitCodeMeaning = switch ($exitCode) {
        0 { "No errors occurred, and no copying was done. The source and destination are synchronized." }
        1 { "One or more files were copied successfully." }
        2 { "Some Extra files or directories were detected. No files were copied." }
        4 { "Some Mismatched files or directories were detected." }
        8 { "Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded)." }
        16 { "Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories." }
        default { "Multiple error conditions may have occurred." }
    }

    Write-Log -logFile $logFile -message "Robocopy completed with exit code: $exitCode - $exitCodeMeaning"

    if ($exitCode -ge 8) {
        Write-Output "Robocopy encountered errors. Check the log file for details."
        Write-Log -logFile $logFile -message "Robocopy encountered errors. Exit code: $exitCode - $exitCodeMeaning"
        return $false
    } else {
        Write-Output "Robocopy completed successfully."
        Write-Log -logFile $logFile -message "Robocopy completed successfully. Exit code: $exitCode - $exitCodeMeaning"
        return $true
    }
}

# Main execution loop
foreach ($pair in $sourcesAndDestinations) {
    $source = $pair.Source
    $destination = $pair.Destination

    # Extract the folder name for logging
    $folderName = [System.IO.Path]::GetFileName($source)
    $logFile = Join-Path $logDir "$folderName`_Log.txt"

    Write-Output ""
    Write-Log -logFile $logFile -message ""
    Write-Log -logFile $logFile -message "Starting process for source: '$source' and destination: '$destination'."

    # Check if the source folder exists
    if (-not (Test-Path -Path $source)) {
        Write-Output "Source folder '$source' does not exist. Process aborted."
        Write-Log -logFile $logFile -message "Source folder '$source' does not exist. Process aborted."
        continue
    }

    $robocopyNeeded = $false

    # Check if the destination folder exists
    if (-not (Test-Path -Path $destination)) {
        Write-Output "Destination folder '$destination' does not exist. Creating it and starting Robocopy..."
        Write-Log -logFile $logFile -message "Destination folder '$destination' does not exist. Creating it and starting Robocopy..."
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        $robocopyNeeded = $true
    } else {
        Write-Output "Destination folder '$destination' exists. Comparing directories..."
        Write-Log -logFile $logFile -message "Destination folder '$destination' exists. Comparing directories..."
    }

    if ($robocopyNeeded) {
        $robocopySuccess = Process-SourceDestination -source $source -destination $destination -logFile $logFile
    } else {
        $robocopySuccess = $true
    }

    if ($robocopySuccess) {
        $comparisonResult = Compare-Directories -sourceDir $source -destDir $destination -logFile $logFile
        if ($comparisonResult -eq $true) {
            Write-Output "Source and destination are identical. Attempting to delete source folder..."
            Write-Log -logFile $logFile -message "Source and destination are identical. Attempting to delete source folder..."

            try {
                Get-ChildItem -Path $source -Recurse -Force | ForEach-Object {
                    if ($_ -is [System.IO.FileInfo]) {
                        $_.IsReadOnly = $false
                    }
                }
                Remove-Item -Path $source -Recurse -Force -ErrorAction Stop
                Write-Output "Source folder '$source' successfully deleted."
                Write-Log -logFile $logFile -message "Source folder '$source' successfully deleted."
            }
            catch {
                Write-Output "Failed to delete the source folder '$source'. Error: $($_.Exception.Message)"
                Write-Log -logFile $logFile -message "Failed to delete the source folder '$source'. Error: $($_.Exception.Message)"
            }

            # Double-check if the folder was actually deleted
            if (Test-Path -Path $source) {
                Write-Output "Source folder '$source' still exists. Manual intervention may be needed."
                Write-Log -logFile $logFile -message "Source folder '$source' still exists. Manual intervention may be needed."
            }
        } else {
            Write-Output "Source and destination are not identical. No action taken."
            Write-Log -logFile $logFile -message "Source and destination are not identical. No action taken."
        }
    } else {
        Write-Output "Robocopy process failed. Check the log file for details."
        Write-Log -logFile $logFile -message "Robocopy process failed. Check the log file for details."
    }

    Write-Output "Process completed for source '$source'. Check the log file at '$logFile' for details."
    Write-Log -logFile $logFile -message "Process completed for source '$source'."
}