function New-DbrDatabase {
    <#
    .SYNOPSIS
        Start the database refresh

    .DESCRIPTION
        Start the database refresh going through all the tables

    .PARAMETER FilePath
        Path to configuration file

    .PARAMETER SourceSqlInstance
        The source target SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target source instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target destination SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target destination instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER SourceDatabase
        Filter database(s) to copy data from

    .PARAMETER DestinationDatabase
        Filter database(s) to copy data to

    .PARAMETER DataFileSizeMB
        Initial size of the data file. Default is 512 MB

    .PARAMETER DataFileGrowthMB
        Growth of the data file when it needs to be extended. Default is 256 MB

    .PARAMETER DataPath
        Path to save the data files to. Default is the destination server's setting

    .PARAMETER LogFileSizeMB
        Initial size of the log file. Default is 256 MB

    .PARAMETER LogFileGrowthMB
        Growth of the log file when it needs to be extended. Default is 128 MB

    .PARAMETER LogPath
        Path to save the log files to. Default is the destination server's setting

    .PARAMETER RecoveryModel
        Recovery model for the database. Default is Simple
        Be carefull when setting this because the operations to copy data can be very logging intensive!

    .PARAMETER Force
        Force the command to remove the destination database when it exists on the destination sql instance

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        New-DbrDatabase -SourceSqlnstance SQL1 -SourceDatabase DB1 -DestinationSqlnstance SQL1 -DestinationDatabase "DB1-Refresh"

        Create the new database based on the existing one on the same instance

    .EXAMPLE
        New-DbrDatabase -SourceSqlnstance SQL1 -SourceDatabase DB1 -DestinationSqlnstance SQL2 -DestinationDatabase "DB1"

        Create the new database based on the existing one on another instance
    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [DbaInstanceParameter]$SourceSqlnstance,
        [pscredential]$SourceSqlCredential,
        [string]$SourceDatabase,
        [DbaInstanceParameter]$DestinationSqlnstance,
        [pscredential]$DestinationSqlCredential,
        [string]$DestinationDatabase,
        [int]$DataFileSizeMB = 512,
        [int]$DataFileGrowthMB = 256,
        [string]$DataPath,
        [int]$LogFileSizeMB = 256,
        [int]$LogFileGrowth = 128,
        [string]$LogPath,
        [ValidateSet('BulkLogged', 'Full', 'Simple')]
        [string]$RecoveryModel = 'Simple',
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        try {
            $sourceServer = Connect-DbaInstance -SqlInstance $SourceSqlnstance -SqlCredential $SourceSqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to source instance $SourceSqlInstance" -ErrorRecord $_ -Target $SourceSqlInstance
            return
        }

        try {
            $destServer = Connect-DbaInstance -SqlInstance $DestinationSqlnstance -SqlCredential $DestinationSqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to source instance $SourceSqlInstance" -ErrorRecord $_ -Target $SourceSqlInstance
            return
        }

        if ($sourceServer.Databases.Name -notcontains $SourceDatabase ) {
            Stop-PSFFunction -Message "Source database $SourceDatabase is not present on $SourceSqlInstance"
        }
        else {
            $sourceDb = $sourceServer.Databases[$SourceDatabase]
        }

        if ($destServer.Databases.Name -contains $DestinationDatabase) {
            if ($Force) {

                if ($PSCmdlet.ShouldProcess("Removing database on $($DestinationSqlnstance)")) {
                    Write-PSFMessage -Message "Removing database $DestinationDatabase" -Level Verbose
                    try {
                        $null = Remove-DbaDatabase -SqlInstance $DestinationSqlnstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase -Confirm:$false
                    }
                    catch {
                        Stop-PSFFunction -Message "Something went wrong removing database $DestinationDatabase" -ErrorRecord $_ -Target $DestinationDatabase
                    }
                }
            }
            else {
                Stop-PSFFunction -Message "Database $DestinationDatabase already exists on $DestinationSqlnstance" -Target $DestinationDatabase
            }
        }

        if (-not $DataPath) {
            $DataPath = $destServer.DefaultFile
        }

        if (-not $LogPath) {
            $LogPath = $destServer.DefaultLog
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Setup the first part of the query
        $query = New-Object System.Text.StringBuilder
        $null = $query.AppendLine("CREATE DATABASE [$($DestinationDatabase)]")

        $primaryFileGroup = "ON PRIMARY
(
    NAME = N'$($DestinationDatabase)_Primary',
    FILENAME = N'$($DataPath)\$($DestinationDatabase).mdf',
    SIZE = $($DataFileSizeMB)MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = $($DataFileGrowthMB)MB
)"

        $null = $query.AppendLine($primaryFileGroup)

        # Check if the database contains more than one fileegroup.
        # If it does loop through them
        if ($sourceDb.FileGroups.Count -gt 1) {
            $fileGroups = $sourceDb.FileGroups | Where-Object Name -ne 'PRIMARY'

            foreach ($filegroup in $fileGroups) {
                $fileGroupFilePath = Join-PSFPath -Path $DataPath -Child "$($DestinationDatabase)_$($filegroup.Name).ndf"
                $filegroupQuery = ",FILEGROUP [$($filegroup.Name)] DEFAULT
(
    NAME = N'$($DestinationDatabase)_UserData',
    FILENAME = N'$($fileGroupFilePath)',
    SIZE = $($DataFileSizeMB)MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = $($DataFileGrowthMB)MB
)"
                $null = $query.AppendLine($filegroupQuery)
            }
        }

        # Setup the log file path
        $logFilePath = Join-PSFPath -Path $LogPath -Child "$($DestinationDatabase).ldf"

        $logFileGroup = "LOG ON
(
    NAME = N'$($DestinationDatabase)_Log',
    FILENAME = N'$($logFilePath)',
    SIZE = $($LogFileSizeMB)MB,
    MAXSIZE = 2048GB,
    FILEGROWTH = $($LogFileGrowth)MB
);"

        $null = $query.AppendLine($logFileGroup)

        if ($PSCmdlet.ShouldProcess("Creating database on $($DestinationSqlnstance)")) {
            try {
                Write-PSFMessage -Message "Creating database $DestinationDatabase" -Level Verbose
                # Create the database
                Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database 'master' -Query $query.ToString()
            }
            catch {
                Stop-PSFFunction -Message "Something went wrong creating the database" -ErrorRecord $_ -Target $DestinationSqlnstance
                return
            }

            try {
                # Set the recovery model
                Write-PSFMessage -Message "Setting recovery model for database $DestinationDatabase" -Level Verbose
                $query = "ALTER DATABASE [$($DestinationDatabase)] SET RECOVERY $($RecoveryModel);"
                Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase -Query $query
            }
            catch {
                Stop-PSFFunction -Message "Something went wrong setting the recovery model" -ErrorRecord $_ -Target $DestinationDatabase
                return
            }
        }
    }
}


