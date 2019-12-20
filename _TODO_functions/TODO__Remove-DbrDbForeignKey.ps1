function Remove-DbrDbForeignKey {

    <#
    .SYNOPSIS
        Remove the foreign keys

    .DESCRIPTION
        Remove the foreign keys in a table

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
        Remove-DbrDbForeignKey -SqlInstance sqldb1 -Database DB1

        Remove all the tables from the database

    .EXAMPLE
        Remove-DbrDbForeignKey -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

        Remove all the tables from the database with the name TABLE1 and TABLE2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string]$Schema,
        [string[]]$Table,
        [string[]]$ForeignKey,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        # Get the tables
        $tables = $db.Tables | Select-Object Schema, Name, ForeignKeys

        # Filter out the tables based on schema
        if ($Schema) {
            $tables = $tables | Where-Object Schema -eq $Schema
        }

        # Filter out the tables based on name
        if ($Table) {
            $tables = $tables | Where-Object Name -in $Table
        }

        if ($ForeignKey) {
            $foreignKeys = $tables.ForeignKeys | Where-Object Name -in $ForeignKey
        }
        else {
            $foreignKeys = $tables.ForeignKeys | Select-Object Name
        }
    }

    process {
        $totalObjects = $foreignKeys.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing foreign keys in database $Database")) {

                $task = "Removing Foreign Key(s)"

                foreach ($object in $foreignKeys) {
                    $objectStep++
                    $operation = "Foreign Key [$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Foreign Key $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Dropping foreign key $($object.Name)"
                    try {
                        ($tables.ForeignKeys | Where-Object Name -eq $object.Name).Drop()

                        #$object.Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop foreign key $object" -Target $Database -ErrorRecord $_
                    }
                }
            }
        }
    }
}

