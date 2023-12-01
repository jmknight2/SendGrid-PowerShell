Function New-SGBrandedLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
        [string]$Domain,

        [Parameter(Mandatory=$true)]
        [string]$APIKey,

        [Parameter(Mandatory=$false)]
        [switch]$Default,

        [Parameter(Mandatory=$false)]
        [string]$CustomReturnPath
    )

    Begin {
        # Build the request body
        $Body = @{
            domain=$Domain
        }

        if(($Domain.Split('.').Count - 1) -gt 1) {
            $SubDomain = $Domain.Replace(($Domain.Split('.')[-2..-1] -join '.'),'').Trim('.')
            $Domain = $Domain.Replace($SubDomain,'').Trim('.')
        }

        if($CustomReturnPath) {$Body['subdomain']=$CustomReturnPath} #Subdomain in SG docs is really just the name for custom return paths
        if($Default.IsPresent) {$Body['default']=$Default.IsPresent}
    }

    Process {
        Try {
            $Response = Invoke-WebRequest -Method Post -Uri 'https://api.sendgrid.com/v3/whitelabel/links' -Headers @{'authorization'="Bearer $($APIKey)";'content-type'='application/json'} -Body (ConvertTo-Json $Body) -UseBasicParsing
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
                $Response = Invoke-WebRequest -Method Post -Uri 'https://api.sendgrid.com/v3/whitelabel/links' -Headers @{'authorization'="Bearer $($APIKey)";'content-type'='application/json'} -Body (ConvertTo-Json $Body) -UseBasicParsing
                $Retry = $false
            }

            $DNS = @(
                (
                    (ConvertFrom-Json $Response.Content).dns.domain_cname |
                        Select-Object -Property @(
                            @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                            @{'Name'='RecordType';Expression={$_.type}},
                            @{'Name'='RecordValues';Expression={$_.data}},
                            @{'Name'='TTL';Expression={'300'}}, 
                            @{'Name'='Zone';Expression={$Domain}}
                        )
                ),
                (
                    (ConvertFrom-Json $Response.Content).dns.owner_cname |
                        Select-Object -Property @(
                            @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                            @{'Name'='RecordType';Expression={$_.type}},
                            @{'Name'='RecordValues';Expression={$_.data}},
                            @{'Name'='TTL';Expression={'300'}}, 
                            @{'Name'='Zone';Expression={$Domain}}
                        )
                )
            )

            [PSCustomObject]@{
                'DomainID' = (ConvertFrom-Json $Response.Content).id
                'DNS' = $DNS
            }
        } Catch {
            $Errors = (Get-ErrorResponseBody -ExceptionObj $_).errors

            foreach($Error in $Errors) {
                Write-Error "Error field: $($Error.field); Error Message: $($Error.message)"
            }
        }

        if([int]($Response.Headers['X-Ratelimit-Remaining'][0]) -le 1) {
            $WaitTime = ([int]($Response.Headers['X-Ratelimit-Reset'][0]) - [int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s))
            Write-Verbose "We have exceeded or nearly exceeded the rate limit. Pausing for $($WaitTime) seconds."
            Start-Sleep -Seconds $WaitTime
        }
    }

    End {}
}