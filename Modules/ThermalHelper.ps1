# ============================================================================
#  Thermal Helper — мониторинг температур
# ============================================================================

function Invoke-ThermalAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== СПИСОК ТЕРМОДАТЧИКОВ =====
function Get-ThermalZones {
    Write-Log -Message "Читаю термодатчики..." -Level "Info"

    $zones = @()

    try {
        # Получаем список всех zone
        $listOut = Invoke-ThermalAdb @("shell", "ls", "/sys/class/thermal/")
        $zoneDirs = @()
        foreach ($line in ($listOut -split "`r?`n")) {
            if ($line -match '^(thermal_zone\d+)$') {
                $zoneDirs += $matches[1]
            }
        }

        foreach ($zone in $zoneDirs) {
            $type = (Invoke-ThermalAdb @("shell", "cat", "/sys/class/thermal/$zone/type")).Trim()
            $tempRaw = (Invoke-ThermalAdb @("shell", "cat", "/sys/class/thermal/$zone/temp")).Trim()

            if ($tempRaw -match '^-?\d+$') {
                $tempC = [int]$tempRaw / 1000.0
                $zones += [PSCustomObject]@{
                    Zone     = $zone
                    Type     = $type
                    TempC    = [math]::Round($tempC, 1)
                }
            }
        }

        Write-Log -Message "Найдено датчиков: $($zones.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения термодатчиков: $_" -Level "Error"
    }

    return ,$zones
}

# ===== ОДНА ТЕМПЕРАТУРА (для графика) =====
function Get-CpuTemperature {
    try {
        # Ищем зону с типом "cpu" или подобным
        $listOut = Invoke-ThermalAdb @("shell", "ls", "/sys/class/thermal/")
        foreach ($line in ($listOut -split "`r?`n")) {
            if ($line -match '^(thermal_zone\d+)$') {
                $zone = $matches[1]
                $type = (Invoke-ThermalAdb @("shell", "cat", "/sys/class/thermal/$zone/type")).Trim()
                if ($type -match 'cpu|soc|ap|big|tsensor') {
                    $tempRaw = (Invoke-ThermalAdb @("shell", "cat", "/sys/class/thermal/$zone/temp")).Trim()
                    if ($tempRaw -match '^-?\d+$') {
                        return [math]::Round([int]$tempRaw / 1000.0, 1)
                    }
                }
            }
        }
    } catch { }
    return $null
}