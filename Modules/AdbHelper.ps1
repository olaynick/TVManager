# ===== БАЗОВЫЕ КОМАНДЫ ADB =====
function Invoke-Adb {
    param(
        [string]$Command,
        [switch]$Silent
    )
    # Передаём команду через cmd /c, чтобы корректно работали кавычки и пробелы
    $fullCmd = "`"$script:adbPath`" $Command"
    $result = cmd /c $fullCmd 2>&1
    if (-not $Silent) {
        foreach ($line in $result) { Write-Log -Message "$line" -Level "Info" }
    }
    return $result
}

# ===== ПОДКЛЮЧЕНИЕ К УСТРОЙСТВУ =====
function Connect-AdbDevice {
    param(
        [string]$Ip,
        [int]$TimeoutSeconds = 20
    )

    if ([string]::IsNullOrWhiteSpace($Ip)) {
        return @{ Success = $false; Message = "IP не указан" }
    }

    # Убираем возможный :5555 в конце, чтобы не было "ip:5555:5555"
    $Ip = $Ip.Trim() -replace ':5555$', ''

    Write-Log -Message "=== Подключение к $Ip ===" -Level "Info"

    Write-Log -Message "Отключаю старые ADB-соединения..." -Level "Info"
    & $script:adbPath disconnect 2>&1 | Out-Null
    Start-Sleep -Milliseconds 300

    Write-Log -Message "Выполняю: adb connect $Ip`:5555" -Level "Info"
    $connectOut = & $script:adbPath connect "$Ip`:5555" 2>&1
    $connectText = ($connectOut | Out-String).Trim()
    Write-Log -Message "Ответ ADB: $connectText" -Level "Info"

    # --- retry-loop: ждём, пока устройство перейдёт в состояние device ---
    $startTime = Get-Date
    $lastState = ""
    $attempt   = 0

    while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        $attempt++
        Start-Sleep -Milliseconds 700

        $devices = & $script:adbPath devices 2>&1
        $ourLine = $devices | Where-Object { $_ -match [regex]::Escape($Ip) } | Select-Object -First 1

        if (-not $ourLine) {
            $lastState = "not-found"
            continue
        }

        if ($ourLine -match "`tdevice$") {
            # Устройство в списке. Проверим реальный отклик.
            $stateOut = & $script:adbPath -s "$Ip`:5555" get-state 2>&1
            $stateText = ($stateOut | Out-String).Trim()

            if ($stateText -eq "device") {
                $script:connected = $true
                $script:deviceIp  = $Ip
                Write-Log -Message "Устройство авторизовано и отвечает (попытка $attempt)." -Level "Success"
                return @{ Success = $true; Message = "Подключено" }
            }

            $lastState = "device-but-no-response"
            continue
        }

        if ($ourLine -match "`tunauthorized") {
            if ($lastState -ne "unauthorized") {
                Write-Log -Message "Требуется подтверждение на экране ТВ. Жду..." -Level "Warning"
                $lastState = "unauthorized"
            }
            continue
        }

        if ($ourLine -match "`toffline") {
            if ($lastState -ne "offline") {
                Write-Log -Message "Устройство offline. Переподключаюсь..." -Level "Warning"
                $lastState = "offline"
            }
            & $script:adbPath disconnect "$Ip`:5555" 2>&1 | Out-Null
            Start-Sleep -Milliseconds 300
            & $script:adbPath connect "$Ip`:5555" 2>&1 | Out-Null
            continue
        }

        $lastState = $ourLine
    }

    # --- Таймаут: разбираемся, почему ---
    $script:connected = $false

    switch ($lastState) {
        "unauthorized" {
            Write-Log -Message "Таймаут: разрешение на ТВ не выдано." -Level "Error"
            return @{ Success = $false; Message = "Разрешите отладку по ADB на экране телевизора и попробуйте снова" }
        }
        "offline" {
            Write-Log -Message "Таймаут: устройство остаётся offline." -Level "Error"
            return @{ Success = $false; Message = "Устройство offline. Попробуйте выключить и включить отладку по ADB на ТВ" }
        }
        "device-but-no-response" {
            Write-Log -Message "Таймаут: устройство в списке, но не отвечает." -Level "Error"
            return @{ Success = $false; Message = "Устройство не отвечает на команды. Перезапустите ADB-сервер" }
        }
        "not-found" {
            Write-Log -Message "Таймаут: устройство не появилось в списке." -Level "Error"
            return @{ Success = $false; Message = "Не удалось подключиться. Проверьте IP и что отладка по сети включена" }
        }
        default {
            Write-Log -Message "Таймаут: неизвестное состояние ($lastState)." -Level "Error"
            return @{ Success = $false; Message = "Не удалось подключиться: $lastState" }
        }
    }
}

# ===== СПИСОК УСТРОЙСТВ =====
function Get-AdbDevices {
    return & $script:adbPath devices 2>&1
}

# ===== УДАЛЕНИЕ ПАКЕТА =====
function Remove-Package {
    param([string]$Package)
    Write-Log -Message "Удаляю: $Package" -Level "Info"
    $out = & $script:adbPath shell pm uninstall --user 0 $Package 2>&1

    if ($out -match "Success") {
        Write-Log -Message "Удалён: $Package" -Level "Success"
        return $true
    } elseif ($out -match "not installed for 0") {
        Write-Log -Message "Пропущен: $Package — не установлен на устройстве" -Level "Warning"
        return $false
    } elseif ($out -match "DELETE_FAILED") {
        Write-Log -Message "Защищён системой: $Package (можно только отключить)" -Level "Warning"
        return $false
    } else {
        Write-Log -Message "Не удалось удалить: $Package — $out" -Level "Warning"
        return $false
    }
}

# ===== ОТКЛЮЧЕНИЕ ПАКЕТА =====
function Disable-Package {
    param([string]$Package)
    Write-Log -Message "Отключаю: $Package" -Level "Info"
    $out = & $script:adbPath shell pm disable-user --user 0 $Package 2>&1
    if ($out -match "new state: disabled") {
        Write-Log -Message "OK: $Package" -Level "Success"
        return $true
    } else {
        Write-Log -Message "Не найден или уже отключён: $Package" -Level "Warning"
        return $false
    }
}

# ===== ВКЛЮЧЕНИЕ ПАКЕТА =====
function Enable-Package {
    param([string]$Package)
    Write-Log -Message "Включаю: $Package" -Level "Info"
    $out = & $script:adbPath shell pm enable $Package 2>&1
    if ($out -match "new state: enabled") {
        Write-Log -Message "OK: $Package" -Level "Success"
        return $true
    } else {
        Write-Log -Message "Не удалось включить: $Package" -Level "Warning"
        return $false
    }
}

# ===== УСТАНОВКА APK =====
function Install-Apk {
    param([string]$Path)
    $name = Split-Path $Path -Leaf
    Write-Log -Message "Установка: $name" -Level "Info"
    $out = & $script:adbPath install -r -g $Path 2>&1
    if ($out -match "Success") {
        Write-Log -Message "OK: $name" -Level "Success"
        return @{ Success = $true; Output = $out }
    } else {
        Write-Log -Message "FAIL: $name — $out" -Level "Error"
        return @{ Success = $false; Output = $out }
    }
}

# ===== ПОЛУЧЕНИЕ СПИСКА ПАКЕТОВ =====
function Get-InstalledPackages {
    return & $script:adbPath shell pm list packages 2>&1 | ForEach-Object { $_ -replace '^package:', '' }
}

# ===== НАЗНАЧЕНИЕ ЛАУНЧЕРА =====
function Set-HomeLauncher {
    param([string]$Activity)
    Write-Log -Message "Назначаю лаунчер: $Activity" -Level "Info"
    $out = & $script:adbPath shell cmd package set-home-activity $Activity 2>&1
    if ($out -match "Success") {
        Write-Log -Message "OK" -Level "Success"
        return $true
    } else {
        Write-Log -Message "Ошибка: $out" -Level "Error"
        return $false
    }
}

# ===== ФАЙЛОВЫЕ ОПЕРАЦИИ =====

# ===== ФАЙЛОВЫЕ ОПЕРАЦИИ =====

function Get-RemoteFiles {
    param([string]$Path = "/sdcard/")

    Write-Log -Message "Читаю содержимое: $Path" -Level "Info"

    # Нормализуем путь: всегда заканчивается на "/"
    if (-not $Path.EndsWith("/")) { $Path = "$Path/" }

    $files = @()

    # ===== Попытка 1: find -printf (точный формат, есть на новых Toybox/BusyBox) =====
    $cmd1 = "find `"$Path`" -maxdepth 1 -mindepth 1 -printf '%y|%s|%f\n' 2>/dev/null"
    $out1 = & $script:adbPath shell $cmd1 2>&1

    $parsed1 = @()
    foreach ($line in $out1) {
        if ($line -match '^([dflbcps])\|(\d+)\|(.+)$') {
            $parsed1 += [PSCustomObject]@{
                Name     = $matches[3]
                IsDir    = ($matches[1] -eq 'd')
                Size     = [int64]$matches[2]
                FullPath = "$Path$($matches[3])"
            }
        }
    }

    if ($parsed1.Count -gt 0) {
        Write-Log -Message "Найдено элементов: $($parsed1.Count) (find -printf)" -Level "Info"
        return ,$parsed1
    }

    # ===== Попытка 2: ls -la (fallback для старых прошивок) =====
    $out2 = & $script:adbPath shell "ls -la `"$Path`"" 2>&1
    foreach ($line in $out2) {
        # Формат: -rw-rw---- 1 root sdcard_rw 1234 2024-01-01 12:00 filename
        if ($line -match '^([d\-l])([rwx\-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\S+\s+\S+)\s+(.+)$') {
            $type = $matches[1]
            $size = [int]$matches[3]
            $name = $matches[5].Trim()
            if ($name -eq "." -or $name -eq "..") { continue }
            $files += [PSCustomObject]@{
                Name     = $name
                IsDir    = ($type -eq "d")
                Size     = $size
                FullPath = "$Path$name"
            }
        }
    }

    if ($files.Count -gt 0) {
        Write-Log -Message "Найдено элементов: $($files.Count) (ls -la)" -Level "Info"
    } else {
        Write-Log -Message "Папка пуста или недоступна: $Path" -Level "Warning"
    }

    return ,$files
}

function Pull-RemoteFile {
    param(
        [string]$RemotePath,
        [string]$LocalPath
    )
    Write-Log -Message "Скачиваю: $RemotePath → $LocalPath" -Level "Info"
    $out = & $script:adbPath pull $RemotePath $LocalPath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "OK: $RemotePath" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $RemotePath — $out" -Level "Error"
        return $false
    }
}

function Push-LocalFile {
    param(
        [string]$LocalPath,
        [string]$RemotePath
    )
    Write-Log -Message "Загружаю: $LocalPath → $RemotePath" -Level "Info"
    $out = & $script:adbPath push $LocalPath $RemotePath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "OK: $LocalPath" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $LocalPath — $out" -Level "Error"
        return $false
    }
}

function Remove-RemoteItem {
    param([string]$Path)
    Write-Log -Message "Удаляю: $Path" -Level "Info"
    $out = & $script:adbPath shell "rm -rf `"$Path`"" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "OK: $Path" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $Path — $out" -Level "Error"
        return $false
    }
}

function New-RemoteFolder {
    param([string]$Path)
    Write-Log -Message "Создаю папку: $Path" -Level "Info"
    $out = & $script:adbPath shell "mkdir -p `"$Path`"" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "OK: $Path" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $Path — $out" -Level "Error"
        return $false
    }
}

# ===== ЭМУЛЯЦИЯ ПУЛЬТА =====
function Send-KeyEvent {
    param(
        [string]$KeyCode,
        [string]$Description = ""
    )
    if ($Description) {
        Write-Log -Message "Пульт: $Description ($KeyCode)" -Level "Info"
    } else {
        Write-Log -Message "Пульт: $KeyCode" -Level "Info"
    }
    $out = & $script:adbPath shell input keyevent $KeyCode 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "OK" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $out" -Level "Error"
        return $false
    }
}

function Send-Text {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }

    Write-Log -Message "Ввод текста: $Text" -Level "Info"

    # ===== АНАЛИЗ ТЕКСТА =====
    $hasCyrillic = ($Text -match '[А-Яа-яЁё]')
    $hasNonAscii = ($Text -match '[^\x00-\x7F]')

    # ===== ЛАТИНИЦА — используем input text (самый надёжный способ) =====
    if (-not $hasNonAscii) {
        Write-Log -Message "Текст только из латиницы/цифр. Использую input text." -Level "Info"

        # Экранируем пробелы (%s) — input text не принимает их напрямую
        $escaped = $Text -replace ' ', '%s'
        # Убираем символы, которые поломают input text
        $escaped = $escaped -replace '[^\w%s\-\.@]', ''

        try {
            & $script:adbPath shell input text $escaped 2>&1 | Out-Null
            Write-Log -Message "Текст отправлен (input text)" -Level "Success"
            return $true
        } catch {
            Write-Log -Message "Ошибка input text: $_" -Level "Error"
            return $false
        }
    }

    # ===== КИРИЛЛИЦА / ЭМОДЗИ / СПЕЦСИМВОЛЫ — пробуем через ADBKeyboard =====
    Write-Log -Message "Текст содержит кириллицу или спецсимволы. Пробую через ADBKeyboard." -Level "Info"

    $hasAdbKb = Test-AdbKeyboardInstalled

    if (-not $hasAdbKb) {
        Write-Log -Message "ADBKeyboard не установлен. Отправляю только ASCII-часть через input text." -Level "Warning"

        # Отправляем только латиницу+цифры
        $asciiOnly = ($Text -replace '[^\w\s\.\-@]', '')
        if ($asciiOnly) {
            $escaped = $asciiOnly -replace ' ', '%s'
            & $script:adbPath shell input text $escaped 2>&1 | Out-Null
            Write-Log -Message "Отправлена только ASCII-часть: $asciiOnly" -Level "Warning"
        }
        Write-Log -Message "Для ввода кириллицы установите ADBKeyboard (кнопка «Открыть APK ADB Keyboard» на экране Пулт)." -Level "Warning"
        return $false
    }

    # ===== ADBKeyboard установлен — переключаем IME и отправляем =====
    $adbkIme = "com.android.adbkeyboard/.AdbIME"
    $prevIme = ""

    try {
        $prevIme = (& $script:adbPath shell settings get secure default_input_method 2>&1 | Out-String).Trim()
    } catch { }

    $isAdbKbActive = ($prevIme -match [regex]::Escape($adbkIme))
    $needSwitch = -not $isAdbKbActive

    if ($needSwitch) {
        Write-Log -Message "Переключаю IME на ADBKeyboard..." -Level "Info"
        try {
            & $script:adbPath shell ime set $adbkIme 2>&1 | Out-Null
            Start-Sleep -Milliseconds 600
        } catch {
            Write-Log -Message "Не удалось переключить IME: $_" -Level "Warning"
        }
    }

    # --- Отправка через broadcast base64 (полная поддержка Unicode) ---
    $sent = $false
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $b64 = [Convert]::ToBase64String($bytes)

        $out = & $script:adbPath shell am broadcast -a ADB_INPUT_B64 --es msg $b64 2>&1
        $outText = ($out | Out-String).Trim()

        if ($outText -match 'Broadcast completed: result=0') {
            $sent = $true
            Write-Log -Message "Broadcast отправлен" -Level "Info"
        } else {
            Write-Log -Message "Ответ broadcast: $outText" -Level "Warning"
        }
    } catch {
        Write-Log -Message "Ошибка broadcast: $_" -Level "Error"
    }

    # --- Даём время ADBKeyboard вставить текст ---
    if ($sent) {
        Start-Sleep -Milliseconds 800
    }

    # --- Возвращаем прежнюю IME ---
    if ($needSwitch -and $prevIme -and $prevIme -notmatch [regex]::Escape($adbkIme)) {
        Write-Log -Message "Возвращаю прежнюю IME: $prevIme" -Level "Info"
        try {
            & $script:adbPath shell ime set $prevIme 2>&1 | Out-Null
        } catch { }
    }

    # ===== ПРЕДУПРЕЖДЕНИЕ ПОЛЬЗОВАТЕЛЮ =====
    if ($sent) {
        Write-Log -Message "Текст отправлен через ADBKeyboard." -Level "Success"
        Write-Log -Message "ВАЖНО: если текст не появился на ТВ — на этой прошивке ADBKeyboard не работает." -Level "Warning"
        Write-Log -Message "На некоторых TCL ввод через ADBKeyboard блокируется системой. Используйте латиницу или пульт." -Level "Warning"
        return $true
    } else {
        Write-Log -Message "ADBKeyboard не подтвердил приём." -Level "Error"
        return $false
    }
}

function Send-MenuKey {
    Write-Log -Message "Пульт: Меню (перебор вариантов)" -Level "Info"

    # Список кодов для перебора
    $codes = @(
        @{ Code = "KEYCODE_TV_CONTENTS_MENU"; Name = "Контекстное меню ТВ" },
        @{ Code = "KEYCODE_SETTINGS";         Name = "Настройки" },
        @{ Code = "KEYCODE_TV_MEDIA_CONTEXT_MENU"; Name = "Медиа-меню" },
        @{ Code = "KEYCODE_SEARCH";           Name = "Поиск" },
        @{ Code = "KEYCODE_MENU";             Name = "Стандартное меню" }
    )

    foreach ($item in $codes) {
        Write-Log -Message "  Пробую: $($item.Name) ($($item.Code))" -Level "Info"
        $out = & $script:adbPath shell input keyevent $item.Code 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "  Отправлен: $($item.Code)" -Level "Success"
        } else {
            Write-Log -Message "  Ошибка: $($item.Code) — $out" -Level "Warning"
        }
        Start-Sleep -Milliseconds 300
    }

    Write-Log -Message "Перебор завершён. Один из кодов должен был открыть меню." -Level "Success"
    return $true
}

# ===== ПАПКА ДЛЯ СКРИНШОТОВ =====
function Get-ScreenshotFolder {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $folder = Join-Path $desktop "screenshot_tv"
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    return $folder
}

# ===== СКРИНШОТ =====
function Take-Screenshot {
    param([string]$LocalPath)

    Write-Log -Message "=== Снятие скриншота ===" -Level "Info"

    $remotePath = "/sdcard/tvmanager_screenshot.png"
    Write-Log -Message "Временный файл на ТВ: $remotePath" -Level "Info"

    Write-Log -Message "Делаю снимок экрана..." -Level "Info"
    $out = & $script:adbPath shell screencap -p $remotePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message "Ошибка screencap: $out" -Level "Error"
        return $false
    }
    Write-Log -Message "OK: снимок создан на ТВ" -Level "Success"

    # Проверяем, создан ли файл
    $checkOut = & $script:adbPath shell ls -la $remotePath 2>&1
    Write-Log -Message "Файл на ТВ: $checkOut" -Level "Info"

    Write-Log -Message "Локальный путь: $LocalPath" -Level "Info"
    Write-Log -Message "Скачиваю на ПК..." -Level "Info"
    $out = & $script:adbPath pull $remotePath $LocalPath 2>&1
    Write-Log -Message "Ответ pull: $out" -Level "Info"

    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message "Ошибка pull: $out" -Level "Error"
        return $false
    }
    Write-Log -Message "OK: скачано" -Level "Success"

    Write-Log -Message "Удаляю временный файл с ТВ: $remotePath" -Level "Info"
    $rmOut = & $script:adbPath shell rm $remotePath 2>&1
    Write-Log -Message "Ответ rm: $rmOut" -Level "Info"

    # Проверяем, что файл удалён
    $checkAfter = & $script:adbPath shell ls $remotePath 2>&1
    if ($checkAfter -match "No such file") {
        Write-Log -Message "Временный файл удалён с устройства" -Level "Success"
    } else {
        Write-Log -Message "Временный файл мог остаться на ТВ: $checkAfter" -Level "Warning"
    }

    return $true
}

function Take-Screenshot-ToFolder {
    $folder = Get-ScreenshotFolder
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $filename = "TV_screenshot_$timestamp.png"
    $localPath = Join-Path $folder $filename

    $result = Take-Screenshot -LocalPath $localPath
    if ($result) {
        Write-Log -Message "Скриншот сохранён: $localPath" -Level "Success"
        return $localPath
    }
    return $null
}

# ===== ЗАПИСЬ ВИДЕО =====

function Stop-ScreenRecord {
    Write-Log -Message "Останавливаю запись..." -Level "Info"
    # Убиваем процесс screenrecord
    & $script:adbPath shell pkill -l SIGINT screenrecord 2>&1 | Out-Null
    Write-Log -Message "OK" -Level "Success"
}

function Pull-RecordedVideo {
    param([string]$RemotePath = "/sdcard/tvmanager_record.mp4")

    $folder = Get-ScreenshotFolder
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $filename = "TV_record_$timestamp.mp4"
    $localPath = Join-Path $folder $filename

    Write-Log -Message "Скачиваю видео: $localPath" -Level "Info"
    $out = & $script:adbPath pull $RemotePath $localPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message "Ошибка pull: $out" -Level "Error"
        return $null
    }

    # Удаляем с ТВ
    & $script:adbPath shell rm $RemotePath 2>&1 | Out-Null

    Write-Log -Message "Видео сохранено: $localPath" -Level "Success"
    return $localPath
}

# ===== СВЕДЕНИЯ ОБ УСТРОЙСТВЕ =====
function Get-DeviceInfo {
    Write-Log -Message "=== Получение сведений об устройстве ===" -Level "Info"

    $info = [ordered]@{
        Model            = ""
        Manufacturer     = ""
        AndroidVersion   = ""
        BuildNumber      = ""
        SerialNumber     = ""
        CpuAbi           = ""
        CpuModel         = ""
        CpuCores         = ""
        GpuInfo          = ""
        TotalRam         = ""
        AvailableRam     = ""
        TotalStorage     = ""
        AvailableStorage = ""
        ScreenResolution = ""
        ScreenDensity    = ""
        IpAddress        = ""
        MacAddress       = ""
        Uptime           = ""
        KernelVersion    = ""
        SecurityPatch    = ""
        Bootloader       = ""
        Fingerprint      = ""
        CpuMaxFreq       = ""
        CpuCurFreq       = ""

    }

    try {
        # ===== GETPROP =====
        Write-Log -Message "Читаю getprop..." -Level "Info"
        $info.Model          = (& $script:adbPath shell getprop ro.product.model 2>&1).Trim()
        $info.Manufacturer   = (& $script:adbPath shell getprop ro.product.manufacturer 2>&1).Trim()
        $info.AndroidVersion = (& $script:adbPath shell getprop ro.build.version.release 2>&1).Trim()
        $info.BuildNumber    = (& $script:adbPath shell getprop ro.build.display.id 2>&1).Trim()
        $info.SerialNumber   = (& $script:adbPath shell getprop ro.serialno 2>&1).Trim()
        $info.CpuAbi         = (& $script:adbPath shell getprop ro.product.cpu.abi 2>&1).Trim()
        $info.KernelVersion  = (& $script:adbPath shell uname -r 2>&1).Trim()
        $info.SecurityPatch  = (& $script:adbPath shell getprop ro.build.version.security_patch 2>&1).Trim()
        $info.Bootloader     = (& $script:adbPath shell getprop ro.bootloader 2>&1).Trim()
        $info.Fingerprint    = (& $script:adbPath shell getprop ro.build.fingerprint 2>&1).Trim()
        Write-Log -Message "OK: getprop" -Level "Success"

        # ===== CPU =====
        Write-Log -Message "Читаю CPU..." -Level "Info"
        $cpuInfo = & $script:adbPath shell cat /proc/cpuinfo 2>&1
        $cpuModel = ""
        $cpuCores = 0
        foreach ($line in $cpuInfo) {
            if ($line -match 'Hardware\s*:\s*(.+)') {
                if (-not $cpuModel) { $cpuModel = $matches[1].Trim() }
            }
            if ($line -match '^processor\s*:\s*\d+') { $cpuCores++ }
        }
        # Если Hardware не найден — пробуем другие источники
        if (-not $cpuModel -or $cpuModel -eq "") {
            $cpuModel = (& $script:adbPath shell getprop ro.product.board 2>&1).Trim()
        }
        if (-not $cpuModel -or $cpuModel -eq "") {
            $cpuModel = (& $script:adbPath shell getprop ro.board.platform 2>&1).Trim()
        }
        if (-not $cpuModel -or $cpuModel -eq "") {
            $cpuModel = (& $script:adbPath shell getprop ro.hardware 2>&1).Trim()
        }
        $info.CpuModel = if ($cpuModel) { $cpuModel } else { "—" }
        $info.CpuCores = if ($cpuCores -gt 0) { "$cpuCores" } else { "—" }
        Write-Log -Message "OK: CPU" -Level "Success"

        # ===== GPU =====
        Write-Log -Message "Читаю GPU..." -Level "Info"
        $gpuInfo = ""
        $glesOut = & $script:adbPath shell dumpsys SurfaceFlinger 2>&1 | Select-String "GLES:"
        if ($glesOut) {
            $gpuInfo = $glesOut.ToString().Trim()
        }
        if (-not $gpuInfo) {
            # Альтернативный источник
            $glesOut2 = & $script:adbPath shell dumpsys SurfaceFlinger 2>&1 | Select-String "GLES"
            if ($glesOut2) { $gpuInfo = $glesOut2.ToString().Trim() }
        }
        $info.GpuInfo = if ($gpuInfo) { $gpuInfo } else { "—" }
        Write-Log -Message "OK: GPU" -Level "Success"

                # ===== ЧАСТОТА CPU =====
        Write-Log -Message "Читаю частоту CPU..." -Level "Info"
        $maxFreqOut = & $script:adbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>&1
        $curFreqOut = & $script:adbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>&1

        if ($maxFreqOut -match '^\d+$') {
            $maxMhz = [math]::Round([int]$maxFreqOut.Trim() / 1000)
            $info.CpuMaxFreq = "$maxMhz МГц"
        }
        if ($curFreqOut -match '^\d+$') {
            $curMhz = [math]::Round([int]$curFreqOut.Trim() / 1000)
            $info.CpuCurFreq = "$curMhz МГц"
        }

        # ===== RAM =====
        Write-Log -Message "Читаю RAM..." -Level "Info"
        $memInfo = & $script:adbPath shell cat /proc/meminfo 2>&1
        foreach ($line in $memInfo) {
            if ($line -match 'MemTotal:\s+(\d+)\s+kB') {
                $info.TotalRam = "$([math]::Round([int]$matches[1] / 1024 / 1024, 2)) ГБ"
            }
            if ($line -match 'MemAvailable:\s+(\d+)\s+kB') {
                $info.AvailableRam = "$([math]::Round([int]$matches[1] / 1024 / 1024, 2)) ГБ"
            }
        }
        Write-Log -Message "OK: RAM" -Level "Success"

        # ===== STORAGE =====
        Write-Log -Message "Читаю Storage..." -Level "Info"
        $dfOut = & $script:adbPath shell df /data 2>&1
        foreach ($line in $dfOut) {
            if ($line -match '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%') {
                $totalBytes = [int64]$matches[1] * 1024
                $availBytes = [int64]$matches[3] * 1024
                $info.TotalStorage = "$([math]::Round($totalBytes / 1GB, 2)) ГБ"
                $info.AvailableStorage = "$([math]::Round($availBytes / 1GB, 2)) ГБ"
            }
        }
        Write-Log -Message "OK: Storage" -Level "Success"

        # ===== ЭКРАН =====
        Write-Log -Message "Читаю разрешение экрана..." -Level "Info"
        $wmSize = & $script:adbPath shell wm size 2>&1
        if ($wmSize -match '(\d+x\d+)') {
            $info.ScreenResolution = $matches[1]
        }
        $wmDensity = & $script:adbPath shell wm density 2>&1
        if ($wmDensity -match '(\d+)') {
            $info.ScreenDensity = "$($matches[1]) dpi"
        }
        Write-Log -Message "OK: разрешение" -Level "Success"

        # ===== IP =====
        Write-Log -Message "Читаю IP..." -Level "Info"
        $ipOut = & $script:adbPath shell ip addr show wlan0 2>&1
        foreach ($line in $ipOut) {
            if ($line -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                $info.IpAddress = $matches[1]
                break
            }
        }
        if (-not $info.IpAddress) {
            $ipAlt = (& $script:adbPath shell getprop dhcp.wlan0.ipaddress 2>&1).Trim()
            if ($ipAlt -match '^\d+\.\d+\.\d+\.\d+$') {
                $info.IpAddress = $ipAlt
            }
        }
        Write-Log -Message "OK: IP" -Level "Success"

        # ===== MAC =====
        Write-Log -Message "Читаю MAC..." -Level "Info"
        $macOut = & $script:adbPath shell cat /sys/class/net/wlan0/address 2>&1
        if ($macOut -match '([0-9a-fA-F:]{17})') {
            $info.MacAddress = $matches[1]
        }
        Write-Log -Message "OK: MAC" -Level "Success"

        # ===== UPTIME =====
        Write-Log -Message "Читаю uptime..." -Level "Info"
        $uptimeOut = (& $script:adbPath shell cat /proc/uptime 2>&1).Trim()
        if ($uptimeOut -match '^([\d\.]+)') {
            $seconds = [math]::Round([double]$matches[1])
            $hours = [math]::Floor($seconds / 3600)
            $minutes = [math]::Floor(($seconds % 3600) / 60)
            $info.Uptime = "$hours ч $minutes мин"
        }
        Write-Log -Message "OK: uptime" -Level "Success"

        Write-Log -Message "=== Сведения получены ===" -Level "Success"
        return [PSCustomObject]$info
    } catch {
        Write-Log -Message "Ошибка получения сведений: $_" -Level "Error"
        return [PSCustomObject]$info
    }
}

# ===== ПИТАНИЕ =====

function Invoke-Reboot {
    Write-Log -Message "=== Перезагрузка телевизора ===" -Level "Warning"

    if (-not $script:connected -or -not $script:deviceIp) {
        Write-Log -Message "ТВ не подключён — перезагрузка невозможна" -Level "Error"
        return $false
    }

    $out = & $script:adbPath shell reboot 2>&1
    Write-Log -Message "Команда отправлена: $($out | Out-String -Stream | Select-Object -First 1)" -Level "Info"

    # Ждём отключения (до 15 сек)
    $maxWait = 15
    $disconnected = $false
    for ($i = 0; $i -lt $maxWait; $i++) {
        Start-Sleep -Seconds 1
        $devices = & $script:adbPath devices 2>&1
        $stillThere = $devices | Where-Object { $_ -match [regex]::Escape($script:deviceIp) -and $_ -match "`tdevice$" }
        if (-not $stillThere) {
            $disconnected = $true
            Write-Log -Message "ТВ отключился, идёт перезагрузка" -Level "Success"
            break
        }
    }

    if (-not $disconnected) {
        Write-Log -Message "ТВ не отключился за $maxWait сек — возможно, `reboot` не сработал" -Level "Warning"
    }

    $script:connected = $false
    return $true
}

function Invoke-Shutdown {
    if (-not $script:connected -or -not $script:deviceIp) {
    Write-Log -Message "ТВ не подключён — операция невозможна" -Level "Error"
    return $false
}
    Write-Log -Message "=== Выключение телевизора ===" -Level "Warning"
    # На Android TV нет команды выключения как таковой, но есть:
    # reboot -p — выключение (power off)
    $out = & $script:adbPath shell reboot -p 2>&1
    Write-Log -Message "Команда отправлена: $out" -Level "Info"

    Start-Sleep -Seconds 3
    $script:connected = $false
    return $true
}

function Invoke-Sleep {
    Write-Log -Message "=== Перевод ТВ в спящий режим ===" -Level "Info"

    # Проверяем, включён ли экран
    $powerState = & $script:adbPath shell dumpsys power 2>&1 | Select-String "mWakefulness"
    Write-Log -Message "Состояние: $powerState" -Level "Info"

    if ($powerState -match "Awake") {
        # Экран включён — отправляем POWER для сна
        Write-Log -Message "Экран активен. Отправляю KEYCODE_POWER..." -Level "Info"
        $out = & $script:adbPath shell input keyevent 26 2>&1
    } else {
        # Экран уже выключен — ничего не делаем, чтобы не разбудить
        Write-Log -Message "Экран уже выключен." -Level "Warning"
    }

    return $true
}

function Invoke-WakeUp {
    Write-Log -Message "=== Пробуждение ТВ ===" -Level "Info"

    # 1. Проверяем текущий статус устройства
    $devices = & $script:adbPath devices 2>&1
    $deviceLine = $devices | Where-Object { $_ -match [regex]::Escape($script:deviceIp) }

    if ($deviceLine -match "`toffline") {
        Write-Log -Message "Устройство offline. Переподключаюсь..." -Level "Warning"
        & $script:adbPath disconnect 2>&1 | Out-Null
        Start-Sleep -Seconds 1
        $connectResult = & $script:adbPath connect "$($script:deviceIp):5555" 2>&1
        Write-Log -Message "Ответ connect: $connectResult" -Level "Info"
        Start-Sleep -Seconds 2
    }

    # 2. Повторно проверяем
    $devices = & $script:adbPath devices 2>&1
    $deviceLine = $devices | Where-Object { $_ -match [regex]::Escape($script:deviceIp) }

    if ($deviceLine -match "`tdevice$") {
        # 3. Отправляем команду пробуждения
        Write-Log -Message "Отправляю KEYCODE_WAKEUP..." -Level "Info"
        $out = & $script:adbPath shell input keyevent 224 2>&1
        Write-Log -Message "Команда отправлена: $out" -Level "Success"
        $script:connected = $true
        return $true
    } else {
        Write-Log -Message "Не удалось подключиться к ТВ. Возможно, он выключен." -Level "Error"
        $script:connected = $false
        return $false
    }
}

function Invoke-RebootRecovery {
    if (-not $script:connected -or -not $script:deviceIp) {
    Write-Log -Message "ТВ не подключён — операция невозможна" -Level "Error"
    return $false
}
    Write-Log -Message "=== Перезагрузка в Recovery ===" -Level "Warning"
    $out = & $script:adbPath shell reboot recovery 2>&1
    Write-Log -Message "Команда отправлена: $out" -Level "Info"
    Start-Sleep -Seconds 3
    $script:connected = $false
    return $true
}

function Invoke-RebootBootloader {
    if (-not $script:connected -or -not $script:deviceIp) {
    Write-Log -Message "ТВ не подключён — операция невозможна" -Level "Error"
    return $false
}
    Write-Log -Message "=== Перезагрузка в Bootloader ===" -Level "Warning"
    $out = & $script:adbPath shell reboot bootloader 2>&1
    Write-Log -Message "Команда отправлена: $out" -Level "Info"
    Start-Sleep -Seconds 3
    $script:connected = $false
    return $true
}

# ===== LOGCAT через Runspace =====
function Start-Logcat {
    param(
        [System.Windows.Controls.RichTextBox]$LogBox,
        [string]$Filter = "",
        [string]$Level = ""
    )

    if (-not $script:connected) {
        Write-Log -Message "Нет подключения к ТВ" -Level "Error"
        return $null
    }

    $adbArgs = @("logcat", "-v", "brief")
    if ($Level -eq "E") { $adbArgs += "*:E" }
    elseif ($Level -eq "W") { $adbArgs += "*:W" }
    elseif ($Level -eq "I") { $adbArgs += "*:I" }
    elseif ($Level -eq "D") { $adbArgs += "*:D" }

    $adbPath = $script:adbPath
    $filterRef = $Filter
    $logBoxRef = $LogBox

    # Файл для хранения PID процесса adb
    $pidFile = Join-Path $env:TEMP "tvmanager_logcat_pid.txt"
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        param($adbPath, $adbArgs, $filterRef, $logBoxRef, $pidFile)

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo.FileName = $adbPath
        $proc.StartInfo.Arguments = ($adbArgs -join " ")
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true
        $proc.StartInfo.CreateNoWindow = $true

        try {
            $proc.Start()
            # Сохраняем PID — пригодится для остановки
            $proc.Id | Out-File -FilePath $pidFile -Encoding UTF8
        } catch {
            return
        }

        $reader = $proc.StandardOutput

        while (-not $proc.HasExited) {
            $line = $null
            try { $line = $reader.ReadLine() } catch { break }
            if ($line -eq $null) { break }
            if ($filterRef -and $line -notmatch $filterRef) { continue }

            $lineCopy = $line
            try {
                $logBoxRef.Dispatcher.BeginInvoke([action]{
                    try {
                        $para = New-Object System.Windows.Documents.Paragraph
                        $para.Margin = New-Object System.Windows.Thickness(0)
                        $run = New-Object System.Windows.Documents.Run
                        $run.Text = "$lineCopy`r`n"

                        $color = [System.Windows.Media.Brushes]::LightGray
                        if ($lineCopy -match '\sE\s') { $color = [System.Windows.Media.Brushes]::LightCoral }
                        elseif ($lineCopy -match '\sW\s') { $color = [System.Windows.Media.Brushes]::Khaki }
                        elseif ($lineCopy -match '\sI\s') { $color = [System.Windows.Media.Brushes]::LightGreen }
                        elseif ($lineCopy -match '\sD\s') { $color = [System.Windows.Media.Brushes]::LightBlue }

                        $run.Foreground = $color
                        $para.Inlines.Add($run)
                        $logBoxRef.Document.Blocks.Add($para)

                        if ($logBoxRef.Document.Blocks.Count -gt 3000) {
                            $logBoxRef.Document.Blocks.Remove($logBoxRef.Document.Blocks.FirstBlock)
                        }

                        $logBoxRef.ScrollToEnd()
                    } catch { }
                })
            } catch { }
        }

        try { if (-not $proc.HasExited) { $proc.Kill() } } catch { }
        try { $proc.Dispose() } catch { }
    })

    $ps.AddArgument($adbPath)
    $ps.AddArgument($adbArgs)
    $ps.AddArgument($filterRef)
    $ps.AddArgument($logBoxRef)
    $ps.AddArgument($pidFile)

    $handle = $ps.BeginInvoke()

    return @{
        PowerShell = $ps
        Handle     = $handle
        Runspace   = $runspace
        PidFile    = $pidFile
    }
}


function Stop-Logcat {
    param($Proc)
    if (-not $Proc) { return }

    # 1. Убиваем все adb.exe, запущенные с аргументом logcat
    try {
        $adbProcesses = Get-CimInstance Win32_Process -Filter "Name = 'adb.exe'" -ErrorAction SilentlyContinue
        foreach ($p in $adbProcesses) {
            if ($p.CommandLine -match "logcat") {
                try {
                    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
                } catch { }
            }
        }
    } catch {
        # Get-CimInstance может быть недоступен — фолбэк на taskkill
        try {
            & taskkill /F /IM adb.exe /FI "WINDOWTITLE eq *logcat*" 2>&1 | Out-Null
        } catch { }
    }

    # 2. Останавливаем Runspace
    $psRef = $Proc.PowerShell
    $rsRef = $Proc.Runspace

    [System.Threading.Tasks.Task]::Run([action]{
        try {
            if ($psRef) {
                try { $psRef.Stop() }    catch { }
                try { $psRef.Dispose() } catch { }
            }
            if ($rsRef) {
                try { $rsRef.Close() }   catch { }
                try { $rsRef.Dispose() } catch { }
            }
        } catch { }
    }) | Out-Null

    Write-Log -Message "Logcat остановлен" -Level "Info"
}

# ===== ЭКСПОРТ / ИМПОРТ ПРОФИЛЕЙ =====

function Export-Profiles {
    param([string]$FilePath)

    $profiles = Get-Profiles

    if (@($profiles).Count -eq 0) {
        Write-Log -Message "Нет профилей для экспорта" -Level "Warning"
        return $false
    }

    $data = [PSCustomObject]@{
        Version    = "1.0"
        ExportedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Profiles   = @($profiles)
    }

    try {
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Log -Message "Экспортировано профилей: $(@($profiles).Count)" -Level "Success"
        Write-Log -Message "Файл: $FilePath" -Level "Info"
        return $true
    } catch {
        Write-Log -Message "Ошибка экспорта: $_" -Level "Error"
        return $false
    }
}

function Import-Profiles {
    param(
        [string]$FilePath,
        [switch]$Replace
    )

    if (-not (Test-Path $FilePath)) {
        Write-Log -Message "Файл не найден: $FilePath" -Level "Error"
        return $false
    }

    try {
        $data = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Log -Message "Ошибка чтения файла: $_" -Level "Error"
        return $false
    }

    if (-not $data.Profiles) {
        Write-Log -Message "В файле нет профилей" -Level "Error"
        return $false
    }

    $imported = @($data.Profiles)

    if ($Replace) {
        # Полная замена
        Set-ConfigValue -Key "SavedProfiles" -Value @($imported)
        Write-Log -Message "Импортировано (замена): $($imported.Count) профилей" -Level "Success"
    } else {
        # Добавление к существующим
        $existing = @(Get-Profiles)
        $added = 0
        $updated = 0

        foreach ($newProfile in $imported) {
            $match = $existing | Where-Object { $_.Name -eq $newProfile.Name }
            if ($match) {
                # Обновляем существующий
                $existing = @($existing | ForEach-Object {
                    if ($_.Name -eq $newProfile.Name) { $newProfile } else { $_ }
                })
                $updated++
            } else {
                # Добавляем новый
                $existing = @($existing) + @($newProfile)
                $added++
            }
        }

        Set-ConfigValue -Key "SavedProfiles" -Value @($existing)
        Write-Log -Message "Импортировано: новых $added, обновлено $updated" -Level "Success"
    }

    return $true
}
# ===== ПРОВЕРКА И ДОБАВЛЕНИЕ ADB В PATH =====

function Test-AdbInPath {
    # Проверяем, доступен ли adb в PATH
    $cmd = Get-Command "adb" -CommandType Application -ErrorAction SilentlyContinue
    if ($cmd) {
        return $true
    }
    return $false
}

function Add-AdbToUserPath {
    param([string]$AdbFolder)

    if (-not (Test-Path $AdbFolder)) {
        Write-Log -Message "Папка не найдена: $AdbFolder" -Level "Error"
        return $false
    }

    $adbExe = Join-Path $AdbFolder "adb.exe"
    if (-not (Test-Path $adbExe)) {
        Write-Log -Message "В папке нет adb.exe: $AdbFolder" -Level "Error"
        return $false
    }

    # 1. Читаем текущий пользовательский PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $currentPath) { $currentPath = "" }

    # 2. Проверяем, нет ли уже этой папки в PATH
    $pathEntries = $currentPath -split ';' | Where-Object { $_ -ne "" }
    $alreadyThere = $pathEntries | Where-Object { $_.TrimEnd('\') -eq $AdbFolder.TrimEnd('\') }

    if ($alreadyThere) {
        Write-Log -Message "Папка уже в PATH: $AdbFolder" -Level "Info"
        # Всё равно обновляем текущую сессию
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + $currentPath
        return $true
    }

    # 3. Добавляем папку в конец пользовательского PATH
    $newPath = if ($currentPath.TrimEnd(';')) { "$currentPath;$AdbFolder" } else { $AdbFolder }

    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Log -Message "Папка добавлена в PATH: $AdbFolder" -Level "Success"

    # 4. Обновляем PATH в текущей сессии (чтобы adb заработал сразу)
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $env:Path = "$machinePath;$newPath"

    # 5. Отправляем WM_SETTINGCHANGE, чтобы другие приложения подхватили
    try {
        [void][NativeMethods]::SendMessageTimeout(
            [IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 0x2, 5000, [ref]([UIntPtr]::Zero)
        )
    } catch { }

    return $true
}

# Вспомогательный класс для SendMessageTimeout
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class NativeMethods
    {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    }
"@ -ErrorAction SilentlyContinue

function Initialize-AdbPath {
    # Если adb уже в PATH — ничего не делаем
    if (Test-AdbInPath) {
        Write-Log -Message "ADB найден в PATH" -Level "Success"
        return $true
    }

    Write-Log -Message "ADB не найден в PATH. Запрашиваю у пользователя..." -Level "Warning"

    # Показываем диалог выбора папки
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Укажите папку, где находится adb.exe (например, C:\platform-tools)"
    $dialog.ShowNewFolderButton = $false

    $result = $dialog.ShowDialog()

    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Log -Message "Пользователь не выбрал папку" -Level "Error"
        return $false
    }

    $selectedFolder = $dialog.SelectedPath
    Write-Log -Message "Выбрана папка: $selectedFolder" -Level "Info"

    # Проверяем, есть ли adb.exe в этой папке
    $adbExe = Join-Path $selectedFolder "adb.exe"
    if (-not (Test-Path $adbExe)) {
        Write-Log -Message "В папке нет adb.exe: $selectedFolder" -Level "Error"
        [System.Windows.MessageBox]::Show(
            "В выбранной папке нет adb.exe.`n`nВыберите папку, где лежит adb.exe.",
            "ADB не найден",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return $false
    }

    # Добавляем в PATH
    $success = Add-AdbToUserPath -AdbFolder $selectedFolder
    if ($success) {
        Write-Log -Message "ADB добавлен в PATH: $selectedFolder" -Level "Success"
        return $true
    }

    return $false
}
# ===== ОЧИСТКА КЭША ПРИЛОЖЕНИЯ =====
function Clear-AppCache {
    param([string]$Package)
    Write-Log -Message "Очистка данных: $Package" -Level "Info"
    $out = & $script:adbPath shell pm clear $Package 2>&1
    if ($out -match "Success") {
        Write-Log -Message "OK: данные очищены" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $out" -Level "Error"
        return $false
    }
}

# ===== РЕЗЕРВНАЯ КОПИЯ APK =====
function Backup-Apk {
    param(
        [string]$Package,
        [string]$LocalFolder
    )

    if (-not (Test-Path $LocalFolder)) {
        New-Item -ItemType Directory -Path $LocalFolder -Force | Out-Null
    }

    Write-Log -Message "Ищу APK для: $Package" -Level "Info"

    # Получаем путь к APK на ТВ
    $out = & $script:adbPath shell pm path $Package 2>&1
    $apkPath = ""
    foreach ($line in $out) {
        if ($line -match '^package:(.+)$') {
            $apkPath = $matches[1].Trim()
            break
        }
    }

    if (-not $apkPath) {
        Write-Log -Message "APK не найден для $Package" -Level "Warning"
        return $false
    }

    Write-Log -Message "Путь на ТВ: $apkPath" -Level "Info"

    $fileName = "$Package.apk"
    $localPath = Join-Path $LocalFolder $fileName

    Write-Log -Message "Скачиваю: $fileName" -Level "Info"
    $pullOut = & $script:adbPath pull $apkPath $localPath 2>&1

    if (Test-Path $localPath) {
        Write-Log -Message "OK: $localPath" -Level "Success"
        return $true
    } else {
        Write-Log -Message "FAIL: $pullOut" -Level "Error"
        return $false
    }
}

function Backup-AllApks {
    param([string]$LocalFolder)

    Write-Log -Message "=== Резервная копия всех сторонних APK ===" -Level "Info"

    if (-not (Test-Path $LocalFolder)) {
        New-Item -ItemType Directory -Path $LocalFolder -Force | Out-Null
    }

    # Получаем список сторонних пакетов
    $out = & $script:adbPath shell pm list packages -3 2>&1
    $packages = @()
    foreach ($line in $out) {
        if ($line -match '^package:(.+)$') {
            $packages += $matches[1].Trim()
        }
    }

    Write-Log -Message "Найдено сторонних: $($packages.Count)" -Level "Info"

    $success = 0
    $failed = 0

    foreach ($pkg in $packages) {
        if (Backup-Apk -Package $pkg -LocalFolder $LocalFolder) {
            $success++
        } else {
            $failed++
        }
    }

    Write-Log -Message "=== Готово: успешно $success, ошибок $failed ===" -Level "Success"
    return @{ Success = $success; Failed = $failed }
}

# ===== ПОЛЕЗНЫЕ ADB-КОМАНДЫ =====

function Invoke-AdbCommand {
    param(
        [string]$Command,
        [string]$Description = ""
    )

    # --- Плейсхолдеры ---
    $placeholders = [regex]::Matches($Command, '<([^>]+)>')
    if ($placeholders.Count -gt 0) {
        Write-Log -Message "Команда требует параметров:" -Level "Info"
        foreach ($ph in $placeholders) {
            Write-Log -Message "  <$($ph.Groups[1].Value)>" -Level "Info"
        }

        $result = Show-ParameterInputDialog -Command $Command -Placeholders $placeholders
        if (-not $result) {
            Write-Log -Message "Выполнение отменено" -Level "Warning"
            return $null
        }
        foreach ($key in $result.Keys) {
            $Command = $Command -replace [regex]::Escape("<$key>"), $result[$key]
        }
        Write-Log -Message "Итоговая команда: adb $Command" -Level "Info"
    }

    if ($Description) {
        Write-Log -Message "Команда: $Description" -Level "Info"
    }

    $tokens = Split-CommandLine -CommandLine $Command
    Write-Log -Message "  → adb $($tokens -join ' ')" -Level "Info"

    # --- Запускаем через ProcessStartInfo, чтобы корректно поймать stdout+stderr+exitcode ---
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $script:adbPath
    $psi.Arguments              = ($tokens | ForEach-Object { '"' + ($_ -replace '"','\"') + '"' }) -join ' '
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
        $proc.Dispose()
    } catch {
        Write-Log -Message "  FAIL: не удалось запустить adb: $_" -Level "Error"
        return $null
    }

    # --- Вывод ---
    $lines = @()
    if ($stdout) { $lines += $stdout -split "`r?`n" | Where-Object { $_ -ne "" } }
    if ($stderr) { $lines += $stderr -split "`r?`n" | Where-Object { $_ -ne "" } }

    if ($exitCode -eq 0) {
        Write-Log -Message "  OK" -Level "Success"
        if ($lines.Count -gt 0) {
            foreach ($line in $lines) {
                Write-Log -Message "  $line" -Level "Info"
            }
        } else {
            Write-Log -Message "  (пустой вывод)" -Level "Info"
        }
    } else {
        Write-Log -Message "  FAIL (код $exitCode)" -Level "Error"
        foreach ($line in $lines) {
            Write-Log -Message "  $line" -Level "Error"
        }
    }

    return $lines
}

function Split-CommandLine {
    param([string]$CommandLine)

    $tokens = @()
    $current = ""
    $inQuotes = $false
    $quoteChar = ""

    for ($i = 0; $i -lt $CommandLine.Length; $i++) {
        $c = $CommandLine[$i]

        if ($inQuotes) {
            if ($c -eq $quoteChar) {
                $inQuotes = $false
                # закрыли кавычку — токен закончился только если дальше пробел/конец
                if ($i -eq $CommandLine.Length - 1 -or $CommandLine[$i+1] -eq ' ') {
                    $tokens += $current
                    $current = ""
                }
            } else {
                $current += $c
            }
        } else {
            if ($c -eq '"' -or $c -eq "'") {
                $inQuotes = $true
                $quoteChar = $c
            } elseif ($c -eq ' ') {
                if ($current -ne "") {
                    $tokens += $current
                    $current = ""
                }
            } else {
                $current += $c
            }
        }
    }
    if ($current -ne "") { $tokens += $current }
    return ,$tokens
}

# ===== ДИАЛОГ ВВОДА ПАРАМЕТРОВ =====
function Show-ParameterInputDialog {
    param(
        [string]$Command,
        [System.Text.RegularExpressions.MatchCollection]$Placeholders
    )

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Ввод параметров"
    $dialog.Width = 500
    $dialog.Height = 350
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#F7F7FA"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "20"

    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = "Auto"
    $grid.RowDefinitions.Add($row1)

    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = "*"
    $grid.RowDefinitions.Add($row2)

    $row3 = New-Object System.Windows.Controls.RowDefinition
    $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row3)

    $header = New-ViewHeader -Text "Введите параметры" -X 0 -Y 0
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $grid.Children.Add($header) | Out-Null

    # Информация о команде
    $infoStack = New-Object System.Windows.Controls.StackPanel

    $cmdLabel = New-Object System.Windows.Controls.TextBlock
    $cmdLabel.Text = "adb $Command"
    $cmdLabel.FontFamily = "Consolas"
    $cmdLabel.FontSize = 12
    $cmdLabel.Foreground = "#4A90E2"
    $cmdLabel.TextWrapping = "Wrap"
    $cmdLabel.Margin = "0,0,0,15"
    $infoStack.Children.Add($cmdLabel) | Out-Null

    # Поля для каждого плейсхолдера
    $script:ParamInputBoxes = @{}
    $uniquePlaceholders = @{}

    foreach ($ph in $Placeholders) {
        $key = $ph.Groups[1].Value
        if ($uniquePlaceholders.ContainsKey($key)) { continue }
        $uniquePlaceholders[$key] = $true

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = "${key}:"
        $lbl.FontSize = 13
        $lbl.Foreground = "#2D2D30"
        $lbl.Margin = "0,5,0,3"
        $infoStack.Children.Add($lbl) | Out-Null

        $box = New-Object System.Windows.Controls.TextBox
        $box.Style = $window.Resources["RoundedTextBox"]
        $box.FontSize = 13
        $box.Margin = "0,0,0,8"
        $infoStack.Children.Add($box) | Out-Null

        $script:ParamInputBoxes[$key] = $box
    }

    [System.Windows.Controls.Grid]::SetRow($infoStack, 1)
    $grid.Children.Add($infoStack) | Out-Null

    # Кнопки
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    $btnPanel.Margin = "0,15,0,0"

    $script:ParamDialogResult = $null

    $btnOk = New-Object System.Windows.Controls.Button
    $btnOk.Content = "Выполнить"
    $btnOk.Style = $window.Resources["RoundedButton"]
    $btnOk.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
    )
    $btnOk.Padding = "15,8"
    $btnOk.Margin = "0,0,8,0"
    $btnOk.Add_Click({
        $values = @{}
        $allFilled = $true
        foreach ($key in $script:ParamInputBoxes.Keys) {
            $val = $script:ParamInputBoxes[$key].Text.Trim()
            if ([string]::IsNullOrWhiteSpace($val)) {
                [System.Windows.MessageBox]::Show("Заполните поле: $key", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                $allFilled = $false
                break
            }
            $values[$key] = $val
        }
        if ($allFilled) {
            $script:ParamDialogResult = $values
            $dialog.Close()
        }
    })
    $btnPanel.Children.Add($btnOk) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Отмена"
    $btnCancel.Style = $window.Resources["RoundedButton"]
    $btnCancel.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnCancel.Padding = "15,8"
    $btnCancel.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnCancel) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null

    return $script:ParamDialogResult
}

# Список полезных команд
function Get-AdbCommandsList {
    return @(
        # ===== Информация =====
        [PSCustomObject]@{ Category = "Информация"; Name = "Модель ТВ"; Command = "shell getprop ro.product.model"; Desc = "Модель телевизора" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Версия Android"; Command = "shell getprop ro.build.version.release"; Desc = "Версия Android" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Серийный номер"; Command = "shell getprop ro.serialno"; Desc = "Серийный номер" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Версия ядра"; Command = "shell uname -a"; Desc = "Информация о ядре" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Язык системы"; Command = "shell getprop persist.sys.locale"; Desc = "Текущий язык" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Патч безопасности"; Command = "shell getprop ro.build.version.security_patch"; Desc = "Дата патча безопасности" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Fingerprint"; Command = "shell getprop ro.build.fingerprint"; Desc = "Идентификатор сборки" },
        [PSCustomObject]@{ Category = "Информация"; Name = "Bootloader"; Command = "shell getprop ro.bootloader"; Desc = "Версия загрузчика" },

        # ===== Производительность =====
        [PSCustomObject]@{ Category = "Производительность"; Name = "Загрузка CPU"; Command = "shell top -n 1 -b"; Desc = "Загрузка процессов (1 раз)" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Память"; Command = "shell cat /proc/meminfo"; Desc = "Информация о RAM" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Диск"; Command = "shell df -h"; Desc = "Использование дисков" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Время работы"; Command = "shell cat /proc/uptime"; Desc = "Uptime" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Температура CPU"; Command = "shell cat /sys/class/thermal/thermal_zone0/temp"; Desc = "Температура CPU" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Все процессы"; Command = "shell ps -A"; Desc = "Список всех процессов" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Частота CPU (макс)"; Command = "shell cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"; Desc = "Максимальная частота" },
        [PSCustomObject]@{ Category = "Производительность"; Name = "Частота CPU (тек.)"; Command = "shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"; Desc = "Текущая частота" },

        # ===== Сеть =====
        [PSCustomObject]@{ Category = "Сеть"; Name = "Wi-Fi IP и MAC"; Command = "shell ip addr show wlan0"; Desc = "IP и MAC Wi-Fi" },
        [PSCustomObject]@{ Category = "Сеть"; Name = "Ethernet"; Command = "shell ip addr show eth0"; Desc = "IP и MAC Ethernet" },
        [PSCustomObject]@{ Category = "Сеть"; Name = "DNS"; Command = "shell getprop net.dns1"; Desc = "Основной DNS" },
        [PSCustomObject]@{ Category = "Сеть"; Name = "Wi-Fi сканирование"; Command = "shell dumpsys wifi | grep -i ssid"; Desc = "Список Wi-Fi сетей" },
        [PSCustomObject]@{ Category = "Сеть"; Name = "Активные соединения"; Command = "shell netstat -an"; Desc = "Открытые порты и соединения" },
        [PSCustomObject]@{ Category = "Сеть"; Name = "Ping Google"; Command = "shell ping -c 3 8.8.8.8"; Desc = "Проверка интернета" },

        # ===== Экран =====
        [PSCustomObject]@{ Category = "Экран"; Name = "Разрешение"; Command = "shell wm size"; Desc = "Разрешение экрана" },
        [PSCustomObject]@{ Category = "Экран"; Name = "Плотность"; Command = "shell wm density"; Desc = "Плотность пикселей" },
        [PSCustomObject]@{ Category = "Экран"; Name = "Скриншот"; Command = "shell screencap -p /sdcard/screenshot.png"; Desc = "Снимок экрана" },
        [PSCustomObject]@{ Category = "Экран"; Name = "Запись 10 сек"; Command = "shell screenrecord --time-limit 10 /sdcard/video.mp4"; Desc = "Запись видео 10 сек" },
        [PSCustomObject]@{ Category = "Экран"; Name = "Ориентация"; Command = "shell settings get system user_rotation"; Desc = "Текущая ориентация" },
        [PSCustomObject]@{ Category = "Экран"; Name = "Тайм-аут сна"; Command = "shell settings get system screen_off_timeout"; Desc = "Время до отключения" },
        [PSCustomObject]@{ Category = "Экран"; Name = "Яркость"; Command = "shell settings get system screen_brightness"; Desc = "Текущая яркость" },

        # ===== Звук =====
        [PSCustomObject]@{ Category = "Звук"; Name = "Громкость"; Command = "shell media volume --show --stream 3 --get"; Desc = "Текущая громкость" },
        [PSCustomObject]@{ Category = "Звук"; Name = "Громче"; Command = "shell media volume --show --stream 3 --adj raise"; Desc = "Увеличить громкость" },
        [PSCustomObject]@{ Category = "Звук"; Name = "Тише"; Command = "shell media volume --show --stream 3 --adj lower"; Desc = "Уменьшить громкость" },
        [PSCustomObject]@{ Category = "Звук"; Name = "Без звука"; Command = "shell media volume --show --stream 3 --set 0"; Desc = "Mute" },

        # ===== Приложения =====
        [PSCustomObject]@{ Category = "Приложения"; Name = "Все пакеты"; Command = "shell pm list packages"; Desc = "Все пакеты" },
        [PSCustomObject]@{ Category = "Приложения"; Name = "Только сторонние"; Command = "shell pm list packages -3"; Desc = "Сторонние пакеты" },
        [PSCustomObject]@{ Category = "Приложения"; Name = "Только системные"; Command = "shell pm list packages -s"; Desc = "Системные пакеты" },
        [PSCustomObject]@{ Category = "Приложения"; Name = "Отключённые"; Command = "shell pm list packages -d"; Desc = "Отключённые пакеты" },
        [PSCustomObject]@{ Category = "Приложения"; Name = "Запущенные"; Command = "shell pm list packages -e"; Desc = "Включённые пакеты" },
        [PSCustomObject]@{ Category = "Приложения"; Name = "Установленные в 3-м"; Command = "shell pm list packages -3 -f"; Desc = "С путями к APK" },

        # ===== Питание =====
        [PSCustomObject]@{ Category = "Питание"; Name = "Перезагрузка"; Command = "reboot"; Desc = "Перезагрузка ТВ" },
        [PSCustomObject]@{ Category = "Питание"; Name = "Выключение"; Command = "shell reboot -p"; Desc = "Выключение ТВ" },
        [PSCustomObject]@{ Category = "Питание"; Name = "Recovery"; Command = "reboot recovery"; Desc = "Перезагрузка в Recovery" },
        [PSCustomObject]@{ Category = "Питание"; Name = "Bootloader"; Command = "reboot bootloader"; Desc = "Перезагрузка в Bootloader" },

        # ===== Прочее =====
        [PSCustomObject]@{ Category = "Прочее"; Name = "Uptime"; Command = "shell uptime"; Desc = "Время работы" },
        [PSCustomObject]@{ Category = "Прочее"; Name = "Дата системы"; Command = "shell date"; Desc = "Текущая дата и время" },
        [PSCustomObject]@{ Category = "Прочее"; Name = "Часовой пояс"; Command = "shell getprop persist.sys.timezone"; Desc = "Часовой пояс" },
        [PSCustomObject]@{ Category = "Прочее"; Name = "Список датчиков"; Command = "shell dumpsys sensorservice | head -n 20"; Desc = "Датчики ТВ" }
    )
}

# ===== РАСШИРЕННЫЙ СПРАВОЧНИК ADB-КОМАНД =====
function Get-AdbExtraCommands {
    return @(
        # ===== Активность и задачи =====
        [PSCustomObject]@{ Category = "Активность"; Name = "Текущая activity"; Command = "shell dumpsys activity activities | grep mResumedActivity"; Desc = "Какое окно сейчас открыто" },
        [PSCustomObject]@{ Category = "Активность"; Name = "Все запущенные activity"; Command = "shell dumpsys activity activities"; Desc = "Полный список activity" },
        [PSCustomObject]@{ Category = "Активность"; Name = "Стек задач"; Command = "shell dumpsys activity recents"; Desc = "История открытых приложений" },
        [PSCustomObject]@{ Category = "Активность"; Name = "Службы"; Command = "shell dumpsys activity services"; Desc = "Запущенные службы" },
        [PSCustomObject]@{ Category = "Активность"; Name = "Broadcast-приёмники"; Command = "shell dumpsys activity broadcasts"; Desc = "Активные приёмники" },
        [PSCustomObject]@{ Category = "Активность"; Name = "Запустить приложение"; Command = "shell monkey -p <package> 1"; Desc = "Запуск приложения (замените <package>)" },

        # ===== Процессы =====
        [PSCustomObject]@{ Category = "Процессы"; Name = "Топ по CPU"; Command = "shell top -n 1 -b -o %CPU,CMDLINE | head -n 20"; Desc = "20 процессов с макс. CPU" },
        [PSCustomObject]@{ Category = "Процессы"; Name = "Топ по RAM"; Command = "shell top -n 1 -b -o %MEM,CMDLINE | head -n 20"; Desc = "20 процессов с макс. RAM" },
        [PSCustomObject]@{ Category = "Процессы"; Name = "Процессы приложения"; Command = "shell ps -A | grep <package>"; Desc = "Процессы пакета (замените <package>)" },
        [PSCustomObject]@{ Category = "Процессы"; Name = "Убить приложение"; Command = "shell am force-stop <package>"; Desc = "Принудительно закрыть приложение" },
        [PSCustomObject]@{ Category = "Процессы"; Name = "Очистить все"; Command = "shell am kill-all"; Desc = "Убить все фоновые процессы" },

        # ===== Батарея =====
        [PSCustomObject]@{ Category = "Батарея"; Name = "Состояние"; Command = "shell dumpsys battery"; Desc = "Уровень, температура, статус" },
        [PSCustomObject]@{ Category = "Батарея"; Name = "Сбросить статистику"; Command = "shell dumpsys batterystats --reset"; Desc = "Сброс статистики батареи" },

        # ===== Wi-Fi =====
        [PSCustomObject]@{ Category = "Wi-Fi"; Name = "Состояние Wi-Fi"; Command = "shell dumpsys wifi | grep -i 'mNetworkInfo'"; Desc = "Текущее подключение" },
        [PSCustomObject]@{ Category = "Wi-Fi"; Name = "Wi-Fi MAC"; Command = "shell cat /sys/class/net/wlan0/address"; Desc = "MAC-адрес Wi-Fi" },
        [PSCustomObject]@{ Category = "Wi-Fi"; Name = "Включить Wi-Fi"; Command = "shell svc wifi enable"; Desc = "Включить Wi-Fi" },
        [PSCustomObject]@{ Category = "Wi-Fi"; Name = "Выключить Wi-Fi"; Command = "shell svc wifi disable"; Desc = "Выключить Wi-Fi" },

        # ===== Bluetooth =====
        [PSCustomObject]@{ Category = "Bluetooth"; Name = "Состояние BT"; Command = "shell dumpsys bluetooth_manager"; Desc = "Информация о Bluetooth" },
        [PSCustomObject]@{ Category = "Bluetooth"; Name = "Включить BT"; Command = "shell svc bluetooth enable"; Desc = "Включить Bluetooth" },
        [PSCustomObject]@{ Category = "Bluetooth"; Name = "Выключить BT"; Command = "shell svc bluetooth disable"; Desc = "Выключить Bluetooth" },

        # ===== Установка и удаление =====
        [PSCustomObject]@{ Category = "Установка"; Name = "Установить APK"; Command = "install -r <path>"; Desc = "Установить APK (замените <path>)" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Установить без перезаписи"; Command = "install -r -d <path>"; Desc = "Разрешить downgrade" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Удалить пакет"; Command = "uninstall <package>"; Desc = "Полное удаление пакета" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Удалить для пользователя"; Command = "shell pm uninstall --user 0 <package>"; Desc = "Удаление без root" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Восстановить пакет"; Command = "shell cmd package install-existing <package>"; Desc = "Восстановить удалённый пакет" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Путь к APK"; Command = "shell pm path <package>"; Desc = "Где лежит APK" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Размер приложения"; Command = "shell pm list packages -3 -f"; Desc = "С путями ко всем сторонним APK" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Скачать APK"; Command = "pull <remote> <local>"; Desc = "Скачать файл с ТВ" },
        [PSCustomObject]@{ Category = "Установка"; Name = "Загрузить APK"; Command = "push <local> <remote>"; Desc = "Загрузить файл на ТВ" },

        # ===== Приложения (дополнительно) =====
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Информация о пакете"; Command = "shell dumpsys package <package>"; Desc = "Всё о пакете" },
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Разрешения пакета"; Command = "shell dumpsys package <package> | grep permission"; Desc = "Разрешения приложения" },
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Версия пакета"; Command = "shell dumpsys package <package> | grep versionName"; Desc = "Версия приложения" },
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Только отключённые"; Command = "shell pm list packages -d -f"; Desc = "Отключённые с путями" },
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Отключить пакет"; Command = "shell pm disable-user --user 0 <package>"; Desc = "Отключить приложение" },
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Включить пакет"; Command = "shell pm enable <package>"; Desc = "Включить обратно" },
        [PSCustomObject]@{ Category = "Приложения+"; Name = "Очистить данные"; Command = "shell pm clear <package>"; Desc = "Сбросить данные приложения" },

        # ===== Ввод и клавиатура =====
        [PSCustomObject]@{ Category = "Ввод"; Name = "Ввести текст"; Command = "shell input text 'Hello'"; Desc = "Ввести текст (латиница)" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Нажать Home"; Command = "shell input keyevent 3"; Desc = "Кнопка Домой" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Нажать Back"; Command = "shell input keyevent 4"; Desc = "Кнопка Назад" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Нажать Enter"; Command = "shell input keyevent 66"; Desc = "Кнопка Enter" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Нажать Menu"; Command = "shell input keyevent 82"; Desc = "Кнопка Меню" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Нажать Power"; Command = "shell input keyevent 26"; Desc = "Питание" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Свайп"; Command = "shell input swipe 500 1000 500 500 300"; Desc = "Свайп вверх" },
        [PSCustomObject]@{ Category = "Ввод"; Name = "Тап по координатам"; Command = "shell input tap 500 500"; Desc = "Тап в точку" },

        # ===== Экран (дополнительно) =====
        [PSCustomObject]@{ Category = "Экран+"; Name = "Выключить экран"; Command = "shell input keyevent 26"; Desc = "Погасить экран" },
        [PSCustomObject]@{ Category = "Экран+"; Name = "Тайм-аут 10 мин"; Command = "shell settings put system screen_off_timeout 600000"; Desc = "10 минут" },
        [PSCustomObject]@{ Category = "Экран+"; Name = "Тайм-аут 30 мин"; Command = "shell settings put system screen_off_timeout 1800000"; Desc = "30 минут" },
        [PSCustomObject]@{ Category = "Экран+"; Name = "Тайм-аут никогда"; Command = "shell settings put system screen_off_timeout 2147483647"; Desc = "Не гасить экран" },
        [PSCustomObject]@{ Category = "Экран+"; Name = "Яркость 50%"; Command = "shell settings put system screen_brightness 127"; Desc = "Установить яркость 50%" },

        # ===== Настройки системы =====
        [PSCustomObject]@{ Category = "Настройки"; Name = "Анимация 1x"; Command = "shell settings put global window_animation_scale 1.0"; Desc = "Стандартная анимация" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Анимация 0.5x"; Command = "shell settings put global window_animation_scale 0.5"; Desc = "Быстрая анимация" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Анимация 0x"; Command = "shell settings put global window_animation_scale 0.0"; Desc = "Отключить анимацию" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Открыть настройки"; Command = "shell am start -a android.settings.SETTINGS"; Desc = "Системные настройки Android" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "О разработчике"; Command = "shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS"; Desc = "Для разработчиков" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Настройки Wi-Fi"; Command = "shell am start -a android.settings.WIFI_SETTINGS"; Desc = "Wi-Fi" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Настройки Bluetooth"; Command = "shell am start -a android.settings.BLUETOOTH_SETTINGS"; Desc = "Bluetooth" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Настройки звука"; Command = "shell am start -a android.settings.SOUND_SETTINGS"; Desc = "Звук" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Настройки экрана"; Command = "shell am start -a android.settings.DISPLAY_SETTINGS"; Desc = "Экран" },
        [PSCustomObject]@{ Category = "Настройки"; Name = "Настройки приложений"; Command = "shell am start -a android.settings.APPLICATION_SETTINGS"; Desc = "Приложения" },

        # ===== Логи и отладка =====
        [PSCustomObject]@{ Category = "Отладка"; Name = "Все логи"; Command = "logcat -d"; Desc = "Дамп логов" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Только ошибки"; Command = "logcat -d *:E"; Desc = "Только ошибки" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Очистить логи"; Command = "logcat -c"; Desc = "Очистить буфер логов" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Дамп системы"; Command = "shell dumpsys"; Desc = "Полный дамп системы" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Дамп батареи"; Command = "shell dumpsys battery"; Desc = "Подробно о батарее" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Дамп дисплея"; Command = "shell dumpsys display"; Desc = "Подробно о дисплее" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Дамп Wi-Fi"; Command = "shell dumpsys wifi"; Desc = "Подробно о Wi-Fi" },
        [PSCustomObject]@{ Category = "Отладка"; Name = "Дамп аудио"; Command = "shell dumpsys audio"; Desc = "Подробно об аудио" },

        # ===== Файлы =====
        [PSCustomObject]@{ Category = "Файлы"; Name = "Список /sdcard"; Command = "shell ls -la /sdcard/"; Desc = "Файлы во внутренней памяти" },
        [PSCustomObject]@{ Category = "Файлы"; Name = "Список Download"; Command = "shell ls -la /sdcard/Download/"; Desc = "Папка загрузок" },
        [PSCustomObject]@{ Category = "Файлы"; Name = "Список /data/app"; Command = "shell ls -la /data/app/"; Desc = "Установленные APK" },
        [PSCustomObject]@{ Category = "Файлы"; Name = "Размер папки"; Command = "shell du -sh /sdcard/"; Desc = "Размер папки" },
        [PSCustomObject]@{ Category = "Файлы"; Name = "Свободно на /sdcard"; Command = "shell df -h /sdcard/"; Desc = "Место" },
        [PSCustomObject]@{ Category = "Файлы"; Name = "Найти файл"; Command = "shell find /sdcard/ -name '*.apk'"; Desc = "Найти APK-файлы" },

        # ===== Сеть (дополнительно) =====
        [PSCustomObject]@{ Category = "Сеть+"; Name = "Все интерфейсы"; Command = "shell ifconfig -a"; Desc = "Список всех интерфейсов" },
        [PSCustomObject]@{ Category = "Сеть+"; Name = "Таблица маршрутов"; Command = "shell ip route"; Desc = "Маршрутизация" },
        [PSCustomObject]@{ Category = "Сеть+"; Name = "DNS-серверы"; Command = "shell getprop | grep dns"; Desc = "Все DNS" },
        [PSCustomObject]@{ Category = "Сеть+"; Name = "Проверить порт"; Command = "shell nc -zv 192.168.1.1 80"; Desc = "Проверка порта" },
        [PSCustomObject]@{ Category = "Сеть+"; Name = "Трассировка"; Command = "shell traceroute 8.8.8.8"; Desc = "Трассировка до Google" },

        # ===== Специальные =====
        [PSCustomObject]@{ Category = "Специальные"; Name = "Скрыть статус-бар"; Command = "shell settings put global policy_control immersive.full=*"; Desc = "Полноэкранный режим" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "Показать статус-бар"; Command = "shell settings put global policy_control null"; Desc = "Вернуть статус-бар" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "Оверскан сброс"; Command = "shell wm overscan reset"; Desc = "Сброс оверскана (старый Android)" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "DPI 320"; Command = "shell wm density 320"; Desc = "Плотность экрана 320" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "DPI 240"; Command = "shell wm density 240"; Desc = "Плотность экрана 240" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "Кэш приложений"; Command = "shell du -sh /data/data/*/cache"; Desc = "Размер кэша приложений" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "Убить все процессы"; Command = "shell am kill-all"; Desc = "Закрыть всё фоновое" },
        [PSCustomObject]@{ Category = "Специальные"; Name = "Стереть данные приложения"; Command = "shell pm clear <package>"; Desc = "Сброс данных" }
    )
}