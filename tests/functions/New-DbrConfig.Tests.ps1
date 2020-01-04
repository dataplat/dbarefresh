$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter SqlInstance -Type DbaInstanceParameter -Mandatory
            Get-Command $CommandName | Should -HaveParameter SqlCredential -Type PSCredential
            Get-Command $CommandName | Should -HaveParameter Database -Type string[] -Mandatory
            Get-Command $CommandName | Should -HaveParameter Schema -Type string[]
            Get-Command $CommandName | Should -HaveParameter Table -Type string[]
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

            It "Database should contain tables" {
                $db.Tables.Count | Should -Be 3
            }
        }
    }

    Context "Run command with all defaults" {

        # Setup parameters
        $params = @{
            SqlInstance     = $server.DomainInstanceName
            Database        = $script:destinationdatabase
            OutFilePath     = $script:defaultexportfile
            EnableException = $true
        }

        New-DbrConfig @params

        It "Should have created file" {
            Test-Path -Path $script:defaultexportfile | Should -Be $true
        }

        It "Should contain data" {
            $data = Get-Content -Path $Script:defaultexportfile
            $data.Length | Should -Be 95
        }

        It "Should contain correct data" {
            $json = ConvertFrom-DbrConfig -FilePath $Script:defaultexportfile

            $json.databases.Count | Should -Be 1
            $json.databases[0].sourceinstance | Should -Be $server.DomainInstanceName
            $json.databases[0].destinationinstance | Should -Be $server.DomainInstanceName
            $json.databases[0].database | Should -Be $script:destinationdatabase
            $json.databases[0].tables.Count | Should -Be 3

            $json.databases[0].tables[1].fullname | Should -Be "dbo.Table2"
            $json.databases[0].tables[1].schema | Should -Be "dbo"
            $json.databases[0].tables[1].name | Should -Be "Table2"
            $json.databases[0].tables[1].query | Should -Be "SELECT [id],[column1],[column2],[table1id] FROM [dbo].[Table2] "
            $json.databases[0].tables[1].columns.count | Should -Be 4
            $json.databases[0].tables[1].columns[1].name | Should -Be "column1"
            $json.databases[0].tables[1].columns[1].datatype | Should -Be "varchar"
            $json.databases[0].tables[1].columns[1].filter | Should -Be $null
        }
    }

}