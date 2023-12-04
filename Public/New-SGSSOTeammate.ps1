Function New-SGSSOTeammate {
    <#
        .Synopsis
        This cmdlet allows you to create a new SendGrid SSO Teammate.

        .DESCRIPTION
        This cmdlet allows you to create a new SendGrid SSO Teammate.

        .PARAMETER ApiKey
        The API Key used to authenticate this request.

        .PARAMETER OnBehalfOf
        The username or account ID of the subuser on behalf of which you wish to execute commands.

        .PARAMETER Username
        The username of the teammate that you wish to edit. 

        .PARAMETER FirstName
        Use this parameter to set the first name of the new teammate.

        .PARAMETER LastName
        Use this parameter to set the last name of the new teammate.

        .PARAMETER IsAdmin
        Use this switch grant full admin access to the new teammate.

        .PARAMETER Persona
        Use this parameter to set the persona of a teammate. Valid values are: accountant, developer, marketer, 
        observer.

        .PARAMETER Scopes
        Use this parameter to set the scopes of a new teammate. For a list of valid scopes, use Get-SGScopes.

        .PARAMETER HasRestrictedSubuserAccess
        Use this switch to enable restricted subuser access for the new teammate. If this switch is used, you must 
        provide a value for the SubUserAccess parameter.

        .PARAMETER SubUserAccess
        Use this parameter to specify restricted access to one or multiple subusers. This parameter accepts an array of 
        objects with the following properties: id, permission_type, and scopes. Below is an example of a valid object:

        @{
            id = '12345678'
            permission_type = 'Restricted'
            scopes = @('mail.send', 'alerts.create')
        }

        .EXAMPLE
        # Update a teammate's first and last name in the main account.
        Set-SGSSOTeammate -ApiKey 'SG.12-************' -Username 'testuser' -FirstName 'Test' -LastName 'User'

        .EXAMPLE
        # Modify the permission scopes of a teammate in a subuser account.
        Set-SGSSOTeammate -ApiKey 'SG.12-************' -Username 'testuser' -OnBehalfOf 'examplesubuser' -Scopes @('mail.send', 'alerts.create')

        .EXAMPLE
        # Grant a teammate restricted subuser access to 2 subusers, granting the mail.send scope in each.
        $subuserAccess = @(
            @{
                id = '12345678'
                permission_type = 'Restricted'
                scopes = @('mail.send')
            },
            @{
                id = '87654321'
                permission_type = 'Restricted'
                scopes = @('mail.send')
            }
        )
        Set-SGSSOTeammate -ApiKey 'SG.12-************' -Username 'testuser' -HasRestrictedSubuserAccess -SubuserAccess $subuserAccess
    #>
    [CmdletBinding(DefaultParameterSetName='RestrictedPersonaAccess')]
    param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName)]
        [string]$ApiKey,

        [Parameter(Mandatory=$false)]
        [string]$OnBehalfOf,

        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName)]
        [string]$Username,

        [Parameter(Mandatory=$true,Position=2,ValueFromPipelineByPropertyName)]
        [string]$FirstName,

        [Parameter(Mandatory=$true,Position=3,ValueFromPipelineByPropertyName)]
        [string]$LastName,

        [Parameter(Mandatory=$true,ParameterSetName='Admin')]
        [switch]$IsAdmin,

        [Parameter(Mandatory=$true,ParameterSetName='RestrictedPersonaAccess')]
        [ValidateSet('accountant','developer','marketer','observer')]
        [string]$persona,

        [Parameter(Mandatory=$true,ParameterSetName='RestrictedScopeAccess')]
        [string[]]$scopes,

        [Parameter(Mandatory=$true,ParameterSetName='subuser_access')]
        [switch]$HasRestrictedSubuserAccess
    )

    DynamicParam
    {
        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
		
		#SubUserAccess
        if ($HasRestrictedSubuserAccess) {
            $attributes = New-Object System.Management.Automation.ParameterAttribute
            $attributes.ParameterSetName = "subuser_access"
            $attributes.Mandatory = $true

            $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attributes)
            
            $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter('SubUserAccess', [System.Array], $attributeCollection)

            $paramDictionary.Add('SubUserAccess', $dynParam1)
        }

        return $paramDictionary
    }

    Begin {
        $Endpoint = "/sso/teammates"

        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
            'Content-Type' = 'application/json'
        }

        if (![string]::IsNullOrWhiteSpace($OnBehalfOf)) {
            if($OnBehalfOf -is [int]) {
                $Headers.Add('on-behalf-of', "account-id $($OnBehalfOf)")
            } else {
                $Headers.Add('on-behalf-of', "$($OnBehalfOf)")
            }
        }

        $Body = @{
            email = $Username
            has_restricted_subuser_access = $HasRestrictedSubuserAccess.IsPresent
            first_name = $FirstName
            last_name = $LastName
        }

        if ($HasRestrictedSubuserAccess.IsPresent) {
            $Body.Add('subuser_access', $SubUserAccess)
        }

        if ($IsAdmin.IsPresent) {
            $Body.Add('is_admin', $IsAdmin.IsPresent)
        }

        if ($persona) {
            $Body.Add('persona', $persona)
        }

        if ($scopes) {
            $Body.Add('scopes', $scopes)
        }
    }

    Process {
        Try {
            Invoke-SGApiRequest -Endpoint $Endpoint -Method 'POST' -Headers $Headers -Body $Body -ErrorAction Stop
        } Catch {
            Throw $_
        }
    }

    End {}
}