Add-AppveyorTest -Name "appveyor.prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

choco install Pester, dbatools, psframework, psscriptanalyzer  -y  --no-progress --limit-output

Write-PSFMessage -Level Important -Message "Pester version: $((Get-Module -Name Pester).Version)"

. "$PSScriptRoot\appveyor-constants.ps1"

<# Write-PSFMessage -Level Host -Message "Setup Database"
$server = Connect-DbaInstance -SqlInstance $instance

if ($server.Databases.Name -notcontains $database) {
    # Create the database
    $query = "CREATE DATABASE $($database)"
    $server.Query($query)

    # Refresh the server object
    $server.Refresh()

    Invoke-DbaQuery -SqlInstance $instance -Database $database -File "$PSScriptRoot\..\tests\functions\database.sql"

    $server.Databases.Refresh()

    if ($server.Databases[$database].Tables.Name -notcontains 'Person') {
        Stop-PSFFunction -Message "Database creation unsuccessful!"
        return
    }
} #>

Write-PSFMessage -Level Important -Message "Disabling UAC"
Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0


$sw.Stop()
Update-AppveyorTest -Name "appveyor-prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds