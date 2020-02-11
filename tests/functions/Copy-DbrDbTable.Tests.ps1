$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SourceSqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SourceSqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter DestinationSqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter DestinationSqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter SourceDatabase -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter DestinationDatabase -Type string
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter Table -Type string[]
            Get-Command $CommandName | Should -HaveParameter EnableException -Type switch
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
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