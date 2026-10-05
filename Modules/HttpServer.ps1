# ============================================================================
#  HTTP Server — управление ТВ с телефона через браузер
#
#  Все функции, вызываемые из Runspace, реализованы через $global:AdbPath.
# ============================================================================

# ============================================================================
#  ГЕНЕРАЦИЯ ТОКЕНА
# ============================================================================
function New-HttpToken {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    $bytes = New-Object byte[] 8
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $token = ""
    foreach ($b in $bytes) {
        $token += $chars[$b % $chars.Length]
    }
    return $token
}

# ============================================================================
#  ПОЛУЧИТЬ ЛОКАЛЬНЫЙ IP ПК
# ============================================================================
function Get-LocalIpAddress {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 |
               Where-Object {
                   $_.InterfaceAlias -notmatch 'Loopback' -and
                   $_.IPAddress -notmatch '^169' -and
                   $_.IPAddress -notmatch '^127'
               } |
               Select-Object -First 1).IPAddress
        if ($ip) { return $ip }
    } catch { }
    return "127.0.0.1"
}

# ============================================================================
#  ЗАПУСК СЕРВЕРА
# ============================================================================
function Start-HttpServer {
    param(
        [int]$Port = 8080,
        [string]$Token = ""
    )

    if ($script:HttpListener) {
        Write-Log -Message "HTTP-сервер уже запущен" -Level "Warning"
        return $false
    }

    if (-not $Token) {
        $Token = New-HttpToken
    }

    $prefix = "http://+:$Port/"
    $script:HttpLocalOnly = $false

    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add($prefix)

        try {
            $listener.IgnoreWriteExceptions = $true
            $listener.TimeoutManager.RequestQueueTimeout = [TimeSpan]::FromMinutes(10)
            $listener.TimeoutManager.IdleConnection = [TimeSpan]::FromMinutes(10)
        } catch { }

        try {
            $prop = $listener.GetType().GetProperty("MaxRequestBodySize",
                [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
            if ($prop) {
                $prop.SetValue($listener, [int64](1024 * 1024 * 1024))
            }
        } catch { }

        try {
            $listener.Start()
        } catch {
            Write-Log -Message "Не удалось открыть $prefix — пробую http://localhost:$Port/" -Level "Warning"
            $listener = New-Object System.Net.HttpListener
            $listener.Prefixes.Add("http://localhost:$Port/")
            try {
                $listener.IgnoreWriteExceptions = $true
                $listener.TimeoutManager.RequestQueueTimeout = [TimeSpan]::FromMinutes(10)
            } catch { }
            $listener.Start()
            $script:HttpLocalOnly = $true
            Write-Log -Message "Сервер слушает только на localhost." -Level "Warning"
        }

        $script:HttpListener      = $listener
        $script:HttpToken         = $Token
        $script:HttpPort          = $Port
        $script:HttpServerRunning = $true

        # ===== Собираем функции для Runspace =====
        $functionNames = @(
            'Invoke-HttpApiStatus',
            'Invoke-HttpApiApps',
            'Invoke-HttpApiLaunchApp',
            'Invoke-HttpApiRemoteKey',
            'Invoke-HttpApiRemoteText',
            'Invoke-HttpApiLog',
            'Invoke-HttpApiScreenshot',
            'Invoke-HttpApiScreenshotBase64',
            'Invoke-HttpApiScreenshotList',
            'Invoke-HttpApiDevices',
            'Invoke-HttpApiPackages',
            'Invoke-HttpApiPackageAction',
            'Invoke-HttpApiPowerAction',
            'Invoke-HttpApiCurrentActivity',
            'Invoke-HttpApiWindows',
            'Invoke-HttpApiCloseApp',
            'Invoke-HttpApiFilesList',
            'Invoke-HttpApiFileDownload',
            'Invoke-HttpApiFileDelete',
            'Invoke-HttpApiPresetsGet',
            'Invoke-HttpApiPresetApply',
            'Invoke-HttpApiApkUpload',
            'Invoke-HttpApiMetrics',
            'Invoke-HttpApiMetricsTop',
            'Invoke-HttpApiBluetoothGet',
            'Invoke-HttpApiBluetoothEnable',
            'Invoke-HttpApiBluetoothDisable',
            'Invoke-HttpApiWifiGet',
            'Invoke-HttpApiTimerSet',
            'Invoke-HttpApiTimerCancel'
        )

        $functionDefs = ""
        foreach ($fn in $functionNames) {
            $cmd = Get-Command $fn -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.ScriptBlock) {
                $fullDef = $cmd.ScriptBlock.Ast.Extent.Text
                $functionDefs += "`n# === $fn ===`n$fullDef`n"
            } else {
                Write-Log -Message "Функция не найдена для Runspace: $fn" -Level "Warning"
            }
        }

        Write-Log -Message "Runspace: собрано $($functionNames.Count) функций, длина $($functionDefs.Length) символов" -Level "Info"

        $stateBlock = @"
`$global:AdbPath    = '$($script:adbPath -replace "'", "''")'
`$global:DeviceIp   = '$($script:deviceIp -replace "'", "''")'
`$global:Connected  = `$$($script:connected.ToString().ToLower())
`$global:AppRoot    = '$($script:AppRoot -replace "'", "''")'
`$global:AppVersion = '$($script:AppVersion -replace "'", "''")'
"@

        $htmlContent = Get-HttpIndexHtml
        $screenshotFolder = Join-Path ([Environment]::GetFolderPath("Desktop")) "screenshot_tv"

        # ===== Runspace =====
        $script:HttpRunspace = [runspacefactory]::CreateRunspace()
        $script:HttpRunspace.ApartmentState = "MTA"
        $script:HttpRunspace.ThreadOptions = "ReuseThread"
        $script:HttpRunspace.Open()

        $ps = [powershell]::Create()
        $ps.Runspace = $script:HttpRunspace

        $ps.AddScript({
            param($listener, $token, $appRoot, $functionDefs, $stateBlock, $htmlContent, $screenshotFolder)

            try { . ([scriptblock]::Create($stateBlock)) } catch { }
            try { . ([scriptblock]::Create($functionDefs)) } catch {
                try {
                    $logDir = Join-Path $appRoot "Logs"
                    if (Test-Path $logDir) {
                        $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
                        "$(Get-Date -Format 'HH:mm:ss.fff') [HTTP-FATAL] Load functions failed: $($_.Exception.Message)" |
                            Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                } catch { }
            }

            function Send-HttpResponse {
                param($Ctx, [int]$Status, [string]$ContentType, [string]$Body)
                try {
                    $Ctx.Response.StatusCode  = $Status
                    $Ctx.Response.ContentType = $ContentType
                    $Ctx.Response.Headers["Access-Control-Allow-Origin"]  = "*"
                    $Ctx.Response.Headers["Access-Control-Allow-Headers"] = "Content-Type, X-Token, X-Filename"
                    $Ctx.Response.Headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
                    $Ctx.Response.ContentLength64 = $bytes.Length
                    $Ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                } catch { }
                finally { try { $Ctx.Response.Close() } catch { } }
            }

            function Send-HttpBinary {
                param($Ctx, [int]$Status, [string]$ContentType, [byte[]]$Bytes)
                try {
                    $Ctx.Response.StatusCode  = $Status
                    $Ctx.Response.ContentType = $ContentType
                    $Ctx.Response.Headers["Access-Control-Allow-Origin"] = "*"
                    $Ctx.Response.ContentLength64 = $Bytes.Length
                    $Ctx.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
                } catch { }
                finally { try { $Ctx.Response.Close() } catch { } }
            }

            function Read-RequestBody {
                param($Ctx)
                try {
                    $reader = New-Object System.IO.StreamReader($Ctx.Request.InputStream, $Ctx.Request.ContentEncoding)
                    return $reader.ReadToEnd()
                } catch { return "" }
            }

            function Read-RequestBodyBytes {
                param($Ctx)
                try {
                    $ms = New-Object System.IO.MemoryStream
                    $Ctx.Request.InputStream.CopyTo($ms)
                    $bytes = $ms.ToArray()
                    $ms.Close()
                    return $bytes
                } catch { return $null }
            }

            function Test-Token {
                param($Ctx, [string]$ExpectedToken)
                $fromQuery = $Ctx.Request.QueryString["token"]
                if ($fromQuery -eq $ExpectedToken) { return $true }
                $fromHeader = $Ctx.Request.Headers["X-Token"]
                if ($fromHeader -eq $ExpectedToken) { return $true }
                return $false
            }

            function Write-HttpLog {
                param([string]$Level, [string]$Message)
                try {
                    $logDir = Join-Path $appRoot "Logs"
                    if (Test-Path $logDir) {
                        $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
                        "$(Get-Date -Format 'HH:mm:ss.fff') [$Level] $Message" |
                            Out-File -FilePath $logFile -Append -Encoding UTF8
                    }
                } catch { }
            }

            Write-HttpLog -Level "HTTP-INFO" -Message "Accept loop started"

            try {
                while ($listener.IsListening) {
                    try {
                        $ctx = $listener.GetContext()
                        $path   = $ctx.Request.Url.AbsolutePath
                        $method = $ctx.Request.HttpMethod

                        if ($method -eq "OPTIONS") {
                            Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "text/plain" -Body ""
                            continue
                        }

                        # ================= СТАТИКА =================
                        if ($path -eq "/" -or $path -eq "/index.html") {
                            Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "text/html; charset=utf-8" -Body $htmlContent
                            continue
                        }

                        if ($path -eq "/mobile.css") {
                            $cssFile = Join-Path $appRoot "Modules\http_mobile.css"
                            if (Test-Path $cssFile) {
                                $cssContent = [System.IO.File]::ReadAllText($cssFile, [System.Text.UTF8Encoding]::new($false))
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "text/css; charset=utf-8" -Body $cssContent
                            } else {
                                Send-HttpResponse -Ctx $ctx -Status 404 -ContentType "text/plain" -Body "CSS not found"
                            }
                            continue
                        }

                        if ($path -eq "/mobile.js") {
                            $jsFile = Join-Path $appRoot "Modules\http_mobile.js"
                            if (Test-Path $jsFile) {
                                $jsContent = [System.IO.File]::ReadAllText($jsFile, [System.Text.UTF8Encoding]::new($false))
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/javascript; charset=utf-8" -Body $jsContent
                            } else {
                                Send-HttpResponse -Ctx $ctx -Status 404 -ContentType "text/plain" -Body "JS not found"
                            }
                            continue
                        }

                        # ================= ТОКЕН =================
                        if ($path -like "/api/*") {
                            if (-not (Test-Token -Ctx $ctx -ExpectedToken $token)) {
                                Send-HttpResponse -Ctx $ctx -Status 401 -ContentType "application/json; charset=utf-8" -Body '{"error":"unauthorized"}'
                                continue
                            }
                        }

                        # ================= СКРИНШОТЫ =================
                        if ($path -like "/shots/*") {
                            $fileName = [System.IO.Path]::GetFileName($path)
                            $filePath = Join-Path $screenshotFolder $fileName
                            if ((Test-Path $filePath) -and $fileName -match '\.(png|jpg|jpeg)$') {
                                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                                Send-HttpBinary -Ctx $ctx -Status 200 -ContentType "image/png" -Bytes $bytes
                            } else {
                                Send-HttpResponse -Ctx $ctx -Status 404 -ContentType "text/plain" -Body "Not found"
                            }
                            continue
                        }

                        # ================= API =================
                        switch -Regex ($path) {
                            '^/api/status$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiStatus)
                                continue
                            }
                            '^/api/apps$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiApps)
                                continue
                            }
                            '^/api/apps/launch$' {
                                $body = Invoke-HttpApiLaunchApp -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/remote/key$' {
                                $body = Invoke-HttpApiRemoteKey -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/remote/text$' {
                                $body = Invoke-HttpApiRemoteText -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/log$' {
                                $lines = 50
                                $q = $ctx.Request.QueryString["lines"]
                                if ($q -and $q -match '^\d+$') { $lines = [int]$q }
                                if ($lines -gt 500) { $lines = 500 }
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiLog -Lines $lines)
                                continue
                            }
                            '^/api/screenshot$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiScreenshot)
                                continue
                            }
                            '^/api/screenshot/base64$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiScreenshotBase64)
                                continue
                            }
                            '^/api/screenshot/list$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiScreenshotList)
                                continue
                            }
                            '^/api/devices$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiDevices)
                                continue
                            }
                            '^/api/packages$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiPackages)
                                continue
                            }
                            '^/api/packages/action$' {
                                $body = Invoke-HttpApiPackageAction -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/power/(reboot|sleep|wakeup|shutdown)$' {
                                $action = ($path -split '/')[-1]
                                $body = Invoke-HttpApiPowerAction -Action $action
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/current-activity$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiCurrentActivity)
                                continue
                            }
                            '^/api/windows$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiWindows)
                                continue
                            }
                            '^/api/windows/close$' {
                                $body = Invoke-HttpApiCloseApp -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/files$' {
                                $p = $ctx.Request.QueryString["path"]
                                if (-not $p) { $p = "/sdcard/" }
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiFilesList -Path $p)
                                continue
                            }
                            '^/api/files/download$' {
                                $p = $ctx.Request.QueryString["path"]
                                if (-not $p) {
                                    Send-HttpResponse -Ctx $ctx -Status 400 -ContentType "text/plain" -Body "Missing path"
                                    continue
                                }
                                $bytes = Invoke-HttpApiFileDownload -Path $p
                                if ($bytes) {
                                    $fn = [System.IO.Path]::GetFileName($p)
                                    $ctx.Response.Headers["Content-Disposition"] = "attachment; filename=`"$fn`""
                                    Send-HttpBinary -Ctx $ctx -Status 200 -ContentType "application/octet-stream" -Bytes $bytes
                                } else {
                                    Send-HttpResponse -Ctx $ctx -Status 404 -ContentType "text/plain" -Body "Not found"
                                }
                                continue
                            }
                            '^/api/files/delete$' {
                                $body = Invoke-HttpApiFileDelete -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/presets$' {
                                if ($method -eq "POST") {
                                    $body = Invoke-HttpApiPresetApply -RequestBody (Read-RequestBody -Ctx $ctx)
                                } else {
                                    $body = Invoke-HttpApiPresetsGet
                                }
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/apk/upload$' {
                                $filename = $ctx.Request.Headers["X-Filename"]
                                if (-not $filename) { $filename = "upload.apk" }

                                $bytes = Read-RequestBodyBytes -Ctx $ctx
                                $body = Invoke-HttpApiApkUpload -Body $bytes -FileName $filename
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/metrics$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiMetrics)
                                continue
                            }
                            '^/api/metrics/top$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiMetricsTop)
                                continue
                            }
                            '^/api/bluetooth$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiBluetoothGet)
                                continue
                            }
                            '^/api/bluetooth/enable$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiBluetoothEnable)
                                continue
                            }
                            '^/api/bluetooth/disable$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiBluetoothDisable)
                                continue
                            }
                            '^/api/wifi$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiWifiGet)
                                continue
                            }
                            '^/api/timer/set$' {
                                $body = Invoke-HttpApiTimerSet -RequestBody (Read-RequestBody -Ctx $ctx)
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body $body
                                continue
                            }
                            '^/api/timer/cancel$' {
                                Send-HttpResponse -Ctx $ctx -Status 200 -ContentType "application/json; charset=utf-8" -Body (Invoke-HttpApiTimerCancel)
                                continue
                            }
                            default {
                                Send-HttpResponse -Ctx $ctx -Status 404 -ContentType "application/json; charset=utf-8" -Body '{"error":"not_found"}'
                                continue
                            }
                        }
                    } catch {
                        Write-HttpLog -Level "HTTP-ERR" -Message "$($_.Exception.Message) | line $($_.InvocationInfo.ScriptLineNumber)"
                        Start-Sleep -Milliseconds 100
                    }
                }
            } catch {
                Write-HttpLog -Level "HTTP-FATAL" -Message "$($_.Exception.Message)"
            }
        }) | Out-Null

        $ps.AddArgument($listener)
        $ps.AddArgument($Token)
        $ps.AddArgument($script:AppRoot)
        $ps.AddArgument($functionDefs)
        $ps.AddArgument($stateBlock)
        $ps.AddArgument($htmlContent)
        $ps.AddArgument($screenshotFolder)

        $script:HttpPS     = $ps
        $script:HttpHandle = $ps.BeginInvoke()

        $localIp = Get-LocalIpAddress
        Write-Log -Message "=== HTTP-сервер запущен ===" -Level "Success"
        Write-Log -Message "  Локальный URL: http://localhost:$Port/?token=$Token" -Level "Info"
        if ($script:HttpLocalOnly) {
            Write-Log -Message "  [ВНИМАНИЕ] Сервер слушает только localhost." -Level "Warning"
        } else {
            Write-Log -Message "  Для телефона:  http://$($localIp):$Port/?token=$Token" -Level "Info"
        }
        Write-Log -Message "  Токен: $Token" -Level "Info"

        try {
            if (Get-Command Update-HttpStatusBar -ErrorAction SilentlyContinue) {
                Update-HttpStatusBar
            }
        } catch { }

        return $true

    } catch {
        Write-Log -Message "Ошибка запуска HTTP-сервера: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ОСТАНОВКА СЕРВЕРА
# ============================================================================
function Stop-HttpServer {
    if (-not $script:HttpServerRunning) { return $false }

    Write-Log -Message "Останавливаю HTTP-сервер..." -Level "Info"

    try {
        if ($script:HttpListener) {
            try { $script:HttpListener.Stop()    } catch { }
            try { $script:HttpListener.Close()   } catch { }
            try { $script:HttpListener.Dispose() } catch { }
            $script:HttpListener = $null
        }
    } catch { }

    try {
        if ($script:HttpPS) {
            try { $script:HttpPS.Stop()    } catch { }
            Start-Sleep -Milliseconds 100
            try { $script:HttpPS.Dispose() } catch { }
            $script:HttpPS = $null
        }
        if ($script:HttpRunspace) {
            try { $script:HttpRunspace.Close()   } catch { }
            try { $script:HttpRunspace.Dispose() } catch { }
            $script:HttpRunspace = $null
        }
    } catch { }

    $script:HttpServerRunning = $false
    $script:HttpLocalOnly     = $false
    Write-Log -Message "HTTP-сервер остановлен" -Level "Success"

    try {
        if (Get-Command Update-HttpStatusBar -ErrorAction SilentlyContinue) {
            Update-HttpStatusBar
        }
    } catch { }

    return $true
}

# ============================================================================
#  РАЗРЕШИТЬ ДОСТУП ПО СЕТИ (UAC)
# ============================================================================
function Enable-HttpNetworkAccess {
    param([int]$Port = 8080)

    Write-Log -Message "=== Запрос прав администратора для сетевого доступа ===" -Level "Info"

    $cmd1 = "netsh http add urlacl url=http://+:$Port/ sddl=D:(A;;GX;;;S-1-1-0)"
    $cmd2 = "netsh advfirewall firewall add rule name=`"TVManager HTTP $Port`" dir=in action=allow protocol=TCP localport=$Port"

    $tempDir = Join-Path $env:TEMP "TVManager_HttpAcl_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $batPath = Join-Path $tempDir "enable_access.bat"
    $logPath = Join-Path $tempDir "result.log"

    $batContent = @"
@echo off
chcp 65001 >nul
echo === TVManager === > "$logPath"
$cmd1 >> "$logPath" 2>&1
$cmd2 >> "$logPath" 2>&1
echo DONE >> "$logPath"
"@

    try {
        [System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.UTF8Encoding]::new($false))
    } catch { return $false }

    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -Verb RunAs -WindowStyle Hidden -Wait
    } catch {
        try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        return $false
    }

    Start-Sleep -Milliseconds 500

    $aclOk = $false
    try {
        $check = & netsh http show urlacl 2>&1 | Out-String
        if ($check -match [regex]::Escape("http://+:$Port/")) { $aclOk = $true }
    } catch { }

    $fwOk = $false
    try {
        $check = & netsh advfirewall firewall show rule name="TVManager HTTP $Port" 2>&1 | Out-String
        if ($check -notmatch 'No rules match') { $fwOk = $true }
    } catch { }

    try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }

    if ($aclOk) { Write-Log -Message "OK: URL ACL установлен" -Level "Success" }
    else { Write-Log -Message "URL ACL НЕ установлен" -Level "Warning" }

    if ($fwOk) { Write-Log -Message "OK: правило брандмауэра добавлено" -Level "Success" }
    else { Write-Log -Message "Правило брандмауэра НЕ добавлено" -Level "Warning" }

    return $aclOk
}

# ============================================================================
#  API: СТАТУС
# ============================================================================
function Invoke-HttpApiStatus {
    try {
        $isConnected = $false
        $deviceIp = $global:DeviceIp

        try {
            if ($global:AdbPath -and $deviceIp) {
                $devices = & $global:AdbPath devices 2>&1
                foreach ($line in $devices) {
                    if ($line -match "^\S+\s+device$" -and $line -match [regex]::Escape($deviceIp)) {
                        $isConnected = $true
                        break
                    }
                }
                if (-not $isConnected) {
                    foreach ($line in $devices) {
                        if ($line -match "^\S+\s+device$") { $isConnected = $true; break }
                    }
                }
            }
        } catch { }

        $result = [ordered]@{
            connected  = $isConnected
            deviceIp   = $deviceIp
            appVersion = $global:AppVersion
            serverTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        return ($result | ConvertTo-Json -Depth 5)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: СПИСОК ПРИЛОЖЕНИЙ
# ============================================================================
function Invoke-HttpApiApps {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $allRaw   = & $global:AdbPath shell pm list packages 2>&1
        $thirdRaw = & $global:AdbPath shell pm list packages -3 2>&1

        $thirdSet = @{}
        foreach ($line in ($thirdRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') { $thirdSet[$matches[1].Trim()] = $true }
        }

        $apps = @()
        foreach ($line in ($allRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $pkg = $matches[1].Trim()
                $apps += [PSCustomObject]@{
                    package  = $pkg
                    isSystem = (-not $thirdSet.ContainsKey($pkg))
                }
            }
        }

        return (@{ apps = $apps } | ConvertTo-Json -Depth 5 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ЗАПУСК ПРИЛОЖЕНИЯ
# ============================================================================
function Invoke-HttpApiLaunchApp {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $pkg = $json.package
        if (-not $pkg -or $pkg -notmatch '^[a-zA-Z][a-zA-Z0-9_\.]+$') {
            return '{"error":"invalid_package"}'
        }

        $out = & $global:AdbPath shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 2>&1
        $outText = ($out | Out-String).Trim()
        $ok = ($outText -match 'Events injected: 1')

        return (@{ success = $ok; package = $pkg } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: КЛАВИША ПУЛЬТА
# ============================================================================
function Invoke-HttpApiRemoteKey {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $key  = $json.key
        if (-not $key) { return '{"error":"missing_key"}' }

        $allowed = @{
            "UP"     = "KEYCODE_DPAD_UP"
            "DOWN"   = "KEYCODE_DPAD_DOWN"
            "LEFT"   = "KEYCODE_DPAD_LEFT"
            "RIGHT"  = "KEYCODE_DPAD_RIGHT"
            "OK"     = "KEYCODE_DPAD_CENTER"
            "HOME"   = "KEYCODE_HOME"
            "BACK"   = "KEYCODE_BACK"
            "MENU"   = "KEYCODE_MENU"
            "SEARCH" = "KEYCODE_SEARCH"
            "PLAY"   = "KEYCODE_MEDIA_PLAY_PAUSE"
            "STOP"   = "KEYCODE_MEDIA_STOP"
            "NEXT"   = "KEYCODE_MEDIA_NEXT"
            "PREV"   = "KEYCODE_MEDIA_PREVIOUS"
            "REWIND" = "KEYCODE_MEDIA_REWIND"
            "FFWD"   = "KEYCODE_MEDIA_FAST_FORWARD"
            "VOLUP"  = "KEYCODE_VOLUME_UP"
            "VOLDN"  = "KEYCODE_VOLUME_DOWN"
            "MUTE"   = "KEYCODE_VOLUME_MUTE"
            "POWER"  = "KEYCODE_POWER"
            "WAKEUP" = "KEYCODE_WAKEUP"
            "SLEEP"  = "KEYCODE_SLEEP"
            "CHUP"   = "KEYCODE_CHANNEL_UP"
            "CHDN"   = "KEYCODE_CHANNEL_DOWN"
            "GUIDE"  = "KEYCODE_GUIDE"
            "INFO"   = "KEYCODE_INFO"
            "TV"     = "KEYCODE_TV"
            "INPUT"  = "KEYCODE_TV_INPUT"
            "RED"    = "KEYCODE_PROG_RED"
            "GREEN"  = "KEYCODE_PROG_GREEN"
            "YELLOW" = "KEYCODE_PROG_YELLOW"
            "BLUE"   = "KEYCODE_PROG_BLUE"
            "SUBTITLE" = "KEYCODE_CAPTIONS"
            "TEXT"     = "KEYCODE_TV_TELETEXT"
            "SETTINGS" = "KEYCODE_SETTINGS"
            "0"  = "KEYCODE_0"
            "1"  = "KEYCODE_1"
            "2"  = "KEYCODE_2"
            "3"  = "KEYCODE_3"
            "4"  = "KEYCODE_4"
            "5"  = "KEYCODE_5"
            "6"  = "KEYCODE_6"
            "7"  = "KEYCODE_7"
            "8"  = "KEYCODE_8"
            "9"  = "KEYCODE_9"
        }

        if (-not $allowed.ContainsKey($key)) {
            return '{"error":"unknown_key"}'
        }

        $keyCode = $allowed[$key]
        $out = & $global:AdbPath shell input keyevent $keyCode 2>&1
        $ok = ($LASTEXITCODE -eq 0)

        return (@{ success = $ok; key = $key; keycode = $keyCode } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ТЕКСТ
# ============================================================================
function Invoke-HttpApiRemoteText {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $text = $json.text
        if ([string]::IsNullOrWhiteSpace($text)) { return '{"error":"empty_text"}' }

        if ($text.Length -gt 200) { $text = $text.Substring(0, 200) }

        $hasNonAscii = ($text -match '[^\x00-\x7F]')

        if (-not $hasNonAscii) {
            $escaped = $text -replace ' ', '%s'
            $escaped = $escaped -replace '[^\w%s\-\.@]', ''
            & $global:AdbPath shell input text $escaped 2>&1 | Out-Null
            $ok = ($LASTEXITCODE -eq 0)
            return (@{ success = $ok; text = $text; method = "input_text" } | ConvertTo-Json -Compress)
        }

        $pkgList = & $global:AdbPath shell pm list packages 2>&1
        $hasAdbKb = (($pkgList | Out-String) -match 'com\.android\.adbkeyboard')

        if (-not $hasAdbKb) {
            $asciiOnly = ($text -replace '[^\w\s\.\-@]', '')
            if ($asciiOnly) {
                $escaped = $asciiOnly -replace ' ', '%s'
                & $global:AdbPath shell input text $escaped 2>&1 | Out-Null
                return (@{ success = $true; text = $asciiOnly; method = "input_text_ascii_only"; warning = "ADBKeyboard не установлен" } | ConvertTo-Json -Compress)
            }
            return '{"success":false,"error":"adbkeyboard_required","message":"Для кириллицы установите ADBKeyboard"}'
        }

        $adbkIme = "com.android.adbkeyboard/.AdbIME"
        $prevIme = ""
        try { $prevIme = (& $global:AdbPath shell settings get secure default_input_method 2>&1 | Out-String).Trim() } catch { }

        $isAdbKbActive = ($prevIme -match [regex]::Escape($adbkIme))
        if (-not $isAdbKbActive) {
            & $global:AdbPath shell ime set $adbkIme 2>&1 | Out-Null
            Start-Sleep -Milliseconds 500
        }

        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $b64 = [Convert]::ToBase64String($bytes)
        $out = & $global:AdbPath shell am broadcast -a ADB_INPUT_B64 --es msg $b64 2>&1
        $outText = ($out | Out-String).Trim()
        $sent = ($outText -match 'Broadcast completed: result=0')

        if (-not $isAdbKbActive -and $prevIme -and $prevIme -notmatch [regex]::Escape($adbkIme)) {
            Start-Sleep -Milliseconds 300
            & $global:AdbPath shell ime set $prevIme 2>&1 | Out-Null
        }

        if ($sent) {
            return (@{ success = $true; text = $text; method = "adbkeyboard_b64" } | ConvertTo-Json -Compress)
        }
        return '{"success":false,"error":"adbkeyboard_failed","message":"ADBKeyboard не подтвердил приём"}'
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ЛОГ
# ============================================================================
function Invoke-HttpApiLog {
    param([int]$Lines = 50)
    try {
        $appRoot = $global:AppRoot
        if (-not $appRoot) { $appRoot = $PWD.Path }
        $logDir = Join-Path $appRoot "Logs"
        $today = Get-Date -Format 'yyyy-MM-dd'
        $logFile = Join-Path $logDir "$today.log"

        if (-not (Test-Path $logFile)) { return '{"lines":[]}' }

        $content = @(Get-Content $logFile -Tail $Lines -ErrorAction SilentlyContinue)
        $content = @($content | Where-Object { $_ -ne $null })

        if ($content.Count -eq 0) { return '{"lines":[]}' }

        $linesArray = @()
        foreach ($l in $content) { $linesArray += [string]$l }

        $obj = @{ lines = $linesArray }
        return (ConvertTo-Json -InputObject $obj -Depth 5 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: СКРИНШОТ
# ============================================================================
function Invoke-HttpApiScreenshot {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $remotePath = "/sdcard/tvmanager_http_shot.png"
        & $global:AdbPath shell screencap -p $remotePath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return '{"error":"screencap_failed"}' }

        $folder = Join-Path ([Environment]::GetFolderPath("Desktop")) "screenshot_tv"
        if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $fileName = "TV_screenshot_$timestamp.png"
        $localPath = Join-Path $folder $fileName

        & $global:AdbPath pull $remotePath $localPath 2>&1 | Out-Null
        & $global:AdbPath shell rm $remotePath 2>&1 | Out-Null

        if (-not (Test-Path $localPath)) { return '{"error":"pull_failed"}' }

        return (@{ success = $true; file = $fileName; path = $localPath; size = (Get-Item $localPath).Length } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

function Invoke-HttpApiScreenshotBase64 {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $remotePath = "/sdcard/tvmanager_http_shot_b64.png"
        & $global:AdbPath shell screencap -p $remotePath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return '{"error":"screencap_failed"}' }

        $folder = Join-Path ([Environment]::GetFolderPath("Desktop")) "screenshot_tv"
        if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $fileName = "TV_screenshot_$timestamp.png"
        $localPath = Join-Path $folder $fileName

        & $global:AdbPath pull $remotePath $localPath 2>&1 | Out-Null
        & $global:AdbPath shell rm $remotePath 2>&1 | Out-Null

        if (-not (Test-Path $localPath)) { return '{"error":"pull_failed"}' }

        $bytes = [System.IO.File]::ReadAllBytes($localPath)
        $b64 = [Convert]::ToBase64String($bytes)

        return (@{ success = $true; file = $fileName; base64 = $b64 } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

function Invoke-HttpApiScreenshotList {
    try {
        $folder = Join-Path ([Environment]::GetFolderPath("Desktop")) "screenshot_tv"
        if (-not (Test-Path $folder)) { return '{"files":[]}' }

        $files = Get-ChildItem -Path $folder -File | Where-Object {
            $_.Extension -in @(".png", ".jpg", ".jpeg")
        } | Sort-Object LastWriteTime -Descending | Select-Object -First 30

        $list = @()
        foreach ($f in $files) {
            $list += [PSCustomObject]@{
                name = $f.Name
                size = $f.Length
                time = $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        return (@{ files = $list } | ConvertTo-Json -Depth 3 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ПРОФИЛИ
# ============================================================================
function Invoke-HttpApiDevices {
    try {
        $list = @()
        try {
            if (Get-Command Get-Profiles -ErrorAction SilentlyContinue) {
                $profiles = Get-Profiles
                foreach ($p in $profiles) {
                    $list += [PSCustomObject]@{ name = $p.Name; ip = $p.Ip }
                }
            }
        } catch { }
        return (@{ devices = $list } | ConvertTo-Json -Depth 3 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ПАКЕТЫ
# ============================================================================
function Invoke-HttpApiPackages {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $allRaw      = & $global:AdbPath shell pm list packages 2>&1
        $thirdRaw    = & $global:AdbPath shell pm list packages -3 2>&1
        $disabledRaw = & $global:AdbPath shell pm list packages -d 2>&1

        $thirdSet = @{}
        foreach ($line in ($thirdRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') { $thirdSet[$matches[1].Trim()] = $true }
        }

        $disabledSet = @{}
        foreach ($line in ($disabledRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') { $disabledSet[$matches[1].Trim()] = $true }
        }

        $apps = @()
        foreach ($line in ($allRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $pkg = $matches[1].Trim()
                $isSystem = (-not $thirdSet.ContainsKey($pkg))
                $isDisabled = $disabledSet.ContainsKey($pkg)

                $apps += [PSCustomObject]@{
                    package    = $pkg
                    apkPath    = ""
                    isSystem   = $isSystem
                    isDisabled = $isDisabled
                }
            }
        }

        return (@{ apps = $apps } | ConvertTo-Json -Depth 5 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ДЕЙСТВИЯ С ПАКЕТАМИ
# ============================================================================
function Invoke-HttpApiPackageAction {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json   = $RequestBody | ConvertFrom-Json
        $pkg    = $json.package
        $action = $json.action

        if (-not $pkg -or $pkg -notmatch '^[a-zA-Z][a-zA-Z0-9_\.]+$') {
            return '{"error":"invalid_package"}'
        }

        $allowed = @('disable','enable','remove','clear')
        if ($action -notin $allowed) {
            return '{"error":"invalid_action"}'
        }

        # =====================================================================
        #  ЗАЩИТА КРИТИЧЕСКИХ ПАКЕТОВ
        #  Список продублирован здесь, чтобы HTTP-Runspace был самодостаточным
        #  (не требует передачи Test-PackageOperation через functionDefs).
        # =====================================================================
        $blockedPackages = @(
            'android',
            'com.android.systemui',
            'com.android.settings',
            'com.android.shell',
            'com.android.providers.settings',
            'com.android.se',
            'com.google.android.gms',
            'com.google.android.gsf',
            'com.tcl.systemserver',
            'com.tcl.providers.config',
            'com.tcl.systemui.plugin',
            'com.tcl.globalkeyoverlay',
            'com.tcl.tvinput',
            'com.mediatek.network'
        )

        # warn-пакеты: разрешаем, но с явным флагом в ответе
        $warnPackages = @(
            'com.android.vending',
            'com.google.android.apps.tv.launcherx',
            'com.tcl.tv',
            'com.tcl.autopair',
            'com.tcl.android.webview',
            'com.tcl.initsetup',
            'com.mediatek.speakerservice',
            'com.mediatek.backgrounddetection',
            'com.mediatek.android.tv.mdns.offload',
            'com.mediatek.android.tv.mdns.offload.overlay',
            'com.mediatek.support.webview',
            'com.dolby.android.audio.service',
            'com.dolby.android.audio.calibration',
            'com.tcl.UpdatePeripheral',
            'com.snm.upgrade',
            'com.tcl.versionUpdateApp'
        )

        # Только для опасных операций (disable/remove/clear)
        if ($action -in @('disable','remove','clear')) {
            if ($pkg -in $blockedPackages) {
                return '{"success":false,"error":"protected","message":"Пакет защищён от изменения (критический для системы)"}'
            }
        }

        $isWarn = ($pkg -in $warnPackages)

        switch ($action) {
            'disable' {
                $out = & $global:AdbPath shell pm disable-user --user 0 $pkg 2>&1
                $outText = ($out | Out-String).Trim()
                $ok = ($outText -match 'new state: disabled' -or $outText -match 'disabled-user')
                $warning = if ($isWarn) { "Пакет отмечен как потенциально критичный" } else { "" }
                return (@{
                    success = $ok
                    action  = "disable"
                    package = $pkg
                    raw     = $outText
                    warning = $warning
                } | ConvertTo-Json -Compress)
            }
            'enable' {
                $out = & $global:AdbPath shell pm enable $pkg 2>&1
                $outText = ($out | Out-String).Trim()
                $ok = ($outText -match 'new state: enabled' -or $outText -match 'enabled')
                return (@{
                    success = $ok
                    action  = "enable"
                    package = $pkg
                    raw     = $outText
                } | ConvertTo-Json -Compress)
            }
            'remove' {
                $out = & $global:AdbPath shell pm uninstall --user 0 $pkg 2>&1
                $outText = ($out | Out-String).Trim()
                $ok = ($outText -match 'Success')
                $warning = if ($isWarn) { "Пакет отмечен как потенциально критичный" } else { "" }
                return (@{
                    success = $ok
                    action  = "remove"
                    package = $pkg
                    raw     = $outText
                    warning = $warning
                } | ConvertTo-Json -Compress)
            }
            'clear' {
                $out = & $global:AdbPath shell pm clear $pkg 2>&1
                $outText = ($out | Out-String).Trim()
                $ok = ($outText -match 'Success')
                return (@{
                    success = $ok
                    action  = "clear"
                    package = $pkg
                    raw     = $outText
                } | ConvertTo-Json -Compress)
            }
        }
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ПИТАНИЕ
# ============================================================================
function Invoke-HttpApiPowerAction {
    param([string]$Action)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        switch ($Action) {
            'reboot' {
                & $global:AdbPath shell reboot 2>&1 | Out-Null
                return '{"success":true,"action":"reboot"}'
            }
            'sleep' {
                $powerOut = & $global:AdbPath shell dumpsys power 2>&1
                $powerText = ($powerOut | Out-String)
                if ($powerText -match 'mWakefulness=Awake') {
                    & $global:AdbPath shell input keyevent 26 2>&1 | Out-Null
                }
                return '{"success":true,"action":"sleep"}'
            }
            'wakeup' {
                & $global:AdbPath shell input keyevent KEYCODE_WAKEUP 2>&1 | Out-Null
                return '{"success":true,"action":"wakeup"}'
            }
            'shutdown' {
                & $global:AdbPath shell reboot -p 2>&1 | Out-Null
                return '{"success":true,"action":"shutdown"}'
            }
            default {
                return '{"error":"unknown_action"}'
            }
        }
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ТЕКУЩАЯ АКТИВНОСТЬ
# ============================================================================
function Invoke-HttpApiCurrentActivity {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $out = & $global:AdbPath shell dumpsys activity activities 2>&1
        $outText = ($out | Out-String)

        $activity = ""
        if ($outText -match 'mResumedActivity.*?([a-z][a-z0-9_\.]+)/([A-Za-z0-9_\.]+)') {
            $activity = "$($matches[1])/$($matches[2])"
        }

        return (@{ activity = $activity } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ОКНА
# ============================================================================
function Invoke-HttpApiWindows {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $out = & $global:AdbPath shell ps -A -o PID,NAME 2>&1
        $outText = ($out | Out-String)

        $procs = @()
        foreach ($line in ($outText -split "`r?`n")) {
            $line = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match '^PID\s+NAME') { continue }

            if ($line -match '^(\d+)\s+(\S+)$') {
                $procPid  = $matches[1]     # ← НЕ $pid!
                $procName = $matches[2]

                if ($procName -match '^\[') { continue }
                if ($procName -notmatch '^[a-z][a-z0-9_\.]+$') { continue }
                if ($procName -notmatch '\.') { continue }

                $procs += [PSCustomObject]@{
                    pid     = $procPid
                    package = $procName
                }
            }
        }

        $uniq = @{}
        $result = @()
        foreach ($p in $procs) {
            if (-not $uniq.ContainsKey($p.package)) {
                $uniq[$p.package] = $true
                $result += $p
            }
        }

        $result = @($result | Sort-Object -Property package)

        return (@{ windows = $result } | ConvertTo-Json -Depth 3 -Compress)
    } catch {
        return '{"error":"internal","message":"' + ($_.ToString() -replace '"','\"') + '"}'
    }
}

function Invoke-HttpApiCloseApp {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $pkg  = $json.package

        if (-not $pkg -or $pkg -notmatch '^[a-zA-Z][a-zA-Z0-9_\.]+$') {
            return '{"error":"invalid_package"}'
        }

        & $global:AdbPath shell am force-stop $pkg 2>&1 | Out-Null
        return '{"success":true}'
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ФАЙЛЫ
# ============================================================================
function Invoke-HttpApiFilesList {
    param([string]$Path = "/sdcard/")
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        if (-not $Path.EndsWith("/")) { $Path = "$Path/" }

        $out = & $global:AdbPath shell ls -la `"$Path`" 2>&1
        $outText = ($out | Out-String)

        $files = @()
        foreach ($line in ($outText -split "`r?`n")) {
            if ($line -match '^([d\-l])([rwx\-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\S+\s+\S+)\s+(.+)$') {
                $type = $matches[1]
                $size = [int]$matches[3]
                $name = $matches[5].Trim()
                if ($name -eq "." -or $name -eq "..") { continue }

                $files += [PSCustomObject]@{
                    name     = $name
                    isDir    = ($type -eq "d")
                    size     = $size
                    fullPath = "$Path$name"
                }
            }
        }

        return (@{ path = $Path; files = $files } | ConvertTo-Json -Depth 5 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

function Invoke-HttpApiFileDownload {
    param([string]$Path)
    try {
        if (-not $global:Connected) { return $null }

        $tempFile = Join-Path $env:TEMP "tvmanager_dl_$(Get-Random).bin"
        & $global:AdbPath pull $Path $tempFile 2>&1 | Out-Null

        if (-not (Test-Path $tempFile)) { return $null }

        $bytes = [System.IO.File]::ReadAllBytes($tempFile)
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        return $bytes
    } catch {
        return $null
    }
}

function Invoke-HttpApiFileDelete {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $path = $json.path
        if (-not $path) { return '{"error":"missing_path"}' }

        & $global:AdbPath shell rm -rf `"$path`" 2>&1 | Out-Null
        return '{"success":true}'
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ПРЕСЕТЫ
# ============================================================================
function Invoke-HttpApiPresetsGet {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $presets = [ordered]@{}

        $out = & $global:AdbPath shell settings get system screen_off_timeout 2>&1
        $presets.screen_off_timeout = ($out | Out-String).Trim()

        $out = & $global:AdbPath shell settings get global window_animation_scale 2>&1
        $presets.window_animation_scale = ($out | Out-String).Trim()

        $out = & $global:AdbPath shell settings get global transition_animation_scale 2>&1
        $presets.transition_animation_scale = ($out | Out-String).Trim()

        $out = & $global:AdbPath shell settings get global animator_duration_scale 2>&1
        $presets.animator_duration_scale = ($out | Out-String).Trim()

        $out = & $global:AdbPath shell settings get global policy_control 2>&1
        $presets.policy_control = ($out | Out-String).Trim()

        $out = & $global:AdbPath shell pm list packages 2>&1
        $outText = ($out | Out-String)
        $presets.ota_packages = @()
        foreach ($pkg in @('com.tcl.UpdatePeripheral','com.tcl.versionUpdateApp','com.snm.upgrade')) {
            if ($outText -match [regex]::Escape($pkg)) {
                $presets.ota_packages += $pkg
            }
        }

        return ($presets | ConvertTo-Json -Depth 3 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

function Invoke-HttpApiPresetApply {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $preset = $json.preset
        if (-not $preset) { return '{"error":"missing_preset"}' }

        $results = @()

        switch ($preset) {
            'screen_5min'    { & $global:AdbPath shell settings put system screen_off_timeout 300000   2>&1 | Out-Null; $results += "5 минут" }
            'screen_15min'   { & $global:AdbPath shell settings put system screen_off_timeout 900000   2>&1 | Out-Null; $results += "15 минут" }
            'screen_30min'   { & $global:AdbPath shell settings put system screen_off_timeout 1800000  2>&1 | Out-Null; $results += "30 минут" }
            'screen_1hour'   { & $global:AdbPath shell settings put system screen_off_timeout 3600000  2>&1 | Out-Null; $results += "1 час" }
            'screen_never'   { & $global:AdbPath shell settings put system screen_off_timeout 2147483647 2>&1 | Out-Null; $results += "никогда" }

            'anim_1x' {
                & $global:AdbPath shell settings put global window_animation_scale 1.0 2>&1 | Out-Null
                & $global:AdbPath shell settings put global transition_animation_scale 1.0 2>&1 | Out-Null
                & $global:AdbPath shell settings put global animator_duration_scale 1.0 2>&1 | Out-Null
                $results += "1x"
            }
            'anim_05x' {
                & $global:AdbPath shell settings put global window_animation_scale 0.5 2>&1 | Out-Null
                & $global:AdbPath shell settings put global transition_animation_scale 0.5 2>&1 | Out-Null
                & $global:AdbPath shell settings put global animator_duration_scale 0.5 2>&1 | Out-Null
                $results += "0.5x"
            }
            'anim_0x' {
                & $global:AdbPath shell settings put global window_animation_scale 0.0 2>&1 | Out-Null
                & $global:AdbPath shell settings put global transition_animation_scale 0.0 2>&1 | Out-Null
                & $global:AdbPath shell settings put global animator_duration_scale 0.0 2>&1 | Out-Null
                $results += "0x"
            }

            'ota_disable' {
                foreach ($pkg in @('com.tcl.UpdatePeripheral','com.tcl.versionUpdateApp','com.snm.upgrade')) {
                    & $global:AdbPath shell pm disable-user --user 0 $pkg 2>&1 | Out-Null
                }
                $results += "OTA отключено"
            }
            'ota_enable' {
                foreach ($pkg in @('com.tcl.UpdatePeripheral','com.tcl.versionUpdateApp','com.snm.upgrade')) {
                    & $global:AdbPath shell pm enable $pkg 2>&1 | Out-Null
                }
                $results += "OTA включено"
            }

            default {
                return '{"error":"unknown_preset","preset":"' + $preset + '"}'
            }
        }

        return (@{ success = $true; preset = $preset; applied = $results } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal","message":"' + ($_.ToString() -replace '"','\"') + '"}'
    }
}

# ============================================================================
#  API: УСТАНОВКА APK
# ============================================================================
function Invoke-HttpApiApkUpload {
    param(
        [byte[]]$Body,
        [string]$FileName
    )
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }
        if (-not $Body -or $Body.Length -eq 0) { return '{"error":"empty_body"}' }

        if (-not $FileName) { $FileName = "upload.apk" }
        $FileName = $FileName -replace '[^\w\.\-]', '_'
        if ($FileName -notmatch '\.(apk|apks|xapk|apkm)$') {
            $FileName = "$FileName.apk"
        }

        $tempDir = Join-Path $env:TEMP "TVManager_ApkUpload_$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $localPath = Join-Path $tempDir $FileName

        [System.IO.File]::WriteAllBytes($localPath, $Body)

        $ext = [System.IO.Path]::GetExtension($localPath).ToLower()
        $isBundle = ($ext -in @(".apks", ".xapk", ".apkm"))

        if ($isBundle) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $extractDir = Join-Path $tempDir "extracted"
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

            try {
                [System.IO.Compression.ZipFile]::ExtractToDirectory($localPath, $extractDir)

                $allApks = Get-ChildItem -Path $extractDir -Filter "*.apk" -File -Recurse | Select-Object -ExpandProperty FullName
                if (-not $allApks -or $allApks.Count -eq 0) {
                    return '{"error":"no_apks_in_bundle"}'
                }

                $baseApk = $allApks | Where-Object { $_ -match '\\base\.apk$' } | Select-Object -First 1
                if (-not $baseApk) {
                    $baseApk = $allApks | Where-Object { (Split-Path $_ -Leaf) -notmatch '^split' } | Select-Object -First 1
                }
                $splits = $allApks | Where-Object { $_ -ne $baseApk }
                $apkList = @($baseApk) + @($splits)

                $adbArgs = @("install-multiple", "-r", "-g", "-d") + $apkList
                $out = & $global:AdbPath @adbArgs 2>&1
                $outText = ($out | Out-String).Trim()
            } finally {
                try { Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
            }
        } else {
            $out = & $global:AdbPath install -r -g -d $localPath 2>&1
            $outText = ($out | Out-String).Trim()
        }

        try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }

        $isSuccess = ($outText -match "Success")

        return (@{
            success  = $isSuccess
            filename = $FileName
            size     = $Body.Length
            output   = $outText
        } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal","message":"' + ($_.ToString() -replace '"','\"') + '"}'
    }
}

# ============================================================================
#  API: МЕТРИКИ
# ============================================================================
function Invoke-HttpApiMetrics {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $result = [ordered]@{
            cpu    = [ordered]@{ usage = 0; maxFreq = ""; curFreq = ""; cores = 0 }
            ram    = [ordered]@{ total = 0; free = 0; available = 0; usedPct = 0 }
            storage = [ordered]@{ total = 0; used = 0; free = 0; usedPct = 0 }
            uptime = ""
            loadAvg = ""
            temperature = -1
        }

        # ===== CPU usage =====
        $cpuOut = & $global:AdbPath shell top -n 1 -b 2>&1
        $cpuText = ($cpuOut | Out-String)

        # Основной формат Android TV: "400%cpu 129%user 0%nice 23%sys ..."
        if ($cpuText -match '(\d+)%cpu\s+([\d\.]+)%user\s+([\d\.]+)%nice\s+([\d\.]+)%sys') {
            $totalCpuPercent = [int]$matches[1]
            $userCpu = [double]$matches[2]
            $sysCpu  = [double]$matches[4]
            $cores = [int]($totalCpuPercent / 100)
            if ($cores -lt 1) { $cores = 1 }
            $usage = ($userCpu + $sysCpu) / $cores
            $result.cpu.usage = [math]::Round($usage, 1)
            $result.cpu.cores = $cores
        }
        # Формат: "CPU: 15% user, 30% sys"
        elseif ($cpuText -match 'CPU:\s*(\d+)%\s*user,\s*(\d+)%\s*sys') {
            $result.cpu.usage = [int]$matches[1] + [int]$matches[2]
        }
        # Fallback: сумма CPU% всех процессов
        else {
            $sumCpu = 0
            foreach ($line in ($cpuText -split "`r?`n")) {
                if ($line -match '^\s*\d+\s+\S+\s+\d+\s+\d+\s+\S+\s+\S+\s+\S+\s+\S\s+([\d\.]+)') {
                    $sumCpu += [double]$matches[1]
                }
            }
            if ($sumCpu -gt 0) {
                $coresOut = & $global:AdbPath shell nproc 2>&1
                $coresText = ($coresOut | Out-String).Trim()
                $cores = 4
                if ($coresText -match '^\d+$') { $cores = [int]$coresText }
                if ($cores -lt 1) { $cores = 1 }
                $result.cpu.usage = [math]::Round($sumCpu / $cores, 1)
                if ($result.cpu.usage -gt 100) { $result.cpu.usage = 100 }
                $result.cpu.cores = $cores
            }
        }

        # Частоты CPU
        $maxFreqOut = & $global:AdbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>&1
        $maxFreqText = ($maxFreqOut | Out-String).Trim()
        if ($maxFreqText -match '^\d+$') {
            $result.cpu.maxFreq = "$([math]::Round([int]$maxFreqText / 1000)) МГц"
        }

        $curFreqOut = & $global:AdbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>&1
        $curFreqText = ($curFreqOut | Out-String).Trim()
        if ($curFreqText -match '^\d+$') {
            $result.cpu.curFreq = "$([math]::Round([int]$curFreqText / 1000)) МГц"
        }

        # ===== RAM =====
        $memOut = & $global:AdbPath shell cat /proc/meminfo 2>&1
        $memText = ($memOut | Out-String)
        if ($memText -match 'MemTotal:\s+(\d+)\s+kB')     { $result.ram.total     = [int64]$matches[1] * 1024 }
        if ($memText -match 'MemFree:\s+(\d+)\s+kB')      { $result.ram.free      = [int64]$matches[1] * 1024 }
        if ($memText -match 'MemAvailable:\s+(\d+)\s+kB') { $result.ram.available = [int64]$matches[1] * 1024 }

        if ($result.ram.total -gt 0) {
            $used = $result.ram.total - $result.ram.available
            $result.ram.usedPct = [math]::Round($used / $result.ram.total * 100, 1)
        }

        # ===== Storage =====
        $dfOut = & $global:AdbPath shell df /data 2>&1
        $dfText = ($dfOut | Out-String)
        foreach ($line in ($dfText -split "`r?`n")) {
            if ($line -match '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%') {
                $total = [int64]$matches[1] * 1024
                $used  = [int64]$matches[2] * 1024
                $free  = [int64]$matches[3] * 1024
                $pct   = [int]$matches[4]

                $result.storage.total = $total
                $result.storage.used  = $used
                $result.storage.free  = $free
                $result.storage.usedPct = $pct
                break
            }
        }

        # ===== Uptime =====
        $uptimeOut = & $global:AdbPath shell cat /proc/uptime 2>&1
        $uptimeText = ($uptimeOut | Out-String).Trim()
        if ($uptimeText -match '^([\d\.]+)') {
            $sec = [math]::Round([double]$matches[1])
            $h = [math]::Floor($sec / 3600)
            $m = [math]::Floor(($sec % 3600) / 60)
            $result.uptime = "$h ч $m мин"
        }

        # ===== Load avg =====
        $loadOut = & $global:AdbPath shell cat /proc/loadavg 2>&1
        $loadText = ($loadOut | Out-String).Trim()
        if ($loadText -match '^([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)') {
            $result.loadAvg = "$($matches[1]) / $($matches[2]) / $($matches[3])"
        }

        # ===== Temperature =====
        $tempOut = & $global:AdbPath shell ls /sys/class/thermal/ 2>&1
        $tempText = ($tempOut | Out-String)
        foreach ($zone in ($tempText -split "`r?`n")) {
            if ($zone -match 'thermal_zone(\d+)') {
                $zoneName = "thermal_zone$($matches[1])"
                $typeOut = & $global:AdbPath shell cat "/sys/class/thermal/$zoneName/type" 2>&1
                $typeText = ($typeOut | Out-String).Trim()
                if ($typeText -match 'cpu|soc|ap|big') {
                    $tOut = & $global:AdbPath shell cat "/sys/class/thermal/$zoneName/temp" 2>&1
                    $tText = ($tOut | Out-String).Trim()
                    if ($tText -match '^-?\d+$') {
                        $result.temperature = [math]::Round([int]$tText / 1000.0, 1)
                        break
                    }
                }
            }
        }

        return ($result | ConvertTo-Json -Depth 5 -Compress)
    } catch {
        return '{"error":"internal","message":"' + ($_.ToString() -replace '"','\"') + '"}'
    }
}

function Invoke-HttpApiMetricsTop {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $out = & $global:AdbPath shell top -n 1 -b -o %CPU,RES,CMDLINE 2>&1
        $outText = ($out | Out-String)

        $procs = @()
        $startLine = 0
        $lines = $outText -split "`r?`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'RES\s*\[?CMDLINE') {
                $startLine = $i + 1
                break
            }
        }

        for ($i = $startLine; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            if ($line -match '^\s*([\d\.]+)\s+(\d+)([KMG])\s+(.+)$') {
                $cpu = [double]$matches[1]
                $memVal = [int]$matches[2]
                $memUnit = $matches[3]
                $name = $matches[4].Trim()

                if ($name -match '^top\s' -or $name -eq "top") { continue }

                $memKb = $memVal
                switch ($memUnit) {
                    "M" { $memKb = $memVal * 1024 }
                    "G" { $memKb = $memVal * 1024 * 1024 }
                }

                $procs += [PSCustomObject]@{
                    cpu = [math]::Round($cpu, 1)
                    memMb = [math]::Round($memKb / 1024, 1)
                    name = $name
                }
            }
        }

        $procs = @($procs | Sort-Object -Property cpu -Descending | Select-Object -First 15)

        return (@{ procs = $procs } | ConvertTo-Json -Depth 3 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: BLUETOOTH
# ============================================================================
function Invoke-HttpApiBluetoothGet {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $result = [ordered]@{
            enabled = $false
            name    = ""
            address = ""
            bonded  = @()
        }

        $dump = & $global:AdbPath shell dumpsys bluetooth_manager 2>&1
        $dumpText = ($dump | Out-String)

        if ($dumpText -match 'enabled:\s*(true|false)') {
            $result.enabled = ($matches[1] -eq "true")
        }

        if ($dumpText -match 'name:\s*([^\r\n]+)') {
            $result.name = $matches[1].Trim()
        }

        if ($dumpText -match 'address:\s*([0-9A-Fa-f:]{17})') {
            $addrVal = $matches[1]
            if ($addrVal -ne "00:00:00:00:00:00") {
                $result.address = $addrVal
            }
        }

        $bondedSection = ""
        if ($dumpText -match '(?s)Bonded devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:|$)') {
            $bondedSection = $matches[1]
        }

        if ($bondedSection) {
            foreach ($line in ($bondedSection -split "`r?`n")) {
                if ($line -match '([0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5})') {
                    $mac = $matches[1]
                    $name = "—"
                    $rest = $line.Substring($line.IndexOf($mac) + $mac.Length).Trim()
                    $rest = $rest -replace '\s*\[[^\]]*\]', ''
                    $rest = $rest.Trim()
                    if ($rest) { $name = $rest }

                    $result.bonded += [PSCustomObject]@{
                        mac       = $mac
                        name      = $name
                        connected = ($line -match '^\s*\*')
                    }
                }
            }
        }

        return ($result | ConvertTo-Json -Depth 5 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

function Invoke-HttpApiBluetoothEnable {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }
        & $global:AdbPath shell svc bluetooth enable 2>&1 | Out-Null
        return '{"success":true}'
    } catch {
        return '{"error":"internal"}'
    }
}

function Invoke-HttpApiBluetoothDisable {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }
        & $global:AdbPath shell svc bluetooth disable 2>&1 | Out-Null
        return '{"success":true}'
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: WI-FI
# ============================================================================
function Invoke-HttpApiWifiGet {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $result = [ordered]@{
            enabled   = $false
            ssid      = ""
            bssid     = ""
            ip        = ""
            mac       = ""
            gateway   = ""
            signal    = -1
            frequency = ""
            linkSpeed = ""
        }

        $ipOut = & $global:AdbPath shell ip addr show wlan0 2>&1
        $ipText = ($ipOut | Out-String)
        if ($ipText -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
            $result.ip = $matches[1]
            $result.enabled = $true
        }
        if ($ipText -match 'link/ether\s+([0-9a-fA-F:]{17})') {
            $result.mac = $matches[1]
        }

        $dump = & $global:AdbPath shell dumpsys wifi 2>&1
        $dumpText = ($dump | Out-String)

        if ($dumpText -match 'SSID:\s*"([^"]+)"') {
            $result.ssid = $matches[1]
        }
        if ($dumpText -match 'BSSID:\s*([0-9a-fA-F:]{17})') {
            $result.bssid = $matches[1]
        }
        if ($dumpText -match 'Frequency:\s*(\d+)') {
            $result.frequency = "$($matches[1]) МГц"
        }
        if ($dumpText -match 'Link speed:\s*(\d+)\s*Mbps') {
            $result.linkSpeed = "$($matches[1]) Мбит/с"
        }
        if ($dumpText -match 'RSSI:\s*(-?\d+)') {
            $result.signal = [int]$matches[1]
        }

        $routeOut = & $global:AdbPath shell ip route 2>&1
        $routeText = ($routeOut | Out-String)
        if ($routeText -match 'default via (\d+\.\d+\.\d+\.\d+)') {
            $result.gateway = $matches[1]
        }

        return ($result | ConvertTo-Json -Depth 5 -Compress)
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  API: ТАЙМЕРЫ
# ============================================================================
function Invoke-HttpApiTimerSet {
    param([string]$RequestBody)
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        $json = $RequestBody | ConvertFrom-Json
        $minutes = [int]$json.minutes
        if ($minutes -lt 1)   { $minutes = 1 }
        if ($minutes -gt 240) { $minutes = 240 }

        $seconds = $minutes * 60

        & $global:AdbPath shell "pkill -f 'sleep.*keyevent' 2>/dev/null" 2>&1 | Out-Null

        $cmd = "nohup sh -c 'sleep $seconds; input keyevent 26' > /dev/null 2>&1 &"
        & $global:AdbPath shell $cmd 2>&1 | Out-Null

        return (@{ success = $true; minutes = $minutes; seconds = $seconds } | ConvertTo-Json -Compress)
    } catch {
        return '{"error":"internal","message":"' + ($_.ToString() -replace '"','\"') + '"}'
    }
}

function Invoke-HttpApiTimerCancel {
    try {
        if (-not $global:Connected) { return '{"error":"not_connected"}' }

        & $global:AdbPath shell "pkill -f 'sleep.*keyevent' 2>/dev/null" 2>&1 | Out-Null

        return '{"success":true}'
    } catch {
        return '{"error":"internal"}'
    }
}

# ============================================================================
#  HTML (читаем из файла)
# ============================================================================
function Get-HttpIndexHtml {
    $htmlFile = Join-Path $script:AppRoot "Modules\http_mobile.html"
    if (Test-Path $htmlFile) {
        return [System.IO.File]::ReadAllText($htmlFile, [System.Text.UTF8Encoding]::new($false))
    }
    return "<html><body style='background:#181818;color:#fff;font-family:sans-serif;padding:20px;'>HTML-файл не найден: $htmlFile</body></html>"
}