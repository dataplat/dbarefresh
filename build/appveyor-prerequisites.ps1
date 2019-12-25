Add-AppveyorTest -Name "appveyor.prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

Write-Host -Object "appveyor.prep: Install Pester" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\Pester\4.9')) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 4.9 | Out-Null
}


Write-Host -Object "appveyor.prep: Install dbatools" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\dbatools\1.0')) {
    Install-Module -Name dbatools -Force -SkipPublisherCheck -MinimumVersion 1.0 | Out-Null
}

Write-Host -Object "appveyor.prep: Install psframework" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\psframework\1.0')) {
    Install-Module -Name psframework -Force -SkipPublisherCheck -MinimumVersion 1.0 | Out-Null
}

Write-Host -Object "appveyor.prep: Install psscriptanalyzer" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\psscriptanalyzer\1.0')) {
    Install-Module -Name psscriptanalyzer -Force -SkipPublisherCheck -MinimumVersion 1.0 | Out-Null
}

$pesterVersion = (Get-Module -Name Pester).Version
Write-PSFMessage -Level Important -Message "Pester version: $($pesterVersion)"

. "$PSScriptRoot\appveyor-constants.ps1"

$sw.Stop()
Update-AppveyorTest -Name "appveyor-prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds