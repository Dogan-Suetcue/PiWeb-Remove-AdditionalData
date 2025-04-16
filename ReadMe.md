# PowerShell Script for Deleting PiWeb Additional Data

## Description

The Remove-AdditionalData PowerShell function is designed to remove additional data from the PiWeb database based on specified parameters. This function allows users to filter data by entity type, file extension, and date range, and optionally generate a detailed report of the deletion process.

⚠ **Warning:** Before executing this script, ensure that you create a backup of your database to prevent unintended data loss.

## Usage

To use the `Remove-AdditionalData` script, follow these steps:

1. **Download the Script**: Obtain the archive that contains the `Remove-AdditionalData` script from [here](https://github.com/Dogan-Suetcue/PiWeb-Remove-AdditionalData/releases/download/v1.0.0/RemoveAdditionalData.zip).

2. **Open PowerShell**: Launch PowerShell on your computer.

3. **Navigate to the archive location**: Use the `Set-Location` Cmdlet to change the directory to the location where the archive is saved. For example:

   ```powershell
   Set-Location C:\Path\To\Your\Location
   ```

4. **Expand the archive**: Use the `Expand-Archive` Cmdlet to expand the archive. For example:

   ```powershell
   Expand-Archive .\RemoveAdditionalData.zip
   ```

5. **Navigate to the script folder**: Use the `Set-Location` Cmdlet to change the directory to the location where the script is saved. For example:

   ```powershell
   Set-Location .\RemoveAdditionalData
   ```

6. **Unblock the Script**: If you downloaded the script from the internet, it might be blocked. Unblock the script using the following command:

   ```powershell
   Get-ChildItem -Include @('*.ps1', '*.psm1') -Recurse | Unblock-File
   ```

7. **Run the Script**: Execute the script by typing its name. You can run it with default parameters or specify your own.

   - **Default Parameters**: Simply run the script and follow the prompt to use default settings.

   - **Custom Parameters**: Specify your parameters directly in the command. For example:

   ```powershell
   .\Remove-AdditionalData.ps1 -BaseURL 'http://hostname:8080' -Entity @('measurement', 'value') -Exclude @('png', 'jpg') -RelativeDaysStart 60 -RelativeDaysEnd 30 -RelativeDaysStep 10 -LogFilePath 'C:\Logs\MyLog.txt' -DetailedReport 1
   ```

### Function Parameters

- **BaseURL**: The URL of the database to be queried. Default value is `'http://localhost:8080'`.
- **Entity**: A list of entities to be queried. Possible values are: `'part'`, `'characteristic'`, `'measurement'`, `'value'`. Default value is `'value'`.
- **Exclude**: A list of file extensions to filter out from deletion. Default value is `@()`.
- **RelativeDaysStart**: The start point of the period to check, in days from today. Default value is `365`.
- **RelativeDaysEnd**: The end point of the period to check, in days from today. Default value is `14`.
- **RelativeDaysStep**: The number of days to group together. Default value is `30`.
- **DetailedReport**: If specified, a detailed report will be generated including part paths and file sizes. Default value is `'0'`.
- **LogFilePath**: The path to the log file where the results should be saved. Default value is `'.\PiWebAdditionalDataDeletionLog.txt'`.

## Process Flow

1. The script begins by importing the required modules (`Common.psm1`, `PiWebHelper.psm1`, `Helper.psm1`).
2. The `Test-PSVersion` function is called to ensure that the current PowerShell version meets the required minimum version (7.5.1). If the version is insufficient, the script exits.
3. The user is prompted to type (y)es to run the script with the default parameters, or any other key to define the parameters themselves.
   - If the user types "yes", the default parameters are set and passed to the `Remove-AdditionalData` function.
   - If the user types any other key, the `Remove-AdditionalData` function is called without parameters.
4. The script iterates over the specified date range, deleting outdated additional data for the specified entities.
5. All operations and results are logged in the specified log file, including any errors encountered during execution.

## Requirements

- PowerShell 7.5.1 or later
- Access to the PiWeb database
- If Basic Authentication is required, a username and password must be provided

## Additional Resources

For more details on working with the PiWeb Raw Data Service, visit the official GitHub page:
[PiWeb RawData Service GitHub](https://zeiss-piweb.github.io/PiWeb-Api/rawdataservice)

## License

This script is provided under the MIT license.
