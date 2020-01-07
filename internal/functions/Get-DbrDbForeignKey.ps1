function Get-DbrDbForeignKey {

    <#
    .SYNOPSIS
        Get all the foreign keys relatred to a table

    .DESCRIPTION
        When deleting tables, the foreigns to that table should be removed.
        This command returns all the tables that have references to a particular table

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Database to remove the tables from

    .PARAMETER Schema
        Schema of the table

    .PARAMETER Table
        Table

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Thanks to Thanks to Ann L for the example T-SQL code
        https://stackoverflow.com/questions/29032618/get-all-foreign-keys-for-all-dependent-tables-for-one-table-to-nth-level

    .EXAMPLE
        Get-DbrDbForeignKey -Schema 'dbo' -Table 'Table1'

        Get the foreign keys for [dbo].[Table1]
    #>

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Database,
        [string[]]$Schema,
        [string[]]$Table,
        [switch]$EnableException
    )

    begin {

        # Get the database
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database

        $tables = @()
        $tables += $db.Tables

        if ($Schema) {
            [array]$tables = $tables | Where-Object Schema -in $Schema
        }

        if ($Table) {
            [array]$tables = $tables | Where-Object { $_.Name -in $Table }
        }

        if ($tables.Count -lt 1) {
            Stop-PSFFunction -Message "No tables to process" -Target $Database
        }

    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $results = @()

        foreach ($object in $tables) {
            $query = ";
                WITH fkey
                AS (SELECT f.object_id AS constraint_id,
                        f.name AS constraint_name,
                        parent_object_id,
                        OBJECT_NAME(f.parent_object_id) AS parent_name,
                        referenced_object_id,
                        SCHEMA_NAME(f.schema_id) AS referenced_schema_name,
                        OBJECT_NAME(f.referenced_object_id) AS referenced_object_name
                    FROM sys.foreign_keys f),
                    recurse
                AS (SELECT depth = 1,
                        fkey.constraint_id,
                        fkey.constraint_name,
                        fkey.parent_object_id,
                        fkey.parent_name,
                        fkey.referenced_object_id,
                        fkey.referenced_schema_name,
                        fkey.referenced_object_name
                    FROM fkey
                    WHERE fkey.referenced_schema_name = '$($object.Schema)'
                        AND referenced_object_name = '$($object.Name)'
                    UNION ALL
                    SELECT depth = recurse.depth + 1,
                        fkey.constraint_id,
                        fkey.constraint_name,
                        fkey.parent_object_id,
                        fkey.parent_name,
                        fkey.referenced_object_id,
                        fkey.referenced_schema_name,
                        fkey.referenced_object_name
                    FROM fkey
                        INNER JOIN recurse
                            ON fkey.referenced_object_id = recurse.parent_object_id),
                    recurseWithFields
                AS (SELECT r.depth,
                        r.constraint_id,
                        r.constraint_name,
                        r.parent_object_id,
                        r.parent_name,
                        r.referenced_object_id,
                        r.referenced_schema_name,
                        r.referenced_object_name,
                        fc.parent_column_id,
                        parent_column_name = p_ac.name,
                        fc.referenced_column_id,
                        reference_column_name = r_ac.name
                    FROM recurse r
                        JOIN sys.foreign_key_columns fc
                            ON r.constraint_id = fc.constraint_object_id
                        JOIN sys.all_columns p_ac
                            ON fc.parent_column_id = p_ac.column_id
                            AND fc.parent_object_id = p_ac.object_id
                        JOIN sys.all_columns r_ac
                            ON fc.referenced_column_id = r_ac.column_id
                            AND fc.referenced_object_id = r_ac.object_id)

                SELECT DISTINCT r.referenced_schema_name AS ReferencedSchema,
                    r.referenced_object_name AS ReferencedTable,
                    r.reference_column_name AS ReferencedColumnName,
                    r.constraint_name AS ConstraintName,
                    r.parent_name AS ParentTable,
                    r.parent_column_name AS ParentColumnName
                FROM recurseWithFields AS r;
            "

            Write-PSFMessage -Message "Retrieving foreign keys referenced to [$($object.Schema)].[$($object.Name)]"

            Write-PSFMessage -Message "Query`n$($query)" -Level Debug

            [array]$result = Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Query $query

            if ($result.Count -ge 1) {
                foreach ($object in $result) {
                    $results += [PSCustomObject]@{
                        ReferencedSchema     = $object.ReferencedSchema
                        ReferencedTable      = $object.ReferencedTable
                        ReferencedColumnName = $object.ReferencedColumnName
                        ConstraintName       = $object.ConstraintName
                        ParentTable          = $object.ParentTable
                        ParentColumnName     = $object.ParentColumnName
                    }
                }
            }
        }

        $results | Select-Object ReferencedSchema, ReferencedTable, ReferencedColumnName, ConstraintName, ParentTable, ParentColumnName -Unique | Sort-Object ReferencedSchema, ReferencedTable
    }


}