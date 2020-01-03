$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"

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

        $query = Get-Content -Path "$PSScriptRoot\..\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $server.Databases.Refresh()

        $db = $server.Databases[$script:destinationdatabase]

        Context "Database pre-checks" {

            [array]$tables = $db.Tables

            [array]$foreignKeys = $tables.ForeignKeys | Sort-Object Name

            It "Database should contain foreign keys" {
                $foreignKeys.Count | Should -Be 2
            }
        }
    }

    Context "Run command with all defaults" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $server.Databases.Refresh()

        $query = Get-Content -Path "$PSScriptRoot\..\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $db = $server.Databases[$script:destinationdatabase]

        # Check before
        [array]$tables = $db.Tables
        [array]$foreignKeys = $tables.ForeignKeys | Sort-Object Name


        It "Database should have correct amount of foreign keys" {
            $foreignKeys.Count | Should -Be 2
        }

        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        [array]$foreignKeys = Get-DbrDbForeignKey @params

        It "Command should return correct amount of foreign keys" {
            $foreignKeys.Count | Should -Be 2
        }

        It "Command should return correct data" {
            $foreignKeys.ReferencedTable | Should -BeIn @('Table1', 'Table2')
            $foreignKeys.ConstraintName | Should -BeIn @('FK__Table2_Table1', 'FK__Table3_Table2')
            $foreignKeys.ParentTable | Should -BeIn @('Table3', 'Table2')
        }
    }

    Context "Run command with table filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $server.Databases.Refresh()

        $query = Get-Content -Path "$PSScriptRoot\..\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            Table           = 'Table2'
            EnableException = $true
        }

        [array]$foreignKeys = Get-DbrDbForeignKey @params

        It "Command should return correct amount of foreign keys" {
            $foreignKeys.Count | Should -Be 1
        }

        It "Command should return correct data" {
            $foreignKeys.ReferencedTable | Should -Be 'Table2'
            $foreignKeys.ConstraintName | Should -Be 'FK__Table3_Table2'
            $foreignKeys.ParentTable | Should -Be 'Table3'
        }
    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false
    }

}