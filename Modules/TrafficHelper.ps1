# ============================================================================
#  Traffic Helper — мониторинг сетевого трафика ТВ
#
#  Источники данных:
#   • /proc/net/dev          — счётчики RX/TX по интерфейсам (байты)
#   • /proc/net/xt_qtaguid   — не всегда доступен на Android TV
#   • dumpsys netstats       — статистика по UID (приложения)
# ============================================================================

function Invoke-TrafficAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ============================================================================
#  ТЕКУЩИЕ СЧЁТЧИКИ ИНТЕРФЕЙСОВ
#  Возвращает: @{ Interface = @{ RxBytes; TxBytes; RxPackets; TxPackets } }
# ============================================================================
function Get-NetworkCounters {
    $result = @{}

    try {
        $raw = Invoke-TrafficAdb @("shell", "cat", "/proc/net/dev")
        if (-not $raw) {
            Write-Log -Message "Не удалось прочитать /proc/net/dev" -Level "Warning"
            return $result
        }

        # Формат строки (после двух строк заголовка):
        #   wlan0: 12345678 12345 0 0 0 0 0 0 87654321 12345 0 0 0 0 0 0
        #    ↑ iface   ↑RX bytes ↑RX packets            ↑TX bytes ↑TX packets
        foreach ($line in ($raw -split "`r?`n")) {
            if ($line -match '^\s*([a-zA-Z0-9_]+):\s+(.+)$') {
                $iface = $matches[1]
                $fields = ($matches[2] -split '\s+') | Where-Object { $_ -ne "" }

                if ($fields.Count -ge 16) {
                    $result[$iface] = @{
                        RxBytes   = [int64]$fields[0]
                        RxPackets = [int64]$fields[1]
                        TxBytes   = [int64]$fields[8]
                        TxPackets = [int64]$fields[9]
                    }
                }
            }
        }

        Write-Log -Message "Прочитано интерфейсов: $($result.Keys.Count)" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка чтения счётчиков: $_" -Level "Error"
    }

    return $result
}

# ============================================================================
#  ТЕКУЩИЙ ИНТЕРФЕЙС (wlan0 / eth0)
# ============================================================================
function Get-ActiveTrafficInterface {
    $counters = Get-NetworkCounters

    # Приоритет: wlan0, потом eth0, потом всё, что не lo
    if ($counters.ContainsKey("wlan0")) { return "wlan0" }
    if ($counters.ContainsKey("eth0"))  { return "eth0" }

    foreach ($k in $counters.Keys) {
        if ($k -ne "lo" -and $k -notmatch '^rmnet') {
            return $k
        }
    }
    return $null
}

# ============================================================================
#  СКОРОСТЬ (дельты между двумя замерами)
#  Возвращает: @{ RxBps; TxBps; RxBytes; TxBytes; TotalRx; TotalTx }
# ============================================================================
function Get-TrafficSpeed {
    param(
        [hashtable]$PrevCounters,
        [string]$Interface,
        [double]$ElapsedSeconds
    )

    $result = @{
        RxBps    = 0
        TxBps    = 0
        RxBytes  = 0
        TxBytes  = 0
        TotalRx  = 0
        TotalTx  = 0
    }

    if (-not $Interface -or $ElapsedSeconds -le 0) { return $result }

    $curr = Get-NetworkCounters
    if (-not $curr.ContainsKey($Interface)) { return $result }
    if (-not $PrevCounters -or -not $PrevCounters.ContainsKey($Interface)) {
        $result.TotalRx = $curr[$Interface].RxBytes
        $result.TotalTx = $curr[$Interface].TxBytes
        return $result
    }

    $prev = $PrevCounters[$Interface]
    $now  = $curr[$Interface]

    $rxDelta = $now.RxBytes - $prev.RxBytes
    $txDelta = $now.TxBytes - $prev.TxBytes

    # Защита от переполнения / сброса счётчиков
    if ($rxDelta -lt 0) { $rxDelta = 0 }
    if ($txDelta -lt 0) { $txDelta = 0 }

    $result.RxBytes = $rxDelta
    $result.TxBytes = $txDelta
    $result.RxBps   = [math]::Round($rxDelta / $ElapsedSeconds, 0)
    $result.TxBps   = [math]::Round($txDelta / $ElapsedSeconds, 0)
    $result.TotalRx = $now.RxBytes
    $result.TotalTx = $now.TxBytes

    return $result
}

# ============================================================================
#  ФОРМАТИРОВАНИЕ СКОРОСТИ / РАЗМЕРА
# ============================================================================
function Format-ByteRate {
    param([double]$BytesPerSecond)

    if ($BytesPerSecond -lt 1024) {
        return "$([math]::Round($BytesPerSecond, 0)) Б/с"
    } elseif ($BytesPerSecond -lt 1024 * 1024) {
        return "$([math]::Round($BytesPerSecond / 1024, 1)) КБ/с"
    } else {
        return "$([math]::Round($BytesPerSecond / 1024 / 1024, 2)) МБ/с"
    }
}

function Format-Bytes {
    param([double]$Bytes)

    if ($Bytes -lt 1024) {
        return "$([math]::Round($Bytes, 0)) Б"
    } elseif ($Bytes -lt 1024 * 1024) {
        return "$([math]::Round($Bytes / 1024, 1)) КБ"
    } elseif ($Bytes -lt 1024 * 1024 * 1024) {
        return "$([math]::Round($Bytes / 1024 / 1024, 1)) МБ"
    } else {
        return "$([math]::Round($Bytes / 1024 / 1024 / 1024, 2)) ГБ"
    }
}

# ============================================================================
#  ТОП ПРИЛОЖЕНИЙ ПО ТРАФИКУ (через dumpsys netstats)
#
#  Формат вывода разный на разных версиях Android.
#  Пытаемся вытащить UID + rxBytes + txBytes.
#  UID → имя пакета получаем через pm list packages -U.
# ============================================================================
function Get-TopTrafficApps {
    param([int]$TopN = 15)

    Write-Log -Message "Читаю статистику трафика по приложениям..." -Level "Info"

    $apps = @()

    try {
        # ---- UID → имя пакета ----
        $uidMap = @{}
        $pkgListRaw = Invoke-TrafficAdb @("shell", "pm", "list", "packages", "-U")
        foreach ($line in ($pkgListRaw -split "`r?`n")) {
            # package:com.example uid:10123
            if ($line -match 'package:(\S+)\s+uid:(\d+)') {
                $uidMap[[int]$matches[2]] = $matches[1]
            }
        }
        Write-Log -Message "  UID-карта: $($uidMap.Keys.Count) записей" -Level "Info"

        # ---- dumpsys netstats detail ----
        $dump = Invoke-TrafficAdb @("shell", "dumpsys", "netstats", "detail")
        if (-not $dump) {
            $dump = Invoke-TrafficAdb @("shell", "dumpsys", "netstats")
        }

        if (-not $dump) {
            Write-Log -Message "  dumpsys netstats пуст" -Level "Warning"
            return ,$apps
        }

        # ---- Парсим блоки вида: ----
        #   ident=[...] uid=10123 set=DEFAULT tag=0x0
        #   st=... rb=12345 rp=10 tb=67890 tp=20
        # или
        #   uid=10123 ...
        #   rxBytes=12345 txBytes=67890
        $currentUid = -1
        $rxTotal = 0
        $txTotal = 0
        $uidStats = @{}

        foreach ($line in ($dump -split "`r?`n")) {
            # UID строки
            if ($line -match 'uid=(\d+)') {
                $currentUid = [int]$matches[1]
                if (-not $uidStats.ContainsKey($currentUid)) {
                    $uidStats[$currentUid] = @{ Rx = 0; Tx = 0 }
                }
            }

            # Накопительные счётчики rx/tx
            if ($currentUid -ge 0) {
                # Формат 1: rb=12345 ... tb=67890
                if ($line -match 'rb=(\d+)') {
                    $uidStats[$currentUid].Rx += [int64]$matches[1]
                }
                if ($line -match 'tb=(\d+)') {
                    $uidStats[$currentUid].Tx += [int64]$matches[1]
                }

                # Формат 2: rxBytes=12345
                if ($line -match 'rxBytes=(\d+)') {
                    $uidStats[$currentUid].Rx += [int64]$matches[1]
                }
                if ($line -match 'txBytes=(\d+)') {
                    $uidStats[$currentUid].Tx += [int64]$matches[1]
                }
            }
        }

        # ---- Собираем в список ----
        foreach ($uid in $uidStats.Keys) {
            if ($uid -lt 0) { continue }
            $stats = $uidStats[$uid]
            $total = $stats.Rx + $stats.Tx

            if ($total -le 0) { continue }

            $pkgName = "UID $uid"
            if ($uidMap.ContainsKey($uid)) {
                $pkgName = $uidMap[$uid]
            } elseif ($uid -ge 10000 -and $uid -lt 20000) {
                $pkgName = "UID $uid (приложение)"
            } elseif ($uid -lt 1000) {
                $pkgName = "UID $uid (система)"
            }

            $apps += [PSCustomObject]@{
                Uid   = $uid
                Name  = $pkgName
                Rx    = $stats.Rx
                Tx    = $stats.Tx
                Total = $total
            }
        }

        $apps = $apps | Sort-Object -Property Total -Descending | Select-Object -First $TopN
        Write-Log -Message "  Приложений с трафиком: $($apps.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения netstats: $_" -Level "Error"
    }

    return ,$apps
}

# ============================================================================
#  ОБЩАЯ СТАТИСТИКА ПО ИНТЕРФЕЙСУ
#  Возвращает: @{ Interface; RxBytes; TxBytes; RxPackets; TxPackets }
# ============================================================================
function Get-InterfaceStats {
    param([string]$Interface)

    $result = [PSCustomObject]@{
        Interface = $Interface
        RxBytes   = 0
        TxBytes   = 0
        RxPackets = 0
        TxPackets = 0
    }

    if (-not $Interface) { return $result }

    $counters = Get-NetworkCounters
    if ($counters.ContainsKey($Interface)) {
        $c = $counters[$Interface]
        $result.RxBytes   = $c.RxBytes
        $result.TxBytes   = $c.TxBytes
        $result.RxPackets = $c.RxPackets
        $result.TxPackets = $c.TxPackets
    }

    return $result
}