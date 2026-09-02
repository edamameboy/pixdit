param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://[^/]+$')]
    [string]$PublicOrigin,

    [int]$BackendPort = 8001,

    [ValidateSet("caddy", "cloudflare")]
    [string]$TrustedProxyProvider = "caddy"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:TURNSTILE_SITE_KEY) -or [string]::IsNullOrWhiteSpace($env:TURNSTILE_SECRET_KEY)) {
    throw "Public mode membutuhkan TURNSTILE_SITE_KEY dan TURNSTILE_SECRET_KEY. Buat site di Cloudflare Turnstile, lalu set kedua environment variable itu di terminal ini."
}

if ([string]::IsNullOrWhiteSpace($env:IMAGE_PROVIDER)) {
    $env:IMAGE_PROVIDER = "comfyui"
}

$env:TRUSTED_PROXY_PROVIDER = $TrustedProxyProvider

Write-Host ""
Write-Host "Layera public backend akan berjalan hanya di 127.0.0.1:$BackendPort" -ForegroundColor Green
Write-Host "Public origin: $PublicOrigin" -ForegroundColor DarkGray
Write-Host "Trusted proxy: $TrustedProxyProvider" -ForegroundColor DarkGray
Write-Host "Jalankan Caddy/Cloudflare Tunnel di depan backend ini untuk akses publik HTTPS." -ForegroundColor DarkGray
Write-Host ""

& "$PSScriptRoot\server.ps1" -Port $BackendPort -DeploymentMode proxy -PublicOrigin $PublicOrigin
