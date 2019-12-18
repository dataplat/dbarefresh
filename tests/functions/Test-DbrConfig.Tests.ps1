$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

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
        $jsonFilePathFail = "$PSScriptRoot\resources\testfail.json"
        $jsonFilePathSuccess = "$PSScriptRoot\resources\testsuccess.json"


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