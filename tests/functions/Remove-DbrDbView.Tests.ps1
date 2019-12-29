$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter View -Type string[]
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
                Type                 = "View"
                ExcludeSystemObjects = $true
            }

            $views = @()
            $views += Get-DbaModule @params

            It "Database should contain views" {
                $views.Count | Should -Be 4
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

        # Check the view count before
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = "View"
            ExcludeSystemObjects = $true
        }

        $views = @()
        $views += Get-DbaModule @params

        It "Should have views" {
            $views.Count | Should -Be 4
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbView @params

        $db.Views.Refresh()

        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = "View"
            ExcludeSystemObjects = $true
        }

        # Check the view count after
        $views = @()
        $views += Get-DbaModule @params

        It "Should not have any views" {
            $views.Count | Should -Be 0
        }
    }

    Context "Run command with view filter" {
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
            Type                 = "View"
            ExcludeSystemObjects = $true
        }

        $views = @()
        $views += Get-DbaModule @params

        It "Should have views" {
            $views.Count | Should -Be 4
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            View            = "View2"
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbView @params

        $db.Views.Refresh()

        # Check the view count after
        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = "View"
            ExcludeSystemObjects = $true
        }

        $views = @()
        $views += Get-DbaModule @params

        It "Should have correct amount of views" {
            $views.Count | Should -Be 3
        }

        It "Should have the correct views" {
            $views.Name | Should -BeIn @("View1", "View3", "View4")
        }
    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false
    }
}