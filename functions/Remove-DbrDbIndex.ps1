function Remove-DbrDbIndex {
    <#
    .SYNOPSIS
        Remove the indexs

    .DESCRIPTION
        Remove the indexs in a table

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
        Remove-DbrDbIndex -SqlInstance sqldb1 -Database DB1

        Remove all the indexs from the database

    .EXAMPLE
        Remove-DbrDbIndex -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

        Remove all the indexs from the tables from the database with the name TABLE1 and TABLE2

    .EXAMPLE
        Remove-DbrDbIndex-SqlInstance sqldb1 -Database DB1 -ForeignKey index1, index2

        Remove all the Index with the names index1 and index2

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
        [string[]]$Index,
        [switch]$EnableException
    )

    begin {

        $progressId = 1

        # Connect to the source instance
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        $db = $server.Databases[$Database]

        $task = "Removing Indexs"

        # Filter out the user defined data type based on schema
        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        # Get the tables
        [array]$tables = $db.Tables | Select-Object Schema, Name, Indexes

        # Filter out the tables based on schema
        if ($Schema) {
            [array]$tables = $tables | Where-Object Schema -in $Schema
        }

        # Filter out the tables based on name
        if ($Table) {
            [array]$tables = $tables | Where-Object Name -in $Table
        }

        if ($Index) {
            [array]$indexes = $tables.Indexes | Where-Object Name -in $Index | Sort-Object Name
        }
        else {
            [array]$indexes = $tables.Indexes | Sort-Object Name
        }
    }

    process {
        $totalObjects = $indexes.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing Indexs in database $Database")) {

                $task = "Removing Index(s)"

                foreach ($object in $indexes) {
                    $objectStep++
                    $operation = "Index [$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Index $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Dropping foreign keys in table [$($object.Parent.Schema)].[$($object.Parent.Name)] from $Database"
                    try {
                        Remove-DbrDbForeignKey -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Schema $object.Parent.Schema -Table $object.Parent.Name
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not remove foreign keys with schema [$($object.Parent.Schema)].[$($object.Parent.Name)]" -ErrorRecord $_ -Target $object.Name -EnableException:$EnableException
                    }

                    Write-PSFMessage -Level Verbose -Message "Dropping Index [$($object.Name)]"
                    try {
                        ($tables.Indexes | Where-Object Name -eq $object.Name).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop index $object" -Target $Database -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}