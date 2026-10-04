# ============================================================================
#  Экспорт полного дампа устройства
# ============================================================================

# ===== СБОР ДАННЫХ =====
function Get-FullDeviceDump {
    Write-Log -Message "=== Сбор полного дампа устройства ===" -Level "Info"

    $dump = [ordered]@{
        ExportedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        App        = "TVManagerTCL"
        AppVersion = "0.0.6"
        DeviceIP   = $script:deviceIp
    }

    # --- 1. Info о устройстве ---
    Write-Log -Message "Собираю сведения об устройстве..." -Level "Info"
    try {
        $dump.Info = Get-DeviceInfo
    } catch {
        Write-Log -Message "Ошибка Get-DeviceInfo: $_" -Level "Warning"
        $dump.Info = $null
    }

    # --- 2. Wi-Fi ---
    Write-Log -Message "Собираю сведения о Wi-Fi..." -Level "Info"
    try {
        if (Get-Command Get-WifiInfo -ErrorAction SilentlyContinue) {
            $dump.Wifi = Get-WifiInfo
        } else {
            $dump.Wifi = $null
        }
    } catch {
        Write-Log -Message "Ошибка Get-WifiInfo: $_" -Level "Warning"
        $dump.Wifi = $null
    }

    # --- 3. Пакеты ---
    Write-Log -Message "Собираю списки пакетов..." -Level "Info"
    try {
        # Все
        $allRaw = & $script:adbPath shell pm list packages 2>&1
        $all = @()
        foreach ($line in $allRaw) {
            if ($line -match '^package:(.+)$') { $all += $matches[1].Trim() }
        }

        # Сторонние
        $thirdRaw = & $script:adbPath shell pm list packages -3 2>&1
        $third = @()
        foreach ($line in $thirdRaw) {
            if ($line -match '^package:(.+)$') { $third += $matches[1].Trim() }
        }

        # Системные
        $sysRaw = & $script:adbPath shell pm list packages -s 2>&1
        $sys = @()
        foreach ($line in $sysRaw) {
            if ($line -match '^package:(.+)$') { $sys += $matches[1].Trim() }
        }

        # Отключённые
        $disRaw = & $script:adbPath shell pm list packages -d 2>&1
        $disabled = @()
        foreach ($line in $disRaw) {
            if ($line -match '^package:(.+)$') { $disabled += $matches[1].Trim() }
        }

        $dump.Packages = [ordered]@{
            Total      = $all.Count
            ThirdParty = $third
            System     = $sys
            Disabled   = $disabled
            All        = $all
        }
        Write-Log -Message "  Всего: $($all.Count), сторонних: $($third.Count), системных: $($sys.Count), отключённых: $($disabled.Count)" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка сбора пакетов: $_" -Level "Warning"
        $dump.Packages = $null
    }

    # --- 4. Настройки системы ---
    Write-Log -Message "Собираю системные настройки..." -Level "Info"
    try {
        $settings = [ordered]@{
            AnimationScale      = "—"
            WindowAnimScale     = "—"
            TransitionAnimScale = "—"
            AnimatorScale       = "—"
            ScreenOffTimeout    = "—"
            ScreenBrightness    = "—"
            UserRotation        = "—"
            AdbEnabled          = "—"
        }

        $val = (& $script:adbPath shell settings get global window_animation_scale 2>&1 | Out-String).Trim()
        if ($val -match '[\d\.]+') { $settings.WindowAnimScale = $val }
        if ($settings.AnimationScale -eq "—") { $settings.AnimationScale = $val }

        $val = (& $script:adbPath shell settings get global transition_animation_scale 2>&1 | Out-String).Trim()
        if ($val -match '[\d\.]+') { $settings.TransitionAnimScale = $val }

        $val = (& $script:adbPath shell settings get global animator_duration_scale 2>&1 | Out-String).Trim()
        if ($val -match '[\d\.]+') { $settings.AnimatorScale = $val }

        $val = (& $script:adbPath shell settings get system screen_off_timeout 2>&1 | Out-String).Trim()
        if ($val -match '^\d+$') { $settings.ScreenOffTimeout = $val }

        $val = (& $script:adbPath shell settings get system screen_brightness 2>&1 | Out-String).Trim()
        if ($val -match '^\d+$') { $settings.ScreenBrightness = $val }

        $val = (& $script:adbPath shell settings get system user_rotation 2>&1 | Out-String).Trim()
        if ($val -match '^\d+$') { $settings.UserRotation = $val }

        $val = (& $script:adbPath shell settings get global adb_enabled 2>&1 | Out-String).Trim()
        if ($val -match '^\d+$') { $settings.AdbEnabled = $val }

        $dump.Settings = [PSCustomObject]$settings
    } catch {
        Write-Log -Message "Ошибка сбора настроек: $_" -Level "Warning"
        $dump.Settings = $null
    }

    # --- 5. История изменений ---
    Write-Log -Message "Читаю историю изменений..." -Level "Info"
    try {
        $changesFile = Get-ChangesFilePath
        if ($changesFile -and (Test-Path $changesFile)) {
            $dump.ChangesHistory = (Get-Content $changesFile -Raw -Encoding UTF8 | ConvertFrom-Json)
        } else {
            $dump.ChangesHistory = $null
        }
    } catch {
        Write-Log -Message "Ошибка чтения истории: $_" -Level "Warning"
        $dump.ChangesHistory = $null
    }

    Write-Log -Message "=== Дамп собран ===" -Level "Success"
    return [PSCustomObject]$dump
}

# ===== СОХРАНЕНИЕ В JSON =====
function Export-DeviceDumpJson {
    param([string]$FilePath)

    try {
        $dump = Get-FullDeviceDump
        $json = $dump | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($FilePath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Log -Message "Дамп сохранён (JSON): $FilePath" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка экспорта JSON: $_" -Level "Error"
        return $false
    }
}

# ===== СОХРАНЕНИЕ В TXT =====
function Export-DeviceDumpTxt {
    param([string]$FilePath)

    try {
        $dump = Get-FullDeviceDump

        $sb = New-Object System.Text.StringBuilder
        $nl = "`r`n"

        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("TVManagerTCL — Дамп устройства")
        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("Дата: $($dump.ExportedAt)")
        [void]$sb.AppendLine("Устройство: $($dump.DeviceIP)")
        [void]$sb.AppendLine()

        # --- Info ---
        if ($dump.Info) {
            [void]$sb.AppendLine("### СВЕДЕНИЯ ОБ УСТРОЙСТВЕ ###")
            [void]$sb.AppendLine("-" * 80)
            foreach ($prop in $dump.Info.PSObject.Properties) {
                $val = if ($prop.Value) { $prop.Value } else { "—" }
                [void]$sb.AppendLine(("{0,-20} {1}" -f "$($prop.Name):", $val))
            }
            [void]$sb.AppendLine()
        }

        # --- Wi-Fi ---
        if ($dump.Wifi) {
            [void]$sb.AppendLine("### WI-FI ###")
            [void]$sb.AppendLine("-" * 80)
            $wifiFields = @(
                @{ L = "Состояние";         V = if ($dump.Wifi.Enabled) { "включён" } else { "выключен" } }
                @{ L = "SSID";              V = $dump.Wifi.Ssid }
                @{ L = "BSSID";             V = $dump.Wifi.Bssid }
                @{ L = "IP";                V = $dump.Wifi.Ip }
                @{ L = "MAC";               V = $dump.Wifi.Mac }
                @{ L = "Шлюз";              V = $dump.Wifi.Gateway }
                @{ L = "DNS";               V = $dump.Wifi.Dns }
                @{ L = "Частота";           V = $dump.Wifi.Frequency }
                @{ L = "Скорость";          V = $dump.Wifi.LinkSpeed }
                @{ L = "Сигнал";            V = $dump.Wifi.Signal }
                @{ L = "Активный интерфейс";V = "$($dump.Wifi.ActiveIfType) ($($dump.Wifi.ActiveIfName))" }
                @{ L = "IP интерфейса";     V = $dump.Wifi.ActiveIfIp }
            )
            foreach ($f in $wifiFields) {
                $v = if ($f.V) { $f.V } else { "—" }
                [void]$sb.AppendLine(("{0,-20} {1}" -f "$($f.L):", $v))
            }
            [void]$sb.AppendLine()
        }

        # --- Settings ---
        if ($dump.Settings) {
            [void]$sb.AppendLine("### СИСТЕМНЫЕ НАСТРОЙКИ ###")
            [void]$sb.AppendLine("-" * 80)
            foreach ($prop in $dump.Settings.PSObject.Properties) {
                [void]$sb.AppendLine(("{0,-22} {1}" -f "$($prop.Name):", $prop.Value))
            }
            [void]$sb.AppendLine()
        }

        # --- Packages ---
        if ($dump.Packages) {
            [void]$sb.AppendLine("### ПАКЕТЫ ###")
            [void]$sb.AppendLine("-" * 80)
            [void]$sb.AppendLine("Всего: $($dump.Packages.Total)")
            [void]$sb.AppendLine("Сторонних: $(@($dump.Packages.ThirdParty).Count)")
            [void]$sb.AppendLine("Системных: $(@($dump.Packages.System).Count)")
            [void]$sb.AppendLine("Отключённых: $(@($dump.Packages.Disabled).Count)")
            [void]$sb.AppendLine()

            if (@($dump.Packages.ThirdParty).Count -gt 0) {
                [void]$sb.AppendLine("--- Сторонние приложения ---")
                foreach ($p in $dump.Packages.ThirdParty) {
                    [void]$sb.AppendLine("  $p")
                }
                [void]$sb.AppendLine()
            }

            if (@($dump.Packages.Disabled).Count -gt 0) {
                [void]$sb.AppendLine("--- Отключённые приложения ---")
                foreach ($p in $dump.Packages.Disabled) {
                    [void]$sb.AppendLine("  $p")
                }
                [void]$sb.AppendLine()
            }
        }

        # --- Changes History ---
        if ($dump.ChangesHistory -and $dump.ChangesHistory.Changes) {
            [void]$sb.AppendLine("### ИСТОРИЯ ИЗМЕНЕНИЙ ###")
            [void]$sb.AppendLine("-" * 80)
            $changes = @($dump.ChangesHistory.Changes)
            [void]$sb.AppendLine("Всего: $($changes.Count)")
            [void]$sb.AppendLine()
            foreach ($c in $changes) {
                [void]$sb.AppendLine("  [$($c.Timestamp)] $($c.Type) — $($c.Target)")
                [void]$sb.AppendLine("    Восстановление: $($c.RestoreCommand)")
            }
            [void]$sb.AppendLine()
        }

        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("Конец дампа")
        [void]$sb.AppendLine("=" * 80)

        [System.IO.File]::WriteAllText($FilePath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
        Write-Log -Message "Дамп сохранён (TXT): $FilePath" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка экспорта TXT: $_" -Level "Error"
        return $false
    }
}

# ===== ДИАЛОГ ЭКСПОРТА =====
function Show-ExportDeviceDumpDialog {
    Add-Type -AssemblyName System.Windows.Forms

    # Спрашиваем формат
    $formatResult = [System.Windows.MessageBox]::Show(
        "Выберите формат:`n`nДа — JSON (структурированный)`nНет — TXT (читаемый)`nОтмена — отмена",
        "Экспорт дампа устройства",
        [System.Windows.MessageBoxButton]::YesNoCancel,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($formatResult -eq [System.Windows.MessageBoxResult]::Cancel) { return }
    $isJson = ($formatResult -eq [System.Windows.MessageBoxResult]::Yes)

    # Спрашиваем путь
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    if ($isJson) {
        $dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $dlg.FileName = "tv_dump_${timestamp}.json"
    } else {
        $dlg.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $dlg.FileName = "tv_dump_${timestamp}.txt"
    }

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    Write-Log -Message "=== Экспорт дампа ===" -Level "Info"

    if ($isJson) {
        $ok = Export-DeviceDumpJson -FilePath $dlg.FileName
    } else {
        $ok = Export-DeviceDumpTxt -FilePath $dlg.FileName
    }

    if ($ok) {
        $size = [math]::Round((Get-Item $dlg.FileName).Length / 1KB, 1)
        [System.Windows.MessageBox]::Show(
            "Дамп сохранён:`n`n$($dlg.FileName)`n`nРазмер: $size КБ",
            "Готово",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    } else {
        [System.Windows.MessageBox]::Show(
            "Не удалось сохранить дамп. Подробности в логе.",
            "Ошибка",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}