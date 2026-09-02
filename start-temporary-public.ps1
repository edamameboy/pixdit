param(
    [Parameter(Mandatory = $true)]
    [string]$PublicHost,

    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$authority = $PublicHost.Trim()
$authority = $authority -replace '^https?://', ''
$authority = ($authority -split '/')[0]
if ([string]::IsNullOrWhiteSpace($authority)) { throw "Isi -PublicHost dengan public IP/domain yang akan dibuka teman, contoh 123.45.67.89:8000." }
if ($authority -notmatch ':\d+$' -and $Port -ne 80) { $authority = "$authority`:$Port" }

$publicOrigin = "http://$authority"
$parsedOrigin = $null
if (-not [Uri]::TryCreate($publicOrigin, [UriKind]::Absolute, [ref]$parsedOrigin) -or -not [string]::IsNullOrWhiteSpace($parsedOrigin.PathAndQuery.Trim('/'))) {
    throw "Public host tidak valid. Gunakan format seperti 123.45.67.89:8000 atau demo.example.com:8000."
}

if ([string]::IsNullOrWhiteSpace($env:IMAGE_PROVIDER)) {
    $env:IMAGE_PROVIDER = "comfyui"
}

Write-Host ""
Write-Host "Layera public sementara akan berjalan di semua network interface pada port $Port." -ForegroundColor Yellow
Write-Host "Bagikan URL ini: $publicOrigin" -ForegroundColor Green
Write-Host "Mode ini memakai HTTP biasa. Gunakan hanya untuk demo singkat, bukan user publik serius." -ForegroundColor Yellow
Write-Host "Matikan server dan hapus port forwarding setelah selesai." -ForegroundColor Yellow
Write-Host ""

& "$PSScriptRoot\server.ps1" -Port $Port -DeploymentMode public-http -PublicOrigin $publicOrigin
