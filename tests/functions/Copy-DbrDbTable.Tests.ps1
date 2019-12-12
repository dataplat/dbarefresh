$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        $knownParameters = 'SourceSqlInstance', 'SourceSqlCredential', 'DestinationSqlInstance', 'DestinationSqlCredential', 'SourceDatabase', 'DestinationDatabase', 'Schema', 'Table', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'UnitTests' {
    BeforeAll {
        $sourceServer = Connect-DbaInstance -SqlInstance $script:instance1
        $destServer = Connect-DbaInstance -SqlInstance $script:instance2

        if ($sourceServer.Databases.Name -contains $script:sourcedatabase) {
            Remove-DbaDatabase -SqlInstance $sourceServer -Database $script:sourcedatabase -Confirm:$false
        }

        if ($destServer.Databases.Name -contains $script:destinationdatabase) {
            Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false
        }

        $query = "CREATE DATABASE [$($script:sourcedatabase)]"
        Invoke-DbaQuery -SqlInstance $sourceServer -Database 'master' -Query $query

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $destServer -Database $script:sourcedatabase -Query $query

        $sourceServer.Databases.Refresh()

        $sourceDb = $sourceServer.Databases[$script:sourcedatabase]

        Context "Database pre-checks" {
            $destServer.Databases.refresh()

            It "Source database should contain data types" {
                $tables = @()
                $tables += $sourceDb.Tables | Sort-Object Schema, Name
                $tables.Count | Should -Be 3
            }
        }
    }

    Context "Execute command with all defaults" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $destServer -Database 'master' -Query $query

        $destServer.Databases.Refresh()
        $destDb = $destServer.Databases[$script:destinationdatabase]

        # Setup parameters
        $params = @{
            SourceSqlInstance      = $sourceServer.DomainInstanceName
            DestinationSqlInstance = $destServer.DomainInstanceName
            SourceDatabase         = $sourceDb.Name
            DestinationDatabase    = $destDb.Name
            EnableException        = $true
        }

        # Run command
        Copy-DbrDbTable @params

        $destDb.Tables.Refresh()

        $tables = @()
        $tables += $destDb.Tables | Sort-Object Schema, Name

        It "Destination database should have tables" {
            $tables.Count | Should -BeGreaterThan 0
        }

        It "Destination database should have correct amount of tables" {
            $tables.Count | Should -Be 3
        }
    }

    Context "Execute command with table filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $destServer -Database 'master' -Query $query

        $destServer.Databases.Refresh()
        $destDb = $destServer.Databases[$script:destinationdatabase]

        # Setup parameters
        $params = @{
            SourceSqlInstance      = $sourceServer.DomainInstanceName
            DestinationSqlInstance = $destServer.DomainInstanceName
            SourceDatabase         = $sourceDb.Name
            DestinationDatabase    = $destDb.Name
            Table                  = "Table3"
            EnableException        = $true
        }

        # Run command
        Copy-DbrDbTable @params

        $destDb.Tables.Refresh()

        $tables = @()
        $tables += $destDb.Tables | Sort-Object Schema, Name

        It "Destination database should have correct amount of tables" {
            $tables.Count | Should -Be 1
        }

        It "Destination database should have correct tables" {
            $tables.Name | Should -BeIn @("Table3")
        }
    }

    Context "Execute command with multiple table filters" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $destServer -Database 'master' -Query $query

        $destServer.Databases.Refresh()
        $destDb = $destServer.Databases[$script:destinationdatabase]

        # Setup parameters
        $params = @{
            SourceSqlInstance      = $sourceServer.DomainInstanceName
            DestinationSqlInstance = $destServer.DomainInstanceName
            SourceDatabase         = $sourceDb.Name
            DestinationDatabase    = $destDb.Name
            Table                  = @("Table3", "Table1")
            EnableException        = $true
        }

        # Run command
        Copy-DbrDbTable @params

        $destDb.Tables.Refresh()

        $tables = @()
        $tables += $destDb.Tables | Sort-Object Schema, Name

        It "Destination database should have correct amount of tables" {
            $tables.Count | Should -Be 2
        }

        It "Destination database should have correct tables" {
            $tables.Name | Should -BeIn @("Table3", "Table1")
        }
    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $sourceServer -Database $script:sourcedatabase -Confirm:$false
        $null = Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false
    }
}