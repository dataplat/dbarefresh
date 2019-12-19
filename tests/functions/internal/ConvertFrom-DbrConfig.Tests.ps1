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

}