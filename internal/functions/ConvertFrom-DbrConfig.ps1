<#
    .SYNOPSIS
        Read the configuration file en convert it to usable objects

    .DESCRIPTION
        Read the configuration file and return the objects to be processed in a form that easy accessible for PowerShell

    .PARAMETER FilePath
        Path to the file

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        ConvertFrom-DbrConfig -FilePath "C:\config\config1.json"

        Read the config file
    #>

function ConvertFrom-DbrConfig {

    [CmdLetBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [switch]$EnableException
    )

    begin {
        if (-not (Test-Path -Path $FilePath)) {
            Stop-PSFFunction -Message "Could not find configuration file" -Target $Path -EnableException:$EnableException
            return
        }

        $jsonErrors = @()
        $jsonErrors += Test-DbrConfig -FilePath $FilePath

        if ($jsonErrors.Count -ge 1) {
            Stop-PSFFunction -Message "Found $($jsonErrors.Count) error(s) in configuration file" -EnableException:$EnableException
            return $jsonErrors
        }

        try {
            $objects = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Stop-PSFFunction -Message "Could not read configuration file" -ErrorRecord $_ -Target $Path
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($item in $objects.Databases) {
            $item = $item | Sort-Object { $_.Tables.Name }

            foreach ($table in $item.Tables) {
                if ($null -eq $table.Query) {
                    $columnObjects = $table.Columns | Where-Object { $_.IsComputed -eq $false -and $_.IsGenerated -eq $false } | Select-Object Name -ExpandProperty Name
                    $columns = "[$($columnObjects -join '],[')]"

                    $query = "SELECT $($columns) FROM [$($item.Sourcedatabase)].[$($table.Schema)].[$($table.Name)] "

                    $filters = @()

                    foreach ($column in $table.Columns) {
                        switch ($column.Filter.Type) {
                            "static" {
                                if (-not $null -eq $column.Filter) {
                                    $compareOperator = $null

                                    if (($column.Filter.Values).Count -ge 2) {
                                        $compareOperator = "IN"
                                    }
                                    else {
                                        switch ($column.Filter.Comparison) {
                                            { $_ -in "eq", "=" } {
                                                $compareOperator = '='
                                            }
                                            "in" {
                                                $compareOperator = 'IN'
                                            }
                                            { $_ -in "le", "<=" } {
                                                $compareOperator = '<='
                                            }
                                            { $_ -in "lt", "<" } {
                                                $compareOperator = '<'
                                            }
                                            { $_ -in "ge", ">=" } {
                                                $compareOperator = '>='
                                            }
                                            { $_ -in "gt", ">" } {
                                                $compareOperator = '>'
                                            }
                                            { $_ -in "like", "*" } {
                                                $compareOperator = 'LIKE'
                                            }
                                            default {
                                                $compareOperator = '='
                                            }
                                        }
                                    }

                                    switch ($column.Datatype) {
                                        { $_ -in 'bigint', 'bit', 'int', 'smallint', 'tinyint' } {
                                            $filters += "[$($column.Name)] $($compareOperator) ($($column.Filter.Values -join ","))"
                                        }
                                        { $_ -in 'char', 'date', 'datetime', 'datetime2', 'nchar', 'nvarchar', 'uniqueidentifier', 'varchar', 'varbinary' } {
                                            $filters += "[$($column.Name)] $($compareOperator) ('$($column.Filter.Values -join "','")')"
                                        }
                                    }
                                }
                            }
                            "query" {
                                $filters += "[$($column.Name)] IN ($($column.Filter.Query))"
                            }
                        }
                    }

                    if ($filters.Count -ge 1) {
                        $query += "WHERE $($filters -join ' AND ')"
                    }

                    $table.Query = $query
                }
            }
        }
    }

    end {
        if (Test-PSFFunctionInterrupt) { return }

        return $objects
    }
}