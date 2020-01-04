function New-DbrConfig {

    <#
    .SYNOPSIS
        Create a new config file from a database

    .DESCRIPTION
        Create new config based on a database and export it

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the user defined data type from

    .PARAMETER OutFilePath
        Output file to export the JSON data to.
        The default location is $env:TEMP with the file name "databaserefresh.json"

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
        New-DbrConfig -SqlInstance inst1 -Database DB1 -OutFilePath C:\temp\DB1.json

        Export the data based on the database "DB1"

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string[]]$Database,
        [string]$OutFilePath,
        [string[]]$Schema,
        [string[]]$Table,
        [switch]$EnableException
    )

    begin {
        # Connect to the source instance
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        $databases = $server.Databases | Where-Object Name -in $Database

        if (-not $OutFilePath) {
            Write-PSFMessage -Message "Setting output file path" -Level Verbose
            $OutFilePath = (Join-Path -Path $env:TEMP -ChildPath "databaserefresh.json")
        }

        if ((Test-Path -Path $OutFilePath)) {
            if ((Get-Item $OutFilePath) -isnot [System.IO.FileInfo]) {
                Stop-PSFFunction -Message "OutFilePath is a directory. Please enter a path for a file"
            }
        }
        else {
            try {
                $null = New-Item -Path $OutFilePath -ItemType File
            }
            catch {
                Stop-PSFFunction -Message "Could not create output file" -Target $OutFilePath
            }
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $config = @()

        $databaseObjectArray = @()

        foreach ($db in $databases) {
            Write-PSFMessage -Message "Retrieving objects from database $($db.Name)" -Level Verbose

            $tables = $db.Tables

            if ($Schema) {
                [array]$tables = $tables | Where-Object Schema -in $Schema
            }

            if ($Table) {
                [array]$tables = $tables | Where-Object Name -in $Table
            }

            if ($tables.Count -lt 1) {
                Stop-PSFFunction -Message "No tables to process for database $db"
            }
            else {
                $tableObjectArray = @()

                Write-PSFMessage -Message "Retrieving tables from database $($db.Name)" -Level Verbose

                foreach ($tableObject in $tables) {
                    $columns = $tableObject.Columns

                    $columnObjectArray = @()

                    Write-PSFMessage -Message "Retrieving columns from table [$($tableObject.Schema)].[$($tableObject.Name)]" -Level Verbose

                    foreach ($columnObject in $columns) {
                        $columnObjectArray += [PSCustomObject]@{
                            name     = $columnObject.Name
                            datatype = $columnObject.datatype.name
                            filter   = $($null)
                        }
                    }

                    $tableObjectArray += [PSCustomObject]@{
                        fullname = "$($tableObject.Schema).$($tableObject.Name)"
                        schema   = $tableObject.Schema
                        name     = $tableObject.Name
                        columns  = $columnObjectArray
                        query    = $null
                    }
                }

                $databaseObjectArray += [PSCustomObject]@{
                    sourceinstance      = $server.DomainInstanceName
                    destinationinstance = $server.DomainInstanceName
                    database            = $db.Name
                    tables              = $tableObjectArray
                }
            }

            $config += [PSCustomObject]@{
                databases = $databaseObjectArray
            }
        }

        if ($PSCmdlet.ShouldProcess("Writing JSON data to '$OutFilePath'")) {
            try {
                $config | ConvertTo-Json -Depth 7 | Set-Content -Path $OutFilePath
            }
            catch {
                Stop-PSFFunction -Message "Could not write JSON data" -Target $OutFilePath -ErrorRecord $_
            }

        }
    }
}