function New-DbrConfig {

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

        $databaseObjectArray | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFilePath
    }
}