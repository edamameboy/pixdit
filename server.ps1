param(
    [int]$Port = 8000,
    [ValidateSet("local", "lan", "proxy", "public-http")][string]$DeploymentMode = "local",
    [string]$PublicOrigin = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$GeneratedRoot = Join-Path $ProjectRoot "generated"
$DeploymentMode = $DeploymentMode.Trim().ToLowerInvariant()
$PublicMode = $DeploymentMode -eq "proxy"
$TemporaryPublicMode = $DeploymentMode -eq "public-http"
$InternetExposedMode = $PublicMode -or $TemporaryPublicMode
$PublicOrigin = $PublicOrigin.Trim().TrimEnd('/')
$PublicOriginUri = $null
$TurnstileSiteKey = if ($env:TURNSTILE_SITE_KEY) { $env:TURNSTILE_SITE_KEY.Trim() } else { "" }
$TurnstileSecretKey = if ($env:TURNSTILE_SECRET_KEY) { $env:TURNSTILE_SECRET_KEY.Trim() } else { "" }
$TrustedProxyProvider = if ($env:TRUSTED_PROXY_PROVIDER) { $env:TRUSTED_PROXY_PROVIDER.Trim().ToLowerInvariant() } else { "caddy" }
if ($TrustedProxyProvider -notin @("caddy", "cloudflare")) { throw "TRUSTED_PROXY_PROVIDER harus 'caddy' atau 'cloudflare'." }
if ($InternetExposedMode) {
    $parsedPublicOrigin = $null
    $requiredScheme = if ($PublicMode) { "https" } else { "http" }
    if (-not [Uri]::TryCreate($PublicOrigin, [UriKind]::Absolute, [ref]$parsedPublicOrigin) -or $parsedPublicOrigin.Scheme -ne $requiredScheme -or -not [string]::IsNullOrWhiteSpace($parsedPublicOrigin.PathAndQuery.Trim('/'))) {
        $originExample = if ($PublicMode) { "https://app.example.com" } else { "http://123.45.67.89:8000" }
        throw "Mode $DeploymentMode memerlukan -PublicOrigin berupa origin $($requiredScheme.ToUpperInvariant()) tanpa path, contoh $originExample."
    }
    $PublicOriginUri = $parsedPublicOrigin
    if ($PublicMode -and ([string]::IsNullOrWhiteSpace($TurnstileSiteKey) -or [string]::IsNullOrWhiteSpace($TurnstileSecretKey))) {
        throw "Mode proxy publik memerlukan TURNSTILE_SITE_KEY dan TURNSTILE_SECRET_KEY."
    }
}
$ImageProvider = if ($env:IMAGE_PROVIDER) { $env:IMAGE_PROVIDER.Trim().ToLowerInvariant() } else { "openai" }
if ($ImageProvider -in @("qwen", "comfyui-qwen", "local")) { $ImageProvider = "comfyui" }
if ($ImageProvider -eq "venagate") { $ImageProvider = "nevagate" }
if ($ImageProvider -notin @("openai", "comfyui", "nevagate")) { throw "IMAGE_PROVIDER harus 'openai', 'comfyui', atau 'nevagate'." }
$OpenAIBaseUrl = if ($env:OPENAI_BASE_URL) { $env:OPENAI_BASE_URL.Trim().TrimEnd('/') } else { "https://api.openai.com/v1" }
$OpenAIEndpoint = "$OpenAIBaseUrl/images/generations"
$OpenAIEditEndpoint = "$OpenAIBaseUrl/images/edits"
$OpenAIModel = if ($env:OPENAI_IMAGE_MODEL) { $env:OPENAI_IMAGE_MODEL.Trim() } else { "gpt-image-2" }
$OpenAIQuality = if ($env:OPENAI_IMAGE_QUALITY) { $env:OPENAI_IMAGE_QUALITY.Trim().ToLowerInvariant() } else { "low" }
if ($OpenAIQuality -notin @("auto", "high", "medium", "low")) { throw "OPENAI_IMAGE_QUALITY harus auto, high, medium, atau low." }
$NevaGateBaseUrl = if ($env:NEVAGATE_BASE_URL) { $env:NEVAGATE_BASE_URL.Trim().TrimEnd('/') } else { "https://nevagate.anext.dev/v1" }
$NevaGateEndpoint = "$NevaGateBaseUrl/chat/completions"
$NevaGateModel = if ($env:NEVAGATE_MODEL) { $env:NEVAGATE_MODEL.Trim() } else { "kimi-k3" }
$NevaGateMaxTokens = if ($env:NEVAGATE_MAX_TOKENS) { [int]$env:NEVAGATE_MAX_TOKENS } else { 8192 }
if ($NevaGateMaxTokens -lt 1024 -or $NevaGateMaxTokens -gt 32768) { throw "NEVAGATE_MAX_TOKENS harus berada di antara 1024 dan 32768." }
$ComfyUIUrl = if ($env:COMFYUI_URL) { $env:COMFYUI_URL.Trim().TrimEnd('/') } else { "http://127.0.0.1:8188" }
$ComfyUIModel = if ($env:COMFYUI_MODEL) { $env:COMFYUI_MODEL } else { "qwen_image_2512_fp8_e4m3fn.safetensors" }
$ComfyUITextEncoder = if ($env:COMFYUI_TEXT_ENCODER) { $env:COMFYUI_TEXT_ENCODER } else { "qwen_2.5_vl_7b_fp8_scaled.safetensors" }
$ComfyUIVae = if ($env:COMFYUI_VAE) { $env:COMFYUI_VAE } else { "qwen_image_vae.safetensors" }
$ComfyUILora = if ($env:COMFYUI_LORA) { $env:COMFYUI_LORA } else { "Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors" }
$ComfyUIWidth = if ($env:COMFYUI_WIDTH) { [int]$env:COMFYUI_WIDTH } else { 768 }
$ComfyUIHeight = if ($env:COMFYUI_HEIGHT) { [int]$env:COMFYUI_HEIGHT } else { 1024 }
$ComfyUITimeoutSeconds = if ($env:COMFYUI_TIMEOUT_SECONDS) { [int]$env:COMFYUI_TIMEOUT_SECONDS } else { 1800 }
$ComfyUIRefineDenoise = if ($env:COMFYUI_REFINE_DENOISE) { [double]$env:COMFYUI_REFINE_DENOISE } else { 0.38 }
if ($ComfyUIRefineDenoise -lt 0.1 -or $ComfyUIRefineDenoise -gt 0.85) { throw "COMFYUI_REFINE_DENOISE harus berada di antara 0.1 dan 0.85." }
if ($ImageProvider -eq "comfyui") { $OpenAIModel = "Qwen-Image-2512"; $OpenAIQuality = "local" }
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Ascii = [System.Text.Encoding]::ASCII

New-Item -ItemType Directory -Force -Path $GeneratedRoot | Out-Null

$CreativeAgents = @(
    @{ name = "Editorial Warm"; agent = "Agent Aruna"; direction = "Premium editorial product photography, warm directional light and tactile shadows. Place the main subject in the lower third with at least the upper 35 percent as calm negative space." },
    @{ name = "Promo Berani"; agent = "Agent Bima"; direction = "Extreme close crop with an energetic diagonal, saturated primary brand color and hard commercial lighting. Avoid a centered front-facing hero shot." },
    @{ name = "Organik Tenang"; agent = "Agent Citra"; direction = "Top-down flat-lay still life, natural textures, soft window light, restrained earthy palette and sparse supporting objects with generous breathing room." },
    @{ name = "Urban Lokal"; agent = "Agent Dara"; direction = "Wide environmental composition inspired by contemporary Indonesian urban spaces, graphic architectural shadows, confident asymmetry and authentic local materials without stereotypes." },
    @{ name = "Artisan Story"; agent = "Agent Elang"; direction = "Intimate macro detail that reveals craft, ingredients or material texture; cinematic shallow depth of field, imperfect natural surfaces and subtle analog-film character." },
    @{ name = "Modern Split"; agent = "Agent Fajar"; direction = "Clean studio scene divided into two strong geometric color fields, crisp edges, unexpected scale and an off-center focal subject. No decorative clutter." },
    @{ name = "Sage Heritage"; agent = "Agent Gita"; direction = "Sculptural contemporary-heritage still life with muted sage and warm neutrals, graceful arch-shaped light and refined museum-like spacing." },
    @{ name = "Graphic Collage"; agent = "Agent Harsa"; direction = "Playful cut-paper collage and bold color blocking surrounding a photoreal focal product, dynamic off-center placement and youthful editorial rhythm, with no written symbols." },
    @{ name = "Classic Spotlight"; agent = "Agent Intan"; direction = "Formal symmetrical composition with a dark rich backdrop, a single soft spotlight, restrained props and timeless premium visual balance." },
    @{ name = "Playful Scale"; agent = "Agent Jaya"; direction = "Optimistic daylight, fresh lime accent and surprising scale: one oversized focal object interacting with simple geometric forms, commercially usable and clearly distinct from a standard product photo." }
)

function Get-StatusText {
    param([int]$StatusCode)
    switch ($StatusCode) {
        200 { return "OK" }
        201 { return "Created" }
        400 { return "Bad Request" }
        401 { return "Unauthorized" }
        403 { return "Forbidden" }
        404 { return "Not Found" }
        405 { return "Method Not Allowed" }
        409 { return "Conflict" }
        413 { return "Payload Too Large" }
        429 { return "Too Many Requests" }
        500 { return "Internal Server Error" }
        502 { return "Bad Gateway" }
        503 { return "Service Unavailable" }
        default { return "OK" }
    }
}

function Get-SecurityHeaders {
    $scriptSources = if ($TurnstileSiteKey) { "'self' https://challenges.cloudflare.com" } else { "'self'" }
    $frameSources = if ($TurnstileSiteKey) { "https://challenges.cloudflare.com" } else { "'none'" }
    $connectSources = if ($TurnstileSiteKey) { "'self' https://challenges.cloudflare.com" } else { "'self'" }
    $headers = @{
        "Content-Security-Policy" = "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; script-src $scriptSources; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src $connectSources; frame-src $frameSources; font-src 'self'; manifest-src 'self'"
        "Cross-Origin-Opener-Policy" = "same-origin"
        "Cross-Origin-Resource-Policy" = "same-origin"
        "Permissions-Policy" = "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
        "Referrer-Policy" = "no-referrer"
        "X-Frame-Options" = "DENY"
    }
    if ($PublicMode) { $headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains" }
    return $headers
}

function Get-RequestClientAddress {
    param([object]$Request)
    $remoteAddress = [string]$Request.RemoteAddress
    if (-not $PublicMode -or $remoteAddress -notin @("127.0.0.1", "::1")) { return $remoteAddress }
    $candidates = @()
    if ($TrustedProxyProvider -eq "cloudflare" -and $Request.Headers.ContainsKey("cf-connecting-ip")) { $candidates += [string]$Request.Headers["cf-connecting-ip"] }
    if ($Request.Headers.ContainsKey("x-forwarded-for")) { $candidates += ([string]$Request.Headers["x-forwarded-for"] -split ',')[0].Trim() }
    foreach ($candidate in $candidates) {
        $parsedAddress = $null
        if ([Net.IPAddress]::TryParse($candidate, [ref]$parsedAddress)) { return $parsedAddress.ToString() }
    }
    return $remoteAddress
}

function Test-RequestOrigin {
    param([object]$Request)
    if ($Request.Method -in @("GET", "HEAD", "OPTIONS")) { return $true }
    if ($Request.Headers.ContainsKey("sec-fetch-site") -and [string]$Request.Headers["sec-fetch-site"] -eq "cross-site") { return $false }
    if (-not $InternetExposedMode) { return $true }
    if ($PublicMode -and (-not $Request.Headers.ContainsKey("x-forwarded-proto") -or [string]$Request.Headers["x-forwarded-proto"] -ne "https")) { return $false }
    if (-not $Request.Headers.ContainsKey("host") -or -not ([string]$Request.Headers["host"]).Equals($PublicOriginUri.Authority, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if ($Request.Headers.ContainsKey("origin")) { return ([string]$Request.Headers["origin"]).TrimEnd('/') -eq $PublicOrigin }
    if ($Request.Headers.ContainsKey("referer")) { return ([string]$Request.Headers["referer"]).StartsWith("$PublicOrigin/", [StringComparison]::OrdinalIgnoreCase) }
    return $TemporaryPublicMode
}

function Write-RawBytes {
    param([System.IO.Stream]$Stream, [byte[]]$Bytes)
    $Stream.Write($Bytes, 0, $Bytes.Length)
}

function Write-HttpResponse {
    param(
        [System.IO.Stream]$Stream,
        [byte[]]$Body,
        [string]$ContentType,
        [int]$StatusCode = 200,
        [hashtable]$ExtraHeaders = @{}
    )
    $headerLines = @(
        "HTTP/1.1 $StatusCode $(Get-StatusText $StatusCode)",
        "Content-Type: $ContentType",
        "Content-Length: $($Body.Length)",
        "Connection: close",
        "X-Content-Type-Options: nosniff"
    )
    $securityHeaders = Get-SecurityHeaders
    foreach ($key in $securityHeaders.Keys) { $headerLines += "${key}: $($securityHeaders[$key])" }
    foreach ($key in $ExtraHeaders.Keys) { $headerLines += "${key}: $($ExtraHeaders[$key])" }
    $header = ($headerLines -join "`r`n") + "`r`n`r`n"
    Write-RawBytes -Stream $Stream -Bytes $Ascii.GetBytes($header)
    if ($Body.Length -gt 0) { Write-RawBytes -Stream $Stream -Bytes $Body }
    $Stream.Flush()
}

function Write-JsonResponse {
    param(
        [System.IO.Stream]$Stream,
        [object]$Data,
        [int]$StatusCode = 200,
        [hashtable]$ExtraHeaders = @{}
    )
    $responseHeaders = @{}
    foreach ($key in $ExtraHeaders.Keys) { $responseHeaders[$key] = $ExtraHeaders[$key] }
    if (-not $responseHeaders.ContainsKey("Cache-Control")) { $responseHeaders["Cache-Control"] = "no-store" }
    $json = $Data | ConvertTo-Json -Depth 8 -Compress
    Write-HttpResponse -Stream $Stream -Body $Utf8.GetBytes($json) -ContentType "application/json; charset=utf-8" -StatusCode $StatusCode -ExtraHeaders $responseHeaders
}

function Start-ChunkedResponse {
    param([System.IO.Stream]$Stream)
    $headerLines = @(
        "HTTP/1.1 200 OK", "Content-Type: application/x-ndjson; charset=utf-8",
        "Transfer-Encoding: chunked", "Connection: close", "Cache-Control: no-store",
        "X-Content-Type-Options: nosniff"
    )
    $securityHeaders = Get-SecurityHeaders
    foreach ($key in $securityHeaders.Keys) { $headerLines += "${key}: $($securityHeaders[$key])" }
    $header = (@($headerLines) + @("", "")) -join "`r`n"
    Write-RawBytes -Stream $Stream -Bytes $Ascii.GetBytes($header)
    $Stream.Flush()
}

function Write-Chunk {
    param([System.IO.Stream]$Stream, [byte[]]$Bytes)
    Write-RawBytes -Stream $Stream -Bytes $Ascii.GetBytes(("{0:X}`r`n" -f $Bytes.Length))
    Write-RawBytes -Stream $Stream -Bytes $Bytes
    Write-RawBytes -Stream $Stream -Bytes $Ascii.GetBytes("`r`n")
    $Stream.Flush()
}

function Write-NdjsonEvent {
    param([System.IO.Stream]$Stream, [object]$Data)
    $json = ($Data | ConvertTo-Json -Depth 8 -Compress) + "`n"
    Write-Chunk -Stream $Stream -Bytes $Utf8.GetBytes($json)
}

function Get-ClientFailureMessage {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord, [string]$PublicMessage)
    if ($InternetExposedMode) { return $PublicMessage }
    return [string]$ErrorRecord.Exception.Message
}

function Complete-ChunkedResponse {
    param([System.IO.Stream]$Stream)
    Write-RawBytes -Stream $Stream -Bytes $Ascii.GetBytes("0`r`n`r`n")
    $Stream.Flush()
}

function Read-HttpRequest {
    param([System.IO.Stream]$Stream)
    $headerBytes = New-Object 'System.Collections.Generic.List[byte]'
    $matched = 0
    $delimiter = [byte[]](13, 10, 13, 10)
    while ($headerBytes.Count -lt 65536) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) { break }
        $byte = [byte]$value
        $headerBytes.Add($byte)
        if ($byte -eq $delimiter[$matched]) {
            $matched++
            if ($matched -eq 4) { break }
        }
        else { $matched = if ($byte -eq 13) { 1 } else { 0 } }
    }
    if ($headerBytes.Count -eq 0 -or $matched -ne 4) { throw "Permintaan HTTP tidak lengkap." }

    $lines = $Ascii.GetString($headerBytes.ToArray()) -split "`r`n"
    $requestLine = $lines[0].Split(' ')
    if ($requestLine.Count -lt 2) { throw "Request line tidak valid." }
    $headers = @{}
    for ($index = 1; $index -lt $lines.Count; $index++) {
        $separator = $lines[$index].IndexOf(':')
        if ($separator -gt 0) {
            $key = $lines[$index].Substring(0, $separator).Trim().ToLowerInvariant()
            $headers[$key] = $lines[$index].Substring($separator + 1).Trim()
        }
    }
    $contentLength = 0
    if ($headers.ContainsKey("content-length")) { [int]::TryParse($headers["content-length"], [ref]$contentLength) | Out-Null }
    if ($contentLength -gt 1048576) { throw "Request body terlalu besar." }
    $bodyBytes = New-Object byte[] $contentLength
    $offset = 0
    while ($offset -lt $contentLength) {
        $read = $Stream.Read($bodyBytes, $offset, $contentLength - $offset)
        if ($read -le 0) { break }
        $offset += $read
    }
    return [PSCustomObject]@{
        Method = $requestLine[0].ToUpperInvariant()
        Path = $requestLine[1].Split('?')[0]
        Headers = $headers
        Body = if ($contentLength -gt 0) { $Utf8.GetString($bodyBytes, 0, $offset) } else { "" }
    }
}

function ConvertFrom-RequestJson {
    param([string]$Body)
    if ([string]::IsNullOrWhiteSpace($Body)) { return [PSCustomObject]@{} }
    return $Body | ConvertFrom-Json
}

function Write-PromptReceipt {
    param([System.IO.Stream]$Stream, [object]$InputData)
    $brief = ([string]$InputData.prompt).Trim()
    if ([string]::IsNullOrWhiteSpace($brief) -or $brief.Length -lt 20) {
        Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ ok = $false; error = "invalid_prompt"; message = "Prompt minimal 20 karakter." }
        return
    }
    if ($brief.Length -gt 1000) {
        Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ ok = $false; error = "prompt_too_long"; message = "Prompt maksimal 1000 karakter." }
        return
    }
    Write-JsonResponse -Stream $Stream -Data @{
        ok = $true
        requestId = [string]$InputData.requestId
        prompt = $brief
        promptLength = $brief.Length
        format = [string]$InputData.format
        style = [string]$InputData.style
    }
}

function Write-EnhancedPrompt {
    param([System.IO.Stream]$Stream, [object]$InputData)
    $brief = ([string]$InputData.prompt).Trim()
    if ($brief.Length -gt 1000) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "prompt_too_long"; message = "Prompt maksimal 1000 karakter." }; return }
    $projectName = ([string]$InputData.projectName).Trim()
    $category = ([string]$InputData.category).Trim()
    $style = ([string]$InputData.style).Trim()
    $format = ([string]$InputData.format).Trim()
    $brand = ([string]$InputData.brand).Trim()
    $headline = ([string]$InputData.headline).Trim()
    $cta = ([string]$InputData.cta).Trim()
    if ([string]::IsNullOrWhiteSpace($category)) { $category = "Bisnis lokal" }
    if ([string]::IsNullOrWhiteSpace($style)) { $style = "Eksploratif" }
    if ([string]::IsNullOrWhiteSpace($format)) { $format = "Instagram Post 4:5" }

    $focusByCategory = @{
        "Makanan & Minuman" = "Tonjolkan produk, bahan, tekstur, dan momen konsumsi yang paling menggugah selera."
        "Kecantikan" = "Tonjolkan manfaat, tekstur produk, ritual pemakaian, dan kesan yang ingin dirasakan audiens."
        "Fashion" = "Tonjolkan potongan, material, detail, gerak, dan karakter pemakai yang dituju."
        "Jasa" = "Visualisasikan hasil atau perubahan yang diterima pelanggan, bukan sekadar alat kerja."
        "Teknologi" = "Tampilkan manfaat produk dalam konteks penggunaan yang mudah dipahami dan terasa manusiawi."
        "Lainnya" = "Tentukan subjek utama, manfaat, audiens, suasana, dan konteks penggunaan secara spesifik."
    }
    $focus = if ($focusByCategory.ContainsKey($category)) { $focusByCategory[$category] } else { $focusByCategory["Lainnya"] }
    $parts = New-Object 'System.Collections.Generic.List[string]'
    if (-not [string]::IsNullOrWhiteSpace($brief)) { $parts.Add($brief.TrimEnd('.', ' ')) }
    elseif (-not [string]::IsNullOrWhiteSpace($projectName)) { $parts.Add("Buat key visual promosi untuk $projectName dalam kategori $category") }
    else { $parts.Add("Buat key visual promosi untuk bisnis kategori $category") }
    $parts.Add("Tujuan visual: $focus")
    $parts.Add("Arah gaya: $style; format: $format; satu fokus visual yang kuat dengan ruang negatif untuk teks poster")
    if (-not [string]::IsNullOrWhiteSpace($brand)) { $parts.Add("Identitas brand yang perlu terasa: $brand") }
    if (-not [string]::IsNullOrWhiteSpace($headline)) { $parts.Add("Makna headline yang perlu didukung visual: $headline") }
    if (-not [string]::IsNullOrWhiteSpace($cta)) { $parts.Add("Aksi yang ingin didorong: $cta") }
    $parts.Add("Hasilkan key visual saja tanpa teks, huruf, angka, watermark, atau logo; aplikasi akan menambahkan elemen branding setelah gambar dibuat")
    $enhanced = ($parts -join ". ").Trim()
    if ($enhanced.Length -gt 1000) { $enhanced = $enhanced.Substring(0, 997).TrimEnd() + "..." }
    Write-JsonResponse -Stream $Stream -Data @{ ok = $true; prompt = $enhanced; promptLength = $enhanced.Length }
}

function Get-ApiKey {
    $key = if ($ImageProvider -eq "nevagate") { $env:NEVAGATE_API_KEY } else { $env:OPENAI_API_KEY }
    if ([string]::IsNullOrWhiteSpace($key)) { return $null }
    return $key.Trim()
}

function Get-ApiKeyVariableName {
    if ($ImageProvider -eq "nevagate") { return "NEVAGATE_API_KEY" }
    return "OPENAI_API_KEY"
}

function Get-ActiveModel {
    if ($ImageProvider -eq "comfyui") { return "Qwen-Image-2512" }
    if ($ImageProvider -eq "nevagate") { return $NevaGateModel }
    return $OpenAIModel
}

function Test-ComfyUI {
    try {
        $null = Invoke-RestMethod -Method Get -Uri "$ComfyUIUrl/system_stats" -TimeoutSec 3
        return $true
    }
    catch { return $false }
}

function Get-ComfyUIReadiness {
    if (-not (Test-ComfyUI)) { return @{ connected = $false; configured = $false; missing = @() } }
    $requirements = @(
        @{ class = "UNETLoader"; input = "unet_name"; file = $ComfyUIModel },
        @{ class = "CLIPLoader"; input = "clip_name"; file = $ComfyUITextEncoder },
        @{ class = "VAELoader"; input = "vae_name"; file = $ComfyUIVae },
        @{ class = "LoraLoaderModelOnly"; input = "lora_name"; file = $ComfyUILora }
    )
    $missing = New-Object 'System.Collections.Generic.List[string]'
    foreach ($requirement in $requirements) {
        try {
            $objectInfo = Invoke-RestMethod -Method Get -Uri "$ComfyUIUrl/object_info/$($requirement.class)" -TimeoutSec 10
            $node = $objectInfo.PSObject.Properties[$requirement.class].Value
            $inputDefinition = $node.input.required.PSObject.Properties[$requirement.input].Value
            $availableFiles = @($inputDefinition[0])
            if ($availableFiles -notcontains $requirement.file) { $missing.Add([string]$requirement.file) }
        }
        catch { $missing.Add([string]$requirement.file) }
    }
    return @{ connected = $true; configured = ($missing.Count -eq 0); missing = $missing.ToArray() }
}

function Get-ProviderHealth {
    if ($ImageProvider -eq "comfyui") {
        $readiness = Get-ComfyUIReadiness
        $statusMessage = if (-not $readiness.connected) {
            "Buka ComfyUI terlebih dahulu di $ComfyUIUrl."
        }
        elseif (-not $readiness.configured) {
            "Model Qwen belum lengkap: $($readiness.missing -join ', ')"
        }
        else { "ComfyUI dan model Qwen siap." }
        return @{
            ok = $true
            configured = $readiness.configured
            provider = "comfyui"
            model = "Qwen-Image-2512"
            endpoint = $ComfyUIUrl
            connected = $readiness.connected
            missing = $readiness.missing
            message = $statusMessage
        }
    }
    if ($ImageProvider -eq "nevagate") {
        return @{
            ok = $true
            configured = [bool](Get-ApiKey)
            provider = "nevagate"
            model = $NevaGateModel
            quality = "experimental-svg"
            endpoint = $NevaGateBaseUrl
            message = if (Get-ApiKey) { "NevaGate siap untuk eksperimen SVG." } else { "NEVAGATE_API_KEY belum diatur." }
        }
    }
    return @{
        ok = $true
        configured = [bool](Get-ApiKey)
        provider = "openai"
        model = $OpenAIModel
        quality = $OpenAIQuality
        endpoint = $OpenAIBaseUrl
        message = if (Get-ApiKey) { "OpenAI GPT Image siap digunakan." } else { "OPENAI_API_KEY belum diatur." }
    }
}

function ConvertTo-VisualBrief {
    param([string]$Brief)
    $visualBrief = [regex]::Replace(
        $Brief,
        '(?im)(?:\b(?:dengan|serta|dan)\s+)?\b(tagline|headline|call\s+to\s+action|cta|tipografi|typography|font|teks|text|logo)\b\s*[:\-]?\s*[^.!?\r\n]*[.!?]?',
        ''
    )
    $visualBrief = [regex]::Replace($visualBrief, '(?i)\b(poster|flyer|banner)\b', 'key visual')
    $visualBrief = [regex]::Replace($visualBrief, '\s{2,}', ' ').Trim(' ', "`r", "`n", ',', ';', ':', '-')
    if ([string]::IsNullOrWhiteSpace($visualBrief)) { return "Create a tasteful commercial key visual based on the supplied business category." }
    return $visualBrief
}

function New-ImagePrompt {
    param(
        [string]$Brief,
        [string]$ProjectName,
        [string]$Category,
        [hashtable]$CreativeAgent,
        [string]$Format = "Instagram Post · 4:5",
        [string]$Style = "Eksploratif",
        [string]$PrimaryColor = "",
        [string]$Refinement = ""
    )
    $visualBrief = ConvertTo-VisualBrief -Brief $Brief
    if (-not [string]::IsNullOrWhiteSpace($Refinement)) {
        return @"
IMAGE EDIT TASK — the attached/source image is the visual source of truth.
USER'S REQUIRED CHANGE (highest priority): $Refinement

Make the requested change clearly visible. Preserve every element the user did not ask to change: subject identity, product shape, camera angle, crop, composition, lighting direction, background structure, and material details. If the requested change names one of those elements, change that element and preserve the rest. Do not reinterpret the full campaign and do not introduce a new product.
Original campaign context (use only to disambiguate the edit): $visualBrief
Business category: $Category
Output format: $Format
Visual continuity: $Style, polished commercial quality, realistic materials.
Hard constraints: return one edited key visual only. No text, pseudo-text, letters, numbers, labels, logos, watermarks, signatures, borders, or UI. Keep packaging blank and unbranded.
"@
    }
    return @"
IMPORTANT OUTPUT RULE: Generate only a clean advertising key visual. This is NOT a finished poster and must contain no typography.
Use case: advertising key visual for an Indonesian small business
Business category: $Category
Primary visual brief: $visualBrief
Requested output format: $Format
User-selected visual style: $Style
Preferred primary color: $(if ($PrimaryColor -match '^#[0-9a-fA-F]{6}$') { $PrimaryColor } else { 'derive a tasteful palette from the brief' })
Creative agent direction: $($CreativeAgent.direction)
Brief interpretation: use the brief only to understand the product, audience, mood, colors, materials, and setting. Treat any request for a tagline, headline, typography, logo, brand name, campaign name, or written copy only as a request to reserve suitable layout space. Never render or imitate those words.
Composition: follow the requested output format; use one clear visual focal point; follow the creative direction instead of defaulting to a centered product shot; reserve clean negative space for copy that the application will overlay later.
Quality: polished, commercially usable, realistic materials and intentional lighting.
Cultural context: contemporary Indonesia, tasteful and authentic when relevant to the brief.
Hard constraints: visual imagery only. Absolutely no text, pseudo-text, glyphs, letters, words, numbers, captions, labels, packaging copy, logos, brand marks, signatures, UI, border, poster title, or watermark anywhere in the image. Keep packaging surfaces blank and unbranded. Do not add unrelated products or people unless the brief explicitly asks for them.
Avoid: typography of any kind, illegible pseudo-text, duplicated objects, cluttered composition, stock-photo clichés, copyrighted characters, or recognizable third-party branding.
"@
}

function ConvertTo-ModelDimension {
    param([double]$Value)
    return [Math]::Max(64, [int]([Math]::Round($Value / 16.0) * 16))
}

function Get-TargetImageDimensions {
    param([string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    $targetPixels = switch ($Quality) { "2mp" { 2000000.0 } "4mp" { 4000000.0 } default { 1000000.0 } }
    $ratio = if ($Format -match "9:16") { 9.0 / 16.0 } elseif ($Format -match "1:1") { 1.0 } else { 4.0 / 5.0 }
    $height = [Math]::Sqrt($targetPixels / $ratio)
    $width = $height * $ratio
    return @{ width = (ConvertTo-ModelDimension $width); height = (ConvertTo-ModelDimension $height) }
}

function Get-ComfyUIDimensions {
    param([string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    return Get-TargetImageDimensions -Format $Format -Quality $Quality
}

function Get-OpenAIImageSize {
    param([string]$Format)
    if ($Format -match "9:16") { return "1024x1792" }
    if ($Format -match "1:1") { return "1024x1024" }
    return "1024x1280"
}

function Invoke-CloudImageRequest {
    param([string]$Endpoint, [hashtable]$Payload, [string]$ApiKey)
    $headers = @{ Authorization = "Bearer $ApiKey" }
    $payloadJson = $Payload | ConvertTo-Json -Depth 8 -Compress
    $payloadBytes = $Utf8.GetBytes($payloadJson)
    $maxAttempts = 5
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try { return Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -ContentType "application/json; charset=utf-8" -Body $payloadBytes -TimeoutSec 300 }
        catch {
            $statusCode = 0
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $statusCode = [int]$_.Exception.Response.StatusCode }
            if ($statusCode -eq 429 -and $attempt -lt $maxAttempts) {
                $waitSeconds = [Math]::Min(15 * $attempt, 60)
                try {
                    $retryHeader = $_.Exception.Response.Headers["Retry-After"]
                    $parsedWait = 0
                    if ($retryHeader -and [int]::TryParse($retryHeader, [ref]$parsedWait)) { $waitSeconds = [Math]::Min([Math]::Max($parsedWait, 1), 90) }
                }
                catch { }
                Start-Sleep -Seconds $waitSeconds
                continue
            }
            $details = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                try { $apiError = $_.ErrorDetails.Message | ConvertFrom-Json; if ($apiError.error.message) { $details = $apiError.error.message } }
                catch { $details = $_.ErrorDetails.Message }
            }
            throw $details
        }
    }
}

function Get-ImageResultFromBytes {
    param([byte[]]$Bytes)
    if (-not $Bytes -or $Bytes.Length -lt 4) { throw "Provider cloud mengembalikan file gambar kosong." }
    $extension = "png"
    $mimeType = "image/png"
    if ($Bytes.Length -ge 12 -and [Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -eq "RIFF" -and [Text.Encoding]::ASCII.GetString($Bytes, 8, 4) -eq "WEBP") {
        $extension = "webp"; $mimeType = "image/webp"
    }
    elseif ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8) {
        $extension = "jpg"; $mimeType = "image/jpeg"
    }
    return @{ base64 = [Convert]::ToBase64String($Bytes); extension = $extension; mimeType = $mimeType }
}

function ConvertTo-QualityImageResult {
    param([hashtable]$Result, [string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    if ([string]$Result.extension -eq "svg") { return $Result }
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    [byte[]]$sourceBytes = [Convert]::FromBase64String([string]$Result.base64)
    $sourceStream = [System.IO.MemoryStream]::new($sourceBytes, $false)
    $sourceImage = $null
    try {
        $sourceImage = [System.Drawing.Image]::FromStream($sourceStream)
        $dimensions = Get-TargetImageDimensions -Format $Format -Quality $Quality
        if ($sourceImage.Width -eq $dimensions.width -and $sourceImage.Height -eq $dimensions.height) { return $Result }
        $bitmap = [System.Drawing.Bitmap]::new($dimensions.width, $dimensions.height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage($sourceImage, 0, 0, $dimensions.width, $dimensions.height)
            }
            finally { $graphics.Dispose() }
            $outputStream = [System.IO.MemoryStream]::new()
            try {
                $bitmap.Save($outputStream, [System.Drawing.Imaging.ImageFormat]::Png)
                return @{ base64 = [Convert]::ToBase64String($outputStream.ToArray()); extension = "png"; mimeType = "image/png" }
            }
            finally { $outputStream.Dispose() }
        }
        finally { $bitmap.Dispose() }
    }
    finally {
        if ($sourceImage) { $sourceImage.Dispose() }
        $sourceStream.Dispose()
    }
}

function ConvertFrom-CloudImageResponse {
    param([object]$Response)
    if (-not $Response.data -or $Response.data.Count -eq 0) { throw "Provider cloud tidak mengembalikan data gambar." }
    $image = $Response.data[0]
    if (-not [string]::IsNullOrWhiteSpace([string]$image.b64_json)) {
        return Get-ImageResultFromBytes -Bytes ([Convert]::FromBase64String([string]$image.b64_json))
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$image.url)) {
        $webClient = New-Object System.Net.WebClient
        try { [byte[]]$bytes = $webClient.DownloadData([string]$image.url) }
        finally { $webClient.Dispose() }
        return Get-ImageResultFromBytes -Bytes $bytes
    }
    throw "Provider cloud tidak mengembalikan b64_json atau URL gambar."
}

function Invoke-OpenAIImage {
    param([string]$Prompt, [string]$ApiKey, [string]$Format)
    $payload = @{
        model = $OpenAIModel
        prompt = $Prompt
        n = 1
        size = (Get-OpenAIImageSize -Format $Format)
        quality = $OpenAIQuality
        output_format = "png"
    }
    return Invoke-CloudImageRequest -Endpoint $OpenAIEndpoint -Payload $payload -ApiKey $ApiKey
}

function Get-NevaGateSvgDimensions {
    param([string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    return Get-TargetImageDimensions -Format $Format -Quality $Quality
}

function ConvertTo-SafeNevaGateSvg {
    param([string]$Svg, [int]$Width, [int]$Height)
    if ([string]::IsNullOrWhiteSpace($Svg) -or $Svg.Length -gt 262144) { throw "Respons SVG NevaGate kosong atau terlalu besar." }

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $stringReader = New-Object System.IO.StringReader($Svg)
    $xmlReader = [System.Xml.XmlReader]::Create($stringReader, $settings)
    $document = New-Object System.Xml.XmlDocument
    $document.XmlResolver = $null
    try { $document.Load($xmlReader) }
    catch { throw "NevaGate tidak mengembalikan SVG yang valid: $($_.Exception.Message)" }
    finally { $xmlReader.Dispose(); $stringReader.Dispose() }

    if (-not $document.DocumentElement -or $document.DocumentElement.LocalName -ne "svg") { throw "Respons NevaGate bukan dokumen SVG." }
    $allowedElements = @("svg", "g", "defs", "linearGradient", "radialGradient", "stop", "rect", "circle", "ellipse", "line", "polyline", "polygon", "path")
    $allowedAttributes = @("xmlns", "id", "viewBox", "width", "height", "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "opacity", "transform", "x", "y", "x1", "x2", "y1", "y2", "cx", "cy", "r", "rx", "ry", "points", "d", "offset", "stop-color", "stop-opacity", "gradientUnits", "gradientTransform")

    function Clean-SvgNode {
        param([System.Xml.XmlNode]$Node)
        foreach ($child in @($Node.ChildNodes)) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                if ($allowedElements -notcontains $child.LocalName) { $null = $Node.RemoveChild($child); continue }
                $null = Clean-SvgNode -Node $child
            }
            elseif ($child.NodeType -notin @([System.Xml.XmlNodeType]::Whitespace, [System.Xml.XmlNodeType]::SignificantWhitespace)) { $null = $Node.RemoveChild($child) }
        }
        if ($Node.Attributes) {
            for ($index = $Node.Attributes.Count - 1; $index -ge 0; $index--) {
                $attribute = $Node.Attributes[$index]
                $value = [string]$attribute.Value
                $isUnsafeReference = ($value -match '(?i)javascript:|data:|https?://|file:') -or (($attribute.LocalName -in @("fill", "stroke")) -and $value -match 'url\(' -and $value -notmatch '^url\(#[A-Za-z_][A-Za-z0-9_.-]*\)$')
                if ($allowedAttributes -notcontains $attribute.Name -or $attribute.Name -match '^on' -or $isUnsafeReference) { $null = $Node.Attributes.RemoveAt($index) }
            }
        }
    }

    $null = Clean-SvgNode -Node $document.DocumentElement
    $root = $document.DocumentElement
    $null = $root.SetAttribute("xmlns", "http://www.w3.org/2000/svg")
    $null = $root.SetAttribute("viewBox", "0 0 $Width $Height")
    $null = $root.SetAttribute("width", [string]$Width)
    $null = $root.SetAttribute("height", [string]$Height)
    return $root.OuterXml
}

function Get-NevaGateMessageText {
    param([object]$Response)
    if (-not $Response.choices -or $Response.choices.Count -eq 0) { throw "NevaGate tidak mengembalikan choices." }
    $content = $Response.choices[0].message.content
    if ($content -is [System.Array]) {
        $parts = @($content | ForEach-Object { if ($_.type -eq "text") { [string]$_.text } })
        return ($parts -join "`n").Trim()
    }
    return ([string]$content).Trim()
}

function Invoke-NevaGateSvg {
    param([string]$Prompt, [string]$ApiKey, [string]$Format, [string]$SourcePath = "", [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    $dimensions = Get-NevaGateSvgDimensions -Format $Format -Quality $Quality
    $systemPrompt = @"
You are an experimental vector key-visual designer. Return exactly one complete SVG document and nothing else.
Canvas: $($dimensions.width) by $($dimensions.height), viewBox 0 0 $($dimensions.width) $($dimensions.height).
Create a polished commercial vector illustration based on the user's brief. It may be abstract, geometric, collage-like, or iconographic, but never claim to be a photograph.
Do not include any text, letters, numbers, logos, watermarks, scripts, stylesheets, foreignObject, embedded raster images, external URLs, href, animation, filters, or event handlers.
Use only: svg, g, defs, linearGradient, radialGradient, stop, rect, circle, ellipse, line, polyline, polygon, and path.
The Kanvas application adds brand, headline, and call-to-action separately.
"@
    $userText = $Prompt
    $userContent = $userText
    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        $extension = [System.IO.Path]::GetExtension($SourcePath).ToLowerInvariant()
        if ($extension -eq ".svg") {
            $existingSvg = [System.IO.File]::ReadAllText($SourcePath)
            if ($existingSvg.Length -gt 262144) { throw "SVG sumber terlalu besar untuk refinement NevaGate." }
            $userContent = "$userText`n`nRevise this existing SVG while preserving its recognizable composition:`n$existingSvg"
        }
        else {
            $rawResult = Get-ImageResultFromBytes -Bytes ([System.IO.File]::ReadAllBytes($SourcePath))
            try { $preparedResult = ConvertTo-QualityImageResult -Result $rawResult -Format $Format -Quality $Quality }
            catch { $preparedResult = $rawResult }
            $mimeType = [string]$preparedResult.mimeType
            $sourceBase64 = [string]$preparedResult.base64
            $userContent = @(
                @{ type = "text"; text = "$userText`nReinterpret the supplied reference as a safe vector SVG while preserving its main composition." },
                @{ type = "image_url"; image_url = @{ url = "data:$mimeType;base64,$sourceBase64" } }
            )
        }
    }
    $payload = @{
        model = $NevaGateModel
        messages = @(
            @{ role = "system"; content = $systemPrompt },
            @{ role = "user"; content = $userContent }
        )
        max_tokens = $NevaGateMaxTokens
        stream = $false
    }
    $response = Invoke-CloudImageRequest -Endpoint $NevaGateEndpoint -Payload $payload -ApiKey $ApiKey
    $messageText = Get-NevaGateMessageText -Response $response
    $svgMatch = [regex]::Match($messageText, '(?is)<svg\b.*?</svg>')
    if (-not $svgMatch.Success) { throw "Model $NevaGateModel hanya mengembalikan teks, bukan SVG yang dapat ditampilkan." }
    $safeSvg = ConvertTo-SafeNevaGateSvg -Svg $svgMatch.Value -Width $dimensions.width -Height $dimensions.height
    return @{ base64 = [Convert]::ToBase64String($Utf8.GetBytes($safeSvg)); extension = "svg"; mimeType = "image/svg+xml" }
}

function Invoke-OpenAIImageEdit {
    param(
        [string]$Prompt,
        [string]$ApiKey,
        [string]$Format,
        [string]$SourcePath,
        [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp"
    )
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
    $rawResult = Get-ImageResultFromBytes -Bytes ([System.IO.File]::ReadAllBytes($SourcePath))
    try { $preparedResult = ConvertTo-QualityImageResult -Result $rawResult -Format $Format -Quality $Quality }
    catch { $preparedResult = $rawResult }
    $sourceMimeType = [string]$preparedResult.mimeType
    [byte[]]$sourceBytes = [Convert]::FromBase64String([string]$preparedResult.base64)
    $sourceFileName = "layera-edit-source.$([string]$preparedResult.extension)"
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromSeconds(300)
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $ApiKey)
    try {
        $maxAttempts = 5
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            $multipart = New-Object System.Net.Http.MultipartFormDataContent
            $response = $null
            try {
                $multipart.Add((New-Object System.Net.Http.StringContent($OpenAIModel)), "model")
                $multipart.Add((New-Object System.Net.Http.StringContent($Prompt, [System.Text.Encoding]::UTF8)), "prompt")
                $multipart.Add((New-Object System.Net.Http.StringContent((Get-OpenAIImageSize -Format $Format))), "size")
                $multipart.Add((New-Object System.Net.Http.StringContent($OpenAIQuality)), "quality")
                $multipart.Add((New-Object System.Net.Http.StringContent("png")), "output_format")
                $imageContent = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $sourceBytes)
                $imageContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue($sourceMimeType)
                $multipart.Add($imageContent, "image[]", $sourceFileName)

                $response = $client.PostAsync($OpenAIEditEndpoint, $multipart).GetAwaiter().GetResult()
                $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                if ($response.IsSuccessStatusCode) {
                    return ConvertFrom-CloudImageResponse -Response ($responseText | ConvertFrom-Json)
                }
                if ([int]$response.StatusCode -eq 429 -and $attempt -lt $maxAttempts) {
                    $waitSeconds = [Math]::Min(15 * $attempt, 60)
                    if ($response.Headers.RetryAfter -and $response.Headers.RetryAfter.Delta) {
                        $waitSeconds = [Math]::Min([Math]::Max([int]$response.Headers.RetryAfter.Delta.TotalSeconds, 1), 90)
                    }
                    Start-Sleep -Seconds $waitSeconds
                    continue
                }
                $details = "OpenAI image edit gagal dengan status HTTP $([int]$response.StatusCode)."
                try { $apiError = $responseText | ConvertFrom-Json; if ($apiError.error.message) { $details = [string]$apiError.error.message } }
                catch { if (-not [string]::IsNullOrWhiteSpace($responseText)) { $details = $responseText } }
                throw $details
            }
            finally {
                if ($response) { $response.Dispose() }
                $multipart.Dispose()
            }
        }
    }
    finally { $client.Dispose() }
}

function New-ComfyUIWorkflow {
    param([string]$Prompt, [long]$Seed, [string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    $dimensions = Get-ComfyUIDimensions -Format $Format -Quality $Quality
    $negativePrompt = "text, typography, letters, words, numbers, headline, caption, title, label, signage, packaging copy, logo, watermark, signature, border, user interface, low resolution, low quality, malformed objects, duplicated objects, deformed hands, oversaturated image, waxy skin, artificial AI look, chaotic composition"
    return @{
        "1" = @{ class_type = "UNETLoader"; inputs = @{ unet_name = $ComfyUIModel; weight_dtype = "default" } }
        "2" = @{ class_type = "LoraLoaderModelOnly"; inputs = @{ model = @("1", 0); lora_name = $ComfyUILora; strength_model = 1.0 } }
        "3" = @{ class_type = "ModelSamplingAuraFlow"; inputs = @{ model = @("2", 0); shift = 3.1 } }
        "4" = @{ class_type = "CLIPLoader"; inputs = @{ clip_name = $ComfyUITextEncoder; type = "qwen_image"; device = "default" } }
        "5" = @{ class_type = "CLIPTextEncode"; inputs = @{ text = $Prompt; clip = @("4", 0) } }
        "6" = @{ class_type = "CLIPTextEncode"; inputs = @{ text = $negativePrompt; clip = @("4", 0) } }
        "7" = @{ class_type = "EmptySD3LatentImage"; inputs = @{ width = $dimensions.width; height = $dimensions.height; batch_size = 1 } }
        "8" = @{ class_type = "KSampler"; inputs = @{
            model = @("3", 0); positive = @("5", 0); negative = @("6", 0); latent_image = @("7", 0)
            seed = $Seed; steps = 4; cfg = 1.0; sampler_name = "euler"; scheduler = "simple"; denoise = 1.0
        } }
        "9" = @{ class_type = "VAELoader"; inputs = @{ vae_name = $ComfyUIVae } }
        "10" = @{ class_type = "VAEDecode"; inputs = @{ samples = @("8", 0); vae = @("9", 0) } }
        "11" = @{ class_type = "SaveImage"; inputs = @{ images = @("10", 0); filename_prefix = "Kanvas-Qwen" } }
    }
}

function New-ComfyUIEditWorkflow {
    param([string]$Prompt, [long]$Seed, [string]$InputImageName)
    $negativePrompt = "text, typography, letters, words, numbers, headline, caption, title, label, signage, packaging copy, logo, watermark, signature, border, user interface, low resolution, low quality, malformed objects, duplicated objects, deformed hands, oversaturated image, waxy skin, artificial AI look, chaotic composition"
    return @{
        "1" = @{ class_type = "UNETLoader"; inputs = @{ unet_name = $ComfyUIModel; weight_dtype = "default" } }
        "2" = @{ class_type = "LoraLoaderModelOnly"; inputs = @{ model = @("1", 0); lora_name = $ComfyUILora; strength_model = 1.0 } }
        "3" = @{ class_type = "ModelSamplingAuraFlow"; inputs = @{ model = @("2", 0); shift = 3.1 } }
        "4" = @{ class_type = "CLIPLoader"; inputs = @{ clip_name = $ComfyUITextEncoder; type = "qwen_image"; device = "default" } }
        "5" = @{ class_type = "CLIPTextEncode"; inputs = @{ text = $Prompt; clip = @("4", 0) } }
        "6" = @{ class_type = "CLIPTextEncode"; inputs = @{ text = $negativePrompt; clip = @("4", 0) } }
        "7" = @{ class_type = "LoadImage"; inputs = @{ image = $InputImageName } }
        "8" = @{ class_type = "KSampler"; inputs = @{
            model = @("3", 0); positive = @("5", 0); negative = @("6", 0); latent_image = @("12", 0)
            seed = $Seed; steps = 4; cfg = 1.0; sampler_name = "euler"; scheduler = "simple"; denoise = $ComfyUIRefineDenoise
        } }
        "9" = @{ class_type = "VAELoader"; inputs = @{ vae_name = $ComfyUIVae } }
        "10" = @{ class_type = "VAEDecode"; inputs = @{ samples = @("8", 0); vae = @("9", 0) } }
        "11" = @{ class_type = "SaveImage"; inputs = @{ images = @("10", 0); filename_prefix = "Kanvas-Qwen-Edit" } }
        "12" = @{ class_type = "VAEEncode"; inputs = @{ pixels = @("7", 0); vae = @("9", 0) } }
    }
}

function Invoke-ComfyUIWorkflow {
    param([hashtable]$Workflow)
    $clientId = [Guid]::NewGuid().ToString("N")
    $payload = @{ prompt = $Workflow; client_id = $clientId } | ConvertTo-Json -Depth 20 -Compress
    # Windows PowerShell encodes a string body using the active ANSI code page.
    # Send explicit UTF-8 bytes so punctuation and Indonesian text remain valid JSON.
    $payloadBytes = $Utf8.GetBytes($payload)
    try {
        $queued = Invoke-RestMethod -Method Post -Uri "$ComfyUIUrl/prompt" -ContentType "application/json; charset=utf-8" -Body $payloadBytes -TimeoutSec 30
    }
    catch {
        $details = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        throw "ComfyUI menolak request workflow Qwen. Detail: $details"
    }
    $promptId = [string]$queued.prompt_id
    if ([string]::IsNullOrWhiteSpace($promptId)) {
        $details = if ($queued.node_errors) { $queued.node_errors | ConvertTo-Json -Depth 10 -Compress } else { "prompt_id tidak diterima" }
        throw "Workflow Qwen tidak dapat dimasukkan ke antrean ComfyUI: $details"
    }

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $ComfyUITimeoutSeconds) {
        Start-Sleep -Milliseconds 1000
        $history = Invoke-RestMethod -Method Get -Uri "$ComfyUIUrl/history/$promptId" -TimeoutSec 15
        $historyProperty = $history.PSObject.Properties | Where-Object { $_.Name -eq $promptId } | Select-Object -First 1
        if (-not $historyProperty) { continue }
        $entry = $historyProperty.Value
        if ($entry.status -and $entry.status.status_str -eq "error") {
            throw "ComfyUI gagal menjalankan Qwen: $($entry.status.messages | ConvertTo-Json -Depth 8 -Compress)"
        }
        foreach ($outputProperty in $entry.outputs.PSObject.Properties) {
            $imagesProperty = $outputProperty.Value.PSObject.Properties | Where-Object { $_.Name -eq "images" } | Select-Object -First 1
            if (-not $imagesProperty -or -not $imagesProperty.Value -or $imagesProperty.Value.Count -eq 0) { continue }
            $image = $imagesProperty.Value[0]
            $viewUri = "$ComfyUIUrl/view?filename=$([System.Uri]::EscapeDataString([string]$image.filename))&subfolder=$([System.Uri]::EscapeDataString([string]$image.subfolder))&type=$([System.Uri]::EscapeDataString([string]$image.type))"
            $webClient = New-Object System.Net.WebClient
            try { [byte[]]$bytes = $webClient.DownloadData($viewUri) }
            finally { $webClient.Dispose() }
            $extension = [System.IO.Path]::GetExtension([string]$image.filename).TrimStart('.').ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($extension)) { $extension = "png" }
            $mimeType = switch ($extension) { "webp" { "image/webp" } "jpg" { "image/jpeg" } "jpeg" { "image/jpeg" } default { "image/png" } }
            return @{ base64 = [System.Convert]::ToBase64String($bytes); extension = $extension; mimeType = $mimeType }
        }
        if ($entry.status -and $entry.status.completed) { throw "ComfyUI menyelesaikan workflow tanpa menghasilkan file gambar." }
    }
    throw "Qwen melewati batas waktu $ComfyUITimeoutSeconds detik. Kurangi resolusi atau periksa ComfyUI."
}

function Invoke-ComfyUIImage {
    param([string]$Prompt, [long]$Seed, [string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    return Invoke-ComfyUIWorkflow -Workflow (New-ComfyUIWorkflow -Prompt $Prompt -Seed $Seed -Format $Format -Quality $Quality)
}

function Send-ComfyUIInputImage {
    param([string]$SourcePath, [string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    Add-Type -AssemblyName System.Net.Http
    $rawResult = Get-ImageResultFromBytes -Bytes ([System.IO.File]::ReadAllBytes($SourcePath))
    try { $preparedResult = ConvertTo-QualityImageResult -Result $rawResult -Format $Format -Quality $Quality }
    catch { $preparedResult = $rawResult }
    $extension = "." + [string]$preparedResult.extension
    $mimeType = [string]$preparedResult.mimeType
    $uploadName = "Kanvas-Edit-$([Guid]::NewGuid().ToString('N'))$extension"
    $client = [System.Net.Http.HttpClient]::new()
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $fileContent = [System.Net.Http.ByteArrayContent]::new([Convert]::FromBase64String([string]$preparedResult.base64))
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($mimeType)
    $form.Add($fileContent, "image", $uploadName)
    $form.Add([System.Net.Http.StringContent]::new("true"), "overwrite")
    try {
        $response = $client.PostAsync("$ComfyUIUrl/upload/image", $form).GetAwaiter().GetResult()
        $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) { throw "HTTP $([int]$response.StatusCode): $responseText" }
        $uploaded = $responseText | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace([string]$uploaded.name)) { throw "ComfyUI tidak mengembalikan nama file input." }
        if ([string]::IsNullOrWhiteSpace([string]$uploaded.subfolder)) { return [string]$uploaded.name }
        return (([string]$uploaded.subfolder).TrimEnd('/', '\') + "/" + [string]$uploaded.name)
    }
    finally {
        $fileContent.Dispose()
        $form.Dispose()
        $client.Dispose()
    }
}

function Resolve-GeneratedImagePath {
    param([string]$SourceUrl)
    $cleanUrl = ([string]$SourceUrl).Split('?')[0]
    if (-not $cleanUrl.StartsWith("/generated/", [System.StringComparison]::OrdinalIgnoreCase)) { throw "Gambar sumber refinement harus berasal dari Library Kanvas." }
    $relativePath = [System.Uri]::UnescapeDataString($cleanUrl.TrimStart('/')).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $relativePath))
    $generatedPrefix = $GeneratedRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $sourcePath.StartsWith($generatedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not [System.IO.File]::Exists($sourcePath)) { throw "File gambar sumber refinement tidak ditemukan." }
    return $sourcePath
}

function Invoke-ComfyUIImageEdit {
    param([string]$Prompt, [long]$Seed, [string]$SourcePath, [string]$Format, [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    $inputImageName = Send-ComfyUIInputImage -SourcePath $SourcePath -Format $Format -Quality $Quality
    return Invoke-ComfyUIWorkflow -Workflow (New-ComfyUIEditWorkflow -Prompt $Prompt -Seed $Seed -InputImageName $inputImageName)
}

function Invoke-ImageProvider {
    param([string]$Prompt, [int]$Index = 0, [string]$Format = "Instagram Post · 4:5", [ValidateSet("1mp", "2mp", "4mp")][string]$Quality = "1mp")
    if ($ImageProvider -eq "comfyui") {
        $seed = [long](([DateTime]::UtcNow.Ticks + ($Index * 104729)) % 2147483646)
        return Invoke-ComfyUIImage -Prompt $Prompt -Seed $seed -Format $Format -Quality $Quality
    }
    if ($ImageProvider -eq "nevagate") {
        return Invoke-NevaGateSvg -Prompt $Prompt -ApiKey (Get-ApiKey) -Format $Format -Quality $Quality
    }
    $result = Invoke-OpenAIImage -Prompt $Prompt -ApiKey (Get-ApiKey) -Format $Format
    return ConvertFrom-CloudImageResponse -Response $result
}

function Save-GeneratedImage {
    param([string]$Base64, [string]$JobId, [int]$Index, [string]$Extension = "webp", [string]$UserId = "")
    $jobFolder = Join-Path $GeneratedRoot $JobId
    New-Item -ItemType Directory -Force -Path $jobFolder | Out-Null
    $safeExtension = if ($Extension -in @("png", "jpg", "jpeg", "webp", "svg")) { $Extension } else { "png" }
    $fileName = "concept-{0:d2}.{1}" -f ($Index + 1), $safeExtension
    [System.IO.File]::WriteAllBytes((Join-Path $jobFolder $fileName), [System.Convert]::FromBase64String($Base64))
    $urlPath = "/generated/$JobId/$fileName"
    if (-not [string]::IsNullOrWhiteSpace($UserId)) { Add-KanvasGeneratedFile -UserId $UserId -UrlPath $urlPath }
    return $urlPath
}

function Start-GenerationStream {
    param([System.IO.Stream]$Stream, [object]$InputData, [object]$User)
    $brief = ([string]$InputData.prompt).Trim()
    if ([string]::IsNullOrWhiteSpace($brief) -or $brief.Length -lt 20) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_prompt"; message = "Prompt minimal 20 karakter." }; return }
    if ($brief.Length -gt 1000) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "prompt_too_long"; message = "Prompt maksimal 1000 karakter." }; return }
    $requestId = [string]$InputData.requestId
    if ([string]::IsNullOrWhiteSpace($requestId)) { $requestId = [Guid]::NewGuid().ToString("N") }
    $requestedFormat = if ([string]::IsNullOrWhiteSpace([string]$InputData.format)) { "Instagram Post · 4:5" } else { ([string]$InputData.format).Trim() }
    $requestedStyle = if ([string]::IsNullOrWhiteSpace([string]$InputData.style)) { "Eksploratif" } else { ([string]$InputData.style).Trim() }
    $primaryColor = if ([string]$InputData.primaryColor -match '^#[0-9a-fA-F]{6}$') { [string]$InputData.primaryColor } else { "" }
    $usage = Get-KanvasUsageStatus -UserId ([string]$User.id)
    $requestedQuality = ([string]$InputData.quality).Trim().ToLowerInvariant()
    if ($requestedQuality -notin @("1mp", "2mp", "4mp")) { $requestedQuality = "1mp" }
    if ($usage.allowedQualities -notcontains $requestedQuality) {
        Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "quality_limit"; upgradeRequired = $true; message = "Paket Gratis hanya mendukung kualitas 1MP/HD. Upgrade ke Pro untuk membuka 2MP dan 4MP."; usage = $usage }
        return
    }
    $agentIndexes = New-Object 'System.Collections.Generic.List[int]'
    foreach ($rawIndex in @($InputData.agentIndexes)) {
        $parsedIndex = 0
        if ([int]::TryParse([string]$rawIndex, [ref]$parsedIndex) -and $parsedIndex -ge 0 -and $parsedIndex -lt $CreativeAgents.Count -and -not $agentIndexes.Contains($parsedIndex)) { $agentIndexes.Add($parsedIndex) }
    }
    if ($agentIndexes.Count -eq 0) { $agentIndexes.Add(0) }
    if ($agentIndexes.Count -gt [int]$usage.maxAgents) {
        Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "agent_limit"; upgradeRequired = (-not $usage.isSubscriber); message = "$($usage.planLabel) hanya dapat menggunakan $($usage.maxAgents) agent dalam satu generasi."; usage = $usage }
        return
    }
    $creditCost = Get-KanvasGenerationCreditCost -Quality $requestedQuality -ImageCount $agentIndexes.Count
    $creditCheck = Test-KanvasCreditAvailability -UserId ([string]$User.id) -EventType "generate" -CreditCost $creditCost
    if (-not $creditCheck.allowed) { Write-KanvasQuotaExceeded -Stream $Stream -UserId ([string]$User.id) -EventType "generate" -RequiredCredits $creditCost; return }
    $brandName = ([string]$InputData.brandName).Trim()
    if ([string]::IsNullOrWhiteSpace($brandName)) { $brandName = ([string]$InputData.projectName).Trim() }
    if (-not (Test-KanvasBrandAllowed -UserId ([string]$User.id) -BrandName $brandName)) {
        Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "brand_limit"; upgradeRequired = $true; message = "Paket Gratis hanya berlaku untuk 1 brand. Brand aktif akun ini adalah '$($usage.brand.name)'. Upgrade ke Pro untuk menggunakan brand tanpa batas."; usage = $usage }
        return
    }

    if ($ImageProvider -ne "comfyui" -and -not (Get-ApiKey)) {
        Write-JsonResponse -Stream $Stream -StatusCode 503 -Data @{ error = "missing_api_key"; message = "$(Get-ApiKeyVariableName) belum diatur pada terminal yang menjalankan server." }
        return
    }
    if ($ImageProvider -eq "comfyui") {
        $readiness = Get-ComfyUIReadiness
        if (-not $readiness.connected) { Write-JsonResponse -Stream $Stream -StatusCode 503 -Data @{ error = "comfyui_offline"; message = "ComfyUI belum aktif. Buka ComfyUI Desktop dan pastikan $ComfyUIUrl dapat diakses." }; return }
        if (-not $readiness.configured) { Write-JsonResponse -Stream $Stream -StatusCode 503 -Data @{ error = "qwen_models_missing"; message = "Model Qwen belum lengkap: $($readiness.missing -join ', ')" }; return }
    }
    $jobId = [Guid]::NewGuid().ToString("N")
    Start-ChunkedResponse -Stream $Stream
    $activeModel = Get-ActiveModel
    Write-NdjsonEvent -Stream $Stream -Data @{ type = "start"; requestId = $requestId; promptLength = $brief.Length; jobId = $jobId; total = $agentIndexes.Count; agentIndexes = $agentIndexes.ToArray(); model = $activeModel; provider = $ImageProvider; format = $requestedFormat; style = $requestedStyle; quality = $requestedQuality; creditCost = $creditCost }
    $successCount = 0
    $brandRecorded = $false
    $perImageCreditCost = Get-KanvasGenerationCreditCost -Quality $requestedQuality -ImageCount 1
    $failureMessages = New-Object 'System.Collections.Generic.List[string]'
    foreach ($index in $agentIndexes) {
        $creativeAgent = $CreativeAgents[$index]
        try {
            Write-NdjsonEvent -Stream $Stream -Data @{ type = "progress"; index = $index; agent = $creativeAgent.agent; name = $creativeAgent.name }
            $imagePrompt = New-ImagePrompt -Brief $brief -ProjectName ([string]$InputData.projectName) -Category ([string]$InputData.category) -CreativeAgent $creativeAgent -Format $requestedFormat -Style $requestedStyle -PrimaryColor $primaryColor
            $result = Invoke-ImageProvider -Prompt $imagePrompt -Index $index -Format $requestedFormat -Quality $requestedQuality
            $result = ConvertTo-QualityImageResult -Result $result -Format $requestedFormat -Quality $requestedQuality
            $base64 = [string]$result.base64
            $url = Save-GeneratedImage -Base64 $base64 -JobId $jobId -Index $index -Extension ([string]$result.extension) -UserId ([string]$User.id)
            $successCount++
            Add-KanvasUsageEvent -UserId ([string]$User.id) -EventType "generate" -CreditCost $perImageCreditCost
            if (-not $brandRecorded) { Add-KanvasAccountBrand -UserId ([string]$User.id) -BrandName $brandName; $brandRecorded = $true }
            Write-NdjsonEvent -Stream $Stream -Data @{ type = "image"; index = $index; name = $creativeAgent.name; agent = $creativeAgent.agent; url = $url; displayUrl = "data:$($result.mimeType);base64,$base64" }
        }
        catch {
            Write-Warning "Generasi agent $index gagal: $($_.Exception.Message)"
            $failureMessage = Get-ClientFailureMessage -ErrorRecord $_ -PublicMessage "Provider gambar gagal menyelesaikan konsep ini. Silakan coba kembali."
            $failureMessages.Add($failureMessage)
            Write-NdjsonEvent -Stream $Stream -Data @{ type = "image_error"; index = $index; name = $creativeAgent.name; message = $failureMessage }
        }
    }
    $firstError = if ($failureMessages.Count -gt 0) { $failureMessages[0] } else { "" }
    Write-NdjsonEvent -Stream $Stream -Data @{ type = "done"; requestId = $requestId; jobId = $jobId; total = $agentIndexes.Count; success = $successCount; failed = $failureMessages.Count; firstError = $firstError; usage = (Get-KanvasUsageStatus -UserId ([string]$User.id)) }
    Complete-ChunkedResponse -Stream $Stream
}

function Start-Refinement {
    param([System.IO.Stream]$Stream, [object]$InputData, [object]$User)
    $brief = ([string]$InputData.prompt).Trim()
    if ([string]::IsNullOrWhiteSpace($brief) -or $brief.Length -lt 20) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_prompt"; message = "Prompt Library tidak valid atau terlalu singkat." }; return }
    if ($brief.Length -gt 1000) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "prompt_too_long"; message = "Prompt maksimal 1000 karakter." }; return }
    $usage = Get-KanvasUsageStatus -UserId ([string]$User.id)
    $editCreditCost = 3
    $creditCheck = Test-KanvasCreditAvailability -UserId ([string]$User.id) -EventType "refine" -CreditCost $editCreditCost
    if (-not $creditCheck.allowed) { Write-KanvasQuotaExceeded -Stream $Stream -UserId ([string]$User.id) -EventType "refine" -RequiredCredits $editCreditCost; return }
    if ($ImageProvider -ne "comfyui" -and -not (Get-ApiKey)) {
        Write-JsonResponse -Stream $Stream -StatusCode 503 -Data @{ error = "missing_api_key"; message = "$(Get-ApiKeyVariableName) belum diatur." }
        return
    }
    if ($ImageProvider -eq "comfyui") {
        $readiness = Get-ComfyUIReadiness
        if (-not $readiness.connected) { Write-JsonResponse -Stream $Stream -StatusCode 503 -Data @{ error = "comfyui_offline"; message = "ComfyUI belum aktif di $ComfyUIUrl." }; return }
        if (-not $readiness.configured) { Write-JsonResponse -Stream $Stream -StatusCode 503 -Data @{ error = "qwen_models_missing"; message = "Model Qwen belum lengkap: $($readiness.missing -join ', ')" }; return }
    }
    $index = [int]$InputData.conceptIndex
    if ($index -lt 0 -or $index -ge $CreativeAgents.Count) { $index = 0 }
    $refinementText = ([string]$InputData.refinement).Trim()
    if ([string]::IsNullOrWhiteSpace($refinementText) -or $refinementText.Length -gt 500) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_refinement"; message = "Instruksi edit harus berisi 1-500 karakter." }; return }
    try {
        $creativeAgent = $CreativeAgents[$index]
        $requestedFormat = if ([string]::IsNullOrWhiteSpace([string]$InputData.format)) { "Instagram Post · 4:5" } else { ([string]$InputData.format).Trim() }
        $requestedStyle = if ([string]::IsNullOrWhiteSpace([string]$InputData.style)) { "Eksploratif" } else { ([string]$InputData.style).Trim() }
        $requestedQuality = ([string]$InputData.quality).Trim().ToLowerInvariant()
        if ($requestedQuality -notin @("1mp", "2mp", "4mp") -or $usage.allowedQualities -notcontains $requestedQuality) { $requestedQuality = "1mp" }
        $primaryColor = if ([string]$InputData.primaryColor -match '^#[0-9a-fA-F]{6}$') { [string]$InputData.primaryColor } else { "" }
        $imagePrompt = New-ImagePrompt -Brief $brief -ProjectName ([string]$InputData.projectName) -Category ([string]$InputData.category) -CreativeAgent $creativeAgent -Format $requestedFormat -Style $requestedStyle -PrimaryColor $primaryColor -Refinement $refinementText
        if ($ImageProvider -eq "comfyui") {
            $sourcePath = Resolve-GeneratedImagePath -SourceUrl ([string]$InputData.sourceUrl)
            $seed = [long](([DateTime]::UtcNow.Ticks + ($index * 104729)) % 2147483646)
            $result = Invoke-ComfyUIImageEdit -Prompt $imagePrompt -Seed $seed -SourcePath $sourcePath -Format $requestedFormat -Quality $requestedQuality
        }
        elseif ($ImageProvider -eq "nevagate") {
            $sourcePath = Resolve-GeneratedImagePath -SourceUrl ([string]$InputData.sourceUrl)
            $result = Invoke-NevaGateSvg -Prompt $imagePrompt -ApiKey (Get-ApiKey) -Format $requestedFormat -SourcePath $sourcePath -Quality $requestedQuality
        }
        else {
            $sourcePath = Resolve-GeneratedImagePath -SourceUrl ([string]$InputData.sourceUrl)
            $result = Invoke-OpenAIImageEdit -Prompt $imagePrompt -ApiKey (Get-ApiKey) -Format $requestedFormat -SourcePath $sourcePath -Quality $requestedQuality
        }
        $result = ConvertTo-QualityImageResult -Result $result -Format $requestedFormat -Quality $requestedQuality
        $base64 = [string]$result.base64
        if ([string]::IsNullOrWhiteSpace($base64)) { throw "Provider AI tidak mengembalikan data gambar." }
        $jobId = "refine-" + [Guid]::NewGuid().ToString("N")
        $url = Save-GeneratedImage -Base64 $base64 -JobId $jobId -Index $index -Extension ([string]$result.extension) -UserId ([string]$User.id)
        Add-KanvasUsageEvent -UserId ([string]$User.id) -EventType "refine" -CreditCost $editCreditCost
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; index = $index; url = $url; displayUrl = "data:$($result.mimeType);base64,$base64"; usage = (Get-KanvasUsageStatus -UserId ([string]$User.id)) }
    }
    catch {
        Write-Warning "Edit gambar gagal: $($_.Exception.Message)"
        Write-JsonResponse -Stream $Stream -StatusCode 502 -Data @{ error = "generation_failed"; message = (Get-ClientFailureMessage -ErrorRecord $_ -PublicMessage "Provider gambar gagal mengedit desain. Silakan coba kembali.") }
    }
}

function Send-StaticFile {
    param([System.IO.Stream]$Stream, [string]$Path, [object]$Request = $null)
    $relativePath = [System.Uri]::UnescapeDataString($Path.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = "index.html" }
    $relativePath = $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $filePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $relativePath))
    $rootPrefix = $ProjectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "forbidden" }; return }
    $generatedPrefix = "generated" + [System.IO.Path]::DirectorySeparatorChar
    $isGeneratedRuntimeFile = $relativePath.StartsWith($generatedPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    if ($InternetExposedMode -and $isGeneratedRuntimeFile) {
        $staticUser = if ($Request) { Get-KanvasAuthenticatedUser -Request $Request } else { $null }
        if (-not $staticUser) {
            Write-KanvasUnauthorized -Stream $Stream
            return
        }
        $urlPath = "/" + $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')
        if (-not (Test-KanvasGeneratedFileAccess -UserId ([string]$staticUser.id) -UrlPath $urlPath)) {
            Write-JsonResponse -Stream $Stream -StatusCode 404 -Data @{ error = "not_found" }
            return
        }
    }
    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
    $mimeTypes = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"; ".js" = "application/javascript; charset=utf-8"; ".png" = "image/png"; ".jpg" = "image/jpeg"; ".jpeg" = "image/jpeg"; ".webp" = "image/webp"; ".svg" = "image/svg+xml"; ".ico" = "image/x-icon" }
    if (-not $mimeTypes.ContainsKey($extension) -or -not [System.IO.File]::Exists($filePath)) { Write-JsonResponse -Stream $Stream -StatusCode 404 -Data @{ error = "not_found" }; return }
    $cache = if ($isGeneratedRuntimeFile) { "private, max-age=31536000, immutable" } else { "no-cache" }
    Write-HttpResponse -Stream $Stream -Body ([System.IO.File]::ReadAllBytes($filePath)) -ContentType $mimeTypes[$extension] -ExtraHeaders @{ "Cache-Control" = $cache }
}

function Handle-Request {
    param([System.IO.Stream]$Stream, [object]$Request)
    if (-not (Test-RequestOrigin -Request $Request)) {
        Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "request_origin_rejected"; message = "Origin atau transport request tidak diizinkan." }
        return
    }
    if (Handle-KanvasAccountRequest -Stream $Stream -Request $Request) { return }
    if ($Request.Method -eq "GET" -and $Request.Path -eq "/api/health") {
        $health = Get-ProviderHealth
        $health.deploymentMode = $DeploymentMode
        $health.publicOrigin = if ($InternetExposedMode) { $PublicOrigin } else { "" }
        Write-JsonResponse -Stream $Stream -Data $health
        return
    }
    $protectedPaths = @("/api/prompt-check", "/api/prompt-enhance", "/api/generate", "/api/refine")
    $authenticatedUser = if ($Request.Path -in $protectedPaths) { Get-KanvasAuthenticatedUser -Request $Request } else { $null }
    if ($Request.Path -in $protectedPaths -and -not $authenticatedUser) {
        Write-KanvasUnauthorized -Stream $Stream
        return
    }
    if ($Request.Method -notin @("GET", "HEAD", "OPTIONS") -and $Request.Path -in $protectedPaths -and -not (Test-KanvasCsrfRequest -Request $Request)) {
        Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "invalid_csrf_token"; message = "Token keamanan sesi tidak valid. Muat ulang halaman lalu coba kembali." }
        return
    }
    if ($Request.Method -eq "POST" -and $Request.Path -eq "/api/prompt-check") { Write-PromptReceipt -Stream $Stream -InputData (ConvertFrom-RequestJson -Body $Request.Body); return }
    if ($Request.Method -eq "POST" -and $Request.Path -eq "/api/prompt-enhance") { Write-EnhancedPrompt -Stream $Stream -InputData (ConvertFrom-RequestJson -Body $Request.Body); return }
    if ($Request.Method -eq "POST" -and $Request.Path -eq "/api/generate") { Start-GenerationStream -Stream $Stream -InputData (ConvertFrom-RequestJson -Body $Request.Body) -User $authenticatedUser; return }
    if ($Request.Method -eq "POST" -and $Request.Path -eq "/api/refine") { Start-Refinement -Stream $Stream -InputData (ConvertFrom-RequestJson -Body $Request.Body) -User $authenticatedUser; return }
    if ($Request.Method -eq "GET") { Send-StaticFile -Stream $Stream -Path $Request.Path -Request $Request; return }
    Write-JsonResponse -Stream $Stream -StatusCode 405 -Data @{ error = "method_not_allowed" }
}

. (Join-Path $ProjectRoot "account.ps1")
Initialize-KanvasDatabase

$listenAddress = if ($DeploymentMode -in @("lan", "public-http")) { [System.Net.IPAddress]::Any } else { [System.Net.IPAddress]::Loopback }
$listener = [System.Net.Sockets.TcpListener]::new($listenAddress, $Port)
try {
    $listener.Start(100)
    Write-Host ""
    Write-Host "Kanvas berjalan di http://localhost:$Port" -ForegroundColor Green
    if ($DeploymentMode -eq "lan") { Write-Host "Mode LAN aktif pada semua interface. Jangan gunakan mode ini langsung di internet." -ForegroundColor Yellow }
    if ($PublicMode) { Write-Host "Mode proxy publik aktif untuk $PublicOrigin. Origin tetap hanya dapat diakses dari komputer ini." -ForegroundColor Green }
    if ($TemporaryPublicMode) {
        Write-Host "Mode public HTTP sementara aktif untuk $PublicOrigin." -ForegroundColor Yellow
        Write-Host "Gunakan hanya untuk demo singkat. Matikan server dan port forwarding setelah selesai." -ForegroundColor Yellow
    }
    Write-Host "Model aktif: $(Get-ActiveModel)" -ForegroundColor DarkGray
    if ($ImageProvider -eq "comfyui") {
        Write-Host "Provider lokal: Qwen-Image-2512 melalui $ComfyUIUrl" -ForegroundColor DarkGray
        $readiness = Get-ComfyUIReadiness
        if ($readiness.configured) { Write-Host "ComfyUI dan model Qwen siap. Generasi lokal aktif." -ForegroundColor Green }
        elseif ($readiness.connected) { Write-Host "ComfyUI terhubung, tetapi model belum lengkap: $($readiness.missing -join ', ')" -ForegroundColor Yellow }
        else { Write-Host "ComfyUI belum terhubung. Buka ComfyUI Desktop sebelum membuat gambar." -ForegroundColor Yellow }
    }
    elseif ($ImageProvider -eq "nevagate") {
        Write-Host "Provider eksperimen: NevaGate $NevaGateModel melalui $NevaGateBaseUrl" -ForegroundColor DarkGray
        if (Get-ApiKey) { Write-Host "NEVAGATE_API_KEY terdeteksi. Eksperimen SVG aktif." -ForegroundColor Green }
        else { Write-Host "NEVAGATE_API_KEY belum diatur. UI dapat dibuka, tetapi eksperimen belum aktif." -ForegroundColor Yellow }
    }
    elseif (Get-ApiKey) { Write-Host "OPENAI_API_KEY terdeteksi. OpenAI GPT Image aktif melalui $OpenAIBaseUrl." -ForegroundColor Green }
    else { Write-Host "OPENAI_API_KEY belum diatur. UI dapat dibuka, tetapi generasi AI belum aktif." -ForegroundColor Yellow }
    Write-Host "Tekan Ctrl+C untuk menghentikan server." -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        if (-not $listener.Pending()) {
            Start-Sleep -Milliseconds 100
            continue
        }
        $client = $listener.AcceptTcpClient()
        try {
            $client.NoDelay = $true
            $client.ReceiveTimeout = 15000
            $client.SendTimeout = 60000
            $stream = $client.GetStream()
            $request = Read-HttpRequest -Stream $stream
            $request | Add-Member -NotePropertyName RemoteAddress -NotePropertyValue ([string]$client.Client.RemoteEndPoint.Address)
            $request | Add-Member -NotePropertyName ClientAddress -NotePropertyValue (Get-RequestClientAddress -Request $request)
            Handle-Request -Stream $stream -Request $request
        }
        catch {
            Write-Warning "Request gagal: $($_.Exception.Message)"
            try { if ($stream -and $stream.CanWrite) { Write-JsonResponse -Stream $stream -StatusCode 500 -Data @{ error = "server_error"; message = (Get-ClientFailureMessage -ErrorRecord $_ -PublicMessage "Server tidak dapat menyelesaikan permintaan.") } } }
            catch { }
        }
        finally {
            if ($stream) { $stream.Dispose(); $stream = $null }
            $client.Dispose()
        }
    }
}
finally { $listener.Stop() }
