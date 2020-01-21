function Remove-DbrDbXmlSchemaCollection {

    <#
    .SYNOPSIS
        Remove the XML schema collection

    .DESCRIPTION
        Remove the XML schema collection in a database

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the XML schema collection from

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER XmlSchemaCollection
        User defined data type to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Remove-DbrDbXmlSchemaCollection -SqlInstance sqldb1 -Database DB1

        Remove all the XML schema collection from the database

    .EXAMPLE
        Remove-DbrDbXmlSchemaCollection -SqlInstance sqldb1 -Database DB1 -XmlSchemaCollection XmlSchemaCollection1, XmlSchemaCollection2

        Remove all the XML schema collection from the database with the name XmlSchemaCollection1 and XmlSchemaCollection2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string[]]$Schema,
        [string[]]$XmlSchemaCollection,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Connect to the source instance
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        $db = $server.Databases[$Database]

        $task = "Removing XML schema collections"

        # Filter out the XML schema collection based on schema
        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            [array]$XmlSchemaCollections = $db.XmlSchemaCollections | Sort-Object Schema, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve XML schema collections from source instance" -ErrorRecord $_ -Target $SqlInstance -EnableException:$EnableException
        }

        if ($Schema) {
            [array]$XmlSchemaCollections = $XmlSchemaCollections | Where-Object Schema -in $Schema
        }

        if ($XmlSchemaCollection) {
            [array]$XmlSchemaCollections = $XmlSchemaCollections | Where-Object Name -in $XmlSchemaCollection
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $XmlSchemaCollections.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Removing XML schema collection in database $Database")) {

                $task = "Removing XML Schema Collection(s)"

                foreach ($object in $XmlSchemaCollections) {
                    $objectStep++
                    $operation = "XML Schema Collection [$($object.Schema)].[$($object.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> XML Schema Collection $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    Write-PSFMessage -Level Verbose -Message "Dropping XML schema collection [$($object.Schema)].[$($object.Name)] from $Database"

                    try {
                        ($db.XmlSchemaCollections | Where-Object { $_.Schema -eq $object.Schema -and $_.Name -eq $object.Name }).Drop()
                    }
                    catch {
                        Stop-PSFFunction -Message "Could not drop XML schema collection from $Database" -Target $object -ErrorRecord $_ -EnableException:$EnableException
                    }
                }
            }
        }
    }
}