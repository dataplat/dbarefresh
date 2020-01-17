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

    .PARAMETER OutPath
        Output path to export the JSON data to.
        The default location is $env:TEMP

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
        [string]$OutPath,
        [string[]]$Schema,
        [string[]]$Table,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        # Connect to the source instance
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential

        [array]$databases = $server.Databases | Where-Object Name -in $Database

        if (-not $OutPath) {
            Write-PSFMessage -Message "Setting output file path" -Level Verbose
            $OutPath = $env:TEMP
        }

        if ((Test-Path -Path $OutPath)) {
            if ((Get-Item $OutPath) -is [System.IO.FileInfo]) {
                Stop-PSFFunction -Message "OutFilePath is not a directory. Please enter a directory"
            }
        }
        else {
            try {
                $null = New-Item -Path $OutPath -ItemType File
            }
            catch {
                Stop-PSFFunction -Message "Could not create output file" -Target $OutFilePath -EnableException:$EnableException
            }
        }

        $supportedDataTypes = Get-PSFConfigValue PSDatabaseRefresh.Config.SupportedDataTypes
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $dbCount = $databases.Count
        $dbStep = 0

        $config = @()

        $databaseObjectArray = @()

        foreach ($db in $databases) {
            $dbStep++
            $task = "Processing database [$($db.Name)]"
            Write-Progress -Id 1 -Activity $task -Status 'Progress->' -PercentComplete $($dbStep / $dbCount * 100)

            Write-PSFMessage -Message "Retrieving objects from database $($db.Name)" -Level Verbose

            $tables = $db.Tables

            $task = "Processing Table(s)"

            if ($Schema) {
                [array]$tables = $tables | Where-Object Schema -in $Schema
            }

            if ($Table) {
                [array]$tables = $tables | Where-Object Name -in $Table
            }

            if ($tables.Count -lt 1) {
                Stop-PSFFunction -Message "No tables to process for database $db" -EnableException:$EnableException
            }
            else {
                $totalObjects = $tables.Count
                $objectStep = 0

                $tableObjectArray = @()

                Write-PSFMessage -Message "Retrieving tables from database $($db.Name)" -Level Verbose

                foreach ($tableObject in $tables) {
                    $objectStep++

                    $operation = "Table [$($tableObject.Schema)].[$($tableObject.Name)]"

                    $params = @{
                        Id               = ($progressId + 2)
                        ParentId         = ($progressId + 1)
                        Activity         = $task
                        Status           = "Progress-> Table $objectStep of $totalObjects"
                        PercentComplete  = $($objectStep / $totalObjects * 100)
                        CurrentOperation = $operation
                    }

                    Write-Progress @params

                    $columns = $tableObject.Columns | Where-Object { $_.DataType.Name -in $supportedDataTypes }

                    $columnObjectArray = @()

                    Write-PSFMessage -Message "Retrieving columns from table [$($tableObject.Schema)].[$($tableObject.Name)]" -Level Verbose

                    foreach ($columnObject in $columns) {
                        $columnObjectArray += [PSCustomObject]@{
                            name        = $columnObject.Name
                            datatype    = $columnObject.datatype.name
                            filter      = $null
                            iscomputed  = $columnObject.Computed
                            isgenerated = $(if ($columnObject.GeneratedAlwaysType -eq 'None') { $false } else { $true } )
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
                    sourcedatabase      = $db.Name
                    destinationdatabase = $db.Name
                    tables              = $tableObjectArray
                }
            }

            $config += [PSCustomObject]@{
                databases = $databaseObjectArray
            }
        }

        if ($PSCmdlet.ShouldProcess("Writing JSON data to '$($OutPath)'")) {
            try {
                $filePath = Join-Path -Path $OutPath -ChildPath "$($server.DomainInstanceName)_DBRefresh.json"
                $config | ConvertTo-Json -Depth 7 | Set-Content -Path $filePath
            }
            catch {
                Stop-PSFFunction -Message "Could not write JSON data" -Target $filePath -ErrorRecord $_ -EnableException:$EnableException
            }

        }
    }
}