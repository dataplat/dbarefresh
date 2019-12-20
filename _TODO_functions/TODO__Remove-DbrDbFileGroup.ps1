function Remove-DbrDbFileGroup. {

    <#
    .SYNOPSIS
        Remove the file groups

    .DESCRIPTION
        Remove the file groups in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the tables from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Table
        Table to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Remove-DbrDbFileGroup. -SqlInstance sqldb1 -Database DB1

        Remove all the file groups from the database

    .EXAMPLE
        Remove-DbrDbFileGroup. -SqlInstance sqldb1 -Database DB1 -Table TABLE1, TABLE2

        Remove all the file groups from the database with the name TABLE1 and TABLE2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$Database,
        [string[]]$Filegroup,
        [switch]$EnableException
    )

    process {
        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        $fileGroups = $db.FileGroups

        # Filter out the file groups based on name
        if ($Filegroup) {
            $fileGroups = $fileGroups | Where-Object Name -in $Filegroup
        }

        if ($fileGroups.Count -ge 1) {

            # Loop through the tables
            foreach ($f in $fileGroups) {
                Write-PSFMessage -Level Verbose -Message "Dropping file group [$($f.Name)] on $($db.Name)"
                try {
                    $f.Drop()
                }
                catch {
                    Stop-PSFFunction -Message "Could not drop file group in $($db.Name)" -Target $f -ErrorRecord $_
                }
            }
        }
    }
}

