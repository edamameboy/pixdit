param(
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$ServerPath = Join-Path $ProjectRoot "server.ps1"
$PreviousProvider = $env:IMAGE_PROVIDER
$PreviousNevaGateKey = $env:NEVAGATE_API_KEY
$secureKey = Read-Host "Masukkan NEVAGATE_API_KEY (input disembunyikan)" -AsSecureString
$keyPointer = [IntPtr]::Zero

try {
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    if ([string]::IsNullOrWhiteSpace($plainKey)) { throw "API key NevaGate tidak boleh kosong." }

    $env:IMAGE_PROVIDER = "nevagate"
    $env:NEVAGATE_API_KEY = $plainKey.Trim()
    $plainKey = $null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ServerPath -Port $Port
    if ($LASTEXITCODE -ne 0) { throw "Server Kanvas berhenti dengan exit code $LASTEXITCODE." }
}
finally {
    if ($keyPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer) }
    if ($null -eq $PreviousProvider) { Remove-Item Env:IMAGE_PROVIDER -ErrorAction SilentlyContinue } else { $env:IMAGE_PROVIDER = $PreviousProvider }
    if ($null -eq $PreviousNevaGateKey) { Remove-Item Env:NEVAGATE_API_KEY -ErrorAction SilentlyContinue } else { $env:NEVAGATE_API_KEY = $PreviousNevaGateKey }
}
