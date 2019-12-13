function Start-DbrDbRefresh {

    <#
    .SYNOPSIS
        Start the database refresh

    .DESCRIPTION
        Start the database refresh going through all the tables

    .PARAMETER SourceSqlInstance
        The source target SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target source instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target destination SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target destination instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER FilterDatabase
        Which filter database to use. The default is "DevFilters"

    .PARAMETER Database
        Database(s) to copy data from

    .PARAMETER BatchSize
        Size of the batch to use. Default is 50000

    .PARAMETER Timeout
        Timeout of the bulk copy. Default is 30 seconds.

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
        Default "DatabaseRefresh"

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER Force
        Forcefully remove jobs when they're present

    .EXAMPLE
        Start-DbrDbRefresh -SourceSqlInstance sqldb1 -DestinationSqlInstance sqldb2 -Database DB1

        Start the provisioning of database DB1 from instance "sqldb1" to "sqldb2"

    .EXAMPLE
        Start-DbrDbRefresh -SourceSqlInstance sqldb1 -DestinationSqlInstance sqldb2, -Database DB1, DB2, DB3

        Start the provisioning of multiple databases from instance "sqldb1" to "sqldb2"

    .EXAMPLE
        Start-DbrDbRefresh -SourceSqlInstance sqldb1 -DestinationSqlInstance sqldb2, sqldb3 -Database DB1, DB2, DB3

        Start the provisioning of multiple databases from instance "sqldb1" to multiple instances
    #>

    [CmdLetBinding(SupportsShouldProcess)]
    [OutputType('System.Object[]')]

    param(
        [DbaInstanceParameter]$SourceSqlInstance,
        [PSCredential]$SourceSqlCredential,
        [DbaInstanceParameter[]]$DestinationSqlInstance,
        [PSCredential]$DestinationSqlCredential,
        [string]$FilterDatabase = "DevFilters",
        [string[]]$Database,
        [int]$BatchSize = 50000,
        [int]$Timeout = 300000,
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
        [switch]$EnableException,
        [switch]$Force
    )

    begin {
        if (-not $SourceSqlInstance) {
            Stop-PSFFunction -Message "Please enter a source sql server instance" -Target $SqlInstance
        }

        if (-not $DestinationSqlInstance) {
            Stop-PSFFunction -Message "Please enter a destination sql server instance" -Target $SqlInstance
        }

        if ($SourceSqlInstance -in $DestinationSqlInstance) {
            Stop-PSFFunction -Message "You cannot enter the source server in the destination" -Target $SqlInstance
        }

        if(-not $ClientName){
            $ClientName = "DatabaseRefresh"
        }

        try {
            $sourceServer = Connect-DbaInstance -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -ClientName $ClientName -MultipleActiveResultSets
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to $SourceSqlInstance" -Target $SourceSqlInstance -ErrorRecord $_ -Category ConnectionError
            return
        }

        $stopwatchTotal = New-Object System.Diagnostics.Stopwatch
        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $results = @()
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Start the stopwatch
        $stopwatchTotal.Start()

        #region instance

        # Loop through each of the destination instances
        foreach ($destInstance in $DestinationSqlInstance) {

            # Connect to server
            try {
                $destServer = Connect-DbaInstance -SqlInstance $destInstance -SqlCredential $DestinationSqlCredential -ClientName $ClientName -MultipleActiveResultSets
            }
            catch {
                Stop-PSFFunction -Message "Could not connect to $destInstance" -Target $destInstance -ErrorRecord $_ -Category ConnectionError
            }

            # Start the job to set the ranges
            try {
                Write-PSFMessage -Level Host -Message "Starting job 'DevRepRanges2forDevelopers' on $destInstance"

                $result = Start-DbaAgentJob -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Job "DevRepRanges2forDevelopers" -EnableException

                # Check if the run was successfull
                if ($result.LastRunOutcome -ne 'Succeeded') {
                    Write-PSFMessage -Level Warning -Message "Outcome of job execution was not successfull"
                }
            }
            catch {
                Stop-PSFFunction -Message "Could not start job 'DevRepRanges2forDevelopers' on $destInstance" -Target $destInstance -ErrorRecord $_
            }

            # Retrieve the databases
            $sourceDatabases = $sourceServer.Databases | Where-Object Name -in $Database
            $destDatabases = $destServer.Databases

            $totalSteps = 15
            $currentStep = 1
            $progressId = 1

            $dbCount = $sourceDatabases.Count
            $dbStep = 0

            #region database

            # Loop through the source databases
            foreach ($db in $sourceDatabases) {

                $dbStep++
                $task = "Refreshing database $($db.Name)"
                Write-Progress -Id 1 -Activity $task -Status 'Progress->' -PercentComplete $($dbStep / $dbCount * 100)

                Write-PSFMessage -Level Host -Message "Provisioning $($db.Name) from $sourceServer to $destServer"

                # Create the database when it's not present
                if ($db.Name -notin $destDatabases.Name) {
                    if ($db.Name -like "LD*") {
                        try {
                            Write-PSFMessage -Level Verbose -Message "Database $($db.Name) doesn't exist. Creating it.."
                            $query = "SELECT [lab_id] AS LabID FROM [Lims].[dbo].[lab_id]"
                            $labID = $destServer.Query($query)
                            $labIdString = "'" + (($labID | Select-Object LabID -ExpandProperty LabID) -join "','") + "'"
                            New-DbrLDDatabase -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -LabID $labIdString -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not create database $($db.name)" -ErrorRecord $_ -Target $destInstance
                        }
                    }
                    else {
                        try {
                            Write-PSFMessage -Level Verbose -Message "Database $($db.Name) doesn't exist. Creating it.."
                            New-DbrDatabase -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not create database $($db.name)" -ErrorRecord $_ -Target $destInstance
                        }
                    }
                }

                # Get the filters
                $query = "SELECT * FROM [dbo].[TableFilters] WHERE dbname = '$($db.Name)'"

                try {
                    $tableFilters = Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $FilterDatabase -Query $query -EnableException | ConvertTo-DbaDataTable
                }
                catch {
                    Stop-PSFFunction -Message "Could not retrieve table filters on $destInstance" -Target $destInstance -ErrorRecord $_ -Continue
                }

                #region object drop

                # Drop all views
                if(-not $SkipViewDrop){
                    $currentStep = 2

                    $params = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing Views"
                    }

                    Write-Progress @params

                    if (-not $SkipView) {
                        try {
                            Remove-DbrDbView -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the views" -Target $function -ErrorRecord $_
                        }
                    }
                }

                # Drop all stored procedures
                if(-not $SkipProcedureDrop){
                    $currentStep = 3

                    $params = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing Stored Procedures"
                    }

                    Write-Progress @params

                    if (-not $SkipProcedure) {
                        try {
                            Remove-DbrDbStoredProcedure -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the stored procedures" -Target $function -ErrorRecord $_
                        }
                    }
                }

                # Drop all user defined functions
                if(-not $SkipFunctionDrop){
                    $currentStep = 4

                    $params = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing User Defined Functions"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        try {
                            Remove-DbrDbFunction -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the functions" -Target $function -ErrorRecord $_
                        }
                    }
                }

                # Drop all user defined data types
                if(-not $SkipDataTypeDrop){
                    $currentStep = 5

                    $params = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing User Defined Data Types"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        try {
                            Remove-DbrDbDataType -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the functions" -Target $function -ErrorRecord $_
                        }
                    }
                }

                # Drop all user defined table types
                if(-not $SkipTableTypeDrop){
                    $currentStep = 6

                    $params = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing User Defined Table Types"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        try {
                            Remove-DbrDbTableType -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the functions" -Target $function -ErrorRecord $_
                        }
                    }
                }

                # Drop all schemas
                if(-not $SkipSchemaDrop){
                    $currentStep = 7

                    $params = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Removing Schemas"
                    }

                    Write-Progress @params

                    if (-not $SkipFunction) {
                        try {
                            Remove-DbrDbSchema -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the schemas" -Target $function -ErrorRecord $_
                        }
                    }
                }

                #endregion object drop

                #region object copy

                #region schema copy

                if(-not $SkipSchemaDrop){
                    $params = @{
                        SourceSqlInstance = $sourceServer
                        SourceSqlCredential = $SourceSqlCredential
                        DestinationSqlInstance = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        EnableException = $true
                    }

                    Copy-DbrDbSchema @params

                    $destServer.Databases[$db.Name].Refresh()
                }

                #endregion schema copy

                #region table copy

                $currentStep = 8

                $params = @{
                    Id = ($progressId + 1)
                    ParentId = $progressId
                    Activity = "Refreshing database"
                    Status = 'Progress->'
                    PercentComplete = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Processing Tables"
                }

                Write-Progress @params

                if (-not $SkipTable) {

                    $sourceTables = $db.Tables

                    $copyParams = @{
                        SqlInstance = $sourceServer
                        SqlCredential = $SourceSqlCredential
                        Destination = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        AutoCreateTable = $false
                        BatchSize = $BatchSize
                        BulkCopyTimeOut = $Timeout
                        KeepIdentity = $true
                        KeepNulls = $true
                        Table = $null
                        Truncate = $false
                        Query = $null
                        EnableException = $true
                    }

                    if(-not $SkipTableDrop){
                        $task = "Removing tables"
                        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task
                        # Remove the tables
                        try {
                            Remove-DbrDbForeignKey -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException

                            Remove-DbrDbTable -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -EnableException
                        }
                        catch {
                            Stop-PSFFunction -Message "Something went wrong dropping the tables" -Target $function -ErrorRecord $_
                        }
                    }

                    $totalObjects = $sourceTables.Count
                    $objectStep = 0

                    if($SkipData){
                        $task = "Creating tables"
                    }
                    else{
                        $task = "Creating tables and copying data"
                    }

                    if(-not $SkipTableDrop){
                        $params = @{
                            SourceSqlInstance = $sourceServer
                            SourceSqlCredential = $SourceSqlCredential
                            DestinationSqlInstance = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            Database = $db.Name
                            EnableException = $true
                        }

                        Copy-DbrDbTable @params

                        $destServer.Databases[$db.Name].Tables.Refresh()
                    }

                    $objectStep = 0

                    foreach ($table in $sourceTables) {
                        $objectStep++
                        $operation = "Table [$($table.Schema)].[$($table.Name)]"

                        $progressParams = @{
                            Id = ($progressId + 2)
                            ParentId = ($progressId + 1)
                            Activity = $task
                            Status = "Progress-> Table $objectStep of $totalObjects"
                            PercentComplete = $($objectStep / $totalObjects * 100)
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

                            if ($db.Name -eq "lab_docs" -and $table.Name -eq "images") {
                                #### Run the lab_docs specific queries

                                ## Get the low and high date
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__FilterDatabase_LowHighDate.sql" -Raw
                                $query = $query -replace ("___FILTERDATABASE___"), $FilterDatabase

                                $lowHighDate = Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $SqlCredential -Query $query

                                ## Get the lab id list
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__FilterDatabase_LabIdList.sql" -Raw
                                $query = $query -replace ("___FILTERDATABASE___"), $FilterDatabase

                                $result = Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $SqlCredential -Query $query
                                $labIdList = "'" + ($result.LabId -join "','") + "'"

                                ## Run the query for the Lims reports
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__LabDocs_LimsReports.sql" -Raw
                                $query = $query -replace ("___LOWDATE___"), $lowHighDate.LowDate

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [lab_docs].[dbo].[images] from Lims"

                                    $copyParams.Query = $query
                                    $results += Copy-DbaDbTableData @copyParams
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($table.Schema)].[$($table.Name)]" -Target $destTable -ErrorRecord $_
                                }

                                ## Run the query for the History reports
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__LabDocs_HistoryReports.sql" -Raw
                                $query = $query -replace ("___LOWDATE___"), $lowHighDate.LowDate

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [lab_docs].[dbo].[images] from History"

                                    $copyParams.Query = $query
                                    $results += Copy-DbaDbTableData @copyParams
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($table.Schema)].[$($table.Name)]" -Target $destTable -ErrorRecord $_
                                }

                                ## Run the query for the lab_docs reports
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__LabDocs_LDReports.sql" -Raw
                                $query = $query -replace ("___LABIDLIST___"), $labIdList
                                $query = $query -replace ("___LOWDATE___"), $lowHighDate.LowDate

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [lab_docs].[dbo].[images] from lab_docs"

                                    $copyParams.Query = $query
                                    $results += Copy-DbaDbTableData @copyParams
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($table.Schema)].[$($table.Name)]" -Target $destTable -ErrorRecord $_
                                }

                            }
                            elseif ($db.Name -like "LD*") {
                                ## Get the blob links
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__LD_BlobLink.sql" -Raw
                                $query = $query -replace ("___DATABASE___"), $db.Name
                                $query = $query -replace ("___TABLE___"), $table.Name

                                $result = Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $SqlCredential -Query $query
                                $blobLinkList = "'" + ($result.BlobLink -join "','") + "'"

                                # Get the blobs
                                $query = Get-Content -Path "$ModuleRoot\internal\scripts\sqlscripts\Query__LD_Blob.sql" -Raw

                                $columnString = "[" + $(($table.Columns | Where-Object Computed -eq $false | Sort-Object ID).Name -join "],[") + "]"
                                $query = $query -replace ("___COLUMNSTRING___"), $columnString
                                $query = $query -replace ("___DATABASE___"), $db.Name
                                $query = $query -replace ("___SCHEMA___"), $table.Schema
                                $query = $query -replace ("___TABLE___"), $table.Name
                                $query = $query -replace ("___BLOBLINK___"), $blobLinkList

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [$($table.Schema)].[$($table.Name)]"

                                    $copyParams.Query = $query
                                    $results += Copy-DbaDbTableData @copyParams
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($table.Schema)].[$($table.Name)]" -Target $destTable -ErrorRecord $_
                                }
                            }
                            else {
                                $columnString = "[" + $(($table.Columns | Where-Object Computed -eq $false | Sort-Object ID).Name -join "],[") + "]"
                                $query = "SELECT $columnString FROM [$($db.Name)].[$($table.Schema)].[$($table.Name)] "

                                # Check if a filter needs to be applied
                                if ($null -ne $tableFilters.rowfilter -and $table.Name -in $tableFilters.tabname ) {
                                    $filter = $tableFilters | Where-Object tabname -eq $table.Name | Select-Object rowfilter -ExpandProperty rowfilter

                                    if ($filter.ToString().Length -ge 1) {
                                        $query += "WHERE $($tableFilters | Where-Object tabname -eq $table.Name | Select-Object rowfilter -ExpandProperty rowfilter)"
                                    }
                                }

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Copying data for table [$($table.Schema)].[$($table.Name)]"

                                    $copyParams.Query = $query
                                    $results += Copy-DbaDbTableData @copyParams
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not copy data for table [$($table.Schema)].[$($table.Name)]" -Target $table -ErrorRecord $_
                                }
                            }

                            [int]$rowCountDest = $destDatabases[$db.Name].Tables[$table.Name].RowCount
                            Write-PSFMessage -Level Verbose -Message "Row Count Source:         $($rowCountSource)"
                            Write-PSFMessage -Level Verbose -Message "Row Count Destination:    $($rowCountDest)"

                            [PSCustomObject]@{
                                SqlInstance    = $destInstance
                                Database       = $db.Name
                                ObjectType     = "Table"
                                Parent         = "N/A"
                                Object         = "$($table.Schema).$($table.Name)"
                                Information    = "Copied $($rowCountDest) of $($rowCountSource) rows"
                                ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                            }

                        } else{
                            if(-not ($destServer.Databases[$db.Name].Tables | Where-Object {$_.Schema -eq $table.Schema -and $_.Name -eq $table.Name})){
                                $query = Export-DbaScript -InputObject $table -Passthru -NoPrefix

                                try {
                                    Write-PSFMessage -Level Verbose -Message "Creating table [$($table.Schema)].[$($table.Name)]"

                                    Invoke-DbaQuery -SqlInstance $destServer -SqlCredential $DestinationSqlCredential -Database $db.Name -Query $query -EnableException
                                }
                                catch {
                                    Stop-PSFFunction -Message "Could not create table [$($table.Schema)].[$($table.Name)]" -Target $table -ErrorRecord $_
                                }

                                [PSCustomObject]@{
                                    SqlInstance    = $destInstance
                                    Database       = $db.Name
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

                    #$db.Refresh()

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
                        CurrentOperation = "Creating User Defined Data Types"
                    }

                    Write-Progress @progressParams

                    $params = @{
                        SourceSqlInstance = $sourceServer
                        SourceSqlCredential = $SourceSqlCredential
                        DestinationSqlInstance = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        EnableException = $true
                    }

                    Copy-DbrDbIndex @params

                    #$db.Refresh()

                    $currentStep = 10

                    $progressParams = @{
                        Id = ($progressId + 1)
                        ParentId = $progressId
                        Activity = "Refreshing database"
                        Status = 'Progress->'
                        PercentComplete = $($currentStep / $totalSteps * 100)
                        CurrentOperation = "Creating Foreign Keys"
                    }

                    Write-Progress @progressParams

                    $params = @{
                        SourceSqlInstance = $sourceServer
                        SourceSqlCredential = $SourceSqlCredential
                        DestinationSqlInstance = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        EnableException = $true
                    }

                    Copy-DbrDbForeignKey @params

                    #$db.Refresh()
                }

                #endregion table copy

                # Get the user defined data types from the source database
                $currentStep = 11

                $progressParams = @{
                    Id               = ($progressId + 1)
                    ParentId         = $progressId
                    Activity         = "Refreshing database"
                    Status           = 'Progress->'
                    PercentComplete  = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Creating User Defined Data Types"
                }

                Write-Progress @progressParams

                if(-not $SkipUserDefinedDataType){
                    $params = @{
                        SourceSqlInstance = $sourceServer
                        SourceSqlCredential = $SourceSqlCredential
                        DestinationSqlInstance = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        EnableException = $true
                    }

                    Copy-DbrDbDataType @params

                    #$db.Refresh()
                }

                # Get the user defined table types from the source database
                $currentStep = 12

                $progressParams = @{
                    Id               = ($progressId + 1)
                    ParentId         = $progressId
                    Activity         = "Refreshing database"
                    Status           = 'Progress->'
                    PercentComplete  = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Creating User Defined Table Types"
                }

                Write-Progress @progressParams

                if(-not $SkipUserDefinedTableType){
                    $params = @{
                        SourceSqlInstance = $sourceServer
                        SourceSqlCredential = $SourceSqlCredential
                        DestinationSqlInstance = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        EnableException = $true
                    }

                    Copy-DbrDbTableType @params

                    #$db.Refresh()
                }


                # Get the views from the source database
                $currentStep = 13

                $progressParams = @{
                    Id               = ($progressId + 1)
                    ParentId         = $progressId
                    Activity         = "Refreshing database"
                    Status           = 'Progress->'
                    PercentComplete  = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Creating Views"
                }

                Write-Progress @progressParams

                if (-not $SkipView) {

                    $params = @{
                        SourceSqlInstance = $sourceServer
                        SourceSqlCredential = $SourceSqlCredential
                        DestinationSqlInstance = $destServer
                        DestinationSqlCredential = $DestinationSqlCredential
                        Database = $db.Name
                        EnableException = $true
                    }

                    Copy-DbrDbView @params

                    #$db.Refresh()
                }

                # Get the stored procedures from the source database
                $currentStep = 14

                $progressParams = @{
                    Id               = ($progressId + 1)
                    ParentId         = $progressId
                    Activity         = "Refreshing database"
                    Status           = 'Progress->'
                    PercentComplete  = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Creating Stored Procedures"
                }

                Write-Progress @progressParams

                if (-not $SkipProcedure) {
                    try {
                        $params = @{
                            SourceSqlInstance = $sourceServer
                            SourceSqlCredential = $SourceSqlCredential
                            DestinationSqlInstance = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            Database = $db.Name
                            EnableException = $true
                        }

                        Copy-DbrDbStoredProcedure @params

                        #$db.Refresh()
                    }
                    catch {
                        Stop-PSFFunction -Message "Something went wrong copying the stored procedures" -Target $sourceServer -ErrorRecord $_
                    }
                }

                # Get the user defined functions from the source database
                $currentStep = 15

                $progressParams = @{
                    Id               = ($progressId + 1)
                    ParentId         = $progressId
                    Activity         = "Refreshing database"
                    Status           = 'Progress->'
                    PercentComplete  = $($currentStep / $totalSteps * 100)
                    CurrentOperation = "Creating User Defined Functions"
                }

                Write-Progress @progressParams

                if (-not $SkipFunction) {
                    try {
                        $params = @{
                            SourceSqlInstance = $sourceServer
                            SourceSqlCredential = $SourceSqlCredential
                            DestinationSqlInstance = $destServer
                            DestinationSqlCredential = $DestinationSqlCredential
                            Database = $db.Name
                            EnableException = $true
                        }

                        Copy-DbrDbFunction @params

                        #$db.Refresh()
                    }
                    catch {
                        Stop-PSFFunction -Message "Something went wrong copying the user defined functions" -Target $sourceServer -ErrorRecord $_
                    }
                }

                #endregion object copy

            }

            #endregion database

            $stopwatchTotal.Stop()

            # Output summary
            $totalTime = $stopwatchTotal.Elapsed

            $totalTimeMessage = "Total time:   $($totalTime.Hours) hour(s), $($totalTime.Minutes) minute(s), $([Math]::Truncate($totalTime.Seconds)) second(s)"

            Write-PSFMessage -Level Output -Message "Total databases refreshed: $($sourceDatabases.Count)"
            Write-PSFMessage -Level Output -Message "Database(s):  $($sourceDatabases.Name -join ",")"
            Write-PSFMessage -Level Output -Message $totalTimeMessage

        } # End for each destination instance

        #endregion instance

    } # End process

    end {
        if (Test-PSFFunctionInterrupt) { return }
    }

}