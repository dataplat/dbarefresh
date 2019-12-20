function Remove-DbrDbTableType {

    <#
    .SYNOPSIS
        Remove the user defined table type

    .DESCRIPTION
        Remove the user defined table type in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the user defined table type from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Udtt
        user defined table type to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Remove-DbrDbTableType -SqlInstance sqldb1 -Database DB1

        Remove all the user defined table type from the database

    .EXAMPLE
        Remove-DbrDbTableType -SqlInstance sqldb1 -Database DB1 -StoredProcedure PROC1, PROC2

        Remove all the user defined table type from the database with the name PROC1 and PROC2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$Database,
        [string]$Schema,
        [string[]]$Udtt,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        $task = "Removing user defined table types"

        # Filter out the user defined table type based on schema
        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            $udtts = @()
            $udtts += $db.UserDefinedTableTypes | Select-Object Schema, Name | Sort-Object Schema, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve user defined table types from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        if ($Schema) {
            $udtts = $udtts | Where-Object Schema -in $Schema
        }

        if ($udtt) {
            $udtts = $udtts | Where-Object Name -in $Udtt
        }
    }

    process {
        $totalObjects = $udtts.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing user defined table type in database $Database")) {

                $task = "Removing Table Type(s)"

                foreach ($object in $udtts) {
                    $objectStep++
                    $operation = "Table type [$($object.Schema)].[$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> table type $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Dropping user defined table type [$($object.Schema)].[$($object.Name)] from $Database"

                    try {
                        ($db.UserDefinedTableTypes | Where-Object { $_.Schema -eq $object.Schema -and $_.Name -eq $object.Name }).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop user defined table type from $Database" -Target $object -ErrorRecord $_
                    }
                }
            }
        }
    }
}

