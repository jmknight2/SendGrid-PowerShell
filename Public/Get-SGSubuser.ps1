Function Get-SGSubuser {
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$false, ParameterSetName='SingleSubuser')]
        [string]$Username,

        [Parameter(Mandatory=$true, ParameterSetName='ManualPaging')]
        [int]$Limit,

        [Parameter(Mandatory=$true, ParameterSetName='ManualPaging')]
        [int]$Offset,

        [Parameter(Mandatory=$false, ParameterSetName='MultipleSubusers')]
        [switch]$All
    )

    Begin {
        $Headers = @{
            Authorization = "Bearer $($ApiKey)"
        }

        $Uri = "$($env:SGAPIBaseUri)/subusers"

        if (![string]::IsNullOrWhiteSpace($Username)) {
            $Uri += "?username=$($Username)"
        } elseif ($All.IsPresent) {
            $Uri += "?limit=500"
        } elseif ($Offset -and $Limit) {
            $Uri += "?limit=$($Limit)&offset=$($Offset)"
        }
    }

    Process {
        $Response = Invoke-RestMethod -UseBasicParsing -Uri $Uri -Method Get -Headers $Headers

        if ($All.IsPresent) {
            $ReturnArray = [System.Collections.ArrayList]@()
            $AllOffset = 500

            Write-Verbose "Adding the first 500 results to the array"
            $ReturnArray.AddRange($Response)

            do {
                Write-Verbose "Entering loop to get the next 500 results"
                $Response = Get-SGSubuser -ApiKey $ApiKey -Limit 500 -Offset $AllOffset
                Write-Verbose "Response count: $($Response.count)"
                if ($Response.count -gt 0) {
                    [void]$ReturnArray.AddRange($Response)
                    $AllOffset += 500
                }
            } until ($Response.count -lt 500)

            return $ReturnArray
        } else {
            return $Response
        }
    }

    End {}    
}