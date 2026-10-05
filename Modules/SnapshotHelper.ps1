# ============================================================================
#  Snapshot Helper — снимки состояния ТВ
#
#  Объединяет три старых функции: профили, дамп и проверку целостности.
#  Снимок — это JSON-файл .tvsnap с полным состоянием ТВ в конкретный момент:
#    - пакеты (installed / disabled / removed)
#    - системные настройки (animation, timeout, brightness, ADB, immersive)
#    - текущий лаунчер
#    - Wi-Fi и Bluetooth (информация)
#    - метаданные устройства (модель, Android, IP)
#
#  Снимки хранятся в папке Snapshots/ рядом с программой.
# ============================================================================

$script:SnapshotsDir = Join-Path $script:AppRoot "Snapshots"

# ============================================================================
#  СОЗДАНИЕ СНИМКА
# ============================================================================
function New-Snapshot {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Description = ""
    )

    if (-not $script:connected) {
        Write-Log -Message "Нет подключения к ТВ" -Level "Error"
        return $null
    }

    Write-Log -Message "=== Создание снимка: $Name ===" -Level "Info"

    $snapshot = [ordered]@{
        FormatVersion = "1.0"
        AppVersion    = "0.0.8"
        Name          = $Name
        Description   = $Description
        CreatedAt     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Device        = [ordered]@{
            Ip             = $script:deviceIp
            Model          = ""
            Manufacturer   = ""
            AndroidVersion = ""
            Serial         = ""
        }
        Packages      = @{
            Installed = @()
            Disabled  = @()
            Removed   = @()
        }
        Settings      = @{}
        Launcher      = ""
        Wifi          = @{}
        Bluetooth     = @{}
    }

    # ---- Метаданные устройства ----
    Write-Log -Message "  Читаю метаданные устройства..." -Level "Info"
    try {
        $snapshot.Device.Model          = (& $script:adbPath shell getprop ro.product.model 2>&1 | Out-String).Trim()
        $snapshot.Device.Manufacturer   = (& $script:adbPath shell getprop ro.product.manufacturer 2>&1 | Out-String).Trim()
        $snapshot.Device.AndroidVersion = (& $script:adbPath shell getprop ro.build.version.release 2>&1 | Out-String).Trim()
        $snapshot.Device.Serial         = (& $script:adbPath shell getprop ro.serialno 2>&1 | Out-String).Trim()
    } catch { }

    # ---- Пакеты ----
    Write-Log -Message "  Читаю пакеты..." -Level "Info"
    try {
        $installed = Get-InstalledPackagesSet
        $disabled  = Get-DisabledPackagesSet

        $installedList = @()
        foreach ($key in $installed.Keys) { $installedList += $key }

        $disabledList = @()
        foreach ($key in $disabled.Keys) { $disabledList += $key }

        $snapshot.Packages.Installed = @($installedList | Sort-Object)
        $snapshot.Packages.Disabled  = @($disabledList | Sort-Object)
        $snapshot.Packages.Removed   = @($script:RemovedPackages | Sort-Object)

        Write-Log -Message "    Установлено: $($installedList.Count), отключено: $($disabledList.Count), удалено: $($script:RemovedPackages.Count)" -Level "Info"
    } catch {
        Write-Log -Message "    Ошибка чтения пакетов: $_" -Level "Warning"
    }

    # ---- Настройки ----
    Write-Log -Message "  Читаю настройки..." -Level "Info"
    try {
        $settings = @{}

        # Animation
        $val = (& $script:adbPath shell settings get global window_animation_scale 2>&1 | Out-String).Trim()
        if ($val) { $settings["window_animation_scale"] = $val }

        $val = (& $script:adbPath shell settings get global transition_animation_scale 2>&1 | Out-String).Trim()
        if ($val) { $settings["transition_animation_scale"] = $val }

        $val = (& $script:adbPath shell settings get global animator_duration_scale 2>&1 | Out-String).Trim()
        if ($val) { $settings["animator_duration_scale"] = $val }

        # Timeout / brightness
        $val = (& $script:adbPath shell settings get system screen_off_timeout 2>&1 | Out-String).Trim()
        if ($val) { $settings["screen_off_timeout"] = $val }

        $val = (& $script:adbPath shell settings get system screen_brightness 2>&1 | Out-String).Trim()
        if ($val) { $settings["screen_brightness"] = $val }

        $val = (& $script:adbPath shell settings get system screen_brightness_mode 2>&1 | Out-String).Trim()
        if ($val) { $settings["screen_brightness_mode"] = $val }

        # Immersive
        $val = (& $script:adbPath shell settings get global policy_control 2>&1 | Out-String).Trim()
        if ($val) { $settings["policy_control"] = $val }

        # ADB
        $val = (& $script:adbPath shell settings get global adb_enabled 2>&1 | Out-String).Trim()
        if ($val) { $settings["adb_enabled"] = $val }

        $val = (& $script:adbPath shell settings get global development_settings_enabled 2>&1 | Out-String).Trim()
        if ($val) { $settings["development_settings_enabled"] = $val }

        $snapshot.Settings = $settings
        Write-Log -Message "    Прочитано настроек: $($settings.Count)" -Level "Info"
    } catch {
        Write-Log -Message "    Ошибка чтения настроек: $_" -Level "Warning"
    }

    # ---- Лаунчер ----
    Write-Log -Message "  Читаю текущий лаунчер..." -Level "Info"
    try {
        $out = & $script:adbPath shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1
        $outText = ($out | Out-String)
        foreach ($line in ($outText -split "`r?`n")) {
            $line = $line.Trim()
            if ($line -match '^([a-z][a-z0-9_\.]+)/([A-Za-z0-9_\.]+)$') {
                $snapshot.Launcher = "$($matches[1])/$($matches[2])"
                break
            }
        }
        Write-Log -Message "    Лаунчер: $($snapshot.Launcher)" -Level "Info"
    } catch { }

    # ---- Wi-Fi ----
    Write-Log -Message "  Читаю Wi-Fi..." -Level "Info"
    try {
        if (Get-Command Get-WifiInfo -ErrorAction SilentlyContinue) {
            $wifi = Get-WifiInfo
            $snapshot.Wifi = @{
                Enabled   = $wifi.Enabled
                Ssid      = $wifi.Ssid
                Ip        = $wifi.Ip
                Mac       = $wifi.Mac
                Gateway   = $wifi.Gateway
                Frequency = $wifi.Frequency
            }
        }
    } catch { }

    # ---- Bluetooth ----
    Write-Log -Message "  Читаю Bluetooth..." -Level "Info"
    try {
        if (Get-Command Get-BluetoothInfo -ErrorAction SilentlyContinue) {
            $bt = Get-BluetoothInfo
            $snapshot.Bluetooth = @{
                Enabled = $bt.Enabled
                Name    = $bt.Name
                Address = $bt.Address
            }
        }
    } catch { }

    # ---- Сохранение ----
    $savedPath = Save-Snapshot -Snapshot $snapshot
    if ($savedPath) {
        Write-Log -Message "=== Снимок сохранён: $savedPath ===" -Level "Success"
        return $savedPath
    }
    return $null
}

# ============================================================================
#  СОХРАНЕНИЕ СНИМКА В ФАЙЛ
# ============================================================================
function Save-Snapshot {
    param([PSCustomObject]$Snapshot)

    try {
        if (-not (Test-Path $script:SnapshotsDir)) {
            New-Item -ItemType Directory -Path $script:SnapshotsDir -Force | Out-Null
        }

        $safeName = $Snapshot.Name -replace '[^\w\s\-\.]', '_'
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $fileName = "${safeName}_${timestamp}.tvsnap"
        $filePath = Join-Path $script:SnapshotsDir $fileName

        $json = $Snapshot | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($filePath, $json, [System.Text.UTF8Encoding]::new($false))

        return $filePath
    } catch {
        Write-Log -Message "Ошибка сохранения снимка: $_" -Level "Error"
        return $null
    }
}

# ============================================================================
#  ЗАГРУЗКА СНИМКА ИЗ ФАЙЛА
# ============================================================================
function Load-Snapshot {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Log -Message "Файл снимка не найден: $FilePath" -Level "Error"
        return $null
    }

    try {
        $json = Get-Content -Raw -Path $FilePath -Encoding UTF8 | ConvertFrom-Json

        # Метаданные о файле
        $json | Add-Member -NotePropertyName "_FilePath" -NotePropertyValue $FilePath -Force
        $json | Add-Member -NotePropertyName "_FileName" -NotePropertyValue (Split-Path $FilePath -Leaf) -Force

        return $json
    } catch {
        Write-Log -Message "Ошибка чтения снимка: $_" -Level "Error"
        return $null
    }
}

# ============================================================================
#  СПИСОК ВСЕХ СНИМКОВ
# ============================================================================
function Get-Snapshots {
    if (-not (Test-Path $script:SnapshotsDir)) {
        return @()
    }

    $files = Get-ChildItem -Path $script:SnapshotsDir -Filter "*.tvsnap" -File |
             Sort-Object LastWriteTime -Descending

    $snapshots = @()
    foreach ($file in $files) {
        try {
            $json = Get-Content -Raw -Path $file.FullName -Encoding UTF8 | ConvertFrom-Json

            # Пакеты могут быть большими — сохраняем только метаданные
            $instCount    = 0
            $disCount     = 0
            $remCount     = 0
            if ($json.Packages) {
                if ($json.Packages.Installed) { $instCount = @($json.Packages.Installed).Count }
                if ($json.Packages.Disabled)  { $disCount  = @($json.Packages.Disabled).Count }
                if ($json.Packages.Removed)   { $remCount  = @($json.Packages.Removed).Count }
            }

            $snapshots += [PSCustomObject]@{
                FilePath       = $file.FullName
                FileName       = $file.Name
                Name           = if ($json.Name) { $json.Name } else { $file.BaseName }
                Description    = if ($json.Description) { $json.Description } else { "" }
                CreatedAt      = if ($json.CreatedAt) { $json.CreatedAt } else { $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") }
                DeviceIp       = if ($json.Device -and $json.Device.Ip) { $json.Device.Ip } else { "" }
                DeviceModel    = if ($json.Device -and $json.Device.Model) { $json.Device.Model } else { "" }
                AndroidVersion = if ($json.Device -and $json.Device.AndroidVersion) { $json.Device.AndroidVersion } else { "" }
                InstalledCount = $instCount
                DisabledCount  = $disCount
                RemovedCount   = $remCount
                FullData       = $json
            }
        } catch {
            Write-Log -Message "Ошибка чтения снимка $($file.Name): $_" -Level "Warning"
        }
    }

    return ,$snapshots
}

# ============================================================================
#  УДАЛЕНИЕ СНИМКА
# ============================================================================
function Remove-Snapshot {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return $false }

    try {
        Remove-Item -Path $FilePath -Force
        Write-Log -Message "Снимок удалён: $(Split-Path $FilePath -Leaf)" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка удаления: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ЭКСПОРТ СНИМКА В ФАЙЛ (копирование)
# ============================================================================
function Export-SnapshotToFile {
    param(
        [string]$SourcePath,
        [string]$DestPath
    )

    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log -Message "Снимок экспортирован: $DestPath" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка экспорта: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ИМПОРТ СНИМКА ИЗ ФАЙЛА
# ============================================================================
function Import-SnapshotFromFile {
    param([string]$SourcePath)

    if (-not (Test-Path $SourcePath)) {
        Write-Log -Message "Файл не найден: $SourcePath" -Level "Error"
        return $null
    }

    try {
        $json = Get-Content -Raw -Path $SourcePath -Encoding UTF8 | ConvertFrom-Json

        if (-not $json.FormatVersion) {
            Write-Log -Message "Неверный формат файла снимка" -Level "Error"
            return $null
        }

        if (-not (Test-Path $script:SnapshotsDir)) {
            New-Item -ItemType Directory -Path $script:SnapshotsDir -Force | Out-Null
        }

        $fileName = Split-Path $SourcePath -Leaf
        $destPath = Join-Path $script:SnapshotsDir $fileName

        # Если такое имя уже есть — добавляем суффикс
        if (Test-Path $destPath) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $timestamp = Get-Date -Format "HH-mm-ss"
            $fileName = "${baseName}_imported_$timestamp.tvsnap"
            $destPath = Join-Path $script:SnapshotsDir $fileName
        }

        Copy-Item -Path $SourcePath -Destination $destPath -Force
        Write-Log -Message "Снимок импортирован: $destPath" -Level "Success"
        return $destPath
    } catch {
        Write-Log -Message "Ошибка импорта: $_" -Level "Error"
        return $null
    }
}

# ============================================================================
#  СРАВНЕНИЕ СНИМКА С ТЕКУЩИМ СОСТОЯНИЕМ ТВ
# ============================================================================
function Compare-SnapshotWithCurrent {
    param([PSCustomObject]$Snapshot)

    Write-Log -Message "=== Сравнение снимка с текущим ТВ ===" -Level "Info"

    $result = [ordered]@{
        RefName        = $Snapshot.Name
        RefCreatedAt   = $Snapshot.CreatedAt
        RefDeviceIp    = if ($Snapshot.Device) { $Snapshot.Device.Ip } else { "" }
        IsSame         = $true
        Error          = ""

        Packages = [ordered]@{
            Added       = @()  # установлены после снимка
            Removed     = @()  # были в снимке, теперь удалены
            DisabledNow = @()  # были включены, сейчас отключены
            EnabledNow  = @()  # были отключены, сейчас включены
        }

        Settings = [ordered]@{
            Changed = @()  # массив объектов @{ Key; Snapshot; Current }
        }

        Launcher = [ordered]@{
            Snapshot = if ($Snapshot.Launcher) { $Snapshot.Launcher } else { "" }
            Current  = ""
            Changed  = $false
        }
    }

    try {
        # ===== Пакеты =====
        $nowInstalled = Get-InstalledPackagesSet
        $nowDisabled  = Get-DisabledPackagesSet

        $refInstalled = @()
        $refDisabled  = @()
        if ($Snapshot.Packages) {
            if ($Snapshot.Packages.Installed) { $refInstalled = @($Snapshot.Packages.Installed) }
            if ($Snapshot.Packages.Disabled)  { $refDisabled  = @($Snapshot.Packages.Disabled) }
        }

        # Установленные после снимка
        foreach ($pkg in $nowInstalled.Keys) {
            if ($pkg -notin $refInstalled) {
                $result.Packages.Added += $pkg
            }
        }

        # Удалённые (были в снимке, нет сейчас)
        foreach ($pkg in $refInstalled) {
            if (-not $nowInstalled.ContainsKey($pkg)) {
                $result.Packages.Removed += $pkg
            }
        }

        # Отключённые сейчас (в снимке были включены)
        foreach ($pkg in $nowDisabled.Keys) {
            if ($pkg -notin $refDisabled) {
                $result.Packages.DisabledNow += $pkg
            }
        }

        # Включённые обратно (в снимке отключены, сейчас включены)
        foreach ($pkg in $refDisabled) {
            if (-not $nowDisabled.ContainsKey($pkg) -and $nowInstalled.ContainsKey($pkg)) {
                $result.Packages.EnabledNow += $pkg
            }
        }

        # ===== Настройки =====
        $settingsToCheck = @(
            @{ Key = "window_animation_scale";     Namespace = "global" },
            @{ Key = "transition_animation_scale"; Namespace = "global" },
            @{ Key = "animator_duration_scale";    Namespace = "global" },
            @{ Key = "screen_off_timeout";         Namespace = "system" },
            @{ Key = "screen_brightness";          Namespace = "system" },
            @{ Key = "policy_control";             Namespace = "global" }
        )

        $refSettings = @{}
        if ($Snapshot.Settings) {
            foreach ($prop in $Snapshot.Settings.PSObject.Properties) {
                $refSettings[$prop.Name] = [string]$prop.Value
            }
        }

        foreach ($s in $settingsToCheck) {
            $key = $s.Key
            $ns  = $s.Namespace

            if (-not $refSettings.ContainsKey($key)) { continue }

            $refValue = $refSettings[$key]
            $curValue = (& $script:adbPath shell settings get $ns $key 2>&1 | Out-String).Trim()

            if ($refValue -ne $curValue) {
                $result.Settings.Changed += [PSCustomObject]@{
                    Key      = $key
                    Namespace = $ns
                    Snapshot = $refValue
                    Current  = $curValue
                }
            }
        }

        # ===== Лаунчер =====
        $curLauncher = ""
        $out = & $script:adbPath shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1
        $outText = ($out | Out-String)
        foreach ($line in ($outText -split "`r?`n")) {
            $line = $line.Trim()
            if ($line -match '^([a-z][a-z0-9_\.]+)/([A-Za-z0-9_\.]+)$') {
                $curLauncher = "$($matches[1])/$($matches[2])"
                break
            }
        }

        $result.Launcher.Current = $curLauncher
        $result.Launcher.Changed = ($curLauncher -ne $result.Launcher.Snapshot)

        # ===== Итог =====
        $result.IsSame = (
            $result.Packages.Added.Count       -eq 0 -and
            $result.Packages.Removed.Count     -eq 0 -and
            $result.Packages.DisabledNow.Count -eq 0 -and
            $result.Packages.EnabledNow.Count  -eq 0 -and
            $result.Settings.Changed.Count     -eq 0 -and
            -not $result.Launcher.Changed
        )

        Write-Log -Message "  Различия: +$($result.Packages.Added.Count) -$($result.Packages.Removed.Count) откл:$($result.Packages.DisabledNow.Count) вкл:$($result.Packages.EnabledNow.Count) настройки:$($result.Settings.Changed.Count) лаунчер:$($result.Launcher.Changed)" -Level "Info"
    } catch {
        $result.Error = "$_"
        Write-Log -Message "Ошибка сравнения: $_" -Level "Error"
    }

    return [PSCustomObject]$result
}

# ============================================================================
#  ПРИМЕНЕНИЕ СНИМКА К ТВ
# ============================================================================
function Apply-Snapshot {
    param(
        [PSCustomObject]$Snapshot,
        [switch]$SyncPackages,
        [switch]$SyncSettings,
        [switch]$SyncLauncher
    )

    if (-not $script:connected) {
        Write-Log -Message "Нет подключения к ТВ" -Level "Error"
        return $false
    }

    if (-not $SyncPackages -and -not $SyncSettings -and -not $SyncLauncher) {
        # По умолчанию всё
        $SyncPackages = $true
        $SyncSettings = $true
        $SyncLauncher = $true
    }

    Write-Log -Message "=== Применение снимка: $($Snapshot.Name) ===" -Level "Info"

    $stats = @{
        PackagesRestored = 0
        PackagesDisabled = 0
        PackagesEnabled  = 0
        SettingsApplied  = 0
        LauncherSet      = $false
    }

    # ===== Настройки =====
    if ($SyncSettings -and $Snapshot.Settings) {
        Write-Log -Message "  Применяю настройки..." -Level "Info"

        $settingsMap = @{
            "window_animation_scale"     = "global"
            "transition_animation_scale" = "global"
            "animator_duration_scale"    = "global"
            "screen_off_timeout"         = "system"
            "screen_brightness"          = "system"
            "screen_brightness_mode"     = "system"
            "policy_control"             = "global"
            "adb_enabled"                = "global"
            "development_settings_enabled" = "global"
        }

        foreach ($prop in $Snapshot.Settings.PSObject.Properties) {
            $key = $prop.Name
            $value = [string]$prop.Value

            if (-not $settingsMap.ContainsKey($key)) { continue }
            if ([string]::IsNullOrWhiteSpace($value) -or $value -eq "null") { continue }

            $ns = $settingsMap[$key]
            try {
                & $script:adbPath shell settings put $ns $key $value 2>&1 | Out-Null
                $stats.SettingsApplied++
                Write-Log -Message "    $ns.$key = $value" -Level "Info"
            } catch {
                Write-Log -Message "    Ошибка применения $key`: $_" -Level "Warning"
            }
        }
    }

    # ===== Пакеты =====
    if ($SyncPackages -and $Snapshot.Packages) {
        Write-Log -Message "  Синхронизирую пакеты..." -Level "Info"

        $nowInstalled = Get-InstalledPackagesSet
        $nowDisabled  = Get-DisabledPackagesSet

        $refInstalled = @()
        $refDisabled  = @()
        $refRemoved   = @()

        if ($Snapshot.Packages.Installed) { $refInstalled = @($Snapshot.Packages.Installed) }
        if ($Snapshot.Packages.Disabled)  { $refDisabled  = @($Snapshot.Packages.Disabled) }
        if ($Snapshot.Packages.Removed)   { $refRemoved   = @($Snapshot.Packages.Removed) }

        # 1. Восстановить удалённые (если возможно)
        foreach ($pkg in $refRemoved) {
            if (-not $nowInstalled.ContainsKey($pkg)) {
                try {
                    $out = & $script:adbPath shell cmd package install-existing $pkg 2>&1
                    $outText = ($out | Out-String).Trim()
                    if ($outText -match 'Success|installed') {
                        $stats.PackagesRestored++
                        Write-Log -Message "    Восстановлен: $pkg" -Level "Success"
                    }
                } catch { }
            }
        }

        # 2. Отключить то, что в снимке было отключено
        foreach ($pkg in $refDisabled) {
            if ($nowInstalled.ContainsKey($pkg) -and -not $nowDisabled.ContainsKey($pkg)) {
                try {
                    $out = & $script:adbPath shell pm disable-user --user 0 $pkg 2>&1
                    $outText = ($out | Out-String).Trim()
                    if ($outText -match 'new state: disabled') {
                        $stats.PackagesDisabled++
                        Write-Log -Message "    Отключён: $pkg" -Level "Info"
                    }
                } catch { }
            }
        }

        # 3. Включить то, что в снимке было включено, но сейчас отключено
        foreach ($pkg in $refInstalled) {
            if ($nowDisabled.ContainsKey($pkg) -and $pkg -notin $refDisabled) {
                try {
                    $out = & $script:adbPath shell pm enable $pkg 2>&1
                    $outText = ($out | Out-String).Trim()
                    if ($outText -match 'new state: enabled') {
                        $stats.PackagesEnabled++
                        Write-Log -Message "    Включён: $pkg" -Level "Info"
                    }
                } catch { }
            }
        }
    }

    # ===== Лаунчер =====
    if ($SyncLauncher -and $Snapshot.Launcher) {
        Write-Log -Message "  Устанавливаю лаунчер: $($Snapshot.Launcher)" -Level "Info"
        try {
            $out = & $script:adbPath shell cmd package set-home-activity $Snapshot.Launcher 2>&1
            $outText = ($out | Out-String).Trim()
            if ($outText -match 'Success|success' -or [string]::IsNullOrWhiteSpace($outText)) {
                $stats.LauncherSet = $true
                Write-Log -Message "    Лаунчер установлен" -Level "Success"
            }
        } catch { }
    }

    Write-Log -Message "=== Снимок применён ===" -Level "Success"
    Write-Log -Message "  Восстановлено пакетов: $($stats.PackagesRestored)" -Level "Info"
    Write-Log -Message "  Отключено: $($stats.PackagesDisabled), включено: $($stats.PackagesEnabled)" -Level "Info"
    Write-Log -Message "  Настроек применено: $($stats.SettingsApplied)" -Level "Info"
    Write-Log -Message "  Лаунчер: $(if ($stats.LauncherSet) { 'да' } else { 'нет' })" -Level "Info"

    return $stats
}

# ============================================================================
#  МИГРАЦИЯ СТАРЫХ ПРОФИЛЕЙ ИЗ config.json
# ============================================================================
function Migrate-LegacyProfiles {
    Write-Log -Message "Проверяю старые профили для миграции..." -Level "Info"

    $profiles = Get-Profiles
    if (-not $profiles -or @($profiles).Count -eq 0) {
        return 0
    }

    $migrated = 0
    foreach ($p in $profiles) {
        try {
            $snapshot = [ordered]@{
                FormatVersion = "1.0"
                AppVersion    = "0.0.8"
                Name          = "$($p.Name) (из старого профиля)"
                Description   = "Автоматически перенесён из старого формата"
                CreatedAt     = if ($p.SavedAt) { $p.SavedAt } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                Device        = [ordered]@{
                    Ip             = if ($p.Ip) { $p.Ip } else { "" }
                    Model          = ""
                    Manufacturer   = ""
                    AndroidVersion = ""
                    Serial         = ""
                }
                Packages      = @{
                    Installed = @()
                    Disabled  = @()
                    Removed   = @()
                }
                Settings      = @{}
                Launcher      = ""
                Wifi          = @{}
                Bluetooth     = @{}
            }

            # Пакеты
            foreach ($pkg in $p.Packages) {
                if ($pkg.State -eq "disabled") {
                    $snapshot.Packages.Disabled += $pkg.Package
                } elseif ($pkg.State -eq "removed") {
                    $snapshot.Packages.Removed += $pkg.Package
                }
            }

            # Настройки анимации
            if ($p.AnimationScale) {
                $snapshot.Settings["window_animation_scale"]     = $p.AnimationScale
                $snapshot.Settings["transition_animation_scale"] = $p.AnimationScale
                $snapshot.Settings["animator_duration_scale"]    = $p.AnimationScale
            }

            Save-Snapshot -Snapshot $snapshot | Out-Null
            $migrated++
        } catch {
            Write-Log -Message "Ошибка миграции профиля $($p.Name): $_" -Level "Warning"
        }
    }

    if ($migrated -gt 0) {
        Write-Log -Message "Мигрировано профилей: $migrated" -Level "Success"
    }

    return $migrated
}

# ============================================================================
#  ПРОСМОТР СОДЕРЖИМОГО РЕЗЕРВНОЙ КОПИИ
# ============================================================================
function Show-SnapshotDetailsDialog {
    param([PSCustomObject]$SnapshotMeta)

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Резервная копия: $($SnapshotMeta.Name)"
    $dialog.Width = 820
    $dialog.Height = 720
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#202020")
    )

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "20"

    $row1 = New-Object System.Windows.Controls.RowDefinition; $row1.Height = "Auto"
    $row2 = New-Object System.Windows.Controls.RowDefinition; $row2.Height = "*"
    $row3 = New-Object System.Windows.Controls.RowDefinition; $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row1)
    $grid.RowDefinitions.Add($row2)
    $grid.RowDefinitions.Add($row3)

    # ===== Заголовок =====
    $headerStack = New-Object System.Windows.Controls.StackPanel

    $titleTb = New-Object System.Windows.Controls.TextBlock
    $titleTb.Text = $SnapshotMeta.Name
    $titleTb.FontSize = 20
    $titleTb.FontWeight = "Bold"
    $titleTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $titleTb.TextWrapping = "Wrap"
    $titleTb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
    $headerStack.Children.Add($titleTb) | Out-Null

    $metaTb = New-Object System.Windows.Controls.TextBlock
    $metaTb.FontSize = 12
    $metaTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $metaTb.TextWrapping = "Wrap"
    $metaTb.Text = "Создано: $($SnapshotMeta.CreatedAt)   ·   Устройство: $($SnapshotMeta.DeviceModel)   ·   IP: $($SnapshotMeta.DeviceIp)"
    $headerStack.Children.Add($metaTb) | Out-Null

    if ($SnapshotMeta.Description) {
        $descTb = New-Object System.Windows.Controls.TextBlock
        $descTb.FontSize = 12
        $descTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $descTb.TextWrapping = "Wrap"
        $descTb.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
        $descTb.Text = $SnapshotMeta.Description
        $headerStack.Children.Add($descTb) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetRow($headerStack, 0)
    $grid.Children.Add($headerStack) | Out-Null

    # ===== Скролл с содержимым =====
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    $scroll.Margin = New-Object System.Windows.Thickness(0, 15, 0, 0)
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $content = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $content

    $data = $SnapshotMeta.FullData

    # ===== Устройство =====
    if ($data.Device) {
        $content.Children.Add((New-SnapshotSection -Title "Устройство")) | Out-Null

        $rows = @(
            @{ Label = "IP";        Value = $data.Device.Ip },
            @{ Label = "Модель";    Value = $data.Device.Model },
            @{ Label = "Бренд";     Value = $data.Device.Manufacturer },
            @{ Label = "Android";   Value = $data.Device.AndroidVersion },
            @{ Label = "Серийный";  Value = $data.Device.Serial }
        )

        $content.Children.Add((New-SnapshotKeyValueCard -Rows $rows)) | Out-Null
    }

    # ===== Пакеты =====
    if ($data.Packages) {
        $installed = @()
        $disabled  = @()
        $removed   = @()
        if ($data.Packages.Installed) { $installed = @($data.Packages.Installed) }
        if ($data.Packages.Disabled)  { $disabled  = @($data.Packages.Disabled) }
        if ($data.Packages.Removed)   { $removed   = @($data.Packages.Removed) }

        $content.Children.Add((New-SnapshotSection -Title "Пакеты")) | Out-Null

        $content.Children.Add((New-SnapshotListCard `
            -Title "Установлено" `
            -Count $installed.Count `
            -Items $installed `
            -Color "#6CCB5F")) | Out-Null

        $content.Children.Add((New-SnapshotListCard `
            -Title "Отключено" `
            -Count $disabled.Count `
            -Items $disabled `
            -Color "#FFC83D")) | Out-Null

        $content.Children.Add((New-SnapshotListCard `
            -Title "Удалено" `
            -Count $removed.Count `
            -Items $removed `
            -Color "#FF6B6B")) | Out-Null
    }

    # ===== Настройки =====
    if ($data.Settings) {
        $content.Children.Add((New-SnapshotSection -Title "Системные настройки")) | Out-Null

        $rows = @()
        foreach ($prop in $data.Settings.PSObject.Properties) {
            $rows += @{ Label = $prop.Name; Value = [string]$prop.Value }
        }

        if ($rows.Count -gt 0) {
            $content.Children.Add((New-SnapshotKeyValueCard -Rows $rows)) | Out-Null
        } else {
            $content.Children.Add((New-SnapshotEmptyCard -Text "Настройки не сохранены")) | Out-Null
        }
    }

    # ===== Лаунчер =====
    if ($data.Launcher) {
        $content.Children.Add((New-SnapshotSection -Title "Лаунчер")) | Out-Null

        $rows = @(
            @{ Label = "Activity"; Value = $data.Launcher }
        )
        $content.Children.Add((New-SnapshotKeyValueCard -Rows $rows)) | Out-Null
    }

    # ===== Wi-Fi =====
    if ($data.Wifi) {
        $content.Children.Add((New-SnapshotSection -Title "Wi-Fi")) | Out-Null

        $rows = @(
            @{ Label = "Включён";   Value = if ($data.Wifi.Enabled) { "да" } else { "нет" } },
            @{ Label = "SSID";      Value = $data.Wifi.Ssid },
            @{ Label = "IP";        Value = $data.Wifi.Ip },
            @{ Label = "MAC";       Value = $data.Wifi.Mac },
            @{ Label = "Шлюз";      Value = $data.Wifi.Gateway },
            @{ Label = "Частота";   Value = $data.Wifi.Frequency }
        )
        $content.Children.Add((New-SnapshotKeyValueCard -Rows $rows)) | Out-Null
    }

    # ===== Bluetooth =====
    if ($data.Bluetooth) {
        $content.Children.Add((New-SnapshotSection -Title "Bluetooth")) | Out-Null

        $rows = @(
            @{ Label = "Включён"; Value = if ($data.Bluetooth.Enabled) { "да" } else { "нет" } },
            @{ Label = "Имя";     Value = $data.Bluetooth.Name },
            @{ Label = "MAC";     Value = $data.Bluetooth.Address }
        )
        $content.Children.Add((New-SnapshotKeyValueCard -Rows $rows)) | Out-Null
    }

    # ===== Кнопки =====
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    $btnPanel.Margin = New-Object System.Windows.Thickness(0, 15, 0, 0)
    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnClose.Padding = New-Object System.Windows.Thickness(15, 8, 15, 8)
    $btnClose.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

# ============================================================================
#  ВСПОМОГАТЕЛЬНЫЕ UI-ФУНКЦИИ ДЛЯ ДИАЛОГА ПРОСМОТРА
# ============================================================================
function New-SnapshotSection {
    param([string]$Title)

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Title
    $tb.FontSize = 14
    $tb.FontWeight = "Bold"
    $tb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $tb.Margin = New-Object System.Windows.Thickness(0, 15, 0, 8)
    return $tb
}

function New-SnapshotKeyValueCard {
    param([array]$Rows)

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $card.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $card.BorderThickness = "1"
    $card.CornerRadius = "6"
    $card.Padding = New-Object System.Windows.Thickness(12)

    $stack = New-Object System.Windows.Controls.StackPanel

    foreach ($row in $Rows) {
        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)

        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = "180"
        $col2 = New-Object System.Windows.Controls.ColumnDefinition
        $col2.Width = "*"
        $grid.ColumnDefinitions.Add($col1)
        $grid.ColumnDefinitions.Add($col2)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $row.Label
        $lbl.FontSize = 12
        $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        $grid.Children.Add($lbl) | Out-Null

        $val = New-Object System.Windows.Controls.TextBlock
        $val.Text = if ($row.Value) { [string]$row.Value } else { "—" }
        $val.FontSize = 12
        $val.FontFamily = "Consolas"
        $val.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $val.TextWrapping = "Wrap"
        [System.Windows.Controls.Grid]::SetColumn($val, 1)
        $grid.Children.Add($val) | Out-Null

        $stack.Children.Add($grid) | Out-Null
    }

    $card.Child = $stack
    return $card
}

function New-SnapshotListCard {
    param(
        [string]$Title,
        [int]$Count,
        [array]$Items,
        [string]$Color
    )

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $card.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $card.BorderThickness = "1"
    $card.CornerRadius = "6"
    $card.Padding = New-Object System.Windows.Thickness(12)
    $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)

    $stack = New-Object System.Windows.Controls.StackPanel

    $headerPanel = New-Object System.Windows.Controls.StackPanel
    $headerPanel.Orientation = "Horizontal"

    $titleTb = New-Object System.Windows.Controls.TextBlock
    $titleTb.Text = $Title
    $titleTb.FontSize = 13
    $titleTb.FontWeight = "Bold"
    $titleTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    )
    $headerPanel.Children.Add($titleTb) | Out-Null

    $countTb = New-Object System.Windows.Controls.TextBlock
    $countTb.Text = "   ($Count)"
    $countTb.FontSize = 12
    $countTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $headerPanel.Children.Add($countTb) | Out-Null

    $stack.Children.Add($headerPanel) | Out-Null

    if ($Count -eq 0) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "  (пусто)"
        $empty.FontSize = 11
        $empty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
        )
        $empty.Margin = New-Object System.Windows.Thickness(10, 4, 0, 0)
        $stack.Children.Add($empty) | Out-Null
    } else {
        $listStack = New-Object System.Windows.Controls.StackPanel
        $listStack.Margin = New-Object System.Windows.Thickness(10, 6, 0, 0)

        $maxShow = 100
        $shown = 0
        foreach ($item in $Items) {
            if ($shown -ge $maxShow) {
                $moreTb = New-Object System.Windows.Controls.TextBlock
                $moreTb.Text = "  ... и ещё $($Items.Count - $maxShow)"
                $moreTb.FontSize = 11
                $moreTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
                )
                $moreTb.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
                $listStack.Children.Add($moreTb) | Out-Null
                break
            }

            $itemTb = New-Object System.Windows.Controls.TextBlock
            $itemTb.Text = "  $item"
            $itemTb.FontFamily = "Consolas"
            $itemTb.FontSize = 11
            $itemTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
            )
            $itemTb.Margin = New-Object System.Windows.Thickness(0, 1, 0, 1)
            $listStack.Children.Add($itemTb) | Out-Null
            $shown++
        }

        $stack.Children.Add($listStack) | Out-Null
    }

    $card.Child = $stack
    return $card
}

function New-SnapshotEmptyCard {
    param([string]$Text)

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $card.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $card.BorderThickness = "1"
    $card.CornerRadius = "6"
    $card.Padding = New-Object System.Windows.Thickness(12)

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 12
    $tb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )

    $card.Child = $tb
    return $card
}