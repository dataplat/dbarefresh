<#
    .SYNOPSIS
        Read the configuration file

    .DESCRIPTION
        Read the configuration file and return the objects to be processed

    .PARAMETER FilePath
        Path to the file

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .EXAMPLE
        ConvertFrom-DbrConfig -FilePath "C:\config\config1.json"

        Read the config file
    #>

function ConvertFrom-DbrConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilePath,
        [switch]$EnableException
    )

    if (-not (Test-Path -Path $FilePath)) {
        Stop-PSFFunction -Message "Could not find configuration file" -Target $Path -EnableException:$EnableException
        return
    }

    try {
        $json = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Stop-PSFFunction -Message "Could not read configuration file" -ErrorRecord $_ -Target $Path
    }

    $json

}