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
            { Test-DbrConfig -FilePath $failingfilepath -EnableException } | Should -Throw "Could not find configuration file"
        }
    }

    Context "Test successful JSON file" {
        $result = @()
        $result += Test-DbrConfig -FilePath $jsonFilePathSuccess

        It "Should not return any rows" {
            $result.Count | Should -Be 0
        }
    }

    Context "Test failing JSON file" {
        $result = @()
        $result += Test-DbrConfig -FilePath $jsonFilePathFail

        It "Should not return any rows" {
            $result.Count | Should -Be 3
        }

        It "Should return the correct errors" {

            $result[0].Value | Should -Be "sourcedatabase"

            $result[2].Table | Should -Be "Table1"
            $result[2].Column | Should -Be "column2"
            $result[2].Error | Should -Be "varcha is not a supported data type"

        }
    }

}