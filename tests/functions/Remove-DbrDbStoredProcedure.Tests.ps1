$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter StoredProcedure -Type string[]
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

        Context "Database pre-checks" {

            $params = @{
                SqlInstance          = $server.DomainInstanceName
                Database             = $script:destinationdatabase
                Type                 = 'StoredProcedure'
                ExcludeSystemObjects = $true
            }

            $procedures = @()
            $procedures += Get-DbaModule @params

            It "Database should contain stored procedures" {
                $procedures.Count | Should -Be 3
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

        # Check the function count before
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = 'StoredProcedure'
            ExcludeSystemObjects = $true
        }

        $procedures = @()
        $procedures += Get-DbaModule @params

        It "Should have stored procedures" {
            $procedures.Count | Should -Be 3
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the functions
        Remove-DbrDbStoredProcedure @params

        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = 'StoredProcedure'
            ExcludeSystemObjects = $true
        }

        # Check the function count after
        $procedures = @()
        $procedures += Get-DbaModule @params

        It "Should not have any stored procedures" {
            $procedures.Count | Should -Be 0
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

        # Check the view count before
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = 'StoredProcedure'
            ExcludeSystemObjects = $true
        }

        $procedures = @()
        $procedures += Get-DbaModule @params

        It "Should have stored procedures" {
            $procedures.Count | Should -Be 3
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            StoredProcedure = "Proc2"
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbStoredProcedure @params

        # Check the view count after
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = 'StoredProcedure'
            ExcludeSystemObjects = $true
        }

        $procedures = @()
        $procedures += Get-DbaModule @params

        It "Should have correct amount of stored procedures" {
            $procedures.Count | Should -Be 2
        }

        It "Should have the correct stored procedures" {
            $procedures.Name | Should -BeIn @("Proc1", "Proc3")
        }
    }
}