Function Get-SGTeammateSubuserAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        [string]$EmailAddress
    )

    Begin {
        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
        }

        $Uri = "$($env:SGAPIBaseUri)/teammates/$($EmailAddress)/subuser_access"
    }

    Process {
        Invoke-RestMethod -UseBasicParsing -Uri $Uri -Method Get -Headers $Headers
    }

    End {}    
}