$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the correct parameters" {
            Get-Command $CommandName | Should -HaveParameter FilePath -Type string -Mandatory
            Get-Command $CommandName | Should -HaveParameter EnableException -Type switch
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {

    BeforeAll {
        $jsonFilePathFail = "$PSScriptRoot\..\..\resources\testfail.json"
        $jsonFilePathSuccess = "$PSScriptRoot\..\..\resources\testsuccess.json"
    }

    Context "Test for errors" {
        It "Should generate FilePath error" {
            $failingfilepath = ($jsonFilePathFail.Substring(0, $jsonFilePathFail.Length - 1))
            { ConvertFrom-DbrConfig -FilePath $failingfilepath -EnableException } | Should -Throw "Could not find configuration file"
        }
    }

    Context "Test command" {

        $result = ConvertFrom-DbrConfig -FilePath $jsonFilePathSuccess

        It "Should return objects" {
            $result | Should -Not -Be $null
        }

        It "Should have all the databases" {
            $result.databases.count | Should -Be 2
        }

        It "Should return the correct databases" {
            $result.databases[1].sourceinstance | Should -Be "localhost"
            $result.databases[1].sourcedatabase | Should -BeExactly  "DB2"
            $result.databases[1].destinationinstance | Should -Be "localhost"
            $result.databases[1].destinationdatabase | Should -BeExactly  "DB2"
        }

        It "Should have the correct amount of tables" {
            $result.databases[0].tables.count | Should -Be 2
        }

        It "Should have correct amount of columns" {
            $result.databases[0].tables[0].columns.count | Should -Be 3
        }
    }

}