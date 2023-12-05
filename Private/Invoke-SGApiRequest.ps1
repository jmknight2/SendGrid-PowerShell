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
        $EpochOrigin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
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
            $Response = Invoke-WebRequest @IrmSplat -UseBasicParsing
            Write-Verbose $IrmSplat.URI

            if ($AutoPaginate) {
                $ReturnArray = [System.Collections.ArrayList]@()
                $PaginationOffset = $Limit

                $ReturnArray.AddRange($Response)
    
                while ($Response.count -eq $Limit) {
                    $Response = Invoke-SGApiRequest -Endpoint $Endpoint -Method $Method -Headers $Headers -Limit $Limit -Offset $PaginationOffset
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
            $RetryInSeconds = [Math]::Floor(($origin.AddSeconds($_.Exception.Response.Headers['X-Ratelimit-Reset']) - (Get-Date)).TotalSeconds)
            $RateLimit = $_.Exception.Response.Headers['X-Ratelimit-Limit']

            switch ($_.Exception.Response.StatusCode.Value__) {
                429 {
                    Write-Error -Message "You have exceeded the rate limit of $($RateLimit) API requests. Please try again in $($RetryInSeconds) seconds" -Category LimitsExceeded -ErrorAction Stop

                    if ($AutoPaginate) {
                        return $ReturnArray
                    } else {
                        return $Response
                    }
                }

                default {
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
        }
    }

    End {}    
}