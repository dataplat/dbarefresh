$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter TableType -Type string[]
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

            [array]$tabletypes = $db.UserDefinedTableTypes | Sort-Object Schema, Name

            It "Database should contain table types" {
                $tabletypes.Count | Should -Be 2
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
        [array]$tabletypes = $db.UserDefinedTableTypes | Sort-Object Schema, Name

        It "Database should contain table types" {
            $tabletypes.Count | Should -Be 2
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbTableType @params

        $db.UserDefinedTableTypes.Refresh()

        # Check after
        [array]$tabletypes = $db.UserDefinedTableTypes | Sort-Object Schema, Name

        It "Database should not contain any table types" {
            $tabletypes.Count | Should -Be 0
        }
    }

    Context "Run command with data type filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $server.Databases.Refresh()

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $db = $server.Databases[$script:destinationdatabase]

        # Check before
        [array]$tabletypes = $db.UserDefinedTableTypes | Sort-Object Schema, Name

        It "Database should contain table types" {
            $tabletypes.Count | Should -Be 2
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            TableType       = "Tabletype1"
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbTableType @params

        $db.UserDefinedTableTypes.Refresh()

        # Check after
        [array]$tabletypes = $db.UserDefinedTableTypes | Sort-Object Schema, Name

        It "Database should contain correct amount of table types" {
            $tabletypes.Count | Should -Be 1
        }

        It "Should have the correct table types" {
            $tabletypes.Name | Should -Be "TableType2"
        }
    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false
    }

}