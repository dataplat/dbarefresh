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

        $tempFile = Join-Path "$($env:temp)" -ChildPath "query.sql"

        Context "Prerequisites" {
            $null = New-Item -Path $tempFile -ItemType File -Force

            It "Temp query file should exists" {
                Test-Path -Path $tempFile | Should -Be $true
            }
        }
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
            $result.databases[1].destinationinstance | Should -Be "localhost"
            $result.databases[1].sourcedatabase | Should -BeExactly  "DB1"
            $result.databases[1].destinationdatabase | Should -BeExactly  "DB2"
        }

        It "Should have the correct amount of tables" {
            $result.databases[0].tables.count | Should -Be 2
        }

        It "Should have correct amount of columns" {
            $result.databases[0].tables[0].columns.count | Should -Be 3
        }

        It "Should a query for each table" {
            $result.databases.tables.query.count | Should -Be $result.databases.tables.count
        }

        <# It "Should return the correct queries" {
            $queryText = "^SELECT [id],[column2],[column3] FROM [dbo].[Table1] WHERE [id] IN (1,2,3,4,5,6,7,7,8,9,10) AND [column2] IN ('value1','value2') AND [column3] = ('value3')*\n.*SELECT [id],[column1],[column3] FROM [dbo].[Table2] WHERE [id] IN (SELECT id FROM dbo.table1) AND [column3] = ('value3')SELECT [id],[column1],[column2],[column3] FROM [dbo].[Table1] WHERE [id] = (1)SELECT [id],[column1],[column2] FROM [dbo].[Table2] SELECT [id],[column1],[column2] FROM [dbo].[Table3] WHERE [column2] = ('value3')$"


            Set-Content -Path $tempFile -Value $result.databases.tables.query -NoNewline

            Get-Content -Path $tempFile | Should -FileContentMatchMultiline $queryText
        } #>
    }

    AfterAll {
        $null = Remove-Item -Path $tempFile -Force
    }

}