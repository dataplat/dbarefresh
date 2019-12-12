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

    .PARAMETER Database
        Database to remove the user defined functions from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Udf
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
        [string]$Database,
        [string]$Schema,
        [string[]]$Udf,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $task = "Collecting functions"
        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            $functions = Get-DbaModule -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $Database -Type TableValuedFunction, InlineTableValuedFunction, ScalarFunction -ExcludeSystemObjects
            $functions = $functions | Sort-Object SchemaName, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve user defined functions from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        # Filter out the udfs based on schema
        if ($Schema) {
            $functions = $functions | Where-Object SchemaName -eq $Schema
        }

        # Filter out the views based on name
        if ($Udf) {
            $functions = $functions | Where-Object Name -in $Udf
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $functions.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying user defined functions to database $Database")) {
                foreach ($function in $functions) {
                    $objectStep++
                    $task = "Creating Function(s)"
                    $operation = "Function [$($function.SchemaName)].[$($function.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Function $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    $stopwatchObject.Start()

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Creating user defined function [$($function.SchemaName)].[$($function.Name)] on $destInstance"

                    try {
                        #$query = ($db.UserDefinedFunctions | Where-Object Schema -eq $function.SchemaName -and Name -eq $function.Name).Script()[2] -join "`n"

                        $query = ($db.UserDefinedFunctions | Where-Object { $_.Schema -eq $function.SchemaName -and $_.Name -eq $function.Name }) | Export-DbaScript -Passthru -NoPrefix | Out-String
                        Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $Database -Query $query -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not create user defined function in $db" -Target $function -ErrorRecord $_
                    }

                    $stopwatchObject.Stop()

                    [PSCustomObject]@{
                        SqlInstance    = $DestinationSqlInstance
                        Database       = $Database
                        ObjectType     = "Function"
                        Parent         = $Database
                        Object         = "$($function.SchemaName).$($function.Name)"
                        Information    = $null
                        ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                    }

                    $stopwatchObject.Reset()
                }
            }
        }
    }
}