function Remove-DbrDbView {

    <#
    .SYNOPSIS
        Remove the views

    .DESCRIPTION
        Remove the views in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the views from

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
        Remove-DbrDbView -SqlInstance sqldb1 -Database DB1

        Remove all the views from the database

    .EXAMPLE
        Remove-DbrDbView -SqlInstance sqldb1 -Database DB1 -View VIEW1, VIEW2

        Remove all the views from the database with the name VIEW1 and VIEW2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string[]]$Schema,
        [string[]]$View,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Connect to the source instance
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        # Get the views
        $views = @()
        $views += Get-DbaModule -SqlInstance $server -SqlCredential $SqlCredential -Database $Database -Type View -ExcludeSystemObjects
        $views = $views | Sort-Object SchemaName, Name

        # Get the database
        $db = $server.Databases[$Database]

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
        $totalObjects = $views.Count
        $objectStep = 0

        $progressId = 1

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing views from database $Database")) {

                $task = "Removing View(s)"

                foreach ($object in $views) {
                    $objectStep++
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

                    Write-PSFMessage -Level Verbose -Message "Dropping view [$($object.SchemaName)].[$($object.Name)] from $Database"

                    try {
                        #$view.Drop()
                        ($db.Views | Where-Object { $_.Schema -eq $object.SchemaName -and $_.Name -eq $object.Name }).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop view from $Database" -Target $object -ErrorRecord $_
                    }
                }
            }
        }
    }
}