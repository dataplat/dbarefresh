function Remove-DbrDbSequence {

    <#
    .SYNOPSIS
        Remove the sequences

    .DESCRIPTION
        Remove the sequences in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the sequence from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER Sequence
        Sequence to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Remove-DbrDbSequence -SqlInstance sqldb1 -Database DB1

        Remove all the sequences from the database

    .EXAMPLE
        Remove-DbrDbSequence -SqlInstance sqldb1 -Database DB1 -Sequence Datatype1, Datatype2

        Remove all the sequences from the database with the name Datatype1 and Datatype2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string[]]$Schema,
        [string[]]$Sequence,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Connect to the source instance
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        $db = $server.Databases[$Database]

        $task = "Removing sequences"

        # Filter out the sequence based on schema
        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            [array]$sequences = $db.Sequences | Sort-Object Schema, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve sequences from source instance" -ErrorRecord $_ -Target $SqlInstance -EnableException:$EnableException
        }

        if ($Schema) {
            [array]$sequences = $sequences | Where-Object Schema -in $Schema
        }

        if ($Sequence) {
            [array]$sequences = $sequences | Where-Object Name -in $Sequence
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $sequences.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing sequence in database $Database")) {

                $task = "Removing Data Type(s)"

                foreach ($object in $sequences) {
                    $objectStep++
                    $operation = "Data Type [$($object.Schema)].[$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Data Type $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Dropping sequence [$($object.Schema)].[$($object.Name)] from $Database"

                    try {
                        ($db.Sequences | Where-Object { $_.Schema -eq $object.Schema -and $_.Name -eq $object.Name }).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop sequence from $Database" -Target $object -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}