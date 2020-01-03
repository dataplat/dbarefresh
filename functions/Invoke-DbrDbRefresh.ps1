function Invoke-DbrDbRefresh {

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

    .PARAMETER Database
        Database(s) to copy data from

    .PARAMETER SkipFunction
        Skip function objects

    .PARAMETER SkipProcedure
        Skip procedure objects

    .PARAMETER SkipTable
        Skip table objects

    .PARAMETER SkipView
        Skip view objects

    .PARAMETER SkipData
        Skip the part of copying the data

    .PARAMETER SkipSchema
        Skip the part of copying the schemas

    .PARAMETER SkipUserDefinedDataType
        Skip the user defined data type

    .PARAMETER SkipUserDefinedTableType
        Skip the user defined table type

    .PARAMETER SkipFunctionDrop
        Skip the dropping of functions

    .PARAMETER SkipProcedureDrop
        Skip the dropping of stored procedures

    .PARAMETER SkipTableDrop
        Skip the dropping of tables

    .PARAMETER SkipViewDrop
        Skip the dropping of views

    .PARAMETER SkipDataTypeDrop
        Skip the dropping of user defined data types

    .PARAMETER SkipTableTypeDrop
        Skip the dropping of user defined table types

    .PARAMETER SkipSchemaDrop
        Skip the dropping of schemas

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER ClientName
        Client name of the refresh process that's visible in the SQL Server processes.
        Default "PSDatabaseRefresh"

    .PARAMETER BatchSize
        Size of the batch to use. Default is 50000

    .PARAMETER Timeout
        Timeout of the bulk copy. Default is 30 seconds.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Invoke-DbrDbRefresh -FilePath C:\temp\db1.json

        Start the provisioning using the config file
    #>

    [CmdLetBinding(SupportsShouldProcess)]
    [OutputType('System.Object[]')]

    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string[]]$SourceSqlInstance,
        [PSCredential]$SourceSqlCredential,
        [string[]]$DestinationSqlInstance,
        [PSCredential]$DestinationSqlCredential,
        [string[]]$Database,
        [switch]$SkipFunction,
        [switch]$SkipProcedure,
        [switch]$SkipTable,
        [switch]$SkipView,
        [switch]$SkipData,
        [switch]$SkipSchema,
        [switch]$SkipUserDefinedDataType,
        [switch]$SkipUserDefinedTableType,
        [switch]$SkipFunctionDrop,
        [switch]$SkipProcedureDrop,
        [switch]$SkipTableDrop,
        [switch]$SkipViewDrop,
        [switch]$SkipDataTypeDrop,
        [switch]$SkipTableTypeDrop,
        [switch]$SkipSchemaDrop,
        [string]$ClientName,
        [int]$BatchSize = 50000,
        [int]$Timeout = 300000,
        [switch]$EnableException
    )

    begin {

        if (-not (Test-Path -Path $FilePath)) {
            Stop-PSFFunction -Message "Could not find configuration file" -Target $Path -EnableException:$EnableException
            return
        }

        # Get the databases from the config
        try {
            $items = @()
            $items += ConvertFrom-DbrConfig -FilePath $FilePath -EnableException | Select-Object databases -ExpandProperty databases
        }
        catch {
            Stop-PSFFunction -Message "Something went wrong converting the configuration file" -ErrorAction $_ -Target $FilePath
        }

        if (-not $ClientName) {
            $ClientName = "PSDatabaseRefresh"
        }

        # Apply filters
        if ($SourceSqlInstance) {
            $items = $items | Where-Object { $_.sourceinstance -in $SourceSqlInstance }
        }

        if ($DestinationSqlInstance) {
            $items = $items | Where-Object { $_.destinationinstance -in $DestinationSqlInstance }
        }

        if ($Database) {
            $items = $items | Where-Object { $_.database -in $Database }
        }

        $stopwatchTotal = New-Object System.Diagnostics.Stopwatch
        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $results = @()

    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Start the stopwatch
        $stopwatchTotal.Start()

        foreach ($item in $items) {

            [array]$destinationsInstances = $item.destinationinstance

            # Loop through each of the destination instances
            foreach ($destInstance in $destinationsInstances) {
                # Connect to server
                try {
                    $sourceServer = Connect-DbaInstance -SqlInstance $item.sourceinstance -SqlCredential $SourceSqlCredential -ClientName $ClientName -MultipleActiveResultSets
                }
                catch {
                    Stop-PSFFunction -Message "Could not connect to $($item.sourceinstance )" -Target $SourceSqlInstance -ErrorRecord $_ -Category ConnectionError
                    return
                }

                try {
                    $destServer = Connect-DbaInstance -SqlInstance $destInstance -SqlCredential $DestinationSqlCredential -ClientName $ClientName -MultipleActiveResultSets
                }
                catch {
                    Stop-PSFFunction -Message "Could not connect to $destInstance" -Target $destInstance -ErrorRecord $_ -Category ConnectionError
                }

                # Retrieve the databases
                $sourceDatabase = $sourceServer.Databases | Where-Object Name -eq $item.database
                $destDatabases = $destServer.Databases

                $totalSteps = 15
                $currentStep = 1
                $progressId = 1

                $dbCount = $sourceDatabases.Count
                $dbStep = 0

                # Loop through the source databases

                $dbStep++
                $task = "Refreshing database $($sourceDatabase.Name)"
                Write-Progress -Id 1 -Activity $task -Status 'Progress->' -PercentComplete $($dbStep / $dbCount * 100)

                Write-PSFMessage -Level Host -Message "Provisioning $($sourceDatabase.Name) from $sourceServer to $destServer"

                if ($sourceDatabase.Name -notin $destDatabases.Name) {
                    if ($PSCmdlet.ShouldProcess("Creating database [$($sourceDatabase.Name)] on $destServer")) {
                        try {
                            Write-PSFMessage -Level Verbose -Message "Database $($sourceDatabase.Name) doesn't exist. Creating it.."

                            $query = "CREATE DATABASE [$($sourceDatabase.Name)]"

                            Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $sourceDatabase.Name -Query $query -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not create database $($sourceDatabase.name)" -ErrorRecord $_ -Target $destInstance
                        }

                        $destServer.Databases.Refresh()
                    }
                }

                # Get the destination database
                $destDatabase = $destServer.Databases[$item.database]

                # Drop all views
                if (-not $SkipViewDrop) {
                    $currentStep = 2

                    $params = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing View(s)"
                    }

                    Write-Progress @params

                    if (-not $SkipView) {
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing view(s)")) {
                            try {
                                Remove-DbrDbView -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the views" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                # Drop all stored procedures
                if (-not $SkipProcedureDrop) {
                    $currentStep = 3

                    $params = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing Stored Procedure(s)"
                    }

                    Write-Progress @params

                    if (-not $SkipProcedure) {
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing stored procedure(s)")) {
                            try {
                                Remove-DbrDbStoredProcedure -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the stored procedures" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                # Drop all user defined functions
                if (-not $SkipFunctionDrop) {
                    $currentStep = 4

                    $params = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing User Defined Function(s)"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing function(s)")) {
                            try {
                                Remove-DbrDbFunction -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the functions" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                # Drop all user defined data types
                if (-not $SkipDataTypeDrop) {
                    $currentStep = 5

                    $params = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing User Defined Data Type(s)"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing data type(s)")) {
                            try {
                                Remove-DbrDbDataType -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the functions" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                # Drop all user defined table types
                if (-not $SkipTableTypeDrop) {
                    $currentStep = 6

                    $params = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing User Defined Table Type(s)"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing table type(s)")) {
                            try {
                                Remove-DbrDbTableType -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the functions" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                # Drop all schemas
                if (-not $SkipSchemaDrop) {
                    $currentStep = 7

                    $params = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing Schema(s)"
                    }

                    Write-Progress @params

                    if (-not $SkipSchema) {
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing schema(s)")) {
                            try {
                                Remove-DbrDbSchema -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the schema" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                #region schema copy

                if (-not $SkipSchemaDrop) {
                    $params = @{
                        SourceSqlInstance        = $sourceServer
                        SourceSqlCredential      = $SourceSqlCredential
                        DestinationSqlInstance   = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database                 = $db.Name
                        EnableException          = $true
                    }

                    Copy-DbrDbSchema @params

                    $destServer.Databases[$db.Name].Refresh()
                }

                #endregion schema copy

                #region table copy

                $currentStep = 8

                $params = @{
                    Id               = ($progressId + 1)
                    ParentId         = $progressId
                    Activity         = "Refreshing database"
                    Status           = 'Progress->'
                    PercentComplete  = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Processing Tables"
                }

                Write-Progress @params

                if (-not $SkipTable) {

                    $sourceTables = $sourceDatabase.Tables

                    $copyParams = @{
                        SqlInstance              = $sourceServer
                        SqlCredential            = $SourceSqlCredential
                        Destination              = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database                 = $sourceDatabase.Name
                        AutoCreateTable          = $false
                        BatchSize                = $BatchSize
                        BulkCopyTimeOut          = $Timeout
                        KeepIdentity             = $true
                        KeepNulls                = $true
                        Table                    = $null
                        Truncate                 = $false
                        Query                    = $null
                        EnableException          = $true
                    }

                    if (-not $SkipTableDrop) {
                        $task = "Removing tables"
                        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

                        # Remove the tables
                        if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing table(s)")) {
                            try {
                                #Remove-DbrDbForeignKey -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException

                                Remove-DbrDbTable -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the tables" -Target $destDatabase -ErrorRecord $_
                            }
                        }
                    }

                    $totalObjects = $sourceTables.Count
                    $objectStep = 0

                    if ($SkipData) {
                        $task = "Creating tables"
                    }
                    else {
                        $task = "Creating tables and copying data"
                    }

                    if (-not $SkipTableDrop) {
                        $params = @{
                            SourceSqlInstance        = $sourceServer
                            SourceSqlCredential      = $SourceSqlCredential
                            DestinationSqlInstance   = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            Database                 = $destDatabase.Name
                            EnableException          = $true
                        }

                        Copy-DbrDbTable @params

                        $destServer.Databases[$destDatabase.Name].Tables.Refresh()
                    }

                    $objectStep = 0

                    foreach ($itemTable in $item.tables) {
                        $table = $sourceDatabase.Tables | Where-Object { $_.Schema -eq $itemTable.schema -and $_.Name -eq $itemTable.Name }

                        $objectStep++
                        $operation = "Table [$($table.Schema)].[$($table.Name)]"

                        $progressParams = @{
                            Id               = ($progressId + 2)
                            ParentId         = ($progressId + 1)
                            Activity         = $task
                            Status           = "Progress-> Table $objectStep of $totalObjects"
                            PercentComplete  = $($objectStep / $totalObjects * 100)
                            CurrentOperation = $operation
                        }

                        Write-Progress @progressParams

                        $rowCountSource = $table.RowCount

                        $stopwatchObject.Start()

                        $copyParams.Table = "[$($table.Schema)].[$($table.Name)]"

                        # Reset the query variable
                        $query = $null

                        # Check if the data needs to be copied or that the only the table needs to be created
                        if (-not $SkipData -and $rowCountSource -ge 1) {
                            if ($PSCmdlet.ShouldProcess("$($destServer)", "Creating table(s) and copying data")) {
                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [$($table.Schema)].[$($table.Name)]"

                                    $copyParams.Query = $itemTable.query
                                    $results += Copy-DbaDbTableData @copyParams
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($table.Schema)].[$($table.Name)]" -Target $table -ErrorRecord $_
                                }
                            }

                            [int]$rowCountDest = $destDatabases[$destDatabase.Name].Tables[$table.Name].RowCount
                            Write-PSFMessage -Level Verbose -Message "Row Count Source:         $($rowCountSource)"
                            Write-PSFMessage -Level Verbose -Message "Row Count Destination:    $($rowCountDest)"

                            [PSCustomObject]@{
                                SqlInstance    = $destInstance
                                Database       = $destDatabase.Name
                                ObjectType     = "Table"
                                Parent         = "N/A"
                                Object         = "$($table.Schema).$($table.Name)"
                                Information    = "Copied $($rowCountDest) of $($rowCountSource) rows"
                                ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                            }

                        }
                        else {
                            if (-not ($destServer.Databases[$destDatabase.Name].Tables | Where-Object { $_.Schema -eq $table.Schema -and $_.Name -eq $table.Name })) {
                                $query = Export-DbaScript -InputObject $table -Passthru -NoPrefix

                                if ($PSCmdlet.ShouldProcess("$($destServer)", "Creating table(s)")) {
                                    try {
                                        Write-PSFMessage -Level Verbose -Message "Creating table [$($table.Schema)].[$($table.Name)]"

                                        Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDatabase.Name -Query $query -EnableException
                                    }
                                    catch {
                                        Stop-PSFFunction -Message "Could not create table [$($table.Schema)].[$($table.Name)]" -Target $table -ErrorRecord $_
                                    }
                                }

                                [PSCustomObject]@{
                                    SqlInstance    = $destInstance
                                    Database       = $destDatabase.Name
                                    ObjectType     = "Table"
                                    Parent         = "N/A"
                                    Object         = "$($table.Schema).$($table.Name)"
                                    Information    = "No rows to copy"
                                    ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                                }
                            }
                        }

                        $stopwatchObject.Stop()

                        $stopwatchObject.Reset()
                    } # End for each table

                    # Create the indexes
                    $currentStep = 9
                    $totalObjects = $sourceTables.Indexes.Count
                    $objectStep = 0
                    $task = "Creating Indexes"

                    $progressParams = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Creating Indexe(s)"
                    }

                    Write-Progress @progressParams

                    if ($PSCmdlet.ShouldProcess("$($destServer)", "Creating index(es)")) {
                        $params = @{
                            SourceSqlInstance        = $sourceServer
                            SourceSqlCredential      = $SourceSqlCredential
                            DestinationSqlInstance   = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            Database                 = $destDatabase.Name
                            EnableException          = $true
                        }

                        Copy-DbrDbIndex @params
                    }

                    $currentStep = 10

                    $progressParams = @{
                        Id               = ($progressId + 1)
                        ParentId         = $progressId
                        Activity         = "Refreshing database"
                        Status           = 'Progress->'
                        PercentComplete  = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Creating Foreign Key(s)"
                    }

                    Write-Progress @progressParams

                    if ($PSCmdlet.ShouldProcess("$($destServer)", "Creating foreign key(s)")) {
                        $params = @{
                            SourceSqlInstance        = $sourceServer
                            SourceSqlCredential      = $SourceSqlCredential
                            DestinationSqlInstance   = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            Database                 = $destDatabase.Name
                            EnableException          = $true
                        }

                        Copy-DbrDbForeignKey @params
                    }
                }

                #endregion table copy

            } # end for each destination instance

        } #end for each item

        $stopwatchTotal.Stop()

        # Output summary
        $totalTime = $stopwatchTotal.Elapsed

        $totalTimeMessage = "Total time:   $($totalTime.Hours) hour(s), $($totalTime.Minutes) minute(s), $([Math]::Truncate($totalTime.Seconds)) second(s)"

        Write-PSFMessage -Level Output -Message "Total databases refreshed: $($items.databases.Count)"
        Write-PSFMessage -Level Output -Message "Database(s):  $($items.databases.database -join ",")"
        Write-PSFMessage -Level Output -Message $totalTimeMessage
    }

    end {
        if (Test-PSFFunctionInterrupt) { return }
    }

}