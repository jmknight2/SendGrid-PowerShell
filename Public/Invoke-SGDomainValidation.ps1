Function Invoke-SGDomainValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
        [string]$DomainID,

        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

    Begin {}

    Process {
        Try {
            $Response = Invoke-WebRequest -Method Post -Uri "https://api.sendgrid.com/v3/whitelabel/domains/$($DomainID)/validate" -Headers @{'authorization'="Bearer $($APIKey)";'content-type'='application/json'} -UseBasicParsing
        } Catch {
            $errorcode = $_
            switch ($_.Exception.Response.StatusCode.Value__) {
                429 {
                    #We add an arbitary number as utilizing the SG time is prone to breakage.
                    Write-Warning "To many requests, we will retry at the reset interval in $((New-TimeSpan (Convert-FromUnixDate $errorcode.Exception.Response.Headers['X-Ratelimit-Reset']) (Get-Date)).Seconds + 3) seconds"
                    Start-Sleep -Seconds ((New-TimeSpan (Convert-FromUnixDate $errorcode.Exception.Response.Headers['X-Ratelimit-Reset']) (Get-Date)).Seconds + 3)
                    $Retry = $true
                }

                default {
                    exit
                    $Retry = $false
                }
            }
        }
        Try {
            if ($Retry) {
                $Response = Invoke-WebRequest -Method Post -Uri "https://api.sendgrid.com/v3/whitelabel/domains/$($DomainID)/validate" -Headers @{'authorization'="Bearer $($APIKey)";'content-type'='application/json'} -UseBasicParsing
                $Retry = $false
            }

            $Continue = $true
        } Catch {
            if($_ -notlike '*404*') {
                $SGErrors = (Get-ErrorResponseBody -ExceptionObj $_).errors

                foreach($Err in $SGErrors) {
                    Write-Error "Error field: $($Err.field); Error Message: $($Err.message)"
                }
            } else {
                Write-Error "Unable to find domain with ID: $($DomainID). Please double-check the ID value."
            }

            $Continue = $false
        }

        if($Continue) {
            if((ConvertFrom-Json $Response.Content).valid -ne $true) {
                foreach($ErrProp in ((ConvertFrom-Json $Response.Content).validation_results | Get-Member -MemberType NoteProperty).Name) {
                    if(!(ConvertFrom-Json $Response.Content).validation_results.$ErrProp.valid) {
                        Write-Error -Message (ConvertFrom-Json $Response.Content).validation_results.$ErrProp.reason
                    }
                }
            }

            if([int]($Response.Headers['X-Ratelimit-Remaining'][0]) -le 1) {
                $WaitTime = ([int]($Response.Headers['X-Ratelimit-Reset'][0]) - [int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s))
                Write-Verbose "We have exceeded or nearly exceeded the rate limit. Pausing for $($WaitTime) seconds."
                Start-Sleep -Seconds $WaitTime
            }
        }
    }

    End {}
}