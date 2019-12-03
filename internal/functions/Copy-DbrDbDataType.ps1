function Copy-DbrDbDataType {

    <#
    .SYNOPSIS
        Copy the user defined data types

    .DESCRIPTION
        Copy the user defined data types in a database

    .PARAMETER SourceSqlInstance
        The source SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to Copy the user defined data types from

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
        Copy-DbrDbDataType -SqlInstance sqldb1 -Database DB1

        Copy all the user defined table types from the database

    .EXAMPLE
        Copy-DbrDbDataType -SqlInstance sqldb1 -Database DB1 -View VIEW1, VIEW2

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
        [string[]]$Uddt,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $db = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $Database

        $task = "Collecting user defined data types"

        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            $uddts = $db.UserDefinedDataTypes | Sort-Object Schema, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve user defined data types from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        if ($Schema) {
            $uddts = $uddts | Where-Object Schema -in $Schema
        }

        if ($Uddt) {
            $uddts = $uddts | Where-Object Name -in $Uddts
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $uddts.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying user defined data types to database $Database")) {
                # Create the user defined table types
                foreach ($uddt in $uddts) {
                    $objectStep++
                    $task = "Creating Data Type(s)"
                    $operation = "Data Type [$($uddt.Schema)].[$($uddt.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Data Type $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    $stopwatchObject.Start()

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Creating data type [$($uddt.Schema)].[$($uddt.Name)] in $($db.Name)"

                    $query = ($uddts | Where-Object { $_.Schema -eq $uddt.Schema -and $_.Name -eq $uddt.Name }) | Export-DbaScript -Passthru -NoPrefix | Out-String

                    try {
                        Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $Database -Query $query -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute script for data type $uddt" -ErrorRecord $_ -Target $view
                    }

                    $stopwatchObject.Stop()

                    [PSCustomObject]@{
                        SqlInstance    = $DestinationSqlInstance
                        Database       = $Database
                        ObjectType     = "User Defined Data Type"
                        Parent         = $Database
                        Object         = "$($uddt.Schema).$($uddt.Name)"
                        Information    = $null
                        ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                    }

                    $stopwatchObject.Reset()
                }
            }
        }
    }
}