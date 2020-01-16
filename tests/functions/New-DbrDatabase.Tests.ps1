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
            Get-Command $CommandName | Should -HaveParameter DataFileSizeMB -Type int
            Get-Command $CommandName | Should -HaveParameter DataFileGrowthMB -Type int
            Get-Command $CommandName | Should -HaveParameter DataPath -Type string
            Get-Command $CommandName | Should -HaveParameter LogFileSizeMB -Type int
            Get-Command $CommandName | Should -HaveParameter LogFileGrowth -Type int
            Get-Command $CommandName | Should -HaveParameter LogPath -Type string
            Get-Command $CommandName | Should -HaveParameter RecoveryModel -Type string
            Get-Command $CommandName | Should -HaveParameter Force -Type switch
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

        Context "Database pre-checks" {
            It "Source database should exist" {
                $sourceServer.Databases.Name | Should -Contain $script:sourcedatabase
            }
        }
    }

    Context "Execute command with all defaults" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase -Confirm:$false

        # Setup parameters
        $params = @{
            SourceSqlInstance      = $sourceServer.DomainInstanceName
            DestinationSqlInstance = $destServer.DomainInstanceName
            SourceDatabase         = $script:sourcedatabase
            DestinationDatabase    = $script:destinationdatabase
            EnableException        = $true
        }

        # Run command
        New-DbrDatabase @params

        $destServer.Databases.Refresh()

        It "Destination database should exist" {
            $destServer.Databases.Name | Should -Contain $script:destinationdatabase
        }
    }

    Context "Execute command getting error missing source database" {
        # Preperations
        Remove-DbaDatabase -SqlInstance $destServer -Database $script:sourcedatabase -Confirm:$false

        # Setup parameters
        $params = @{
            SourceSqlInstance      = $sourceServer.DomainInstanceName
            DestinationSqlInstance = $destServer.DomainInstanceName
            SourceDatabase         = $script:sourcedatabase
            DestinationDatabase    = $script:sourcedatabase
            EnableException        = $true
        }

        $destServer.Databases.Refresh()

        It "Command should throw error" {
            { New-DbrDatabase @params } | Should -Throw
        }

        It "Command should return correct error" {
            { New-DbrDatabase @params } | Should -Throw "Source database $($script:sourcedatabase) is not present on $($sourceServer.DomainInstanceName)"
        }
    }

    Context "Execute command getting error existing database" {
        $query = "CREATE DATABASE [$($script:sourcedatabase)]"
        Invoke-DbaQuery -SqlInstance $sourceServer -Database 'master' -Query $query

        # Setup parameters
        $params = @{
            SourceSqlInstance      = $sourceServer.DomainInstanceName
            DestinationSqlInstance = $destServer.DomainInstanceName
            SourceDatabase         = $script:sourcedatabase
            DestinationDatabase    = $script:sourcedatabase
            EnableException        = $true
        }

        $destServer.Databases.Refresh()

        It "Command should throw error" {
            { New-DbrDatabase @params } | Should -Throw
        }

        It "Command should return correct error" {
            { New-DbrDatabase @params } | Should -Throw "Database $script:sourcedatabase already exists on $($destServer.DomainInstanceName)"
        }
    }
}