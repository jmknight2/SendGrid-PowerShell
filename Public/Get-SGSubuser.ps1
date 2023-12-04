Function Get-SGSubuser {
    <#
        .Synopsis
        This cmdlet allows you to retrieve a SendGrid Subuser.

        .DESCRIPTION
        This cmdlet allows you to retrieve a SendGrid Subuser.

        .PARAMETER ApiKey
        The API Key used to authenticate this request.

        .PARAMETER Username
        The username of the subuser you wish to retrieve.

        .PARAMETER All
        Retrieve all subusers. This will return an array of all subusers in the account.

        .PARAMETER Limit
        The number of results to return. This is only required if you are manually paging through results.

        .PARAMETER Offset
        The offset of the results to return. This is only required if you are manually paging through results.

        .EXAMPLE
        # Retrieve a single subuser.
        Get-SGSubuser -ApiKey 'SG.12-************' -Username 'example'
    #>
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$false, ParameterSetName='SingleSubuser')]
        [string]$Username,

        [Parameter(Mandatory=$false, ParameterSetName='AllSubusers')]
        [switch]$All
    )

    Begin {
        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
        }

        $Endpoint = "/subusers"

        if (![string]::IsNullOrWhiteSpace($Username)) {
            $Uri += "?username=$($Username)"
        } elseif ($All.IsPresent) {
            $Uri += "?limit=500"
        } elseif ($Offset -and $Limit) {
            $Uri += "?limit=$($Limit)&offset=$($Offset)"
        }
    }

    Process {
        Try {
            Invoke-SGApiRequest -Endpoint $Endpoint -Method 'GET' -Headers $Headers -Limit 5 -Offset 0 -AutoPaginate $All.IsPresent
        } Catch {
            Throw $_
        }
    }

    End {}    
}