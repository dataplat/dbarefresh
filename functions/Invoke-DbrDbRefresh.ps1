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

    .PARAMETER SourceDatabase
        Filter database(s) to copy data from

    .PARAMETER DestinationDatabase
        Filter database(s) to copy data to

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
        [string[]]$SourceDatabase,
        [string[]]$DestinationDatabase,
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
            Stop-PSFFunction -Message "Something went wrong converting the configuration file" -ErrorRecord $_ -Target $FilePath
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

        if ($SourceDatabase) {
            $items = $items | Where-Object { $_.sourcedatabase -in $SourceDatabase }
        }

        if ($DestinationDatabase) {
            $items = $items | Where-Object { $_.destinationdatabase -in $DestinationDatabase }
        }


        $stopwatchTotal = New-Object System.Diagnostics.Stopwatch
        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $results = @()

    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Start the stopwatch
        $stopwatchTotal.Start()

        $dbCount = $items.Count
        $dbStep = 0

        foreach ($item in $items) {

            if (($item.sourceinstance -eq $item.destinationinstance) -and ($item.sourcedatabase -eq $item.destinationdatabase)) {
                Stop-PSFFunction -Message "Source and destination database cannot be the same when source and destination instance are the same" -Continue
            }

            # Connect to server
            try {
                $sourceServer = Connect-DbaInstance -SqlInstance $item.sourceinstance -SqlCredential $SourceSqlCredential -ClientName $ClientName -MultipleActiveResultSets
            }
            catch {
                Stop-PSFFunction -Message "Could not connect to $($item.sourceinstance)" -Target $SourceSqlInstance -ErrorRecord $_ -Category ConnectionError
                return
            }

            if ($item.sourcedatabase -notin $sourceServer.Databases.Name) {
                Stop-PSFFunction -Message "Source database [$($item.sourcedatabase)] could not be found on $sourceServer" -Target $item.sourcedatabase -Continue
            }

            $sourceDb = $sourceServer.Databases[$item.sourcedatabase]

            [array]$destinationsInstances = $item.destinationinstance

            $dbStep++
            $task = "Refreshing database [$($item.destinationdatabase)]"
            Write-Progress -Id 1 -Activity $task -Status 'Progress->' -PercentComplete $($dbStep / $dbCount * 100)

            # Loop through each of the destination instances
            foreach ($destInstance in $destinationsInstances) {

                try {
                    $destServer = Connect-DbaInstance -SqlInstance $destInstance -SqlCredential $DestinationSqlCredential -ClientName $ClientName -MultipleActiveResultSets
                }
                catch {
                    Stop-PSFFunction -Message "Could not connect to $destInstance" -Target $destInstance -ErrorRecord $_ -Category ConnectionError
                }

                $totalSteps = 15
                $currentStep = 1
                $progressId = 1

                # Loop through the databases
                Write-PSFMessage -Level Host -Message "Provisioning $($item.destinationdatabase) from $sourceServer to $destServer"

                if ($item.destinationdatabase -notin $destServer.Databases.Name) {
                    if ($PSCmdlet.ShouldProcess("Creating database [$($item.destinationdatabase)] on $destServer")) {
                        try {
                            Write-PSFMessage -Level Verbose -Message "Database $($item.destinationdatabase) doesn't exist. Creating it.."

                            $query = "CREATE DATABASE [$($item.destinationdatabase)]"

                            Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database 'master' -Query $query -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not create database $($item.destinationdatabase)" -ErrorRecord $_ -Target $destInstance
                        }

                        $destServer.Databases.Refresh()
                    }
                }

                # Get the destination database
                $destDb = $destServer.Databases[$item.destinationdatabase]

                #region remove object

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
                                Remove-DbrDbView -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name
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
                                Remove-DbrDbStoredProcedure -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name -EnableException
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
                                Remove-DbrDbFunction -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name -EnableException
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
                                Remove-DbrDbDataType -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name -EnableException
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
                                Remove-DbrDbTableType -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name -EnableException
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
                                Remove-DbrDbSchema -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name -EnableException
                            }
                            catch {
                                Stop-PSFFunction -Message "Something went wrong dropping the schema" -Target $destServer -ErrorRecord $_
                            }
                        }
                    }
                }

                #endregion remove object

                #region create object

                #region schema copy

                if (-not $SkipSchemaDrop) {
                    $params = @{
                        SourceSqlInstance        = $sourceServer
                        SourceSqlCredential      = $SourceSqlCredential
                        DestinationSqlInstance   = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        SourceDatabase           = $sourceDb.Name
                        DestinationDatabase      = $destDb.Name
                        EnableException          = $true
                    }

                    Copy-DbrDbSchema @params

                    $destDb.Refresh()
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

                #if (-not $SkipTable) {

                $sourceTables = $sourceDb.Tables

                if (-not $SkipTableDrop) {
                    $task = "Removing tables"
                    Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

                    # Remove the tables
                    if ($PSCmdlet.ShouldProcess("$($destServer)", "Removing table(s)")) {
                        try {
                            Remove-DbrDbTable -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $destDb.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the tables" -Target $destDb -ErrorRecord $_
                        }
                    }

                    $destDb.Refresh()
                }

                $totalObjects = $sourceTables.Count
                $objectStep = 0

                if ($SkipData) {
                    $task = "Creating tables"
                }
                else {
                    $task = "Creating tables and copying data"
                }

                $params = @{
                    SourceSqlInstance        = $sourceServer
                    SourceSqlCredential      = $SourceSqlCredential
                    DestinationSqlInstance   = $destServer
                    DestinationSqlCredential = $DestinationSqlCredential
                    SourceDatabase           = $sourceDb.Name
                    DestinationDatabase      = $destDb.Name
                    Schema                   = $item.tables.schema
                    Table                    = $item.tables.Name
                    EnableException          = $true
                }

                Copy-DbrDbTable @params

                $destDb.Refresh()
                $destDb.Tables.Refresh()

                $objectStep = 0

                if (-not $SkipData) {
                    $copyParams = @{
                        SqlInstance              = $sourceServer
                        SqlCredential            = $SourceSqlCredential
                        Database                 = $sourceDb.Name
                        Destination              = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        DestinationDatabase      = $destDb.Name
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

                    foreach ($itemTable in $item.tables) {

                        $objectStep++
                        $operation = "Table [$($itemTable.Schema)].[$($itemTable.Name)]"

                        $progressParams = @{
                            Id               = ($progressId + 2)
                            ParentId         = ($progressId + 1)
                            Activity         = $task
                            Status           = "Progress-> Table $objectStep of $totalObjects"
                            PercentComplete  = $($objectStep / $totalObjects * 100)
                            CurrentOperation = $operation
                        }

                        Write-Progress @progressParams

                        $sourceTableObject = $sourceDb.Tables | Where-Object { $_.Schema -eq $itemTable.schema -and $_.Name -eq $itemTable.name }
                        $rowCountSource = $sourceTableObject.RowCount

                        $stopwatchObject.Start()

                        # Reset the query variable
                        $query = $null

                        # Check if the data needs to be copied or that the only the table needs to be created
                        if ($rowCountSource -ge 1) {
                            if ($PSCmdlet.ShouldProcess("$($destServer)", "Creating table(s) and copying data")) {

                                $copyParams.Table = "[$($itemTable.schema)].[$($itemTable.name)]"

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [$($itemTable.schema)].[$($itemTable.Name)]"

                                    $copyParams.Query = $itemTable.query

                                    $results += Copy-DbaDbTableData @copyParams

                                    $destDb.Refresh()
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($itemTable.schema)].[$($itemTable.Name)]" -Target $sourceTableObject -ErrorRecord $_
                                }
                            }

                            $destTableObject = $destDb.Tables | Where-Object { $_.Schema -eq $itemTable.schema -and $_.Name -eq $itemTable.name }
                            [int]$rowCountDest = $destTableObject.RowCount

                            Write-PSFMessage -Level Verbose -Message "Row Count Source:         $($rowCountSource)"
                            Write-PSFMessage -Level Verbose -Message "Row Count Destination:    $($rowCountDest)"

                            $stopwatchObject.Stop()

                            [PSCustomObject]@{
                                SqlInstance    = $destInstance
                                Database       = $destDb.Name
                                ObjectType     = "Table"
                                Parent         = "N/A"
                                Object         = "$($itemTable.Schema).$($itemTable.Name)"
                                Notes          = "Copied $($rowCountDest) of $($rowCountSource) rows"
                                ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                            }
                        }

                        $stopwatchObject.Reset()
                    } # End for each table
                }
                else {
                        [PSCustomObject]@{
                            SourceSqlInstance        = $sourceServer
                            SourceSqlCredential      = $SourceSqlCredential
                            DestinationSqlInstance   = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            ObjectType               = "Table"
                            Parent                   = "N/A"
                            Object                   = "$($itemTable.Schema).$($itemTable.Name)"
                            Notes                    = "No rows to copy"
                            ElapsedSeconds           = $null
                    }
                }

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
                        SourceDatabase           = $sourceDb.Name
                        DestinationDatabase      = $destDb.Name
                        EnableException          = $true
                    }

                    Copy-DbrDbIndex @params

                    $destDb.Refresh()
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
                        SourceDatabase           = $sourceDb.Name
                        DestinationDatabase      = $destDb.Name
                        EnableException          = $true
                    }

                    Copy-DbrDbForeignKey @params

                    $destDb.Refresh()
                }
                #}

                #endregion table copy

                #endregion remove object

            } # end for each destination instance

        } #end for each item

        $stopwatchTotal.Stop()


    }

    end {
        # Output summary
        $totalTime = $stopwatchTotal.Elapsed

        $totalTimeMessage = "Total time:   $($totalTime.Hours) hour(s), $($totalTime.Minutes) minute(s), $([Math]::Truncate($totalTime.Seconds)) second(s)"

        Write-PSFMessage -Level Output -Message "Total databases refreshed: $($items.databases.Count)"
        Write-PSFMessage -Level Output -Message "Database(s):  $($items.databases.destinationdatabase -join ",")"
        Write-PSFMessage -Level Output -Message $totalTimeMessage

        if (Test-PSFFunctionInterrupt) { return }
    }

}