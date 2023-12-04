function Get-SGScopes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    Begin {
        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
        }

        $Uri = "$($env:SGAPIBaseUri)/scopes"
    }

    Process {
        Invoke-RestMethod -UseBasicParsing -Uri $Uri -Method Get -Headers $Headers | Select-Object -ExpandProperty scopes
    }

    End {}
}
