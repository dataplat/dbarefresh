$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter Table -Type string[]
            Get-Command $CommandName | Should -HaveParameter EnableException -Type switch
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance2

        if ($server.Databases.Name -contains $script:destinationdatabase) {
            Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false
        }

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $server.Databases.Refresh()

        $db = $server.Databases[$script:destinationdatabase]

        Context "Database pre-checks" {

            $tables = @()
            $tables += $db.Tables | Select-Object Schema, Name, ForeignKeys | Sort-Object Schema, Name

            It "Database should contain tables" {
                $tables.Count | Should -Be 3
            }
        }
    }

    Context "Run command with all defaults" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $server.Databases.Refresh()

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $db = $server.Databases[$script:destinationdatabase]

        # Check the table count before
        $tables = @()
        $tables += $db.Tables | Select-Object Schema, Name, ForeignKeys | Sort-Object Schema, Name

        It "Should have tables" {
            $tables.Count | Should -Be 3
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the functions
        Remove-DbrDbTable @params

        $db.Tables.Refresh()

        $tables = @()
        $tables += $db.Tables | Select-Object Schema, Name, ForeignKeys | Sort-Object Schema, Name

        It "Should not have any tables" {
            $tables.Count | Should -Be 0
        }
    }

    Context "Run command with procedure filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $server.Databases.Refresh()

        $db = $server.Databases[$script:destinationdatabase]

        # Check the table count before
        $tables = @()
        $tables += $db.Tables | Select-Object Schema, Name, ForeignKeys | Sort-Object Schema, Name

        It "Should have stored procedures" {
            $tables.Count | Should -Be 3
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            Table           = "Table2"
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbTable @params

        # Check the table count after
        $tables = @()
        $tables += $db.Tables | Select-Object Schema, Name, ForeignKeys | Sort-Object Schema, Name

        It "Should have correct amount of tables" {
            $tables.Count | Should -Be 2
        }

        It "Should have the correct tables" {
            $tables.Name | Should -BeIn @("Table1", "Table3")
        }
    }
}