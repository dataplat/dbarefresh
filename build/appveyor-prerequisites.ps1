Add-AppveyorTest -Name "appveyor.prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Running
$sw = [system.diagnostics.stopwatch]::startNew()

#Write-Host -Object "appveyor.prep: Install psframework" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\psframework\1.1.59')) {
    Install-Module -Name psframework -Force -SkipPublisherCheck -MaximumVersion 1.1.59 | Out-Null
}

Write-PSFMessage -Message "appveyor.prep: Install Pester" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\Pester\4.9.0')) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -MaximumVersion 4.9.0 | Out-Null
}

Write-PSFMessage -Message "appveyor.prep: Install dbatools" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\dbatools\1.0.77')) {
    Install-Module -Name dbatools -Force -SkipPublisherCheck -MaximumVersion 1.0.77 | Out-Null
}

Write-PSFMessage -Message "appveyor.prep: Install psscriptanalyzer" -Level Important
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\psscriptanalyzer\1.18.3')) {
    Install-Module -Name psscriptanalyzer -Force -SkipPublisherCheck -MaximumVersion 1.18.3 | Out-Null
}

. "$PSScriptRoot\appveyor-constants.ps1"

$sw.Stop()
Update-AppveyorTest -Name "appveyor-prerequisites" -Framework NUnit -FileName "appveyor-prerequisites.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds