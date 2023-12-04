Function Get-SGTeammate {
    <#
        .Synopsis
        This cmdlet allows you to retrieve a SendGrid Teammate.

        .DESCRIPTION
        This cmdlet allows you to retrieve a SendGrid Teammate.

        .PARAMETER ApiKey
        The API Key used to authenticate this request.

        .PARAMETER OnBehalfOf
        The ID or username of the subuser you wish to retrieve the teammate(s) from. If not specified, the account 
        where the API key was created will be used.

        .PARAMETER Username
        The username of the teammate you wish to retrieve.

        .PARAMETER All
        Retrieve all teammates. This will return an array of all teammates in the account.

        .PARAMETER Limit
        The number of results to return. This is only required if you are manually paging through results.

        .PARAMETER Offset
        The offset of the results to return. This is only required if you are manually paging through results.

        .EXAMPLE
        # Retrieve a single teammate.
        Get-SGTeammate -ApiKey 'SG.12-************' -Username 'example'
    #>
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$false)]
        [string]$OnBehalfOf,

        [Parameter(Mandatory=$false, ParameterSetName='SingleTeammate')]
        [string]$Username,

        [Parameter(Mandatory=$true, ParameterSetName='ManualPaging')]
        [int]$Limit,

        [Parameter(Mandatory=$true, ParameterSetName='ManualPaging')]
        [int]$Offset,

        [Parameter(Mandatory=$false, ParameterSetName='AllTeammates')]
        [switch]$All
    )

    Begin {
        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
        }

        if (![string]::IsNullOrWhiteSpace($OnBehalfOf)) {
            if($OnBehalfOf -is [int]) {
                $Headers.Add('on-behalf-of', "account-id $($OnBehalfOf)")
            } else {
                $Headers.Add('on-behalf-of', "$($OnBehalfOf)")
            }
        }

        $Endpoint = "/teammates"

        if (![string]::IsNullOrWhiteSpace($Username)) {
            $Endpoint += "/$($Username)"
        } elseif ($All.IsPresent) {
            $Endpoint += "?limit=500"
        } elseif ($Offset -and $Limit) {
            $Endpoint += "?limit=$($Limit)&offset=$($Offset)"
        }
    }

    Process {
        Try {
            $Response = Invoke-SGApiRequest -Endpoint $Endpoint -Method Get -Headers $Headers -ErrorAction Stop

            if ($All.IsPresent) {
                $ReturnArray = [System.Collections.ArrayList]@()
                $AllOffset = 500

                Write-Verbose "Adding the first 500 results to the array"
                $ReturnArray.AddRange($Response)

                do {
                    Write-Verbose "Entering loop to get the next 500 results"
                    $Response = Get-SGTeammate -ApiKey $ApiKey -Limit 500 -Offset $AllOffset
                    Write-Verbose "Response count: $($Response.count)"
                    if ($Response.count -gt 0) {
                        [void]$ReturnArray.AddRange($Response)
                        $AllOffset += 500
                    }
                } until ($Response.count -lt 500)

                return $ReturnArray
            } else {
                if([string]::IsNullOrWhiteSpace($Username)) {
                    return $Response.result
                } else {
                    return $Response
                }
            }
        } Catch {
            Throw $_
        }
    }

    End {}    
}