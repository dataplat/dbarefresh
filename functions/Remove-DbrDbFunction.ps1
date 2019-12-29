function Remove-DbrDbFunction {

    <#
    .SYNOPSIS
        Remove the user defined functions

    .DESCRIPTION
        Remove the user defined functions in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the user defined functions from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Function
        User defined functions to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Remove-DbrDbFunction -SqlInstance sqldb1 -Database DB1

        Remove all the user defined functions from the database

    .EXAMPLE
        Remove-DbrDbFunction -SqlInstance sqldb1 -Database DB1 -Function Udf1, Udf2

        Remove all the Udfs from the database with the name Udf1 and Udf2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string[]]$Schema,
        [string[]]$Function,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Get the udfs
        $params = @{
            SqlInstance          = $SqlInstance
            SqlCredential        = $SqlCredential
            Database             = $Database
            Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
            ExcludeSystemObjects = $true
        }

        $functions = @()
        $functions += Get-DbaModule @params | Sort-Object SchemaName, Name
        $functions = $functions | Sort-Object SchemaName, Name

        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        # Filter out the udfs based on schema
        if ($Schema) {
            [array]$functions = $functions | Where-Object SchemaName -in $Schema
        }

        # Filter out the views based on name
        if ($Function) {
            [array]$functions = $functions | Where-Object Name -in $Function
        }
    }

    process {
        $totalObjects = $functions.Count
        $objectStep = 0

        if ($PSCmdlet.ShouldProcess("Removing user defined functions in database $Database")) {

            $task = "Removing Function(s)"

            # Loop through all the udfs
            foreach ($object in $functions) {
                $objectStep++
                $operation = "User Defined Function [$($object.SchemaName)].[$($object.Name)]"

                $params = @{
                    Id               = ($progressId + 2)
                    ParentId         = ($progressId + 1)
                    Activity         = $task
                    Status           = "Progress-> Function $objectStep of $totalObjects"
                    PercentComplete  = $($objectStep / $totalObjects * 100)
                    CurrentOperation = $operation
                }

                Write-Progress @params

                Write-PSFMessage -Level Verbose -Message "Dropping user defined function [$($object.SchemaName)].[$($object.Name)] from $Database"

                try {
                    ($db.UserDefinedFunctions | Where-Object { $_.Schema -eq $object.SchemaName -and $_.Name -eq $object.Name }).Drop()
                }
                catch {
                    Stop-PSFFunction -Message "Could not drop user defined function from $Database" -Target $object -ErrorRecord $_
                }
            }
        }
    }
}

