function Copy-DbrDbSchema {

    <#
    .SYNOPSIS
        Copy the schemas

    .DESCRIPTION
        Copy the schemas in a database

    .PARAMETER SourceSqlInstance
        The source SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to Copy the schemas from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Udtt
        View to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Copy-DbrDbSchema -SqlInstance sqldb1 -Database DB1

        Copy all the user defined table types from the database

    .EXAMPLE
        Copy-DbrDbSchema -SqlInstance sqldb1 -Database DB1 -View VIEW1, VIEW2

        Copy all the user defined table types from the database with the name VIEW1 and VIEW2

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
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $db = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $Database

        $task = "Collecting schemas"

        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            $schemas = @()
            $schemas += $db.Schemas | Where-Object IsSystemObject -eq $false | Sort-Object Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve schemas from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        if ($Schema) {
            $schemas = $schemas | Where-Object Name -in $Schema
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $schemas.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying schemas to database $Database")) {
                # Create the user defined table types
                foreach ($object in $schemas) {
                    $objectStep++
                    $task = "Creating Schema(s)"
                    $operation = "Schema [$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Schema $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    $stopwatchObject.Start()

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Creating Schema [$($object.Name)] in $($db.Name)"

                    $query = $object | Export-DbaScript -Passthru -NoPrefix | Out-String

                    try {
                        Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $Database -Query $query -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute script for schema $object" -ErrorRecord $_ -Target $object
                    }

                    $stopwatchObject.Stop()

                    [PSCustomObject]@{
                        SqlInstance    = $DestinationSqlInstance
                        Database       = $Database
                        ObjectType     = "Schema"
                        Parent         = $Database
                        Object         = "$($object.Name)"
                        Information    = $null
                        ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                    }

                    $stopwatchObject.Reset()
                }
            }
        }
    }
}