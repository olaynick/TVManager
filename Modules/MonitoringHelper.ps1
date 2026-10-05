# ============================================================================
#  Monitoring Helper — централизованный сбор метрик состояния ТВ
#
#  Объединяет данные из разных источников:
#    - CPU / RAM / Storage / Temperature / Uptime
#    - Топ процессов
#    - Сеть (Wi-Fi, Ethernet, скорость, трафик)
#    - Bluetooth
#
#  Каждая функция возвращает простой PSCustomObject — чтобы View мог
#  легко отрисовать.
# ============================================================================

# ============================================================================
#  МЕТРИКИ СИСТЕМЫ (CPU / RAM / Storage / Temp)
# ============================================================================
function Get-SystemMetrics {
    $result = [ordered]@{
        Cpu = [ordered]@{
            Usage      = 0
            Cores      = 0
            MaxFreq    = ""
            CurFreq    = ""
            PerCore    = @()  # пока не заполняем
        }
        Ram = [ordered]@{
            Total     = 0
            Free      = 0
            Available = 0
            UsedPct   = 0
        }
        Storage = [ordered]@{
            Total   = 0
            Used    = 0
            Free    = 0
            UsedPct = 0
        }
        Uptime    = ""
        LoadAvg   = ""
        Temperature = -1
    }

    if (-not $script:connected) {
        return [PSCustomObject]$result
    }

    try {
        # ===== CPU =====
        $cpuOut = & $script:adbPath shell top -n 1 -b 2>&1
        $cpuText = ($cpuOut | Out-String)

        if ($cpuText -match '(\d+)%cpu\s+([\d\.]+)%user\s+([\d\.]+)%nice\s+([\d\.]+)%sys') {
            $totalCpuPercent = [int]$matches[1]
            $userCpu = [double]$matches[2]
            $sysCpu  = [double]$matches[4]
            $cores = [int]($totalCpuPercent / 100)
            if ($cores -lt 1) { $cores = 1 }
            $usage = ($userCpu + $sysCpu) / $cores
            $result.Cpu.Usage = [math]::Round($usage, 1)
            $result.Cpu.Cores = $cores
        } elseif ($cpuText -match 'CPU:\s*(\d+)%\s*user,\s*(\d+)%\s*sys') {
            $result.Cpu.Usage = [int]$matches[1] + [int]$matches[2]
        } else {
            # Fallback: сумма CPU% процессов
            $sumCpu = 0
            foreach ($line in ($cpuText -split "`r?`n")) {
                if ($line -match '^\s*\d+\s+\S+\s+\d+\s+\d+\s+\S+\s+\S+\s+\S+\s+\S\s+([\d\.]+)') {
                    $sumCpu += [double]$matches[1]
                }
            }
            if ($sumCpu -gt 0) {
                $coresOut = & $script:adbPath shell nproc 2>&1
                $coresText = ($coresOut | Out-String).Trim()
                $cores = 4
                if ($coresText -match '^\d+$') { $cores = [int]$coresText }
                if ($cores -lt 1) { $cores = 1 }
                $result.Cpu.Usage = [math]::Round($sumCpu / $cores, 1)
                if ($result.Cpu.Usage -gt 100) { $result.Cpu.Usage = 100 }
                $result.Cpu.Cores = $cores
            }
        }

        # Частоты
        $maxFreqOut = & $script:adbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>&1
        $maxFreqText = ($maxFreqOut | Out-String).Trim()
        if ($maxFreqText -match '^\d+$') {
            $result.Cpu.MaxFreq = "$([math]::Round([int]$maxFreqText / 1000)) МГц"
        }

        $curFreqOut = & $script:adbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>&1
        $curFreqText = ($curFreqOut | Out-String).Trim()
        if ($curFreqText -match '^\d+$') {
            $result.Cpu.CurFreq = "$([math]::Round([int]$curFreqText / 1000)) МГц"
        }

        # ===== RAM =====
        $memOut = & $script:adbPath shell cat /proc/meminfo 2>&1
        $memText = ($memOut | Out-String)
        if ($memText -match 'MemTotal:\s+(\d+)\s+kB')     { $result.Ram.Total     = [int64]$matches[1] * 1024 }
        if ($memText -match 'MemFree:\s+(\d+)\s+kB')      { $result.Ram.Free      = [int64]$matches[1] * 1024 }
        if ($memText -match 'MemAvailable:\s+(\d+)\s+kB') { $result.Ram.Available = [int64]$matches[1] * 1024 }

        if ($result.Ram.Total -gt 0) {
            $used = $result.Ram.Total - $result.Ram.Available
            $result.Ram.UsedPct = [math]::Round($used / $result.Ram.Total * 100, 1)
        }

        # ===== Storage =====
        $dfOut = & $script:adbPath shell df /data 2>&1
        $dfText = ($dfOut | Out-String)
        foreach ($line in ($dfText -split "`r?`n")) {
            if ($line -match '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%') {
                $result.Storage.Total = [int64]$matches[1] * 1024
                $result.Storage.Used  = [int64]$matches[2] * 1024
                $result.Storage.Free  = [int64]$matches[3] * 1024
                $result.Storage.UsedPct = [int]$matches[4]
                break
            }
        }

        # ===== Uptime =====
        $uptimeOut = & $script:adbPath shell cat /proc/uptime 2>&1
        $uptimeText = ($uptimeOut | Out-String).Trim()
        if ($uptimeText -match '^([\d\.]+)') {
            $sec = [math]::Round([double]$matches[1])
            $h = [math]::Floor($sec / 3600)
            $m = [math]::Floor(($sec % 3600) / 60)
            $result.Uptime = "$h ч $m мин"
        }

        # ===== Load avg =====
        $loadOut = & $script:adbPath shell cat /proc/loadavg 2>&1
        $loadText = ($loadOut | Out-String).Trim()
        if ($loadText -match '^([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)') {
            $result.LoadAvg = "$($matches[1]) / $($matches[2]) / $($matches[3])"
        }

        # ===== Temperature =====
        $tempOut = & $script:adbPath shell ls /sys/class/thermal/ 2>&1
        $tempText = ($tempOut | Out-String)
        foreach ($zone in ($tempText -split "`r?`n")) {
            if ($zone -match 'thermal_zone(\d+)') {
                $zoneName = "thermal_zone$($matches[1])"
                $typeOut = & $script:adbPath shell cat "/sys/class/thermal/$zoneName/type" 2>&1
                $typeText = ($typeOut | Out-String).Trim()
                if ($typeText -match 'cpu|soc|ap|big') {
                    $tOut = & $script:adbPath shell cat "/sys/class/thermal/$zoneName/temp" 2>&1
                    $tText = ($tOut | Out-String).Trim()
                    if ($tText -match '^-?\d+$') {
                        $result.Temperature = [math]::Round([int]$tText / 1000.0, 1)
                        break
                    }
                }
            }
        }
    } catch {
        Write-Log -Message "Ошибка сбора метрик: $_" -Level "Warning"
    }

    return [PSCustomObject]$result
}

# ============================================================================
#  ТОП ПРОЦЕССОВ
# ============================================================================
function Get-TopProcesses {
    param([int]$TopN = 15)

    $result = @()

    if (-not $script:connected) { return ,$result }

    try {
        $out = & $script:adbPath shell top -n 1 -b -o %CPU,RES,CMDLINE 2>&1
        $outText = ($out | Out-String)

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

                $result += [PSCustomObject]@{
                    CPU   = [math]::Round($cpu, 1)
                    MemMb = [math]::Round($memKb / 1024, 1)
                    Name  = $name
                }
            }
        }

        $result = @($result | Sort-Object -Property CPU -Descending | Select-Object -First $TopN)
    } catch {
        Write-Log -Message "Ошибка чтения процессов: $_" -Level "Warning"
    }

    return ,$result
}

# ============================================================================
#  СЕТЬ — ОБЩИЕ СВЕДЕНИЯ
# ============================================================================
function Get-NetworkSummary {
    $result = [ordered]@{
        ActiveInterface = "—"
        ActiveIfType    = "—"
        ActiveIfIp      = "—"
        ActiveIfMac     = "—"
        WifiEnabled     = $false
        WifiSsid        = ""
        WifiBssid       = ""
        WifiIp          = ""
        WifiMac         = ""
        WifiGateway     = ""
        WifiDns         = ""
        WifiFrequency   = ""
        WifiSignal      = -1
        WifiLinkSpeed   = ""
    }

    if (-not $script:connected) { return [PSCustomObject]$result }

    try {
        # Wi-Fi
        if (Get-Command Get-WifiInfo -ErrorAction SilentlyContinue) {
            $wifi = Get-WifiInfo
            $result.WifiEnabled   = $wifi.Enabled
            $result.WifiSsid      = $wifi.Ssid
            $result.WifiBssid     = $wifi.Bssid
            $result.WifiIp        = $wifi.Ip
            $result.WifiMac       = $wifi.Mac
            $result.WifiGateway   = $wifi.Gateway
            $result.WifiDns       = $wifi.Dns
            $result.WifiFrequency = $wifi.Frequency
            $result.WifiSignal    = $wifi.Signal
            $result.WifiLinkSpeed = $wifi.LinkSpeed
            $result.ActiveIfType  = $wifi.ActiveIfType
            $result.ActiveIfName  = $wifi.ActiveIfName
            $result.ActiveIfIp    = $wifi.ActiveIfIp
            $result.ActiveIfMac   = $wifi.ActiveIfMac
        }
    } catch {
        Write-Log -Message "Ошибка чтения сети: $_" -Level "Warning"
    }

    return [PSCustomObject]$result
}

# ============================================================================
#  ТЕКУЩАЯ СКОРОСТЬ ТРАФИКА
#  Возвращает @{ RxBps; TxBps; TotalRx; TotalTx } по активному интерфейсу
# ============================================================================
function Get-CurrentTrafficSpeed {
    param(
        [hashtable]$PrevCounters,
        [string]$Interface,
        [double]$ElapsedSeconds
    )

    $result = @{
        RxBps   = 0
        TxBps   = 0
        TotalRx = 0
        TotalTx = 0
    }

    if (-not $script:connected -or -not $Interface -or $ElapsedSeconds -le 0) {
        return $result
    }

    try {
        $raw = & $script:adbPath shell cat /proc/net/dev 2>&1
        $rawText = ($raw | Out-String)

        $curr = @{}
        foreach ($line in ($rawText -split "`r?`n")) {
            if ($line -match '^\s*([a-zA-Z0-9_]+):\s+(.+)$') {
                $iface = $matches[1]
                $fields = ($matches[2] -split '\s+') | Where-Object { $_ -ne "" }

                if ($fields.Count -ge 16) {
                    $curr[$iface] = @{
                        RxBytes = [int64]$fields[0]
                        TxBytes = [int64]$fields[8]
                    }
                }
            }
        }

        if (-not $curr.ContainsKey($Interface)) { return $result }

        $result.TotalRx = $curr[$Interface].RxBytes
        $result.TotalTx = $curr[$Interface].TxBytes

        if ($PrevCounters -and $PrevCounters.ContainsKey($Interface)) {
            $rxDelta = $curr[$Interface].RxBytes - $PrevCounters[$Interface].RxBytes
            $txDelta = $curr[$Interface].TxBytes - $PrevCounters[$Interface].TxBytes

            if ($rxDelta -lt 0) { $rxDelta = 0 }
            if ($txDelta -lt 0) { $txDelta = 0 }

            $result.RxBps = [math]::Round($rxDelta / $ElapsedSeconds, 0)
            $result.TxBps = [math]::Round($txDelta / $ElapsedSeconds, 0)
        }

        # Возвращаем и текущие счётчики — для следующего замера
        $result.Counters = $curr
    } catch { }

    return $result
}

# ============================================================================
#  BLUETOOTH
# ============================================================================
function Get-BluetoothSummary {
    $result = [ordered]@{
        Enabled = $false
        Name    = ""
        Address = ""
        Bonded  = @()
    }

    if (-not $script:connected) { return [PSCustomObject]$result }

    try {
        if (Get-Command Get-BluetoothInfo -ErrorAction SilentlyContinue) {
            $bt = Get-BluetoothInfo
            $result.Enabled = $bt.Enabled
            $result.Name    = $bt.Name
            $result.Address = $bt.Address
        }

        if (Get-Command Get-BluetoothBondedDevices -ErrorAction SilentlyContinue) {
            $bonded = Get-BluetoothBondedDevices
            foreach ($dev in $bonded) {
                $result.Bonded += [PSCustomObject]@{
                    Mac       = $dev.Mac
                    Name      = $dev.Name
                    Connected = $dev.Connected
                }
            }
        }
    } catch {
        Write-Log -Message "Ошибка чтения Bluetooth: $_" -Level "Warning"
    }

    return [PSCustomObject]$result
}

# ============================================================================
#  ФОРМАТИРОВАНИЕ
# ============================================================================
function Format-MonBytes {
    param([double]$Bytes)

    if ($Bytes -lt 1024) { return "$([math]::Round($Bytes, 0)) Б" }
    if ($Bytes -lt 1024 * 1024) { return "$([math]::Round($Bytes / 1024, 1)) КБ" }
    if ($Bytes -lt 1024 * 1024 * 1024) { return "$([math]::Round($Bytes / 1024 / 1024, 1)) МБ" }
    return "$([math]::Round($Bytes / 1024 / 1024 / 1024, 2)) ГБ"
}

function Format-MonRate {
    param([double]$BytesPerSecond)

    if ($BytesPerSecond -lt 1024) { return "$([math]::Round($BytesPerSecond, 0)) Б/с" }
    if ($BytesPerSecond -lt 1024 * 1024) { return "$([math]::Round($BytesPerSecond / 1024, 1)) КБ/с" }
    return "$([math]::Round($BytesPerSecond / 1024 / 1024, 2)) МБ/с"
}