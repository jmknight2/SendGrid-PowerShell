Function Remove-SGTeammate {
    <#
        .Synopsis
        This cmdlet allows you to remove an existing SendGrid Teammate.

        .DESCRIPTION
        This cmdlet allows you to remove an existing SendGrid Teammate.

        .PARAMETER ApiKey
        The API Key used to authenticate this request.

        .PARAMETER OnBehalfOf
        The username or account ID of the subuser on behalf of which you wish to execute commands.

        .PARAMETER Username
        The username of the teammate that you wish to remove.

        .EXAMPLE
        # Remove a teammate from the main account.
        Remove-SGTeammate -ApiKey 'SG.12-************' -Username 'testuser'

        .EXAMPLE
        # Remove a teammate from a subuser account.
        Remove-SGTeammate -ApiKey 'SG.12-************' -Username 'testuser' -OnBehalfOf 'examplesubuser'
    #>
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName)]
        [string]$ApiKey,

        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName)]
        [string]$OnBehalfOf,

        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName)]
        [string]$Username
    )

    Begin {
        $Endpoint = "/teammates/$($Username)"

        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
        }

        # If the OnBehalfOf parameter is used, we need to add the appropriate header.
        if (![string]::IsNullOrWhiteSpace($OnBehalfOf)) {
            if($OnBehalfOf -is [int]) {
                $Headers.Add('on-behalf-of', "account-id $($OnBehalfOf)")
            } else {
                $Headers.Add('on-behalf-of', "$($OnBehalfOf)")
            }
        }
    }

    Process {
        Try {
            Invoke-SGApiRequest -Endpoint $Endpoint -Headers $Headers -Method 'DELETE' -ErrorAction Stop
        } Catch {
            Throw $_
        }
    }

    End {}    
}