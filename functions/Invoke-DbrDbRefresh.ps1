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
                switch ($column.filter.datatype) {
                    "int" {
                        if ($column.filter.values.count -ge 2) {
                            $filters += "[$($column.name)] IN ($($column.filter.values -join ","))"
                        }
                        else {
                            $filters += "[$($column.name)] = $($column.filter.values)"
                        }

                    }
                    "varchar" {
                        if ($column.filter.values.count -ge 2) {
                            $filters += "[$($column.name)] IN ('$($column.filter.values -join "','")')"
                        }
                        else {
                            $filters += "[$($column.name)] = '$($column.filter.values)'"
                        }

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




