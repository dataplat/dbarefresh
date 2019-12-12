$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        $knownParameters = 'SourceSqlInstance', 'SourceSqlCredential', 'DestinationSqlInstance', 'DestinationSqlCredential', 'SourceDatabase', 'DestinationDatabase', 'Schema', 'Function', 'EnableException'
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

        Context "Database pre-checks" {

            It "Source database should contain functions" {
                $params = @{
                    SqlInstance          = $sourceServer.DomainInstanceName
                    Database             = $script:sourcedatabase
                    Type                 = @("TableValuedFunction", "InlineTableValuedFunction", "ScalarFunction")
                    ExcludeSystemObjects = $true
                }

                $functions = Get-DbaModule @params
                $functions.Count | Should -Be 3
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
            SourceDatabase         = $script:sourcedatabase
            DestinationDatabase    = $script:destinationdatabase
            EnableException        = $true
        }

        # Run command
        Copy-DbrDbFunction @params

        $destDb.Refresh()

        $params = @{
            SqlInstance          = $destServer.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = @("TableValuedFunction", "InlineTableValuedFunction", "ScalarFunction")
            ExcludeSystemObjects = $true
        }

        $functions = Get-DbaModule @params

        It "Destination database should have functions" {
            $functions.Count | Should -BeGreaterThan 0
        }

        It "Destination database should have correct amount of functions" {
            $functions.Count | Should -Be 3
        }
    }

    Context "Execute command with function filter" {
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
            SourceDatabase         = $script:sourcedatabase
            DestinationDatabase    = $script:destinationdatabase
            Function               = @("Function1", "SayHello")
            EnableException        = $true
        }

        # Run command
        Copy-DbrDbFunction @params

        $destDb.Refresh()

        $params = @{
            SqlInstance          = $destServer.DomainInstanceName
            Database             = $script:destinationdatabase
            Type                 = @("TableValuedFunction", "InlineTableValuedFunction", "ScalarFunction")
            ExcludeSystemObjects = $true
        }

        $functions = Get-DbaModule @params

        It "Destination database should have correct amount of functions" {
            $functions.Count | Should -Be 2
        }

        It "Destination database should have correct functions" {
            $functions.Name | Should -BeIn @("Function1", "SayHello")
        }
    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $sourceServer -Database $script:sourcedatabase -Confirm:$false
        $null = Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false
    }
}