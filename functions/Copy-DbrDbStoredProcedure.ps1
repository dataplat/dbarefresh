function Copy-DbrDbStoredProcedure {

    <#
    .SYNOPSIS
        Copy the stored procedures

    .DESCRIPTION
        Copy the stored procedures in a database

    .PARAMETER SourceSqlInstance
        The source SQL Server instance or instances.

    .PARAMETER SourceSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER DestinationSqlInstance
        The target SQL Server instance or instances.

    .PARAMETER DestinationSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER SourceDatabase
        Database to copy the user defined data types from

    .PARAMETER DestinationDatabase
        Database to copy the user defined data types to

    .PARAMETER Schema
        Filter based on schema

    .PARAMETER StoredProcedure
        Stored procedures to filter out

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        Copy-DbrDbStoredProcedure -SqlInstance sqldb1 -Database DB1

        Copy all the stored procedures from the database

    .EXAMPLE
        Copy-DbrDbStoredProcedure -SqlInstance sqldb1 -Database DB1 -StoredProcedure PROC1, PROC2

        Copy all the stored procedures from the database with the name PROC1 and PROC2

    #>

    [CmdLetBinding(SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [DbaInstanceParameter]$SourceSqlInstance,
        [PSCredential]$SourceSqlCredential,
        [parameter(Mandatory)]
        [DbaInstanceParameter]$DestinationSqlInstance,
        [PSCredential]$DestinationSqlCredential,
        [parameter(Mandatory)]
        [string]$SourceDatabase,
        [string]$DestinationDatabase,
        [string[]]$Schema,
        [string[]]$StoredProcedure,
        [switch]$EnableException
    )

    begin {
        $progressId = 1

        $task = "Collecting stored procedures"

        Write-Progress -Id ($progressId + 2) -ParentId ($progressId + 1) -Activity $task

        try {
            $params = @{
                SqlInstance          = $SourceSqlInstance
                SqlCredential        = $SourceSqlCredential
                Database             = $SourceDatabase
                Type                 = "StoredProcedure"
                ExcludeSystemObjects = $true
            }

            [array]$procedures = Get-DbaModule @params
            [array]$procedures = $procedures | Sort-Object SchemaName, Name
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve stored procedures from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        # Filter out the stored procedures based on schema
        if ($Schema) {
            [array]$procedures = $procedures | Where-Object SchemaName -in $Schema
        }

        # Filter out the stored procedures based on name
        if ($StoredProcedure) {
            [array]$procedures = $procedures | Where-Object Name -in $StoredProcedure
        }

        # Get the databases
        try {
            $sourceDb = Get-DbaDatabase -SqlInstance $SourceSqlInstance -SqlCredential $SourceSqlCredential -Database $SourceDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from source instance" -ErrorRecord $_ -Target $SourceSqlInstance
        }

        try {
            $destDb = Get-DbaDatabase -SqlInstance $DestinationSqlInstance -SqlCredential $DestinationSqlCredential -Database $DestinationDatabase
        }
        catch {
            Stop-PSFFunction -Message "Could not retrieve database from destination instance" -ErrorRecord $_ -Target $DestinationSqlInstance
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $totalObjects = $procedures.Count
        $objectStep = 0

        if ($totalObjects -ge 1) {
            if ($PSCmdlet.ShouldProcess("Copying stored procedures to database $SourceDatabase")) {

                foreach ($object in $procedures) {
                    if ($object.Name -notin $destDb.StoredProcedures.Name) {
                        $objectStep++
                        $task = "Creating Stored Procedure(s)"
                        $operation = "Stored Procedure [$($object.SchemaName)].[$($object.Name)]"

                        $params = @{
                            Id               = ($progressId + 2)
                            ParentId         = ($progressId + 1)
                            Activity         = $task
                            Status           = "Progress-> Procedure $objectStep of $totalObjects"
                            PercentComplete  = $($objectStep / $totalObjects * 100)
                            CurrentOperation = $operation
                        }

                        Write-Progress @params

                        Write-PSFMessage -Level Verbose -Message "Creating stored procedure [$($object.SchemaName)].[$($object.Name)] in $($SourceDatabase)"

                        try {
                            $query = ($sourceDb.StoredProcedures | Where-Object { $_.Schema -eq $object.SchemaName -and $_.Name -eq $object.Name }) | Export-DbaScript -Passthru -NoPrefix | Out-String

                            $params = @{
                                SqlInstance     = $DestinationSqlInstance
                                SqlCredential   = $DestinationSqlCredential
                                Database        = $DestinationDatabase
                                Query           = $query
                                EnableException = $true
                            }

                            Invoke-DbaQuery @params
                        }
                        catch {
                            Stop-PSFFunction -Message "Could not create procedure [$($object.SchemaName)].[$($object.Name)] in $($sourceDbName)`n$_" -Target $procedure -ErrorRecord $_
                        }

                        [PSCustomObject]@{
                            SourceSqlInstance      = $SourceSqlInstance
                            DestinationSqlInstance = $DestinationSqlInstance
                            SourceDatabase         = $SourceDatabase
                            DestinationDatabase    = $DestinationDatabase
                            ObjectType             = "Stored Procedure"
                            Parent                 = $null
                            Object                 = "$($object.SchemaName).$($object.Name)"
                            Information            = $null
                        }
                    }
                    else {
                        Write-PSFMessage -Message "Procedure [$($object.SchemaName)].[$($object.Name)] already exists. Skipping..." -Level Verbose
                    }
                }
            }
        }
    }
}