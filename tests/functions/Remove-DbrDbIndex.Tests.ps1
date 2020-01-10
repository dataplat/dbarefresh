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
            Get-Command $CommandName | Should -HaveParameter Index -Type string[]
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

            [array]$tables = $db.Tables

            [array]$indexes = $tables.Indexes | Sort-Object Name

            It "Database should contain indexs" {
                $indexes.Count | Should -Be 8
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

        # Check before
        [array]$tables = $db.Tables
        [array]$indexes = $tables.Indexes | Sort-Object Name

        It "Database should have correct amount of indexs" {
            $indexes.Count | Should -Be 8
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the indexs
        Remove-DbrDbIndex @params

        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $db = $server.Databases[$script:destinationdatabase]
        [array]$tables = $db.Tables

        # Check after
        It "Database should not contain any indexs" {
            $tables.Indexes.Count | Should -Be 0
        }
    }

    Context "Run command with index filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $server.Databases.Refresh()

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $db = $server.Databases[$script:destinationdatabase]

        # Check before
        [array]$tables = $db.Tables
        [array]$indexes = $tables.Indexes | Sort-Object Name

        It "Database should have correct amount of indexs" {
            $indexes.Count | Should -Be 8
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            Index           = @('NIX__Table1_column2', 'NIX__Table3_column2', 'NIX__Table3_table2id')
            EnableException = $true
        }

        # Remove the indexs
        Remove-DbrDbIndex @params

        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $db = $server.Databases[$script:destinationdatabase]
        [array]$tables = $db.Tables

        # Check after
        It "Database should have the correct amount of indexes" {
            $tables.Indexes.Count | Should -Be 5
        }

        It "Should have the correct index(es)" {
            $tables.Indexes.Name | Should -BeIn @('NIX__Table2_column2', 'NIX__Table2_table1id', 'PK_Table1', 'PK_Table2', 'PK_Table3')
        }
    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false
    }
}
