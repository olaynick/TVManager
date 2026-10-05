# ============================================================================
#  AppOps Helper — управление фоновой активностью и автозапуском
# ============================================================================

function Invoke-AppOpsAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ============================================================================
#  ПРОВЕРКА: ПОДДЕРЖИВАЕТСЯ ЛИ ОПЕРАЦИЯ BOOT_COMPLETED
#  На стандартном AOSP (в т.ч. TCL) этой операции нет.
#  Проверяем один раз на первом же пакете.
# ============================================================================
function Test-BootCompletedSupported {
    param([string]$TestPackage = "com.android.systemui")

    $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "get", $TestPackage, "BOOT_COMPLETED")
    if ($out -match 'Unknown operation string' -or $out -match 'No operations') {
        return $false
    }
    if ($out -match 'BOOT_COMPLETED:') {
        return $true
    }
    return $false
}

# ============================================================================
#  СПИСОК ПРИЛОЖЕНИЙ С АВТОЗАПУСКОМ И СТАТУСАМИ
# ============================================================================
function Get-AppsWithAutostart {
    Write-Log -Message "Читаю список приложений..." -Level "Info"

    $result = @()

    try {
        # ---- Проверяем, поддерживается ли BOOT_COMPLETED на этой прошивке ----
        $bootSupported = Test-BootCompletedSupported
        if ($bootSupported) {
            Write-Log -Message "  Автозапуск (BOOT_COMPLETED): поддерживается" -Level "Info"
        } else {
            Write-Log -Message "  Автозапуск (BOOT_COMPLETED): не поддерживается прошивкой" -Level "Warning"
        }

        # ---- Отключённые пакеты ----
        $disabledRaw = Invoke-AppOpsAdb @("shell", "pm", "list", "packages", "-d")
        $disabledSet = @{}
        foreach ($line in ($disabledRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $disabledSet[$matches[1].Trim()] = $true
            }
        }

        # ---- Сторонние приложения ----
        $thirdPartyRaw = Invoke-AppOpsAdb @("shell", "pm", "list", "packages", "-3")
        $thirdParty = @()
        foreach ($line in ($thirdPartyRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $thirdParty += $matches[1].Trim()
            }
        }

        # ---- Системные приложения (кроме критичных) ----
        $systemRaw = Invoke-AppOpsAdb @("shell", "pm", "list", "packages", "-s")
        $system = @()
        foreach ($line in ($systemRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $pkg = $matches[1].Trim()
                if ($pkg -match '^com\.(android|google)\.' -or
                    $pkg -match '^com\.tcl\.(systemserver|providers\.config|autopair)' -or
                    $pkg -match '^com\.mediatek\.' -or
                    $pkg -match '^com\.dolby\.') {
                    continue
                }
                $system += $pkg
            }
        }

        $allPkgs = @($thirdParty) + @($system)

        # ---- Читаем appops для каждого ----
        foreach ($pkg in $allPkgs) {
            $bgOp = "default"
            $bootOp = "unsupported"
            $isDisabled = $disabledSet.ContainsKey($pkg)

            try {
                # RUN_IN_BACKGROUND — универсальная операция
                $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "get", $pkg, "RUN_IN_BACKGROUND")
                if ($out -match 'RUN_IN_BACKGROUND:\s*(\w+)') {
                    $bgOp = $matches[1]
                }

                # BOOT_COMPLETED — только если поддерживается
                if ($bootSupported) {
                    $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "get", $pkg, "BOOT_COMPLETED")
                    if ($out -match 'BOOT_COMPLETED:\s*(\w+)') {
                        $bootOp = $matches[1]
                    } else {
                        $bootOp = "default"
                    }
                }
            } catch { }

            $result += [PSCustomObject]@{
                Package         = $pkg
                IsSystem        = ($pkg -in $system)
                IsDisabled      = $isDisabled
                Background      = $bgOp
                Autostart       = $bootOp
                BootSupported   = $bootSupported
            }
        }

        Write-Log -Message "Прочитано пакетов: $($result.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения appops: $_" -Level "Error"
    }

    return ,$result
}

# ============================================================================
#  УСТАНОВКА РАЗРЕШЕНИЙ
#  Возвращает объект: @{ Success; Unsupported; Message }
# ============================================================================
function Set-AppOpsPermission {
    param(
        [string]$Package,
        [string]$Op,
        [string]$Mode
    )

    try {
        $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "set", $Package, $Op, $Mode)
        $outText = ($out | Out-String).Trim()

        if ($outText -match 'Unknown operation string') {
            return @{ Success = $false; Unsupported = $true; Message = "Операция $Op не поддерживается прошивкой" }
        }
        if ($outText -match 'error|Error|Exception|Security') {
            return @{ Success = $false; Unsupported = $false; Message = $outText }
        }
        return @{ Success = $true; Unsupported = $false; Message = "OK" }
    } catch {
        return @{ Success = $false; Unsupported = $false; Message = "$_" }
    }
}

# ============================================================================
#  ПАКЕТНАЯ УСТАНОВКА
# ============================================================================
function Set-AppOpsBatch {
    param(
        [array]$Packages,
        [string]$Op,
        [string]$Mode
    )

    $ok = 0
    $unsupported = $false
    foreach ($pkg in $Packages) {
        $r = Set-AppOpsPermission -Package $pkg -Op $Op -Mode $Mode
        if ($r.Success) { $ok++ }
        if ($r.Unsupported) { $unsupported = $true }
    }
    return @{ Ok = $ok; Unsupported = $unsupported }
}