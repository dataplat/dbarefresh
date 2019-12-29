
$query = ";WITH fkey
    AS (SELECT f.object_id AS constraint_id,
        f.name AS constraint_name,
        parent_object_id,
        OBJECT_NAME(f.parent_object_id) AS parent_name,
        referenced_object_id,
        OBJECT_NAME(f.referenced_object_id) AS referenced_object_name
        FROM sys.foreign_keys f),
    recurse
    AS (SELECT depth = 1,
        *
        FROM fkey
        WHERE referenced_object_name = 'myTable' -- <-- use this to filter results.
        UNION ALL
        SELECT depth = recurse.depth + 1,
        fkey.*
        FROM fkey
        JOIN recurse
        ON fkey.referenced_object_id = recurse.parent_object_id),
    recurseWithFields
    AS (SELECT r.*,
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

    SELECT *
    FROM recurseWithFields;
"