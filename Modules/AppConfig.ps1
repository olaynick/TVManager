# ============================================================================
#  КОНФИГ ПРИЛОЖЕНИЯ
# ============================================================================

$script:ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config.json"
$script:Config = $null

function Get-DefaultConfig {
    return [PSCustomObject]@{
        LastIp              = ""
        AutoConnect         = $false
        LastApkFolder       = ""
        LastFileManagerPath = "/sdcard/"
        WindowWidth         = 900
        WindowHeight        = 700
        SavedProfiles       = @()
    }
}

function Load-AppConfig {
    if (Test-Path $script:ConfigPath) {
        try {
            $json = Get-Content $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $default = Get-DefaultConfig
            foreach ($prop in $default.PSObject.Properties) {
                if (-not $json.PSObject.Properties[$prop.Name]) {
                    $json | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
                }
            }
            $script:Config = $json
            Write-Log -Message "Конфиг загружен: $($script:ConfigPath)" -Level "Info"
        } catch {
            Write-Log -Message "Ошибка чтения конфига: $_" -Level "Warning"
            $script:Config = Get-DefaultConfig
        }
    } else {
        $script:Config = Get-DefaultConfig
        Save-AppConfig
        Write-Log -Message "Создан новый конфиг: $($script:ConfigPath)" -Level "Info"
    }
}

function Save-AppConfig {
    try {
        $dir = Split-Path $script:ConfigPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $script:Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ConfigPath -Encoding UTF8
    } catch {
        Write-Log -Message "Ошибка сохранения конфига: $_" -Level "Error"
    }
}

function Set-ConfigValue {
    param([string]$Key, $Value)
    if ($script:Config.PSObject.Properties[$Key]) {
        $script:Config.$Key = $Value
    } else {
        $script:Config | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
    }
    Save-AppConfig
}

function Get-ConfigValue {
    param([string]$Key)
    if ($script:Config.PSObject.Properties[$Key]) {
        return $script:Config.$Key
    }
    return $null
}

# ============================================================================
#  ПРОФИЛИ УСТРОЙСТВ
# ============================================================================

function Get-Profiles {
    $profiles = Get-ConfigValue -Key "SavedProfiles"
    if (-not $profiles) { return @() }
    if ($profiles -is [System.Management.Automation.PSCustomObject]) {
        return @($profiles)
    }
    if ($profiles -is [array]) {
        return $profiles
    }
    return @($profiles)
}

function Save-Profile {
    param(
        [string]$Name,
        [string]$Ip,
        [array]$Packages = @(),
        [array]$PackagesToEnable = @(),
        [array]$ThirdPartyPackages = @(),
        [string]$AnimationScale = "",
        [bool]$OtaDisabled = $false
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Ip)) {
        return $false
    }

    $profiles = Get-Profiles
    $profiles = @($profiles)

    $newProfile = [PSCustomObject]@{
        Name               = $Name
        Ip                 = $Ip
        Packages           = @($Packages)
        PackagesToEnable   = @($PackagesToEnable)
        ThirdPartyPackages = @($ThirdPartyPackages)
        AnimationScale     = $AnimationScale
        OtaDisabled        = $OtaDisabled
        SavedAt            = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $existing = $profiles | Where-Object { $_.Name -eq $Name }
    if ($existing) {
        $profiles = @($profiles | ForEach-Object {
            if ($_.Name -eq $Name) { $newProfile } else { $_ }
        })
    } else {
        $profiles = @($profiles) + @($newProfile)
    }

    Set-ConfigValue -Key "SavedProfiles" -Value @($profiles)
    Write-Log -Message "Профиль сохранён: $Name ($Ip)" -Level "Success"
    Write-Log -Message "  Отключённых/удалённых: $($Packages.Count)" -Level "Info"
    Write-Log -Message "  Включённых: $($PackagesToEnable.Count)" -Level "Info"
    Write-Log -Message "  Сторонних: $($ThirdPartyPackages.Count)" -Level "Info"
    return $true
}

function Remove-Profile {
    param([string]$Name)
    $profiles = Get-Profiles
    $profiles = @($profiles | Where-Object { $_.Name -ne $Name })
    Set-ConfigValue -Key "SavedProfiles" -Value @($profiles)
    Write-Log -Message "Профиль удалён: $Name" -Level "Success"
    return $true
}

# ============================================================================
#  ПРИМЕНЕНИЕ ПРОФИЛЯ
# ============================================================================
function Apply-Profile {
    param([PSCustomObject]$Profile)

    if (-not $script:connected) {
        Write-Log -Message "Нет подключения к ТВ" -Level "Error"
        return $false
    }

    Write-Log -Message "=== Применяю профиль '$($Profile.Name)' ===" -Level "Info"

    Write-Log -Message "Читаю текущее состояние ТВ..." -Level "Info"
    $installedNow = Get-InstalledPackagesSet
    $disabledNow = Get-DisabledPackagesSet

    # ===== Настройки анимации =====
    if ($Profile.AnimationScale) {
        Write-Log -Message "Устанавливаю анимацию: $($Profile.AnimationScale)" -Level "Info"
        & $script:adbPath shell settings put global window_animation_scale $Profile.AnimationScale
        & $script:adbPath shell settings put global transition_animation_scale $Profile.AnimationScale
        & $script:adbPath shell settings put global animator_duration_scale $Profile.AnimationScale
    }

    # ===== OTA =====
    if ($Profile.OtaDisabled -eq $true) {
        Write-Log -Message "Отключаю OTA..." -Level "Info"
        foreach ($item in $script:otaPackages) {
            Disable-Package -Package $item.Package | Out-Null
        }
        $script:OtaDisabled = $true
    } elseif ($Profile.OtaDisabled -eq $false) {
        Write-Log -Message "Включаю OTA..." -Level "Info"
        foreach ($item in $script:otaPackages) {
            Enable-Package -Package $item.Package | Out-Null
        }
        $script:OtaDisabled = $false
    }

    # ===== Синхронизация пакетов =====
    $toEnable = @()
    $toDisable = @()
    $toRemove = @()

    foreach ($p in $Profile.Packages) {
        $pkgName = $p.Package
        $state = $p.State

        if ($state -eq "disabled") {
            if ($installedNow.ContainsKey($pkgName) -and -not $disabledNow.ContainsKey($pkgName)) {
                $toDisable += $pkgName
            }
        } elseif ($state -eq "removed") {
            if ($installedNow.ContainsKey($pkgName)) {
                $toRemove += $pkgName
            }
        }
    }

    foreach ($p in $Profile.PackagesToEnable) {
        $pkgName = $p.Package
        if ($disabledNow.ContainsKey($pkgName)) {
            $toEnable += $pkgName
        }
    }

    Write-Log -Message "  К включению: $($toEnable.Count)" -Level "Info"
    Write-Log -Message "  К отключению: $($toDisable.Count)" -Level "Info"
    Write-Log -Message "  К удалению: $($toRemove.Count)" -Level "Info"

    # ===== Включение =====
    foreach ($pkg in $toEnable) {
        if (Enable-Package -Package $pkg) {
            Write-Log -Message "  Включён: $pkg" -Level "Success"
        }
    }

    # ===== Отключение =====
    foreach ($pkg in $toDisable) {
        if (Disable-Package -Package $pkg) {
            Write-Log -Message "  Отключён: $pkg" -Level "Success"
            Save-Change -Type "package_disabled" -Target $pkg -RestoreCommand "adb shell pm enable $pkg"
        }
    }

    # ===== Удаление =====
    foreach ($pkg in $toRemove) {
        # Remove-Package теперь возвращает объект @{Success; Method; Message}
        $rmResult = Remove-Package -Package $pkg -Mode "auto"

        if ($rmResult.Success) {
            Write-Log -Message "  Удалён ($($rmResult.Method)): $pkg" -Level "Success"

            if ($script:RemovedPackages -notcontains $pkg) {
                $script:RemovedPackages += $pkg
            }

            # Формируем команду отката в зависимости от метода
            $restoreCmd = switch ($rmResult.Method) {
                "user0"   { "adb shell cmd package install-existing $pkg" }
                "all"     { "adb shell cmd package install-existing $pkg" }
                "disable" { "adb shell pm enable $pkg" }
                default   { "adb shell cmd package install-existing $pkg" }
            }

            Save-Change -Type "package_removed" -Target $pkg -RestoreCommand $restoreCmd
        } else {
            Write-Log -Message "  Не удалось обработать: $pkg ($($rmResult.Message))" -Level "Warning"
        }
    }

    Save-AllChanges
    Write-Log -Message "=== Профиль применён ===" -Level "Success"
    return $true
}