# SmartFileSync

SmartFileSync is a PowerShell-based file synchronization tool that enhances Robocopy with intelligent automation and safety features. It focuses on creating new copies of source folders and cleaning up identical sources, while preserving both source and destination in cases of differences.

## Features

- **Intelligent Comparison**: Automatically compares source and destination directories to determine the appropriate action.
- **Selective Copying**: Only creates new copies when the destination doesn't exist.
- **Safe Source Deletion**: Deletes the source folder only when it's identical to an existing destination.
- **Preservation of Differences**: Keeps both source and destination intact when they differ.
- **Detailed Logging**: Comprehensive logging of all operations for easy troubleshooting and auditing.
- **Robocopy Integration**: Leverages Robocopy for efficient and reliable file copying.
- **CSV Input Support**: Processes multiple source-destination pairs using a CSV file.

### Supported Scenarios

SmartFileSync handles the following scenarios:

1. **New Destination Creation**: 
   - If the destination folder doesn't exist, it creates it and performs a full copy from the source.

2. **Identical Source and Destination**:
   - When an existing destination is identical to the source, it deletes the source folder to save space.

3. **Different Source and Destination**:
   - If the destination exists but differs from the source, no action is taken, preserving both the source and existing destination.

4. **Multiple Directory Pairs**:
   - Processes multiple source-destination pairs from a single CSV file.

5. **Error Handling**:
   - Provides detailed logs for any errors encountered during the process.

### Comparison Method

SmartFileSync uses a two-step process to compare source and destination directories:

1. **File Count**: It first compares the number of files in both directories.
2. **File Hash**: If the file counts match, it then compares the SHA256 hash of each file in the source with its counterpart in the destination.

This method ensures a thorough comparison, detecting differences in both the presence of files and their contents.

### Important Notes

- The script does not update or modify existing destination folders.
- It only copies files when creating a new destination.
- When sources and existing destinations differ, both are left untouched.
- Source deletion only occurs when the destination is identical to the source.

## Requirements

- Windows PowerShell 5.1 or later
- Windows 7 or later (for Robocopy support)

## Usage

1. Place the CSV file named `SourcesAndDestinations.csv` in the `C:\Temp\` directory. The CSV should have the following format:
   ```
   Source,Destination
   C:\SourceFolder1,D:\DestinationFolder1
   C:\SourceFolder2,E:\DestinationFolder2
   ```

2. Run the script:
   ```powershell
   .\SmartFileSync.ps1
   ```

3. After execution, check the logs in the `C:\Temp\Robocopy_Logs` directory for operation details. Each synchronization operation will have its own log file named after the source folder.

## Configuration

You can modify the following variables in the script to customize its behavior:

- `$csvFile`: Path to the CSV file containing source and destination pairs. Default is `C:\Temp\SourcesAndDestinations.csv`.
- `$logDir`: Directory where log files will be stored. Default is `C:\Temp\Robocopy_Logs`.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Upcoming Features

- `/MIR` (Mirror) mode for creating exact copies of directory structures.
- Individual file synchronization support.
- Additional Robocopy parameter customization.
- GUI interface for easier configuration and execution.
