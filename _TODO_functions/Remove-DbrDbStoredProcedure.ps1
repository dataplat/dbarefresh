function Remove-DbrDbStoredProcedure {

    <#
    .SYNOPSIS
        Remove the stored procedures

    .DESCRIPTION
        Remove the stored procedures in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the stored procedures from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER StoredProcedure
        Stored procedures to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Remove-DbrDbStoredProcedure -SqlInstance sqldb1 -Database DB1

        Remove all the stored procedures from the database

    .EXAMPLE
        Remove-DbrDbStoredProcedure -SqlInstance sqldb1 -Database DB1 -StoredProcedure PROC1, PROC2

        Remove all the stored procedures from the database with the name PROC1 and PROC2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$Database,
        [string]$Schema,
        [string[]]$StoredProcedure,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Get the stored procedures
        $procedures = Get-DbaModule -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Type StoredProcedure -ExcludeSystemObjects
        $procedures = $procedures | Sort-Object SchemaName, Name

        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        # Filter out the stored procedures based on schema
        if ($Schema) {
            $procedures = $procedures | Where-Object SchemaName -eq $Schema
        }

        # Filter out the stored procedures based on name
        if ($StoredProcedure) {
            $procedures = $procedures | Where-Object Name -in $StoredProcedure
        }
    }

    process {
        $totalObjects = $procedures.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing stored procedures in database $Database")) {

                $task = "Removing Stored Procedure(s)"

                foreach ($procedure in $procedures) {
                    $objectStep++
                    $operation = "Procedure [$($procedure.SchemaName)].[$($procedure.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Stored Procedure $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Dropping stored procedure [$($procedure.SchemaName)].[$($procedure.Name)] from $Database"

                    try {
                        ($db.StoredProcedures | Where-Object { $_.Schema -eq $procedure.SchemaName -and $_.Name -eq $procedure.Name }).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop stored procedure from $Database" -Target $procedure -ErrorRecord $_
                    }
                }
            }
        }
    }
}

