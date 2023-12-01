Function New-SGDomain {
    #https://sendgrid.api-docs.io/v3.0/domain-authentication/list-all-authenticated-domains
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
        [string]$Domain,

        [Parameter(Mandatory=$true)]
        [string]$APIKey,

        [Parameter(Mandatory=$false)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string[]]$IpAddresses,

        [Parameter(Mandatory=$false)]
        [switch]$CustomSPF,

        [Parameter(Mandatory=$false)]
        [switch]$Default,

        [Parameter(Mandatory=$false)]
        [switch]$AutomaticSecurity,

        [Parameter(Mandatory=$false)]
        [string]$CustomDKIMSelector,

        [Parameter(Mandatory=$false)]
        [string]$CustomReturnPath
    )

    Begin {
        Function Convert-FromUnixDate ($UnixDate) {
            [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
        }

        # Build the request body
        $Body = @{
            domain=$Domain
            automatic_security = $false
        }

        #This only controls how it outputs the zone in the DNSMigrationModule
        if(($Domain.Split('.').Count - 1) -gt 1) {
            $SubDomain = $Domain.Replace(($Domain.Split('.')[-2..-1] -join '.'),'').Trim('.')
            $Domain = $Domain.Replace($SubDomain,'').Trim('.')
        }

        if($CustomReturnPath) {$Body['subdomain']=$CustomReturnPath} #Subdomain in SG docs is really just the name for custom return paths
        if($Username) {$Body['username']=$Username}
        if($IpAddresses) {$Body['ips']=$IpAddresses}
        if($CustomSPF.IsPresent) {$Body['custom_spf']=$CustomSPF.IsPresent}
        if($Default.IsPresent) {$Body['default']=$Default.IsPresent}
        if($AutomaticSecurity.IsPresent) {$Body['automatic_security']=$AutomaticSecurity.IsPresent}
        if(!([string]::IsNullOrWhiteSpace($CustomDKIMSelector))) {$Body['custom_dkim_selector']=$CustomDKIMSelector}
    }

    Process {
        Try {
            $Response = Invoke-WebRequest -Method Post -Uri 'https://api.sendgrid.com/v3/whitelabel/domains' -Headers @{'authorization'="Bearer $($APIKey)";'content-type'='application/json'} -Body (ConvertTo-Json $Body) -UseBasicParsing
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
                $Response = Invoke-WebRequest -Method Post -Uri 'https://api.sendgrid.com/v3/whitelabel/domains' -Headers @{'authorization'="Bearer $($APIKey)";'content-type'='application/json'} -Body (ConvertTo-Json $Body) -UseBasicParsing
                $Retry = $false
            }
            # Sendgrid is dumb and packages the DNS records inside an object, so we decipher it into a format we can easily consume.
            # Depending upon whether or not automatic_security is true, the field names change. We have to handle that below.
            if(!$AutomaticSecurity.IsPresent) {
                $DNS = @(
                    (
                        (ConvertFrom-Json $Response.Content).dns.dkim |
                            Select-Object -Property @(
                                @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                                @{'Name'='RecordType';Expression={$_.type}},
                                @{'Name'='RecordValues';Expression={$_.data}},
                                @{'Name'='TTL';Expression={'300'}}, 
                                @{'Name'='Zone';Expression={$Domain}}
                            )
                    ),
                    (
                        (ConvertFrom-Json $Response.Content).dns.mail_server |
                            Select-Object -Property @(
                                @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                                @{'Name'='RecordType';Expression={$_.type}},
                                @{'Name'='RecordValues';Expression={"10 $($_.data)"}},
                                @{'Name'='TTL';Expression={'300'}}, 
                                @{'Name'='Zone';Expression={$Domain}}
                            )
                    ),
                    (
                        (ConvertFrom-Json $Response.Content).dns.subdomain_spf |
                            Select-Object -Property @(
                                @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                                @{'Name'='RecordType';Expression={$_.type}},
                                @{'Name'='RecordValues';Expression={$_.data}},
                                @{'Name'='TTL';Expression={'300'}}, 
                                @{'Name'='Zone';Expression={$Domain}}
                            )
                    )
                )
            } else {
                $DNS = @(
                    (
                        (ConvertFrom-Json $Response.Content).dns.dkim1 |
                            Select-Object -Property @(
                                @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                                @{'Name'='RecordType';Expression={$_.type}},
                                @{'Name'='RecordValues';Expression={$_.data}},
                                @{'Name'='TTL';Expression={'300'}}, 
                                @{'Name'='Zone';Expression={$Domain}}
                            )
                    ),
                    (
                        (ConvertFrom-Json $Response.Content).dns.dkim2 |
                            Select-Object -Property @(
                                @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                                @{'Name'='RecordType';Expression={$_.type}},
                                @{'Name'='RecordValues';Expression={$_.data}},
                                @{'Name'='TTL';Expression={'300'}}, 
                                @{'Name'='Zone';Expression={$Domain}}
                            )
                    ),
                    (
                        (ConvertFrom-Json $Response.Content).dns.mail_cname |
                            Select-Object -Property @(
                                @{'Name'='RecordName';Expression={$_.host.Replace(".$($Domain)",'')}}, 
                                @{'Name'='RecordType';Expression={$_.type}},
                                @{'Name'='RecordValues';Expression={$_.data}},
                                @{'Name'='TTL';Expression={'300'}}, 
                                @{'Name'='Zone';Expression={$Domain}}
                            )
                    )
                )
            }
            
            [PSCustomObject]@{
                'DomainID' = (ConvertFrom-Json $Response.Content).id
                'DNS' = $DNS
            }
        } Catch {
            $Errors = (Get-ErrorResponseBody -ExceptionObj $_).errors

            foreach($Err in $Errors) {
                Write-Error "Error field: $($Err.field); Error Message: $($Err.message)"
            }
        }
        
        # I'm leaving this commented since this endpoint doesn't seem to be rate limited and the below block is causing issues.
        <#if([int]($Response.Headers['X-Ratelimit-Remaining'][0]) -eq 0) {
            $WaitTime = ([int]($Response.Headers['X-Ratelimit-Reset'][0]) - [int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s))
            Write-Verbose "We have exceeded or nearly exceeded the rate limit. Pausing for $($WaitTime) seconds."
            Start-Sleep -Seconds $WaitTime
        }#>
    }

    End {      
    }
}