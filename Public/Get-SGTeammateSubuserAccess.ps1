Function Get-SGTeammateSubuserAccess {
    <#
        .Synopsis
        This cmdlet allows you to retrieve the subuser access settings for a SendGrid Teammate.

        .DESCRIPTION
        This cmdlet allows you to retrieve the subuser access settings for a SendGrid Teammate.

        .PARAMETER ApiKey
        The API Key used to authenticate this request.

        .PARAMETER EmailAddress
        The email address of the teammate for which you wish to retrieve subuser access settings.

        .EXAMPLE
        # Retrieve the subuser access settings for a teammate.
        Get-SGTeammateSubuserAccess -ApiKey 'SG.12-************' -EmailAddress 'test@example.com'
    #>
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

        $Endpoint = "/teammates/$($EmailAddress)/subuser_access"
    }

    Process {
        Try {
            Invoke-SGApiRequest -Endpoint $Endpoint -Method 'GET' -Headers $Headers
        } Catch {
            Throw $_
        }
    }

    End {}    
}