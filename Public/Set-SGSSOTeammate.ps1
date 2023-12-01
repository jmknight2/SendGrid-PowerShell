Function Set-SGSSOTeammate {
    <#
        .Synopsis
        This cmdlet allows you to modify an existing SSO Teammate.

        .DESCRIPTION
        Finds the specified zone in AWS Route 53, if it exists, and adds a record with the specified info to that
        zone. If the zone doesn't exist, then the command creates the zone and adds the record to it.

        .PARAMETER RecordName
        The name field of the DNS record.

        .PARAMETER Zone
        The name of the zone under which this record wil be placed.

        .PARAMETER RecordType
        The type of the DNS record which will be added to the zone. Acceptable values are: A|AAAA|CNAME|MX|SRV|TXT

        .PARAMETER RecordValues
        The actual values to be placed in the DNS record.

        .PARAMETER TTL
        The Time To Live for the record to be added. If not present, 300 is used by default.

        .PARAMETER DelegationSetID
        This can be used to set the delegation set for every record processed on this command
        If you specificy this parameter and the zone exists on another delegation set,
        we will override that existing zone and remake it

        .PARAMETER AWSProfile
        Dynamically generated parameter that populates intellisense based upon the AWS profiles installed on your 
        machine. If you don't see any intellisense options, then you need to use the Set-AWSCredential command to 
        setup an AWS Credential Profile.

        .PARAMETER Tags
        This parameter accepts one or more objects containing tag details and converts them into tags which are 
        applied to the Route 53 zone. The object model is as follows:
        
            [PSCustomObject]@{
                Key='[My Tag Name]'
                Value='[My Tag Contents]'
            }

        .PARAMETER CreateZone
        This switch must be present to complete actions that require the creation of a new zone.

        .EXAMPLE
        New-R53ResourceRecordSet -RecordName email -Zone example.com -RecordType MX -RecordValues '10 mx.emailprovider.com' -TTL 600 -AWSProfile exampleprofile
    #>
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName)]
        [string]$Username,

        [Parameter(Mandatory=$false,Position=2,ValueFromPipelineByPropertyName)]
        [string]$FirstName,

        [Parameter(Mandatory=$false,Position=3,ValueFromPipelineByPropertyName)]
        [string]$LastName,

        [Parameter(Mandatory=$false)]
        [string]$SubuserUsername,

        [Parameter(Mandatory=$false,ParameterSetName='Admin')]
        [switch]$IsAdmin,

        [Parameter(Mandatory=$false,ParameterSetName='RestrictedPersonaAccess')]
        [ValidateSet('accountant','developer','marketer','observer')]
        [string]$persona,

        [Parameter(Mandatory=$false,ParameterSetName='RestrictedScopeAccess')]
        [ValidateSet([SendgridScope])]
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
        $Uri = "$($env:SGAPIBaseUri)/sso/teammates/$($Username)"

        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
            'Content-Type' = 'application/json'
        }

        if (![string]::IsNullOrWhiteSpace($SubuserUsername)) {
            $Headers.Add('on-behalf-of', $SubuserUsername)
        }

        $Body = @{
            has_restricted_subuser_access = $HasRestrictedSubuserAccess.IsPresent
        }

        if ($HasRestrictedSubuserAccess.IsPresent) {
            $Body.Add('subuser_access', $PSBoundParameters.SubUserAccess)
        }

        if (![string]::IsNullOrWhiteSpace($FirstName)) {
            $Body.Add('first_name', $FirstName)
        }

        if (![string]::IsNullOrWhiteSpace($LastName)) {
            $Body.Add('last_name', $LastName)
        }

        if ($IsAdmin.IsPresent) {
            $Body.Add('is_admin', $IsAdmin.IsPresent)
        }

        if (![string]::IsNullOrWhiteSpace($persona)) {
            $Body.Add('persona', $persona)
        }

        if ($scopes) {
            $Body.Add('scopes', $scopes)
        }
    }

    Process {
        Invoke-RestMethod -UseBasicParsing -Uri $Uri -Method PATCH -Headers $Headers -Body (ConvertTo-Json $Body -Depth 10)
    }

    End {}    
}