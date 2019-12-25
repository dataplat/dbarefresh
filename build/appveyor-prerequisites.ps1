Add-AppveyorTest -Name "appveyor.prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

#Write-Host -Object "appveyor.prep: Install psframework" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\psframework')) {
    Install-Module -Name psframework -Force -SkipPublisherCheck -MinimumVersion 1.0 | Out-Null
}

Write-PSFMessage -Message "appveyor.prep: Install Pester" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\Pester')) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 4.9 | Out-Null
}

Write-PSFMessage -Message "appveyor.prep: Install dbatools" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\dbatools')) {
    Install-Module -Name dbatools -Force -SkipPublisherCheck -MinimumVersion 1.0 | Out-Null
}

Write-PSFMessage -Message "appveyor.prep: Install psscriptanalyzer" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\psscriptanalyzer')) {
    Install-Module -Name psscriptanalyzer -Force -SkipPublisherCheck -MinimumVersion 1.0 | Out-Null
}

$pesterVersion = (Get-Module -Name Pester).Version
Write-PSFMessage -Level Important -Message "Pester version: $($pesterVersion)"

. "$PSScriptRoot\appveyor-constants.ps1"

$sw.Stop()
Update-AppveyorTest -Name "appveyor-prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds