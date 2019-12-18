Clear-Host

$json = Get-Content -Path ".\test.json" -Raw | ConvertFrom-Json

foreach ($item in $json.databases) {
    "From $($item.sourcedatabase) to $($item.destinationdatabase)"

    foreach ($table in $item.tables) {
        $columns = "[$($table.columns.name -join '],[')]"

        $query = "SELECT $($columns) FROM [$($table.schema)].[$($table.name)] "
        #$query

        $filters = @()
        foreach ($column in $table.columns) {

            if (-not $null -eq $column.filter) {
                $compareOperator = $null
                $values = $null
                $values
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

                switch ($column.filter.datatype) {
                    "int" {
                        $filters += "[$($column.name)] $($compareOperator) ($($column.filter.values -join ","))"
                    }
                    "varchar" {
                        $filters += "[$($column.name)] $($compareOperator) ('$($column.filter.values -join "','")')"
                    }
                }
            }
        }

        if ($filters.Count -ge 1) {
            $query += "WHERE $($filters -join ' AND ')"
        }

        $query
    }
}




