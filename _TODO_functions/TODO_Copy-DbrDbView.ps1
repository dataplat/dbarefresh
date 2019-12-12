function Copy-DbrDbView {

    <#
    .SYNOPSIS
        Copy the views

    .DESCRIPTION
        Copy the views in a database

    .PARAMETER SourceSqlInstance
        The source SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to Copy the views from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER View
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
        Copy-DbrDbView -SqlInstance sqldb1 -Database DB1

        Copy all the views from the database

    .EXAMPLE
        Copy-DbrDbView -SqlInstance sqldb1 -Database DB1 -View VIEW1, VIEW2

        Copy all the views from the database with the name VIEW1 and VIEW2

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
        [string[]]$View,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $stopwatchObject = New-Object System.Diagnostics.Stopwatch

        $task = "Collecting views"

        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task
        try {
            $views = Get-DbaModule -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $Database -Type View -ExcludeSystemObjects
            $views = $views | Sort-Object SchemaName, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve views from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $views.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying views to database $Database")) {
                foreach ($view in $views) {
                    $objectStep++
                    $task = "Creating View(s)"
                    $operation = "View [$($view.SchemaName)].[$($view.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> View $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    $stopwatchObject.Start()

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Creating view [$($view.SchemaName)].[$($view.Name)] in $($db.Name)"

                    $stopwatchObject.Start()

                    $query = ($db.Views | Where-Object Schema -eq $view.SchemaName -and Name -eq $view.Name) | Export-DbaScript -Passthru -NoPrefix | Out-String

                    try {
                        Invoke-DbaQuery -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $Database -Query $query -EnableException
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not execute script for view $view" -ErrorRecord $_ -Target $view
                    }

                    $stopwatchObject.Stop()

                    [PSCustomObject]@{
                        SqlInstance    = $DestinationSqlInstance
                        Database       = $Database
                        ObjectType     = "View"
                        Parent         = $Database
                        Object         = "$($view.SchemaName).$($view.Name)"
                        Information    = $null
                        ElapsedSeconds = [int][Math]::Truncate($stopwatchObject.Elapsed.TotalSeconds)
                    }

                    $stopwatchObject.Reset()
                }
            }
        }
    }
}