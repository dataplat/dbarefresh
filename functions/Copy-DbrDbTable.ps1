function Copy-DbrDbTable {

    <#
    .SYNOPSIS
        Copy the tables

    .DESCRIPTION
        Copy the tables in a database

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

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Copy-DbrDbTable -SqlInstance sqldb1 -Database DB1

        Copy all the tables from the database

    .EXAMPLE
        Copy-DbrDbTable -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

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

        try {
            # Connect to the source instance
            $sourceServer = Connect-DbaInstance -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential
        }
        catch {
            Stop-PSFFunction -Message "Could not connect to instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        $tables = @()
        $tables += $sourceServer.Databases[$SourceDatabase].Tables | Sort-Object Schema, Name

        # Filter out the tables based on schema
        if ($Schema) {
            $tables = $tables | Where-Object Schema -in $Schema
        }

        # Filter out the tables based on name
        if ($Table) {
            $tables = $tables | Where-Object Name -in $Table
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $tables.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying tables to database $DestinationDatabase")) {
                $task = "Creating Table(s)"
                $query = New-Object System.Text.StringBuilder

                foreach ($object in $tables) {
                    $objectStep++

                    if ($destinationDb.Tables.Name -notcontains $object.Name) {
                        $operation = "Table [$($object.Schema)].[$($object.Name)]"

                        $params = @{
                            Id               = ($progressId + 2)
                            ParentId         = ($progressId + 1)
                            Activity         = $task
                            Status           = "Progress-> Table $objectStep of $totalObjects"
                            PercentComplete  = $($objectStep / $totalObjects * 100)
                            CurrentOperation = $operation
                        }

                        Write-Progress @params

                        Write-PSFMessage -Level Verbose -Message "Creating table script for [$($object.Schema)].[$($object.Name)]"

                        $null = $query.AppendLine("$($object | Export-DbaScript -Passthru -NoPrefix | Out-String)`n")

                        foreach ($column in $object.Columns) {
                            if ($column.DefaultConstraint.Text) {
                                Write-PSFMessage -Level Verbose -Message "Creating default constraint script for [$($object.Schema)].[$($object.Name)].[$($column.Name)]"
                                $null = $query.AppendLine("$($column.DefaultConstraint | Export-DbaScript -Passthru -NoPrefix | Out-String)`n")
                            }
                        }
                    }
                }

                if ($query.Length -ge 1) {
                    try {
                        Write-PSFMessage -Level Verbose -Message "Executing table script"
                        Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase -Query ($query.ToString()) -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute table script" -Target $query -ErrorRecord $_
                    }
                }
                else {
                    Write-PSFMessage -Level Warning -Message "Query was empty" -Target $object
                }
            }
        }
    }
}