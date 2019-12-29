$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
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
            $schemas = @()
            $schemas += $db.Schemas | Where-Object IsSystemObject -eq $false | Sort-Object Name

            It "Database should contain schemas" {
                $schemas.Count | Should -Be 4
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

        $schemas = @()
        $schemas += $db.Schemas | Where-Object IsSystemObject -eq $false | Sort-Object Name

        It "Should have schemas" {
            $schemas.Count | Should -Be 4
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the functions
        Remove-DbrDbSchema @params

        $db.Schemas.Refresh()

        $params = @{
            SqlInstance          = $server.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = @('TableValuedFunction', 'InlineTableValuedFunction', 'ScalarFunction')
            ExcludeSystemObjects = $true
        }

        # Check the function count after
        $schemas = @()
        $schemas += $db.Schemas | Where-Object IsSystemObject -eq $false | Sort-Object Name

        It "Should not have any schemas" {
            $schemas.Count | Should -Be 0
        }
    }

    Context "Run command with schema filter" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $server -Database 'master' -Query $query

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $server -Database $script:destinationdatabase -Query $query

        $server.Databases.Refresh()

        $db = $server.Databases[$script:destinationdatabase]

        $schemas = @()
        $schemas += $db.Schemas | Where-Object IsSystemObject -eq $false | Sort-Object Name

        It "Should have schemas" {
            $schemas.Count | Should -Be 4
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            Schema          = @('Schema1', 'Schema3')
            EnableException = $true
        }

        # Remove the schemas
        Remove-DbrDbSchema @params

        $db.Schemas.Refresh()

        # Check the schema count after
        $schemas = @()
        $schemas += $db.Schemas | Where-Object IsSystemObject -eq $false | Sort-Object Name

        It "Should have correct amount of schemas" {
            $schemas.Count | Should -Be 2
        }

        It "Should have the correct views" {
            $schemas.Name | Should -BeIn @("Schema2", "Schema4")
        }
    }
}