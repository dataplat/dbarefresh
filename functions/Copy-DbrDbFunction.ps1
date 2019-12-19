function Copy-DbrDbFunction {

    <#
    .SYNOPSIS
        Copy the user defined functions

    .DESCRIPTION
        Copy the user defined functions in a database

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
        Copy-DbrDbFunction -SqlInstance sqldb1 -Database DB1

        Copy all the user defined functions from the database

    .EXAMPLE
        Copy-DbrDbFunction -SqlInstance sqldb1 -Database DB1 -Udf Udf1, Udf2

        Copy all the Udfs from the database with the name Udf1 and Udf2

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
        [string[]]$Function,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $task = "Collecting functions"
        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        $params = @{
            SqlInstance          = $SourceSqlInstance
            SqlCredential        = $SourceSqlCredential
            Database             = $SourceDatabase
            Type                 = @("TableValuedFunction", "InlineTableValuedFunction", "ScalarFunction")
            ExcludeSystemObjects = $true
        }

        $db = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $SourceDatabase

        try {
            $functions = Get-DbaModule @params
            $functions = $functions | Sort-Object SchemaName, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve user defined functions from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        # Filter out the functions based on schema
        if ($Schema) {
            $functions = $functions | Where-Object SchemaName -in $Schema
        }

        # Filter out the functions based on name
        if ($Function) {
            $functions = $functions | Where-Object Name -in $Function
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $functions.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying user defined functions to database $DestinationDatabase")) {
                foreach ($object in $functions) {
                    $objectStep++
                    $task = "Creating Function(s)"
                    $operation = "Function [$($object.SchemaName)].[$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Function $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Creating user defined function [$($object.SchemaName)].[$($object.Name)] on $destInstance"

                    try {
                        $query = ($db.UserDefinedFunctions | Where-Object { $_.Schema -eq $object.SchemaName -and $_.Name -eq $object.Name }) | Export-DbaScript -Passthru -NoPrefix | Out-String
                        Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase -Query $query -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not create user defined function in $db" -Target $function -ErrorRecord $_
                    }

                    [PSCustomObject]@{
                        SqlInstance = $DestinationSqlInstance
                        Database    = $SourceDatabase
                        ObjectType  = "Function"
                        Parent      = $SourceDatabase
                        Object      = "$($object.SchemaName).$($object.Name)"
                        Information = $null
                    }
                }
            }
        }
    }
}