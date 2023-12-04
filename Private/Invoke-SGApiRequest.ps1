function Invoke-SGApiRequest {
    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,

        [Parameter(Mandatory=$true)]
        [hashtable]$Headers,

        [Parameter(Mandatory=$true)]
        [string]$Method,

        [Parameter(Mandatory=$false)]
        [hashtable]$Body,

        [Parameter(Mandatory=$false, ParameterSetName='AutoPaging')]
        [int]$Limit,

        [Parameter(Mandatory=$false, ParameterSetName='AutoPaging')]
        [int]$Offset=0,

        [Parameter(Mandatory=$false, ParameterSetName='AutoPaging')]
        [bool]$AutoPaginate
    )

    Begin {
        $Uri = "$($env:SGAPIBaseUri)$($Endpoint)"

        if (($null -ne $Limit) -and ($null -ne $Offset)) {
            if ($Uri.Contains('?')) {
                $Uri += "&"
            } else {
                $Uri += "?"
            }
            $Uri += "limit=$($Limit)&offset=$($Offset)"
        }
        
        # Build the splat for Invoke-RestMethod
        $IrmSplat = @{
            URI = $Uri
            Method = $Method
            Headers = $Headers
            ErrorAction = 'Stop'
        }

        # If a body was provided, convert it to JSON and add it to the splat.
        if ($null -ne $Body) {
            $IrmSplat.Add('Body', (ConvertTo-Json -InputObject $Body -Depth 10))
        }
    }

    Process {
        try {
            $Response = Invoke-RestMethod @IrmSplat -UseBasicParsing
            Write-Verbose $IrmSplat.URI

            if ($AutoPaginate) {
                $ReturnArray = [System.Collections.ArrayList]@()
                $PaginationOffset = $Limit
    
                Write-Verbose "Adding the first $($Limit) results to the array"
                $ReturnArray.AddRange($Response)
    
                while ($Response.count -eq $Limit) {
                    Write-Verbose "Entering loop to get the next 500 results"
                    $Response = Invoke-SGApiRequest -Endpoint $Endpoint -Method $Method -Headers $Headers -Limit $Limit -Offset $PaginationOffset
                    Write-Verbose "Response count: $($Response.count)"
                    if ($Response.count -gt 0) {
                        [void]$ReturnArray.AddRange($Response)
                        $PaginationOffset += $Limit
                    }
                }
    
                return $ReturnArray
            } else {
                return $Response
            }
        } catch {
            $Errors = ConvertFrom-Json -InputObject (Get-ErrorResponseBody $_)

            foreach ($Err in $Errors.errors) {
                if (![string]::IsNullOrWhiteSpace($Err.error_id)) {
                    $ErrorId = $Err.error_id
                }
                
                if (![string]::IsNullOrWhiteSpace($Err.field)) {
                    $ErrorTarget = $Err.field
                }

                Write-Error $Err.message -Category ObjectNotFound -ErrorId $ErrorId -TargetObject $ErrorTarget -ErrorAction Stop

                [void](Remove-Variable -Name ErrorId,ErrorTarget -ErrorAction SilentlyContinue)
            }
        }
    }

    End {}    
}