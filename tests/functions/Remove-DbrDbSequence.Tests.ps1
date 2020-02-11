$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter 'Sequence' -Type string[]
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

            [array]$sequences = $db.Sequences | Sort-Object Schema, Name

            It "Database should contain sequences" {
                $sequences.Count | Should -Be 5
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
        [array]$sequences = $db.Sequences | Sort-Object Schema, Name

        It "Database should contain sequences" {
            $sequences.Count | Should -Be 5
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbSequence @params

        $db.Sequences.Refresh()

        # Check after
        [array]$sequences = $db.Sequences | Sort-Object Schema, Name

        It "Database should not contain any sequences" {
            $sequences.Count | Should -Be 0
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
        [array]$sequences = $db.Sequences | Sort-Object Schema, Name

        It "Database should contain sequences" {
            $sequences.Count | Should -Be 5
        }

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            Sequence        = @("Seq1", "Seq3", "Seq5")
            EnableException = $true
        }

        # Remove the views
        Remove-DbrDbSequence @params

        $db.Sequences.Refresh()

        # Check after
        [array]$sequences = $db.Sequences | Sort-Object Schema, Name

        It "Database should contain correct amount of sequences" {
            $sequences.Count | Should -Be 2
        }

        It "Should have the correct sequences" {
            $sequences.Name | Should -BeIn @("Seq2", "Seq4")
        }

    }

    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $server -Database $script:destinationdatabase -Confirm:$false
    }
}
