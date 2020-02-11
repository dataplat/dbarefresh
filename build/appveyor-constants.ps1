$instance1 = "localhost\sql2017"
$instance2 = "localhost\sql2017"
$sourcedatabase = "DB1"
$destinationdatabase = "DB2"
$defaultexportfilename = "database.json"
$defaultexportfile = (Join-Path -Path $env:USERPROFILE -ChildPath $defaultexportfilename)
