function Remove-DbrDbTable {

    <#
    .SYNOPSIS
        Remove the tables

    .DESCRIPTION
        Remove the tables in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the tables from

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
        Remove-DbrDbTable -SqlInstance sqldb1 -Database DB1

        Remove all the tables from the database

    .EXAMPLE
        Remove-DbrDbTable -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

        Remove all the tables from the database with the name TABLE1 and TABLE2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string[]]$Schema,
        [string[]]$Table,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        # Get the tables
        $tables = @()
        $tables += $db.Tables | Select-Object Schema, Name, ForeignKeys | Sort-Object Schema, Name

        # Filter out the tables based on schema
        if ($Schema) {
            [array]$tables = $tables | Where-Object Schema -in $Schema
        }

        # Filter out the tables based on name
        if ($Table) {
            [array]$tables = $tables | Where-Object Name -in $Table
        }
    }

    process {
        $totalObjects = $tables.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing tables in database $Database")) {

                $progressId = 1

                $task = "Removing Table(s)"

                foreach ($object in $tables) {
                    Write-PSFMessage -Level Verbose -Message "Retrieving referenced columns for table [$($object.Schema)].[$($object.Name)] in [$($db.Name)]"

                    $params = @{
                        SqlInstance     = $SqlInstance
                        SqlCredential   = $SqlCredential
                        Database        = $Database
                        Schema          = $object.Schema
                        Table           = $object.Name
                        EnableException = $true
                    }

                    [array]$foreignKeys = Get-DbrDbForeignKey @params

                    if ($foreignKeys.Count -ge 1) {
                        Write-PSFMessage -Message "Dropping referenced foreign keys for table [$($object.Schema)].[$($object.Name)]"

                        $params = @{
                            SqlInstance     = $SqlInstance
                            SqlCredential   = $SqlCredential
                            Database        = $Database
                            ForeignKey      = $foreignKeys.ConstraintName
                            EnableException = $true
                        }

                        Remove-DbrDbForeignKey @params

                        $db.Tables.Refresh()
                    }

                    if ($object.ForeignKeys.Count -ge 1) {
                        Write-PSFMessage -Message "Dropping foreign keys for table [$($object.Schema)].[$($object.Name)]"

                        $params = @{
                            SqlInstance     = $SqlInstance
                            SqlCredential   = $SqlCredential
                            Database        = $Database
                            Schema          = $object.Schema
                            Table           = $object.Name
                            EnableException = $true
                        }

                        Remove-DbrDbForeignKey @params

                        $db.Tables.Refresh()
                    }

                    $db.Refresh()

                    $objectStep++
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

                    Write-PSFMessage -Level Verbose -Message "Dropping table [$($object.Schema)].[$($object.Name)] in [$($db.Name)]"

                    try {
                        ($db.Tables | Where-Object { $_.Schema -eq $object.Schema -and $_.Name -eq $object.Name }).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop table in $Database" -Target $object -ErrorRecord $_
                    }
                }
            }
        }
    }
}

