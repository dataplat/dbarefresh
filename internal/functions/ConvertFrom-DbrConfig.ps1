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
            Stop-PSFFunction -Message "Found $($jsonErrors.Count) error(s) in configuration file"
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

        foreach ($item in $objects.databases) {
            foreach ($table in $item.tables) {
                if ($null -eq $table.query) {
                    $columns = "[$($table.columns.name -join '],[')]"

                    $query = "SELECT $($columns) FROM [$($table.schema)].[$($table.name)] "

                    $filters = @()

                    foreach ($column in $table.columns) {
                        switch ($column.filter.type) {
                            "static" {
                                if (-not $null -eq $column.filter) {
                                    $compareOperator = $null

                                    if (($column.filter.values).Count -ge 2) {
                                        $compareOperator = "IN"
                                    }
                                    else {
                                        switch ($column.filter.comparison) {
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

                                    switch ($column.datatype) {
                                        "int" {
                                            $filters += "[$($column.name)] $($compareOperator) ($($column.filter.values -join ","))"
                                        }
                                        "varchar" {
                                            $filters += "[$($column.name)] $($compareOperator) ('$($column.filter.values -join "','")')"
                                        }
                                    }
                                }
                            }
                            "query" {
                                $filters += "[$($column.name)] In ($($column.filter.query))"
                            }
                        }
                    }

                    if ($filters.Count -ge 1) {
                        $query += "WHERE $($filters -join ' AND ')"
                    }

                    $table.query = $query
                }
            }
        }
    }

    end {
        if (Test-PSFFunctionInterrupt) { return }

        return $objects
    }
}