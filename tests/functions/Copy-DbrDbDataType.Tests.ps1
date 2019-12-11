$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        $knownParameters = 'SourceSqlInstance', 'SourceSqlCredential', 'DestinationSqlInstance', 'DestinationSqlCredential', 'SourceDatabase', 'DestinationDatabase', 'Schema', 'DataType', 'EnableException'
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

        $query = "CREATE DATABASE [$($script:destinationdatabase)]"
        Invoke-DbaQuery -SqlInstance $destServer -Database 'master' -Query $query

        $query = Get-Content -Path "$PSScriptRoot\..\..\build\database.sql" -Raw
        Invoke-DbaQuery -SqlInstance $destServer -Database $script:sourcedatabase -Query $query

        $sourceServer.Databases.Refresh()
        $destServer.Databases.refresh()

    }

    Context "Copy data types" {
        $sourceDb = $sourceServer.Databases[$script:sourcedatabase]
        $destDb = $destServer.Databases[$script:destinationdatabase]

        Context "Database pre-checks" {
            It "Should contain data types" {
                $dataTypes = @()
                $dataTypes += $sourceDb.UserDefinedDataTypes | Sort-Object Schema, Name
                $dataTypes.Count | Should BeGreaterThan 0
            }

            It "Should not contain data types" {
                $dataTypes = @()
                $dataTypes += $destDb.UserDefinedDataTypes | Sort-Object Schema, Name
                $dataTypes.Count | Should Be 0
            }
        }

        Context "Execute command" {
            $params = @{
                SourceSqlInstance      = $script:instance1
                DestinationSqlInstance = $destServer
                SourceDatabase         = $sourceDb.Name
                DestinationDatabase    = $destDb.Name
                EnableException        = $true
            }

            Copy-DbrDbDataType @params

            $destDb.UserDefinedDataTypes.Refresh()

            $dataTypes = @()
            $dataTypes += $destDb.UserDefinedDataTypes | Sort-Object Schema, Name

            It "Destination database should have data types" {
                $dataTypes.Count | Should BeGreaterThan 0
            }
        }
    }

    AfterAll {
        #Remove-DbaDatabase -SqlInstance $sourceServer -Database $script:sourcedatabase
        #Remove-DbaDatabase -SqlInstance $destServer -Database $script:destinationdatabase
    }
}