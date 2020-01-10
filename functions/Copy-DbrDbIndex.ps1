function Copy-DbrDbIndex {

    <#
    .SYNOPSIS
        Copy the table indexes

    .DESCRIPTION
        Copy the table indexes in a database

    .PARAMETER SourceSqlInstance
        The source SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER SourceDatabase
        Database to copy the user defined data types from

    .PARAMETER DestinationDatabase
        Database to copy the user defined data types to

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Table
        Table to filter out

    .PARAMETER Index
        Index to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Copy-DbrDbIndex -SqlInstance sqldb1 -Database DB1

        Copy all the tables from the database

    .EXAMPLE
        Copy-DbrDbIndex -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

        Copy all the tables from the database with the name TABLE1 and TABLE2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SourceSqlInstance,
        [PSCredential]$SourceSqlCredential,
        [parameter(Mandatory)]
        [DbaInstanceParameter]$DestinationSqlInstance,
        [PSCredential]$DestinationSqlCredential,
        [parameter(Mandatory)]
        [string]$SourceDatabase,
        [string]$DestinationDatabase,
        [string[]]$Schema,
        [string[]]$Table,
        [string[]]$Index,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Check the parameters
        if (-not $DestinationDatabase) {
            Write-PSFMessage -Message "Setting destination database to '$($SourceDatabase)'" -Level Verbose
            $DestinationDatabase = $SourceDatabase
        }

        if (($DestinationDatabase -eq $SourceDatabase) -and ($SourceSqlInstance -eq $DestinationSqlInstance)) {
            Stop-PSFFunction -Message "Please enter a destination database when copying on the same instance" -Target $DestinationDatabase
            return
        }

        # Get the database
        try {
            $sourceDb = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $SourceDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        try {
            $destDb = Get-DbaDatabase -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from destination instance" -ErrorRecord $_ -Target $DestinationSqlInstance
        }

        [array]$sourceTables = $sourceDb.Tables | Sort-Object Schema, Name

        # Filter out the indexes based on schema
        if ($Schema) {
            $sourceTables = @()
            [array]$sourceTables = $sourceTables | Where-Object Schema -in $Schema
        }

        # Filter out the indexes based on name
        if ($Table) {
            [array]$sourceTables = $sourceTables | Where-Object Name -in $Table
        }

        if ($Index) {
            [array]$indexes = $sourceTables.Indexes | Where-Object Name -in $Index | Sort-Object Name
        }
        else {
            [array]$indexes = $sourceTables.Indexes | Sort-Object Name
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $indexes.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying indexes to database $Database")) {

                $task = "Creating Index(es)"

                foreach ($object in $indexes) {

                    if ($object.Name -notin $destDb.Tables.Indexes.Name) {
                        $objectStep++
                        $operation = "Index [$($object.Name)]"

                        $progressParams = @{
                            Id               = ($progressId + 2)
                            ParentId         = ($progressId + 1)
                            Activity         = $task
                            Status           = "Progress-> Index $objectStep of $totalObjects"
                            PercentComplete  = $($objectStep / $totalObjects * 100)
                            CurrentOperation = $operation
                        }

                        Write-Progress @progressParams

                        Write-PSFMessage -Level Verbose -Message "Creating index $object for $($object.Parent)"

                        try {
                            $query = $object | Export-DbaScript -Passthru -NoPrefix | Out-String

                            $params = @{
                                SqlInstance     = $DestinationSqlInstance
                                SqlCredential   = $DestinationSqlCredential
                                Database        = $DestinationDatabase
                                Query           = $query
                                EnableException = $true
                            }

                            Invoke-DbaQuery @params
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not execute script for index $object" -ErrorRecord $_ -Target $object
                        }

                        [PSCustomObject]@{
                            SourceSqlInstance      = $SourceSqlInstance
                            DestinationSqlInstance = $DestinationSqlInstance
                            SourceDatabase         = $SourceDatabase
                            DestinationDatabase    = $DestinationDatabase
                            ObjectType             = "Index"
                            Parent                 = $object.Parent
                            Object                 = "$($object.Name)"
                            Notes                  = $null
                        }
                    }
                    else {
                        Write-PSFMessage -Message "Index [$($object.Name)] already exists. Skipping..." -Level Verbose
                    }
                }
            }
        }
    }
}