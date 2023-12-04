# Pulls the error response out of REST method calls, because Invoke-RestMethod won't give them to us.
# Source: https://stackoverflow.com/a/48154663/7838933
Function Get-ErrorResponseBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [System.Management.Automation.ErrorRecord]$ExceptionObj
    )

    Begin {}

    Process {
        if ($PSVersionTable.PSVersion.Major -gt 6) { 
            $result = $ExceptionObj.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()

            Try {
                ConvertFrom-Json $reader.ReadToEnd()
            } Catch {
                [PSCustomObject]@{
                    error = $reader.ReadToEnd()
                }
            }
        } else {
            $ExceptionObj.ErrorDetails.Message
        }
    }

    End {
        if($reader) {
            $reader.Close() 
        }
    }
}