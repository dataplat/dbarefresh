function Copy-DbrDbForeignKey {

    <#
    .SYNOPSIS
        Copy the table foreign keys

    .DESCRIPTION
        Copy the table foreign keys in a database

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

    .PARAMETER ForeignKey
        Foreign key to filter out

    .PARAMETER Force
        If set, the command will remove any objects that are present prior to creating them

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Copy-DbrDbForeignKey -SqlInstance sqldb1 -Database DB1

        Copy all the tables from the database

    .EXAMPLE
        Copy-DbrDbForeignKey -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

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
        [string[]]$ForeignKey,
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
            Stop-PSFFunction -Message "Please enter a destination database when copying on the same instance" -Target $DestinationDatabase -EnableException:$EnableException
            return
        }

        # Get the database
        try {
            $sourceDb = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $SourceDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from source instance" -ErrorRecord $_ -Target $SourceSqlInstance -EnableException:$EnableException
        }

        try {
            $destDb = Get-DbaDatabase -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from destination instance" -ErrorRecord $_ -Target $DestinationSqlInstance -EnableException:$EnableException
        }

        [array]$sourceTables = $sourceDb.Tables

        # Filter out the foreign keys based on schema
        if ($Schema) {
            [array]$sourceTables = $sourceTables | Where-Object Schema -in $Schema
        }

        # Filter out the foreign keys based on table
        if ($Table) {
            [array]$sourceTables = $sourceTables | Where-Object Name -in $Table
        }

        # Filter out the foreign keys based on table
        if ($ForeignKey) {
            [array]$foreignKeys = $sourceTables.ForeignKeys | Where-Object Name -in $ForeignKey
        }
        else {
            [array]$foreignKeys = $sourceTables.ForeignKeys
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $foreignKeys.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying foreign keys to database $Database")) {

                $query = $null

                $task = "Creating Foreign Key(s)"

                foreach ($object in $foreignKeys) {

                    if ($destDb.Tables | Where-Object { $_.Schema -eq $object.Parent.Schema -and $_.Name -eq $object.Parent.Name }) {

                        if ($Force -and ($object.Name -in $destDb.Tables.ForeignKeys.Name)) {
                            $params = @{
                                SqlInstance   = $DestinationSqlInstance
                                SqlCredential = $DestinationSqlCredential
                                Database      = $DestinationDatabase
                                ForeignKey    = $object.Name
                            }

                            Remove-DbrDbForeignKey @params
                        }

                        if ($object.Name -notin $destDb.Tables.ForeignKeys.Name) {

                            $objectStep++
                            $operation = "Foreign Key [$($object.Name)]"

                            $progressParams = @{
                                Id               = ($progressId + 2)
                                ParentId         = ($progressId + 1)
                                Activity         = $task
                                Status           = "Progress-> Foreign Key $objectStep of $totalObjects"
                                PercentComplete  = $($objectStep / $totalObjects * 100)
                                CurrentOperation = $operation
                            }

                            Write-Progress @progressParams

                            Write-PSFMessage -Level Verbose -Message "Creating foreign key $object for $($object.Parent)"

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
                                Stop-PSFFunction -Message "Could not execute script for foreign key $object" -ErrorRecord $_ -Target $object -EnableException:$EnableException
                            }

                            [PSCustomObject]@{
                                SourceSqlInstance      = $SourceSqlInstance
                                DestinationSqlInstance = $DestinationSqlInstance
                                SourceDatabase         = $SourceDatabase
                                DestinationDatabase    = $DestinationDatabase
                                ObjectType             = "Foreign Key"
                                Parent                 = $object.Parent
                                Object                 = "$($object.Name)"
                                Notes                  = $null
                            }
                        }
                        else {
                            Write-PSFMessage -Message "Foreign key [$($object.Name)] already exists. Skipping..." -Level Verbose
                        }
                    }
                    else {
                        Stop-PSFFunction -Message "Foreign key could not created. Table [$($object.Parent.Schema)].[$($object.Parent.Name)] does not exist" -Target $object
                    }
                }
            }
        }
    }
}