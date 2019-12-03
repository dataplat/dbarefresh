# constants
if (Test-Path C:\temp\constants.ps1) {
    Write-Verbose "C:\temp\constants.ps1 found."
    . C:\temp\constants.ps1
}
else {
    $script:instance1 = "localhost"
    $script:instance2 = "localhost"
    $script:sourcedatabase = "DB1"
    $script:destinationdatabase = "DB2"
}