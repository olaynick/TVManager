function Get-LocalSubnet {
    $myIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169'
    } | Select-Object -First 1).IPAddress

    if (-not $myIp) { return $null }

    $subnet = ($myIp -split '\.')[0..2] -join '.'
    return @{ MyIp = $myIp; Subnet = $subnet }
}

function Scan-Network {
    param([string]$Subnet)

    $devices = @()

    # ===== ШАГ 1: ARP-таблица =====
    $arpOutput = arp -a
    foreach ($line in $arpOutput) {
        if ($line -match '(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F-]{17})\s+(\S+)') {
            $arpIp = $matches[1]
            $arpType = $matches[3]
            if ($arpType -eq "статический" -or $arpType -eq "static") { continue }
            $firstOctet = [int]($arpIp -split '\.')[0]
            if ($firstOctet -ge 224 -or $firstOctet -eq 0) { continue }
            if ($arpIp -notlike "$Subnet.*") { continue }
            $devices += [PSCustomObject]@{ IP = $arpIp; Source = "ARP" }
        }
    }

    # ===== ШАГ 2: Асинхронный ping =====
    $pingTasks = @()
    foreach ($i in 1..254) {
        $ip = "$Subnet.$i"
        $ping = New-Object System.Net.NetworkInformation.Ping
        $task = $ping.SendPingAsync($ip, 200)
        $pingTasks += [PSCustomObject]@{ Ping = $ping; IP = $ip; Task = $task }
    }

    try {
        [System.Threading.Tasks.Task]::WaitAll(($pingTasks | ForEach-Object { $_.Task }), 3000) | Out-Null
    } catch { }

    foreach ($t in $pingTasks) {
        try {
            if ($t.Task.IsCompleted -and $t.Task.Result.Status -eq "Success") {
                if (-not ($devices | Where-Object { $_.IP -eq $t.IP })) {
                    $devices += [PSCustomObject]@{ IP = $t.IP; Source = "ping" }
                }
            }
        } catch { }
        $t.Ping.Dispose()
    }

    # ===== ШАГ 3: Проверка порта 5555 для ВСЕХ устройств =====
    $portTasks = @()
    foreach ($d in $devices) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $tcp.ConnectAsync($d.IP, 5555)
            $portTasks += [PSCustomObject]@{ Tcp = $tcp; Device = $d; Task = $task }
        } catch { $tcp.Dispose() }
    }

    Start-Sleep -Milliseconds 2000

    foreach ($t in $portTasks) {
        try {
            if ($t.Tcp.Connected) {
                $t.Device.Source = "ADB"
            }
        } catch { }
        $t.Tcp.Dispose()
    }

    # ===== ШАГ 4: Проверка порта 5555 для адресов БЕЗ ping и ARP =====
    $knownIps = $devices | ForEach-Object { $_.IP }
    $silentIps = @()
    foreach ($i in 1..254) {
        $ip = "$Subnet.$i"
        if ($ip -notin $knownIps) { $silentIps += $ip }
    }

    $silentPortTasks = @()
    foreach ($ip in $silentIps) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $tcp.ConnectAsync($ip, 5555)
            $silentPortTasks += [PSCustomObject]@{ Tcp = $tcp; IP = $ip; Task = $task }
        } catch { $tcp.Dispose() }
    }

    Start-Sleep -Milliseconds 2000

    foreach ($t in $silentPortTasks) {
        try {
            if ($t.Tcp.Connected) {
                $devices += [PSCustomObject]@{ IP = $t.IP; Source = "ADB" }
            }
        } catch { }
        $t.Tcp.Dispose()
    }

    # ===== Сортировка: ADB сверху =====
    $devices = $devices | Sort-Object @{Expression={ if ($_.Source -eq "ADB") { 0 } else { 1 } }}, @{Expression={ [version]$_.IP }}

    return ,$devices
}