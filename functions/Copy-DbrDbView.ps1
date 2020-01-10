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

    .PARAMETER SourceDatabase
        Database to copy the user defined data types from

    .PARAMETER DestinationDatabase
        Database to copy the user defined data types to

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER View
        View to filter out

    .PARAMETER Force
        If set, the command will remove any objects that are present prior to creating them

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
        [string]$SourceDatabase,
        [string]$DestinationDatabase,
        [string[]]$Schema,
        [string[]]$View,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $task = "Collecting views"

        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task
        try {
            $params = @{
                SqlInstance          = $SourceSqlInstance
                SqlCredential        = $SourceSqlCredential
                Database             = $SourceDatabase
                Type                 = "View"
                ExcludeSystemObjects = $true
            }

            [array]$views = Get-DbaModule @params
            [array]$views = $views | Sort-Object SchemaName, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve views from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        # Get the database
        try {
            $sourceDb = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $SourceDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        try {
            $destDb = Get-DbaDatabase -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from destination instance" -ErrorRecord $_ -Target $DestinationSqlInstance
        }

        # Filter out the views based on schema
        if ($Schema) {
            [array]$views = $views | Where-Object SchemaName -in $Schema
        }

        # Filter out the views based on name
        if ($View) {
            [array]$views = $views | Where-Object Name -in $View
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $views.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying views to database $DestinationDatabase")) {
                foreach ($object in $views) {

                    if ($Force -and ($object.Name -in $destDb.Views.Name)) {
                        $params = @{
                            SqlInstance   = $DestinationSqlInstance
                            SqlCredential = $DestinationSqlCredential
                            Database      = $DestinationDatabase
                            Schema        = $object.Schema
                            View          = $object.Name
                        }

                        Remove-DbrDbView @params
                    }

                    if ($object.Name -notin $destDb.Views.Name) {
                        $objectStep++
                        $task = "Creating View(s)"
                        $operation = "View [$($object.SchemaName)].[$($object.Name)]"

                        $params = @{
                            Id               = ($progressId + 2)
                            ParentId         = ($progressId + 1)
                            Activity         = $task
                            Status           = "Progress-> View $objectStep of $totalObjects"
                            PercentComplete  = $($objectStep / $totalObjects * 100)
                            CurrentOperation = $operation
                        }

                        Write-Progress @params

                        Write-PSFMessage -Level Verbose -Message "Creating view [$($object.SchemaName)].[$($object.Name)] in $($sourceDb.Name)"

                        $query = ($sourceDb.Views | Where-Object { $_.Schema -eq $object.SchemaName -and $_.Name -eq $object.Name }) | Export-DbaScript -Passthru -NoPrefix | Out-String

                        try {
                            $params = @{
                                SqlInstance     = $DestinationSqlInstance
                                SqlCredential   = $DestinationSqlCredential
                                Database        = $DestinationDatabase
                                Query           = $query
                                EnableException = $true
                            }

                            Invoke-DbaQuery @params
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not execute script for view $object" -ErrorRecord $_ -Target $view
                        }

                        [PSCustomObject]@{
                            SourceSqlInstance      = $SourceSqlInstance
                            DestinationSqlInstance = $DestinationSqlInstance
                            SourceDatabase         = $SourceDatabase
                            DestinationDatabase    = $DestinationDatabase
                            ObjectType             = "View"
                            Parent                 = $null
                            Object                 = "$($object.SchemaName).$($object.Name)"
                            Notes                  = $null
                        }
                    }
                    else {
                        Write-PSFMessage -Message "View [$($object.SchemaName)].[$($object.Name)] already exists. Skipping..." -Level Verbose
                    }
                }
            }
        }
    }
}