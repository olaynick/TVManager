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

# ===== СПИСОК ПРИЛОЖЕНИЙ С АВТОЗАПУСКОМ =====
function Get-AppsWithAutostart {
    Write-Log -Message "Читаю список приложений..." -Level "Info"

    $result = @()

    try {
        # Получаем сторонние приложения (у системных обычно нет смысла ограничивать)
        $thirdPartyRaw = Invoke-AppOpsAdb @("shell", "pm", "list", "packages", "-3")
        $thirdParty = @()
        foreach ($line in ($thirdPartyRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $thirdParty += $matches[1].Trim()
            }
        }

        # Получаем системные приложения (без GMS-ядра) — тоже интересны
        $systemRaw = Invoke-AppOpsAdb @("shell", "pm", "list", "packages", "-s")
        $system = @()
        foreach ($line in ($systemRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $pkg = $matches[1].Trim()
                # Исключаем критичные системные
                if ($pkg -match '^com\.(android|google)\.' -or
                    $pkg -match '^com\.tcl\.(systemserver|providers\.config|autopair)' -or
                    $pkg -match '^com\.mediatek\.' -or
                    $pkg -match '^com\.dolby\.') {
                    continue
                }
                $system += $pkg
            }
        }

        # Читаем appops для каждой группы
        $allPkgs = @($thirdParty) + @($system)

        foreach ($pkg in $allPkgs) {
            $bgOp = "default"
            $bootOp = "default"

            try {
                # RUN_IN_BACKGROUND — фоновая активность
                $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "get", $pkg, "RUN_IN_BACKGROUND")
                if ($out -match 'RUN_IN_BACKGROUND:\s*(\w+)') {
                    $bgOp = $matches[1]
                }

                # BOOT_COMPLETED — автозапуск
                $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "get", $pkg, "BOOT_COMPLETED")
                if ($out -match 'BOOT_COMPLETED:\s*(\w+)') {
                    $bootOp = $matches[1]
                }
            } catch { }

            $result += [PSCustomObject]@{
                Package     = $pkg
                IsSystem    = ($pkg -in $system)
                Background  = $bgOp
                Autostart   = $bootOp
            }
        }

        Write-Log -Message "Прочитано пакетов: $($result.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения appops: $_" -Level "Error"
    }

    return ,$result
}

# ===== УСТАНОВКА РАЗРЕШЕНИЙ =====
function Set-AppOpsPermission {
    param(
        [string]$Package,
        [string]$Op,        # RUN_IN_BACKGROUND / BOOT_COMPLETED / RUN_ANY_IN_BACKGROUND
        [string]$Mode       # allow / deny / default / ignore
    )

    try {
        $out = Invoke-AppOpsAdb @("shell", "cmd", "appops", "set", $Package, $Op, $Mode)
        if ($out -match 'error|Error|Exception|Security') {
            Write-Log -Message "Ошибка $Op для $Package`: $out" -Level "Warning"
            return $false
        }
        return $true
    } catch {
        Write-Log -Message "Ошибка: $_" -Level "Error"
        return $false
    }
}

# ===== ПАКЕТНАЯ УСТАНОВКА =====
function Set-AppOpsBatch {
    param(
        [array]$Packages,
        [string]$Op,
        [string]$Mode
    )

    $ok = 0
    foreach ($pkg in $Packages) {
        if (Set-AppOpsPermission -Package $pkg -Op $Op -Mode $Mode) {
            $ok++
        }
    }
    return $ok
}