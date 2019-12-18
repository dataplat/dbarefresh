function Test-DbrConfig {
    <#
    .SYNOPSIS
        Checks the configuration if it's valid

    .DESCRIPTION
        When you're dealing with large configurations, things can get complicated and messy.
        This function will test for a range of rules and returns all the tables and columns that contain errors.

    .PARAMETER FilePath
        Path to the file to test

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER Force
        If this switch is enabled, existing objects on Destination with matching names from Source will be dropped.

    .EXAMPLE
        Test-DbrConfig -FilePath C:\temp\db1.json

        Test the configuration file
    #>

    [CmdletBinding()]

    param (
        [parameter(Mandatory)]
        [string]$FilePath,
        [switch]$EnableException
    )

    begin {
        if (-not (Test-Path -Path $FilePath)) {
            Stop-PSFFunction -Message "Could not find configuration file" -Target $FilePath -EnableException:$EnableException
            return
        }

        # Get all the items that should be processed
        try {
            $json = Get-Content -Path $FilePath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Stop-PSFFunction -Message "Could not parse configuration file" -ErrorRecord $_ -Target $FilePath -EnableException:$EnableException
        }

        $supportedDataTypes = 'bigint', 'bit', 'bool', 'char', 'date', 'datetime', 'datetime2', 'decimal', 'int', 'money', 'nchar', 'ntext', 'nvarchar', 'smalldatetime', 'smallint', 'text', 'time', 'uniqueidentifier', 'userdefineddatatype', 'varchar'

        $requiredDatabaseProperties = 'sourceinstance', 'sourcedatabase', 'destinationinstance', 'destinationdatabase', 'tables'
        $requiredTableProperties = 'fullname', 'schema', 'name', 'columns'
        $requiredColumnProperties = 'name', 'datatype', 'filter'
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($database in $json.databases) {
            # Test the database properties
            $dbProperties = $database | Get-Member | Where-Object MemberType -eq NoteProperty | Select-Object Name -ExpandProperty Name
            $compareResultDb = Compare-Object -ReferenceObject $requiredDatabaseProperties -DifferenceObject $dbProperties

            if ($null -ne $compareResultDb) {
                if ($compareResultDb.SideIndicator -contains "<=") {
                    [PSCustomObject]@{
                        SourceInstance      = $database.sourceinstance
                        SourceDatabase      = $database.sourcedatabase
                        DestinationInstance = $database.destinationinstance
                        DestinationDatabase = $database.destinationdatabase
                        Table               = $null
                        Column              = $null
                        Value               = ($compareResultDb | Where-Object SideIndicator -eq "<=").InputObject -join ","
                        Error               = "The database property does not contain all the required properties"
                    }
                }

                if ($compareResultDb.SideIndicator -contains "=>") {
                    [PSCustomObject]@{
                        SourceInstance      = $database.sourceinstance
                        SourceDatabase      = $database.sourcedatabase
                        DestinationInstance = $database.destinationinstance
                        DestinationDatabase = $database.destinationdatabase
                        Table               = $null
                        Column              = $null
                        Value               = ($compareResultDb | Where-Object SideIndicator -eq "=>").InputObject -join ","
                        Error               = "The database property contains a property that is not in the required properties"
                    }
                }
            }

            foreach ($table in $database.Tables) {
                # Test the table properties
                $tableProperties = $table | Get-Member | Where-Object MemberType -eq NoteProperty | Select-Object Name -ExpandProperty Name
                $compareResultTable = Compare-Object -ReferenceObject $requiredTableProperties -DifferenceObject $tableProperties

                if ($null -eq $compareResultTable) {
                    if ($compareResultTable.SideIndicator -contains "<=") {
                        [PSCustomObject]@{
                            SourceInstance      = $database.sourceinstance
                            SourceDatabase      = $database.sourcedatabase
                            DestinationInstance = $database.destinationinstance
                            DestinationDatabase = $database.destinationdatabase
                            Table               = $table.Name
                            Column              = $column.Name
                            Value               = ($compareResultTable | Where-Object SideIndicator -eq "<=").InputObject -join ","
                            Error               = "The table property does not contain all the required properties"
                        }
                    }

                    if ($compareResultTable.SideIndicator -contains "=>") {
                        [PSCustomObject]@{
                            SourceInstance      = $database.sourceinstance
                            SourceDatabase      = $database.sourcedatabase
                            DestinationInstance = $database.destinationinstance
                            DestinationDatabase = $database.destinationdatabase
                            Table               = $table.Name
                            Column              = $column.Name
                            Value               = ($compareResultTable | Where-Object SideIndicator -eq "=>").InputObject -join ","
                            Error               = "The table property contains a property that is not in the required properties"
                        }
                    }
                }

                foreach ($column in $table.Columns) {
                    # Test the column properties
                    $columnProperties = $column | Get-Member | Where-Object MemberType -eq NoteProperty | Select-Object Name -ExpandProperty Name
                    $compareResultColumn = Compare-Object -ReferenceObject $requiredColumnProperties -DifferenceObject $columnProperties

                    if ($null -ne $compareResultColumn) {
                        if ($compareResultColumn.SideIndicator -contains "<=") {
                            [PSCustomObject]@{
                                SourceInstance      = $database.sourceinstance
                                SourceDatabase      = $database.sourcedatabase
                                DestinationInstance = $database.destinationinstance
                                DestinationDatabase = $database.destinationdatabase
                                Table               = $table.Name
                                Column              = $column.Name
                                Value               = ($compareResultColumn | Where-Object SideIndicator -eq "<=").InputObject -join ","
                                Error               = "The column property does not contain all the required properties"
                            }
                        }

                        if ($compareResultColumn.SideIndicator -contains "=>") {
                            [PSCustomObject]@{
                                SourceInstance      = $database.sourceinstance
                                SourceDatabase      = $database.sourcedatabase
                                DestinationInstance = $database.destinationinstance
                                DestinationDatabase = $database.destinationdatabase
                                Table               = $table.Name
                                Column              = $column.Name
                                Value               = ($compareResultColumn | Where-Object SideIndicator -eq "=>").InputObject -join ","
                                Error               = "The column property contains a property that is not in the required properties"
                            }
                        }
                    }

                    # Test column type
                    if ($column.datatype -notin $supportedDataTypes) {
                        [PSCustomObject]@{
                            SourceInstance      = $database.sourceinstance
                            SourceDatabase      = $database.sourcedatabase
                            DestinationInstance = $database.destinationinstance
                            DestinationDatabase = $database.destinationdatabase
                            Table               = $table.Name
                            Column              = $column.Name
                            Value               = $column.datatype
                            Error               = "$($column.datatype) is not a supported data type"
                        }
                    }
                }
            }
        }
    }
}