Function New-SGSSOTeammate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName)]
        [string]$Username,

        [Parameter(Mandatory=$true,Position=2,ValueFromPipelineByPropertyName)]
        [string]$FirstName,

        [Parameter(Mandatory=$true,Position=3,ValueFromPipelineByPropertyName)]
        [string]$LastName,

        [Parameter(Mandatory=$false,ParameterSetName='Admin')]
        [switch]$IsAdmin,

        [Parameter(Mandatory=$false,ParameterSetName='RestrictedPersonaAccess')]
        [ValidateSet('accountant','developer','marketer','observer')]
        [string]$persona,

        [Parameter(Mandatory=$false,ParameterSetName='RestrictedScopeAccess')]
        [string[]]$scopes,

        [Parameter(Mandatory=$false,ParameterSetName='subuser_access')]
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
        $Uri = "$($env:SGAPIBaseUri)/sso/teammates"

        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
            'Content-Type' = 'application/json'
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
        Invoke-RestMethod -UseBasicParsing -Uri $Uri -Method POST -Headers $Headers -Body (ConvertTo-Json $Body -Depth 10)
    }

    End {}
}