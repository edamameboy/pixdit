$DataRoot = Join-Path $ProjectRoot "data"
$DatabasePath = if ($env:KANVAS_DATABASE_PATH) {
    [System.IO.Path]::GetFullPath($env:KANVAS_DATABASE_PATH)
}
else {
    Join-Path $DataRoot "kanvas.mdb"
}
$DataRoot = Split-Path -Parent $DatabasePath
$DatabaseConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$DatabasePath;Persist Security Info=False;"
$SessionCookieName = if ($PublicMode) { "__Host-layera_session" } else { "kanvas_session" }
$PasswordIterations = 210000
$FormatSeparator = [char]0x00B7
$DefaultPosterFormat = "Instagram Post $FormatSeparator 4:5"
$script:SignupChallenges = @{}
$SignupChallengeLifetimeMinutes = 10
$SignupAttemptsPerHour = 8
$SignupAccountsPerDevice = 3

function Add-KanvasDbParameters {
    param([System.Data.OleDb.OleDbCommand]$Command, [object[]]$Values = @())
    foreach ($value in $Values) {
        if ($null -eq $value) {
            $parameter = $Command.Parameters.Add("@p", [System.Data.OleDb.OleDbType]::VarWChar)
            $parameter.Value = [DBNull]::Value
        }
        elseif ($value -is [bool]) {
            $parameter = $Command.Parameters.Add("@p", [System.Data.OleDb.OleDbType]::Boolean)
            $parameter.Value = $value
        }
        elseif ($value -is [DateTime]) {
            $parameter = $Command.Parameters.Add("@p", [System.Data.OleDb.OleDbType]::Date)
            $parameter.Value = $value
        }
        elseif ($value -is [int] -or $value -is [long]) {
            $parameter = $Command.Parameters.Add("@p", [System.Data.OleDb.OleDbType]::Integer)
            $parameter.Value = [int]$value
        }
        else {
            $textValue = [string]$value
            if ($textValue.Length -gt 250) {
                $parameter = $Command.Parameters.Add("@p", [System.Data.OleDb.OleDbType]::LongVarWChar)
            }
            else {
                $parameter = $Command.Parameters.Add("@p", [System.Data.OleDb.OleDbType]::VarWChar, [Math]::Max(1, $textValue.Length))
            }
            $parameter.Value = $textValue
        }
    }
}

function Invoke-KanvasDbNonQuery {
    param([string]$Sql, [object[]]$Parameters = @())
    $connection = [System.Data.OleDb.OleDbConnection]::new($DatabaseConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        Add-KanvasDbParameters -Command $command -Values $Parameters
        return $command.ExecuteNonQuery()
    }
    finally { $connection.Dispose() }
}

function Invoke-KanvasDbScalar {
    param([string]$Sql, [object[]]$Parameters = @())
    $connection = [System.Data.OleDb.OleDbConnection]::new($DatabaseConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        Add-KanvasDbParameters -Command $command -Values $Parameters
        return $command.ExecuteScalar()
    }
    finally { $connection.Dispose() }
}

function Invoke-KanvasDbQuery {
    param([string]$Sql, [object[]]$Parameters = @())
    $connection = [System.Data.OleDb.OleDbConnection]::new($DatabaseConnectionString)
    $rows = New-Object 'System.Collections.Generic.List[object]'
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        Add-KanvasDbParameters -Command $command -Values $Parameters
        $reader = $command.ExecuteReader()
        try {
            while ($reader.Read()) {
                $record = [ordered]@{}
                for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                    $value = $reader.GetValue($index)
                    $record[$reader.GetName($index)] = if ($value -is [DBNull]) { $null } else { $value }
                }
                $rows.Add([PSCustomObject]$record)
            }
        }
        finally { $reader.Dispose() }
    }
    finally { $connection.Dispose() }
    return $rows.ToArray()
}

function Test-KanvasDbTable {
    param([string]$Name)
    try { $null = Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM [$Name]"; return $true }
    catch { return $false }
}

function Test-KanvasDbColumn {
    param([string]$Table, [string]$Column)
    try { $null = Invoke-KanvasDbScalar -Sql "SELECT TOP 1 [$Column] FROM [$Table]"; return $true }
    catch { return $false }
}

function New-KanvasPasswordRecord {
    param([string]$Password)
    $salt = New-Object byte[] 16
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($salt) }
    finally { $random.Dispose() }
    $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
        $Password,
        $salt,
        $PasswordIterations,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    try { $hash = $derive.GetBytes(32) }
    finally { $derive.Dispose() }
    return @{
        salt = [Convert]::ToBase64String($salt)
        hash = [Convert]::ToBase64String($hash)
        iterations = $PasswordIterations
    }
}

function Test-KanvasPassword {
    param([string]$Password, [string]$Salt, [string]$ExpectedHash, [int]$Iterations)
    try {
        $saltBytes = [Convert]::FromBase64String($Salt)
        $expectedBytes = [Convert]::FromBase64String($ExpectedHash)
        $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
            $Password,
            $saltBytes,
            $Iterations,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        try { $actualBytes = $derive.GetBytes($expectedBytes.Length) }
        finally { $derive.Dispose() }
        if ($actualBytes.Length -ne $expectedBytes.Length) { return $false }
        $difference = 0
        for ($index = 0; $index -lt $actualBytes.Length; $index++) {
            $difference = $difference -bor ($actualBytes[$index] -bxor $expectedBytes[$index])
        }
        return $difference -eq 0
    }
    catch { return $false }
}

function New-KanvasUser {
    param([string]$Email, [string]$DisplayName, [string]$Password, [bool]$Initialized = $false)
    $userId = [Guid]::NewGuid().ToString("N")
    $passwordRecord = New-KanvasPasswordRecord -Password $Password
    $now = [DateTime]::UtcNow
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO Users ([id], [email], [display_name], [password_hash], [password_salt], [password_iterations], [created_at], [updated_at]) VALUES (?, ?, ?, ?, ?, ?, ?, ?)" -Parameters @(
        $userId, $Email.ToLowerInvariant(), $DisplayName, $passwordRecord.hash, $passwordRecord.salt,
        $passwordRecord.iterations, $now, $now
    )
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO Preferences ([user_id], [default_format], [default_style], [primary_color], [start_view], [updated_at]) VALUES (?, ?, ?, ?, ?, ?)" -Parameters @(
        $userId, $DefaultPosterFormat, "Eksploratif", "#5a3529", "dashboard", $now
    )
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO UserState ([user_id], [projects_json], [library_json], [initialized], [updated_at]) VALUES (?, ?, ?, ?, ?)" -Parameters @(
        $userId, "[]", "[]", $Initialized, $now
    )
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO AccountPlans ([user_id], [plan_code], [updated_at]) VALUES (?, ?, ?)" -Parameters @(
        $userId, "free", $now
    )
    return $userId
}

function Initialize-KanvasDatabase {
    New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null
    if (-not [System.IO.File]::Exists($DatabasePath)) {
        try {
            $catalog = New-Object -ComObject ADOX.Catalog
            $null = $catalog.Create("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$DatabasePath;Jet OLEDB:Engine Type=5;")
            if ($catalog.ActiveConnection) { $catalog.ActiveConnection.Close() }
        }
        catch { throw "Database lokal tidak dapat dibuat. Pastikan Microsoft Access Database Engine tersedia. Detail: $($_.Exception.Message)" }
        finally { if ($catalog) { [Runtime.InteropServices.Marshal]::ReleaseComObject($catalog) | Out-Null } }
    }

    if (-not (Test-KanvasDbTable -Name "Users")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE Users ([id] TEXT(32) NOT NULL, [email] TEXT(255) NOT NULL, [display_name] TEXT(100) NOT NULL, [password_hash] TEXT(255) NOT NULL, [password_salt] TEXT(255) NOT NULL, [password_iterations] LONG NOT NULL, [created_at] DATETIME NOT NULL, [updated_at] DATETIME NOT NULL, CONSTRAINT pk_users PRIMARY KEY ([id]))"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE UNIQUE INDEX ux_users_email ON Users ([email])"
    }
    if (-not (Test-KanvasDbTable -Name "Sessions")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE Sessions ([token_hash] TEXT(64) NOT NULL, [csrf_token] TEXT(86) NOT NULL, [user_id] TEXT(32) NOT NULL, [expires_at] DATETIME NOT NULL, [created_at] DATETIME NOT NULL, CONSTRAINT pk_sessions PRIMARY KEY ([token_hash]))"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE INDEX ix_sessions_user ON Sessions ([user_id])"
    }
    elseif (-not (Test-KanvasDbColumn -Table "Sessions" -Column "csrf_token")) {
        $null = Invoke-KanvasDbNonQuery -Sql "ALTER TABLE Sessions ADD COLUMN [csrf_token] TEXT(86)"
        $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM Sessions"
    }
    if (-not (Test-KanvasDbTable -Name "Preferences")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE Preferences ([user_id] TEXT(32) NOT NULL, [default_format] TEXT(80) NOT NULL, [default_style] TEXT(40) NOT NULL, [primary_color] TEXT(7) NOT NULL, [start_view] TEXT(20) NOT NULL, [updated_at] DATETIME NOT NULL, CONSTRAINT pk_preferences PRIMARY KEY ([user_id]))"
    }
    if (-not (Test-KanvasDbTable -Name "UserState")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE UserState ([user_id] TEXT(32) NOT NULL, [projects_json] MEMO, [library_json] MEMO, [initialized] YESNO NOT NULL, [updated_at] DATETIME NOT NULL, CONSTRAINT pk_user_state PRIMARY KEY ([user_id]))"
    }
    if (-not (Test-KanvasDbTable -Name "AccountPlans")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE AccountPlans ([user_id] TEXT(32) NOT NULL, [plan_code] TEXT(20) NOT NULL, [updated_at] DATETIME NOT NULL, CONSTRAINT pk_account_plans PRIMARY KEY ([user_id]))"
    }
    if (-not (Test-KanvasDbTable -Name "UsageEvents")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE UsageEvents ([id] TEXT(32) NOT NULL, [user_id] TEXT(32) NOT NULL, [event_type] TEXT(20) NOT NULL, [credit_cost] LONG NOT NULL, [created_at] DATETIME NOT NULL, CONSTRAINT pk_usage_events PRIMARY KEY ([id]))"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE INDEX ix_usage_events_user ON UsageEvents ([user_id])"
    }
    elseif (-not (Test-KanvasDbColumn -Table "UsageEvents" -Column "credit_cost")) {
        $null = Invoke-KanvasDbNonQuery -Sql "ALTER TABLE UsageEvents ADD COLUMN [credit_cost] LONG"
        $null = Invoke-KanvasDbNonQuery -Sql "UPDATE UsageEvents SET [credit_cost] = IIF([event_type] = 'refine', 3, 2) WHERE [credit_cost] IS NULL"
    }
    if (-not (Test-KanvasDbTable -Name "AccountBrands")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE AccountBrands ([user_id] TEXT(32) NOT NULL, [brand_key] TEXT(120) NOT NULL, [display_name] TEXT(120) NOT NULL, [created_at] DATETIME NOT NULL, CONSTRAINT pk_account_brands PRIMARY KEY ([user_id]))"
    }
    if (-not (Test-KanvasDbTable -Name "SignupSignals")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE SignupSignals ([id] TEXT(32) NOT NULL, [user_id] TEXT(32) NOT NULL, [device_hash] TEXT(64) NOT NULL, [ip_hash] TEXT(64) NOT NULL, [user_agent_hash] TEXT(64) NOT NULL, [created_at] DATETIME NOT NULL, CONSTRAINT pk_signup_signals PRIMARY KEY ([id]))"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE INDEX ix_signup_device ON SignupSignals ([device_hash])"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE INDEX ix_signup_ip ON SignupSignals ([ip_hash])"
    }
    if (-not (Test-KanvasDbTable -Name "SecurityEvents")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE SecurityEvents ([id] TEXT(32) NOT NULL, [event_key] TEXT(64) NOT NULL, [event_type] TEXT(30) NOT NULL, [created_at] DATETIME NOT NULL, CONSTRAINT pk_security_events PRIMARY KEY ([id]))"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE INDEX ix_security_event ON SecurityEvents ([event_key], [event_type])"
    }
    if (-not (Test-KanvasDbTable -Name "GeneratedFiles")) {
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE TABLE GeneratedFiles ([url_path] TEXT(255) NOT NULL, [user_id] TEXT(32) NOT NULL, [created_at] DATETIME NOT NULL, CONSTRAINT pk_generated_files PRIMARY KEY ([url_path]))"
        $null = Invoke-KanvasDbNonQuery -Sql "CREATE INDEX ix_generated_files_user ON GeneratedFiles ([user_id])"
    }

    foreach ($existingUser in @(Invoke-KanvasDbQuery -Sql "SELECT [id] FROM Users")) {
        if ([int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM AccountPlans WHERE [user_id] = ?" -Parameters @([string]$existingUser.id)) -eq 0) {
            $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO AccountPlans ([user_id], [plan_code], [updated_at]) VALUES (?, ?, ?)" -Parameters @([string]$existingUser.id, "free", [DateTime]::UtcNow)
        }
    }
    $null = Invoke-KanvasDbNonQuery -Sql "UPDATE AccountPlans SET [plan_code] = 'premium', [updated_at] = ? WHERE [plan_code] = 'subscriber'" -Parameters @([DateTime]::UtcNow)

    $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM Sessions WHERE [expires_at] <= ?" -Parameters @([DateTime]::UtcNow)
    if (-not $InternetExposedMode -and [int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM Users") -eq 0) {
        $null = New-KanvasUser -Email "maya@rumahseduh.id" -DisplayName "Maya Faradina" -Password "kanvasdemo"
    }
    if ($InternetExposedMode) {
        $demoUsers = @(Invoke-KanvasDbQuery -Sql "SELECT [password_hash], [password_salt], [password_iterations] FROM Users WHERE [email] = ?" -Parameters @("maya@rumahseduh.id"))
        if ($demoUsers.Count -gt 0 -and (Test-KanvasPassword -Password "kanvasdemo" -Salt ([string]$demoUsers[0].password_salt) -ExpectedHash ([string]$demoUsers[0].password_hash) -Iterations ([int]$demoUsers[0].password_iterations))) {
            throw "Mode publik ditolak karena akun demo Maya masih memakai kata sandi bawaan. Ubah kata sandinya melalui mode local terlebih dahulu."
        }
    }
}

function Get-KanvasSha256Hex {
    param([string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) }
    finally { $sha.Dispose() }
    return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

function New-KanvasSignupChallenge {
    $left = Get-Random -Minimum 2 -Maximum 10
    $right = Get-Random -Minimum 1 -Maximum 10
    $token = [Guid]::NewGuid().ToString("N")
    $script:SignupChallenges[$token] = @{ answer = $left + $right; expiresAt = [DateTime]::UtcNow.AddMinutes($SignupChallengeLifetimeMinutes) }
    foreach ($key in @($script:SignupChallenges.Keys)) {
        if ([DateTime]$script:SignupChallenges[$key].expiresAt -le [DateTime]::UtcNow) { $script:SignupChallenges.Remove($key) }
    }
    return @{ token = $token; question = "$left + $right = ?"; expiresInSeconds = $SignupChallengeLifetimeMinutes * 60 }
}

function Test-KanvasSignupChallenge {
    param([string]$Token, [string]$Answer)
    if ([string]::IsNullOrWhiteSpace($Token) -or -not $script:SignupChallenges.ContainsKey($Token)) { return $false }
    $challenge = $script:SignupChallenges[$Token]
    $script:SignupChallenges.Remove($Token)
    $parsedAnswer = 0
    return ([DateTime]$challenge.expiresAt -gt [DateTime]::UtcNow -and [int]::TryParse($Answer, [ref]$parsedAnswer) -and $parsedAnswer -eq [int]$challenge.answer)
}

function Test-KanvasSignupRateLimit {
    param([string]$RemoteAddress)
    $address = if ([string]::IsNullOrWhiteSpace($RemoteAddress)) { "unknown" } else { $RemoteAddress.Trim() }
    $key = Get-KanvasSha256Hex -Value $address
    return Test-KanvasSecurityRateLimit -Key $key -EventType "signup" -Limit $SignupAttemptsPerHour -WindowMinutes 60
}

function Test-KanvasSecurityRateLimit {
    param([string]$Key, [string]$EventType, [int]$Limit, [int]$WindowMinutes)
    $cutoff = [DateTime]::UtcNow.AddMinutes(-$WindowMinutes)
    $count = [int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM SecurityEvents WHERE [event_key] = ? AND [event_type] = ? AND [created_at] >= ?" -Parameters @($Key, $EventType, $cutoff))
    if ($count -ge $Limit) { return $false }
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO SecurityEvents ([id], [event_key], [event_type], [created_at]) VALUES (?, ?, ?, ?)" -Parameters @([Guid]::NewGuid().ToString("N"), $Key, $EventType, [DateTime]::UtcNow)
    if ((Get-Random -Minimum 1 -Maximum 101) -eq 1) { $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM SecurityEvents WHERE [created_at] < ?" -Parameters @([DateTime]::UtcNow.AddDays(-7)) }
    return $true
}

function Test-KanvasTurnstile {
    param([string]$Token, [string]$RemoteAddress)
    if ([string]::IsNullOrWhiteSpace($TurnstileSecretKey) -or [string]::IsNullOrWhiteSpace($Token) -or $Token.Length -gt 2048) { return $false }
    try {
        $payload = @{ secret = $TurnstileSecretKey; response = $Token; remoteip = $RemoteAddress; idempotency_key = [Guid]::NewGuid().ToString() } | ConvertTo-Json -Compress
        $verification = Invoke-RestMethod -Method Post -Uri "https://challenges.cloudflare.com/turnstile/v0/siteverify" -ContentType "application/json" -Body $Utf8.GetBytes($payload) -TimeoutSec 15
        if (-not [bool]$verification.success) { return $false }
        if ($PublicMode -and -not [string]::IsNullOrWhiteSpace([string]$verification.hostname) -and [string]$verification.hostname -ne $PublicOriginUri.Host) { return $false }
        return $true
    }
    catch { return $false }
}

function Get-KanvasSignupSignal {
    param([object]$InputData, [object]$Request)
    $deviceId = ([string]$InputData.deviceId).Trim()
    $fingerprint = ([string]$InputData.deviceFingerprint).Trim()
    if ($deviceId.Length -lt 12 -or $deviceId.Length -gt 160) { $deviceId = "missing-device" }
    if ($fingerprint.Length -gt 500) { $fingerprint = $fingerprint.Substring(0, 500) }
    $remoteAddress = ([string]$Request.ClientAddress).Trim()
    $userAgent = if ($Request.Headers.ContainsKey("user-agent")) { [string]$Request.Headers["user-agent"] } else { "unknown" }
    $remoteAddressValue = if ($remoteAddress) { $remoteAddress } else { "unknown" }
    return @{
        deviceHash = Get-KanvasSha256Hex -Value $deviceId
        ipHash = Get-KanvasSha256Hex -Value $remoteAddressValue
        userAgentHash = Get-KanvasSha256Hex -Value "$userAgent|$fingerprint"
    }
}

function Test-KanvasSignupDeviceAllowed {
    param([string]$DeviceHash)
    $cutoff = [DateTime]::UtcNow.AddDays(-90)
    $count = [int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM SignupSignals WHERE [device_hash] = ? AND [created_at] >= ?" -Parameters @($DeviceHash, $cutoff))
    return $count -lt $SignupAccountsPerDevice
}

function Add-KanvasSignupSignal {
    param([string]$UserId, [hashtable]$Signal)
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO SignupSignals ([id], [user_id], [device_hash], [ip_hash], [user_agent_hash], [created_at]) VALUES (?, ?, ?, ?, ?, ?)" -Parameters @(
        [Guid]::NewGuid().ToString("N"), $UserId, $Signal.deviceHash, $Signal.ipHash, $Signal.userAgentHash, [DateTime]::UtcNow
    )
}

function Add-KanvasGeneratedFile {
    param([string]$UserId, [string]$UrlPath)
    if ([string]::IsNullOrWhiteSpace($UserId) -or [string]::IsNullOrWhiteSpace($UrlPath)) { return }
    $normalizedPath = ([string]$UrlPath).Trim()
    if ($normalizedPath.Length -gt 255 -or -not $normalizedPath.StartsWith("/generated/", [System.StringComparison]::OrdinalIgnoreCase)) { return }
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO GeneratedFiles ([url_path], [user_id], [created_at]) VALUES (?, ?, ?)" -Parameters @(
        $normalizedPath, $UserId, [DateTime]::UtcNow
    )
}

function Test-KanvasGeneratedFileAccess {
    param([string]$UserId, [string]$UrlPath)
    if ([string]::IsNullOrWhiteSpace($UserId) -or [string]::IsNullOrWhiteSpace($UrlPath)) { return $false }
    $normalizedPath = ([string]$UrlPath).Trim()
    return [int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM GeneratedFiles WHERE [url_path] = ? AND [user_id] = ?" -Parameters @($normalizedPath, $UserId)) -gt 0
}

function New-KanvasSessionToken {
    $bytes = New-Object byte[] 32
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($bytes) }
    finally { $random.Dispose() }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-KanvasSession {
    param([string]$UserId, [bool]$Remember = $false)
    $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM Sessions WHERE [expires_at] <= ?" -Parameters @([DateTime]::UtcNow)
    if ([int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM Sessions WHERE [user_id] = ?" -Parameters @($UserId)) -ge 8) {
        $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM Sessions WHERE [user_id] = ?" -Parameters @($UserId)
    }
    $token = New-KanvasSessionToken
    $csrfToken = New-KanvasSessionToken
    $expiresAt = if ($Remember) { [DateTime]::UtcNow.AddDays(30) } else { [DateTime]::UtcNow.AddHours(24) }
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO Sessions ([token_hash], [csrf_token], [user_id], [expires_at], [created_at]) VALUES (?, ?, ?, ?, ?)" -Parameters @(
        (Get-KanvasSha256Hex -Value $token), $csrfToken, $UserId, $expiresAt, [DateTime]::UtcNow
    )
    return @{ token = $token; csrfToken = $csrfToken; expiresAt = $expiresAt; remember = $Remember; maxAge = [int]([Math]::Floor(($expiresAt - [DateTime]::UtcNow).TotalSeconds)) }
}

function Get-KanvasCookieValue {
    param([object]$Request, [string]$Name)
    if (-not $Request.Headers.ContainsKey("cookie")) { return $null }
    foreach ($pair in ([string]$Request.Headers["cookie"] -split ';')) {
        $separator = $pair.IndexOf('=')
        if ($separator -le 0) { continue }
        if ($pair.Substring(0, $separator).Trim() -eq $Name) { return $pair.Substring($separator + 1).Trim() }
    }
    return $null
}

function Get-KanvasAuthenticatedUser {
    param([object]$Request)
    $token = Get-KanvasCookieValue -Request $Request -Name $SessionCookieName
    if ([string]::IsNullOrWhiteSpace($token)) { return $null }
    $sessionRows = @(Invoke-KanvasDbQuery -Sql "SELECT [user_id], [expires_at] FROM Sessions WHERE [token_hash] = ?" -Parameters @((Get-KanvasSha256Hex -Value $token)))
    if ($sessionRows.Count -eq 0 -or [DateTime]$sessionRows[0].expires_at -le [DateTime]::UtcNow) { return $null }
    $userRows = @(Invoke-KanvasDbQuery -Sql "SELECT [id], [email], [display_name], [created_at] FROM Users WHERE [id] = ?" -Parameters @([string]$sessionRows[0].user_id))
    if ($userRows.Count -eq 0) { return $null }
    return $userRows[0]
}

function Get-KanvasSessionRecord {
    param([object]$Request)
    $token = Get-KanvasCookieValue -Request $Request -Name $SessionCookieName
    if ([string]::IsNullOrWhiteSpace($token)) { return $null }
    $rows = @(Invoke-KanvasDbQuery -Sql "SELECT [user_id], [csrf_token], [expires_at] FROM Sessions WHERE [token_hash] = ?" -Parameters @((Get-KanvasSha256Hex -Value $token)))
    if ($rows.Count -eq 0 -or [DateTime]$rows[0].expires_at -le [DateTime]::UtcNow) { return $null }
    return $rows[0]
}

function Test-KanvasFixedTimeText {
    param([string]$Actual, [string]$Expected)
    if ([string]::IsNullOrWhiteSpace($Actual) -or [string]::IsNullOrWhiteSpace($Expected)) { return $false }
    $actualBytes = [Text.Encoding]::UTF8.GetBytes($Actual)
    $expectedBytes = [Text.Encoding]::UTF8.GetBytes($Expected)
    if ($actualBytes.Length -ne $expectedBytes.Length) { return $false }
    $difference = 0
    for ($index = 0; $index -lt $actualBytes.Length; $index++) { $difference = $difference -bor ($actualBytes[$index] -bxor $expectedBytes[$index]) }
    return $difference -eq 0
}

function Test-KanvasCsrfRequest {
    param([object]$Request)
    if (-not $Request.Headers.ContainsKey("x-csrf-token")) { return $false }
    $session = Get-KanvasSessionRecord -Request $Request
    if (-not $session) { return $false }
    return Test-KanvasFixedTimeText -Actual ([string]$Request.Headers["x-csrf-token"]) -Expected ([string]$session.csrf_token)
}

function Get-KanvasPreferences {
    param([string]$UserId)
    $rows = @(Invoke-KanvasDbQuery -Sql "SELECT [default_format], [default_style], [primary_color], [start_view] FROM Preferences WHERE [user_id] = ?" -Parameters @($UserId))
    if ($rows.Count -eq 0) {
        return @{ defaultFormat = $DefaultPosterFormat; defaultStyle = "Eksploratif"; primaryColor = "#5a3529"; startView = "dashboard" }
    }
    return @{
        defaultFormat = [string]$rows[0].default_format
        defaultStyle = [string]$rows[0].default_style
        primaryColor = [string]$rows[0].primary_color
        startView = [string]$rows[0].start_view
    }
}

function Get-KanvasPlanCode {
    param([string]$UserId)
    $plan = [string](Invoke-KanvasDbScalar -Sql "SELECT [plan_code] FROM AccountPlans WHERE [user_id] = ?" -Parameters @($UserId))
    if ($plan -eq "subscriber") { return "premium" }
    if ($plan -notin @("free", "premium")) { return "free" }
    return $plan
}

function Get-KanvasUsageStatus {
    param([string]$UserId)
    $plan = Get-KanvasPlanCode -UserId $UserId
    $isPremium = $plan -eq "premium"
    $localNow = [DateTime]::Now
    if ($isPremium) {
        $periodStartLocal = [DateTime]::new($localNow.Year, $localNow.Month, 1)
        $periodResetLocal = $periodStartLocal.AddMonths(1)
        $creditLimit = 200
        $period = "monthly"
    }
    else {
        $daysSinceMonday = (([int]$localNow.DayOfWeek + 6) % 7)
        $periodStartLocal = $localNow.Date.AddDays(-$daysSinceMonday)
        $periodResetLocal = $periodStartLocal.AddDays(7)
        $creditLimit = 11
        $period = "weekly"
    }
    $periodStart = $periodStartLocal.ToUniversalTime()
    $generationUsed = [int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM UsageEvents WHERE [user_id] = ? AND [event_type] = ? AND [created_at] >= ?" -Parameters @($UserId, "generate", $periodStart))
    $refinementUsed = [int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM UsageEvents WHERE [user_id] = ? AND [event_type] = ? AND [created_at] >= ?" -Parameters @($UserId, "refine", $periodStart))
    $usedValue = Invoke-KanvasDbScalar -Sql "SELECT SUM([credit_cost]) FROM UsageEvents WHERE [user_id] = ? AND [created_at] >= ?" -Parameters @($UserId, $periodStart)
    $creditsUsed = if ($null -eq $usedValue -or $usedValue -is [DBNull]) { 0 } else { [int]$usedValue }
    $creditsRemaining = [Math]::Max(0, $creditLimit - $creditsUsed)
    $brandRows = @(Invoke-KanvasDbQuery -Sql "SELECT [brand_key], [display_name] FROM AccountBrands WHERE [user_id] = ?" -Parameters @($UserId))
    return @{
        plan = $plan
        planLabel = if ($isPremium) { "Layera Pro" } else { "Paket Gratis" }
        isPremium = $isPremium
        isSubscriber = $isPremium
        maxAgents = if ($isPremium) { 10 } else { 1 }
        allowedQualities = if ($isPremium) { @("1mp", "2mp", "4mp") } else { @("1mp") }
        credits = @{
            limit = $creditLimit
            used = $creditsUsed
            remaining = $creditsRemaining
            period = $period
            resetAt = $periodResetLocal.ToUniversalTime().ToString("o")
        }
        brand = @{
            limit = if ($isPremium) { -1 } else { 1 }
            used = $brandRows.Count
            name = if ($brandRows.Count -gt 0) { [string]$brandRows[0].display_name } else { "" }
        }
        generation = @{
            limit = if ($isPremium) { -1 } else { 1 }
            used = $generationUsed
            remaining = if ($isPremium) { -1 } else { [Math]::Max(0, 1 - $generationUsed) }
            exhausted = ((-not $isPremium -and $generationUsed -ge 1) -or $creditsRemaining -lt 2)
            resetAt = $periodResetLocal.ToUniversalTime().ToString("o")
        }
        refinement = @{
            limit = if ($isPremium) { -1 } else { 3 }
            used = $refinementUsed
            remaining = if ($isPremium) { -1 } else { [Math]::Max(0, 3 - $refinementUsed) }
            exhausted = ((-not $isPremium -and $refinementUsed -ge 3) -or $creditsRemaining -lt 3)
            resetAt = $periodResetLocal.ToUniversalTime().ToString("o")
        }
    }
}

function Add-KanvasUsageEvent {
    param([string]$UserId, [ValidateSet("generate", "refine")][string]$EventType, [int]$CreditCost)
    if ($CreditCost -lt 1) { throw "Credit cost harus lebih besar dari nol." }
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO UsageEvents ([id], [user_id], [event_type], [credit_cost], [created_at]) VALUES (?, ?, ?, ?, ?)" -Parameters @(
        [Guid]::NewGuid().ToString("N"), $UserId, $EventType, $CreditCost, [DateTime]::UtcNow
    )
}

function Get-KanvasGenerationCreditCost {
    param([ValidateSet("1mp", "2mp", "4mp")][string]$Quality, [int]$ImageCount = 1)
    $perImage = switch ($Quality) { "2mp" { 4 } "4mp" { 8 } default { 2 } }
    return $perImage * [Math]::Max(1, $ImageCount)
}

function Test-KanvasCreditAvailability {
    param([string]$UserId, [ValidateSet("generate", "refine")][string]$EventType, [int]$CreditCost)
    $usage = Get-KanvasUsageStatus -UserId $UserId
    if ($CreditCost -gt [int]$usage.credits.remaining) { return @{ allowed = $false; reason = "credits"; usage = $usage } }
    if ($EventType -eq "generate" -and $usage.generation.exhausted) { return @{ allowed = $false; reason = "generation_limit"; usage = $usage } }
    if ($EventType -eq "refine" -and $usage.refinement.exhausted) { return @{ allowed = $false; reason = "refinement_limit"; usage = $usage } }
    return @{ allowed = $true; usage = $usage }
}

function ConvertTo-KanvasBrandKey {
    param([string]$BrandName)
    $normalized = [regex]::Replace(([string]$BrandName).Trim().ToLowerInvariant(), '\s+', ' ')
    if ([string]::IsNullOrWhiteSpace($normalized)) { return "brand-tanpa-nama" }
    return $normalized.Substring(0, [Math]::Min(120, $normalized.Length))
}

function Test-KanvasBrandAllowed {
    param([string]$UserId, [string]$BrandName)
    if ((Get-KanvasPlanCode -UserId $UserId) -eq "premium") { return $true }
    $rows = @(Invoke-KanvasDbQuery -Sql "SELECT [brand_key] FROM AccountBrands WHERE [user_id] = ?" -Parameters @($UserId))
    if ($rows.Count -eq 0) { return $true }
    return [string]$rows[0].brand_key -eq (ConvertTo-KanvasBrandKey -BrandName $BrandName)
}

function Add-KanvasAccountBrand {
    param([string]$UserId, [string]$BrandName)
    if ((Get-KanvasPlanCode -UserId $UserId) -eq "premium") { return }
    if ([int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM AccountBrands WHERE [user_id] = ?" -Parameters @($UserId)) -gt 0) { return }
    $displayName = ([string]$BrandName).Trim()
    if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = "Brand tanpa nama" }
    $null = Invoke-KanvasDbNonQuery -Sql "INSERT INTO AccountBrands ([user_id], [brand_key], [display_name], [created_at]) VALUES (?, ?, ?, ?)" -Parameters @(
        $UserId, (ConvertTo-KanvasBrandKey -BrandName $BrandName), $displayName.Substring(0, [Math]::Min(120, $displayName.Length)), [DateTime]::UtcNow
    )
}

function Write-KanvasQuotaExceeded {
    param([System.IO.Stream]$Stream, [string]$UserId, [ValidateSet("generate", "refine")][string]$EventType, [int]$RequiredCredits = 0)
    $usage = Get-KanvasUsageStatus -UserId $UserId
    $resetDate = ([DateTime]$usage.credits.resetAt).ToLocalTime().ToString("d MMMM yyyy", [Globalization.CultureInfo]::GetCultureInfo("id-ID"))
    $message = if ($usage.isPremium) {
        "Kredit Layera Pro kamu tidak cukup untuk tindakan ini. Kredit berikutnya hadir pada $resetDate."
    }
    else {
        "Kamu sudah menggunakan semua token kreatif yang ada.`n`nToken gratis selanjutnya akan hadir pada $resetDate.`n`nAyo upgrade ke pro agar dapat membuka potensial terbaik dari program ini, dapat membuat ~100 gambar, bebas memilih behavior agentic, dll."
    }
    Write-JsonResponse -Stream $Stream -StatusCode 429 -Data @{ ok = $false; error = "quota_exhausted"; quotaType = $EventType; requiredCredits = $RequiredCredits; upgradeRequired = (-not $usage.isPremium); upgradeLabel = "Upgrade ke pro - Rp. 199.999/bln"; message = $message; usage = $usage }
}

function Get-KanvasPublicUser {
    param([object]$User)
    return @{
        id = [string]$User.id
        email = [string]$User.email
        displayName = [string]$User.display_name
        createdAt = ([DateTime]$User.created_at).ToUniversalTime().ToString("o")
        plan = (Get-KanvasPlanCode -UserId ([string]$User.id))
    }
}

function Get-KanvasSessionCookie {
    param([hashtable]$Session)
    $cookie = "$SessionCookieName=$($Session.token); Path=/; HttpOnly; SameSite=Strict"
    if ($PublicMode) { $cookie += "; Secure" }
    if ($Session.remember) { $cookie += "; Max-Age=$($Session.maxAge)" }
    return $cookie
}

function Write-KanvasUnauthorized {
    param([System.IO.Stream]$Stream)
    Write-JsonResponse -Stream $Stream -StatusCode 401 -Data @{ ok = $false; authenticated = $false; error = "unauthorized"; message = "Silakan masuk kembali ke akun Kanvas." }
}

function Handle-KanvasAccountRequest {
    param([System.IO.Stream]$Stream, [object]$Request)
    $route = "$($Request.Method) $($Request.Path)"

    if ($route -eq "GET /api/auth/challenge") {
        $challenge = if ($TurnstileSiteKey) { @{ mode = "turnstile"; siteKey = $TurnstileSiteKey } } else { (New-KanvasSignupChallenge) + @{ mode = "math" } }
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; challenge = $challenge }
        return $true
    }

    if ($route -eq "POST /api/auth/register") {
        $inputData = ConvertFrom-RequestJson -Body $Request.Body
        $displayName = ([string]$inputData.displayName).Trim()
        $email = ([string]$inputData.email).Trim().ToLowerInvariant()
        $password = [string]$inputData.password
        if (-not (Test-KanvasSignupRateLimit -RemoteAddress ([string]$Request.ClientAddress))) { Write-JsonResponse -Stream $Stream -StatusCode 429 -Data @{ error = "signup_rate_limit"; message = "Terlalu banyak percobaan pendaftaran dari jaringan ini. Coba lagi dalam satu jam." }; return $true }
        $captchaValid = if ($TurnstileSiteKey) {
            Test-KanvasTurnstile -Token ([string]$inputData.turnstileToken) -RemoteAddress ([string]$Request.ClientAddress)
        }
        else {
            Test-KanvasSignupChallenge -Token ([string]$inputData.captchaToken) -Answer ([string]$inputData.captchaAnswer)
        }
        if (-not $captchaValid) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_captcha"; message = "Verifikasi keamanan tidak valid atau sudah kedaluwarsa. Silakan coba kembali." }; return $true }
        $signupSignal = Get-KanvasSignupSignal -InputData $inputData -Request $Request
        if (-not (Test-KanvasSignupDeviceAllowed -DeviceHash $signupSignal.deviceHash)) { Write-JsonResponse -Stream $Stream -StatusCode 429 -Data @{ error = "device_signup_limit"; message = "Batas akun gratis untuk perangkat ini sudah tercapai. Hubungi bantuan jika ini keliru." }; return $true }
        if ($displayName.Length -lt 2 -or $displayName.Length -gt 80) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_name"; message = "Nama harus terdiri dari 2-80 karakter." }; return $true }
        if ($email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$' -or $email.Length -gt 255) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_email"; message = "Alamat email tidak valid." }; return $true }
        if ($password.Length -lt 8 -or $password.Length -gt 128) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "weak_password"; message = "Kata sandi minimal 8 karakter." }; return $true }
        if ([int](Invoke-KanvasDbScalar -Sql "SELECT COUNT(*) FROM Users WHERE [email] = ?" -Parameters @($email)) -gt 0) { Write-JsonResponse -Stream $Stream -StatusCode 409 -Data @{ error = "email_exists"; message = "Email tersebut sudah terdaftar." }; return $true }
        try {
            $userId = New-KanvasUser -Email $email -DisplayName $displayName -Password $password -Initialized $true
            Add-KanvasSignupSignal -UserId $userId -Signal $signupSignal
            $session = New-KanvasSession -UserId $userId -Remember ([bool]$inputData.remember)
            $user = @(Invoke-KanvasDbQuery -Sql "SELECT [id], [email], [display_name], [created_at] FROM Users WHERE [id] = ?" -Parameters @($userId))[0]
            Write-JsonResponse -Stream $Stream -StatusCode 201 -ExtraHeaders @{ "Set-Cookie" = (Get-KanvasSessionCookie -Session $session) } -Data @{
                ok = $true; authenticated = $true; csrfToken = $session.csrfToken; user = (Get-KanvasPublicUser -User $user); preferences = (Get-KanvasPreferences -UserId $userId)
            }
        }
        catch {
            Write-Warning "Pendaftaran gagal: $($_.Exception.Message)"
            $message = if ($InternetExposedMode) { "Akun belum dapat dibuat. Silakan coba kembali." } else { "Akun tidak dapat dibuat: $($_.Exception.Message)" }
            Write-JsonResponse -Stream $Stream -StatusCode 500 -Data @{ error = "registration_failed"; message = $message }
        }
        return $true
    }

    if ($route -eq "POST /api/auth/login") {
        $inputData = ConvertFrom-RequestJson -Body $Request.Body
        $email = ([string]$inputData.email).Trim().ToLowerInvariant()
        $password = [string]$inputData.password
        $clientKey = Get-KanvasSha256Hex -Value ("ip:" + [string]$Request.ClientAddress)
        $emailKey = Get-KanvasSha256Hex -Value ("email:" + $email)
        if (-not (Test-KanvasSecurityRateLimit -Key $clientKey -EventType "login_ip" -Limit 30 -WindowMinutes 15) -or -not (Test-KanvasSecurityRateLimit -Key $emailKey -EventType "login_email" -Limit 10 -WindowMinutes 15)) {
            Write-JsonResponse -Stream $Stream -StatusCode 429 -Data @{ error = "login_rate_limit"; message = "Terlalu banyak percobaan masuk. Tunggu 15 menit lalu coba kembali." }
            return $true
        }
        $users = @(Invoke-KanvasDbQuery -Sql "SELECT [id], [email], [display_name], [password_hash], [password_salt], [password_iterations], [created_at] FROM Users WHERE [email] = ?" -Parameters @($email))
        if ($users.Count -eq 0 -or -not (Test-KanvasPassword -Password $password -Salt ([string]$users[0].password_salt) -ExpectedHash ([string]$users[0].password_hash) -Iterations ([int]$users[0].password_iterations))) {
            Write-JsonResponse -Stream $Stream -StatusCode 401 -Data @{ error = "invalid_credentials"; message = "Email atau kata sandi tidak cocok." }
            return $true
        }
        $session = New-KanvasSession -UserId ([string]$users[0].id) -Remember ([bool]$inputData.remember)
        Write-JsonResponse -Stream $Stream -ExtraHeaders @{ "Set-Cookie" = (Get-KanvasSessionCookie -Session $session) } -Data @{
            ok = $true; authenticated = $true; csrfToken = $session.csrfToken; user = (Get-KanvasPublicUser -User $users[0]); preferences = (Get-KanvasPreferences -UserId ([string]$users[0].id))
        }
        return $true
    }

    if ($route -eq "GET /api/auth/me") {
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        $session = Get-KanvasSessionRecord -Request $Request
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; authenticated = $true; csrfToken = [string]$session.csrf_token; user = (Get-KanvasPublicUser -User $user); preferences = (Get-KanvasPreferences -UserId ([string]$user.id)) }
        return $true
    }

    if ($route -eq "GET /api/usage") {
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; usage = (Get-KanvasUsageStatus -UserId ([string]$user.id)) }
        return $true
    }

    if ($route -eq "POST /api/auth/logout") {
        if (-not (Test-KanvasCsrfRequest -Request $Request)) { Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "invalid_csrf_token"; message = "Token keamanan sesi tidak valid." }; return $true }
        $token = Get-KanvasCookieValue -Request $Request -Name $SessionCookieName
        if (-not [string]::IsNullOrWhiteSpace($token)) { $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM Sessions WHERE [token_hash] = ?" -Parameters @((Get-KanvasSha256Hex -Value $token)) }
        $expiredCookie = "$SessionCookieName=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"
        if ($PublicMode) { $expiredCookie += "; Secure" }
        Write-JsonResponse -Stream $Stream -ExtraHeaders @{ "Set-Cookie" = $expiredCookie } -Data @{ ok = $true }
        return $true
    }

    if ($route -eq "GET /api/state") {
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        $rows = @(Invoke-KanvasDbQuery -Sql "SELECT [projects_json], [library_json], [initialized] FROM UserState WHERE [user_id] = ?" -Parameters @([string]$user.id))
        if ($rows.Count -eq 0) { Write-JsonResponse -Stream $Stream -Data @{ projects = @(); library = @(); initialized = $false }; return $true }
        try { $projects = @(([string]$rows[0].projects_json | ConvertFrom-Json)) } catch { $projects = @() }
        try { $library = @(([string]$rows[0].library_json | ConvertFrom-Json)) } catch { $library = @() }
        Write-JsonResponse -Stream $Stream -Data @{ projects = $projects; library = $library; initialized = [bool]$rows[0].initialized }
        return $true
    }

    if ($route -eq "PUT /api/state") {
        if (-not (Test-KanvasCsrfRequest -Request $Request)) { Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "invalid_csrf_token"; message = "Token keamanan sesi tidak valid." }; return $true }
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        $inputData = ConvertFrom-RequestJson -Body $Request.Body
        $projectsJson = ConvertTo-Json -InputObject @($inputData.projects) -Depth 20 -Compress
        $libraryJson = ConvertTo-Json -InputObject @($inputData.library) -Depth 20 -Compress
        if (($projectsJson.Length + $libraryJson.Length) -gt 900000) { Write-JsonResponse -Stream $Stream -StatusCode 413 -Data @{ error = "state_too_large"; message = "Data proyek akun terlalu besar untuk prototipe lokal." }; return $true }
        $null = Invoke-KanvasDbNonQuery -Sql "UPDATE UserState SET [projects_json] = ?, [library_json] = ?, [initialized] = ?, [updated_at] = ? WHERE [user_id] = ?" -Parameters @(
            $projectsJson, $libraryJson, $true, [DateTime]::UtcNow, [string]$user.id
        )
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; savedAt = [DateTime]::UtcNow.ToString("o") }
        return $true
    }

    if ($route -eq "PUT /api/account/profile") {
        if (-not (Test-KanvasCsrfRequest -Request $Request)) { Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "invalid_csrf_token"; message = "Token keamanan sesi tidak valid." }; return $true }
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        $inputData = ConvertFrom-RequestJson -Body $Request.Body
        $displayName = ([string]$inputData.displayName).Trim()
        if ($displayName.Length -lt 2 -or $displayName.Length -gt 80) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_name"; message = "Nama harus terdiri dari 2-80 karakter." }; return $true }
        $null = Invoke-KanvasDbNonQuery -Sql "UPDATE Users SET [display_name] = ?, [updated_at] = ? WHERE [id] = ?" -Parameters @($displayName, [DateTime]::UtcNow, [string]$user.id)
        $updatedUser = @(Invoke-KanvasDbQuery -Sql "SELECT [id], [email], [display_name], [created_at] FROM Users WHERE [id] = ?" -Parameters @([string]$user.id))[0]
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; user = (Get-KanvasPublicUser -User $updatedUser) }
        return $true
    }

    if ($route -eq "PUT /api/account/preferences") {
        if (-not (Test-KanvasCsrfRequest -Request $Request)) { Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "invalid_csrf_token"; message = "Token keamanan sesi tidak valid." }; return $true }
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        $inputData = ConvertFrom-RequestJson -Body $Request.Body
        $allowedFormats = @($DefaultPosterFormat, "Instagram Story $FormatSeparator 9:16", "Persegi $FormatSeparator 1:1")
        $allowedStyles = @("Eksploratif", "Minimal", "Berani")
        $format = [string]$inputData.defaultFormat
        $style = [string]$inputData.defaultStyle
        $color = ([string]$inputData.primaryColor).ToLowerInvariant()
        $startView = [string]$inputData.startView
        if ($format -notin $allowedFormats -or $style -notin $allowedStyles -or $color -notmatch '^#[0-9a-f]{6}$' -or $startView -notin @("dashboard", "library")) {
            Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "invalid_preferences"; message = "Preferensi yang dikirim tidak valid." }
            return $true
        }
        $null = Invoke-KanvasDbNonQuery -Sql "UPDATE Preferences SET [default_format] = ?, [default_style] = ?, [primary_color] = ?, [start_view] = ?, [updated_at] = ? WHERE [user_id] = ?" -Parameters @(
            $format, $style, $color, $startView, [DateTime]::UtcNow, [string]$user.id
        )
        Write-JsonResponse -Stream $Stream -Data @{ ok = $true; preferences = (Get-KanvasPreferences -UserId ([string]$user.id)) }
        return $true
    }

    if ($route -eq "PUT /api/account/password") {
        if (-not (Test-KanvasCsrfRequest -Request $Request)) { Write-JsonResponse -Stream $Stream -StatusCode 403 -Data @{ error = "invalid_csrf_token"; message = "Token keamanan sesi tidak valid." }; return $true }
        $user = Get-KanvasAuthenticatedUser -Request $Request
        if (-not $user) { Write-KanvasUnauthorized -Stream $Stream; return $true }
        $inputData = ConvertFrom-RequestJson -Body $Request.Body
        $currentPassword = [string]$inputData.currentPassword
        $newPassword = [string]$inputData.newPassword
        $passwordRows = @(Invoke-KanvasDbQuery -Sql "SELECT [password_hash], [password_salt], [password_iterations] FROM Users WHERE [id] = ?" -Parameters @([string]$user.id))
        if ($passwordRows.Count -eq 0 -or -not (Test-KanvasPassword -Password $currentPassword -Salt ([string]$passwordRows[0].password_salt) -ExpectedHash ([string]$passwordRows[0].password_hash) -Iterations ([int]$passwordRows[0].password_iterations))) {
            Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "wrong_password"; message = "Kata sandi saat ini tidak cocok." }
            return $true
        }
        if ($newPassword.Length -lt 8 -or $newPassword.Length -gt 128) { Write-JsonResponse -Stream $Stream -StatusCode 400 -Data @{ error = "weak_password"; message = "Kata sandi baru minimal 8 karakter." }; return $true }
        $passwordRecord = New-KanvasPasswordRecord -Password $newPassword
        $null = Invoke-KanvasDbNonQuery -Sql "UPDATE Users SET [password_hash] = ?, [password_salt] = ?, [password_iterations] = ?, [updated_at] = ? WHERE [id] = ?" -Parameters @(
            $passwordRecord.hash, $passwordRecord.salt, $passwordRecord.iterations, [DateTime]::UtcNow, [string]$user.id
        )
        $null = Invoke-KanvasDbNonQuery -Sql "DELETE FROM Sessions WHERE [user_id] = ?" -Parameters @([string]$user.id)
        $session = New-KanvasSession -UserId ([string]$user.id) -Remember $true
        Write-JsonResponse -Stream $Stream -ExtraHeaders @{ "Set-Cookie" = (Get-KanvasSessionCookie -Session $session) } -Data @{ ok = $true; csrfToken = $session.csrfToken }
        return $true
    }

    return $false
}
