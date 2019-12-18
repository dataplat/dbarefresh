$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\..\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        $knownParameters = 'FilePath', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'UnitTests' {

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