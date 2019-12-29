$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter Function -Type string[]
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
                Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
                ExcludeSystemObjects = $true
            }

            $functions = @()
            $functions += Get-DbaModule @params

            It "Database should contain functions" {
                $functions.Count | Should -Be 3
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
            Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
            ExcludeSystemObjects = $true
        }

        $functions = @()
        $functions += Get-DbaModule @params

        It "Should have functions" {
            $functions.Count | Should -Be 3
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the functions
        Remove-DbrDbFunction @params

        $db.UserDefinedFunctions.Refresh()

        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
            ExcludeSystemObjects = $true
        }

        # Check the function count after
        $functions = @()
        $functions += Get-DbaModule @params

        It "Should not have any functions" {
            $functions.Count | Should -Be 0
        }
    }

    Context "Run command with function filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $server.Databases.Refresh()

        $db = $server.Databases[$script:destinationdatabase]

        # Check the view count before
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
            ExcludeSystemObjects = $true
        }

        $functions = @()
        $functions += Get-DbaModule @params

        It "Should have functions" {
            $functions.Count | Should -Be 3
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            Function        = "RandomNumberFunction"
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbFunction @params

        $db.UserDefinedFunctions.Refresh()

        # Check the view count after
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
            ExcludeSystemObjects = $true
        }

        $functions = @()
        $functions += Get-DbaModule @params

        It "Should not have correct amount of functions" {
            $functions.Count | Should -Be 2
        }

        It "Should have the correct views" {
            $functions.Name | Should -BeIn @("Function1", "SayHello")
        }
    }
}
