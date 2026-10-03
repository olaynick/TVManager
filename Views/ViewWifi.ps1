# ============================================================================
#  Экран Wi-Fi (только информация)
#  Изменение состояния Wi-Fi НЕ делаем отсюда: при подключении по Wi-Fi
#  выключение рубит канал управления, и приложение теряет связь с ТВ.
#  Для изменения — кнопка «Открыть настройки Wi-Fi на ТВ».
# ============================================================================

# ===== БЕЗОПАСНЫЙ ВЫЗОВ ADB (внутренний) =====
function Invoke-WifiAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== АКТИВНЫЙ СЕТЕВОЙ ИНТЕРФЕЙС =====
function Get-ActiveNetworkInterface {
    Write-Log -Message "Определяю активный сетевой интерфейс..." -Level "Info"

    $result = [ordered]@{
        Type       = "—"
        Name       = "—"
        Ip         = "—"
        Mac        = "—"
        LinkUp     = $false
        HasCarrier = $false
    }

    # --- wlan0 ---
    $wlanOut = Invoke-WifiAdb @("shell", "ip", "addr", "show", "wlan0")
    if ($wlanOut) {
        $isUp       = ($wlanOut -match 'state UP' -or $wlanOut -match ',\s*UP')
        $hasCarrier = ($wlanOut -match 'LOWER_UP')
        $ip = "—"
        if ($wlanOut -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') { $ip = $matches[1] }
        $mac = "—"
        if ($wlanOut -match 'link/ether\s+([0-9a-fA-F:]{17})') { $mac = $matches[1] }

        if ($ip -ne "—" -and $isUp) {
            $result.Type       = "Wi-Fi"
            $result.Name       = "wlan0"
            $result.Ip         = $ip
            $result.Mac        = $mac
            $result.LinkUp     = $isUp
            $result.HasCarrier = $hasCarrier
            Write-Log -Message "Активен Wi-Fi: $ip (wlan0)" -Level "Info"
            return [PSCustomObject]$result
        }
    }

    # --- eth0 ---
    $ethOut = Invoke-WifiAdb @("shell", "ip", "addr", "show", "eth0")
    if ($ethOut) {
        $isUp       = ($ethOut -match 'state UP' -or $ethOut -match ',\s*UP')
        $hasCarrier = ($ethOut -match 'LOWER_UP')
        $ip = "—"
        if ($ethOut -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') { $ip = $matches[1] }
        $mac = "—"
        if ($ethOut -match 'link/ether\s+([0-9a-fA-F:]{17})') { $mac = $matches[1] }

        if ($ip -ne "—" -and $isUp) {
            $result.Type       = "Ethernet"
            $result.Name       = "eth0"
            $result.Ip         = $ip
            $result.Mac        = $mac
            $result.LinkUp     = $isUp
            $result.HasCarrier = $hasCarrier
            Write-Log -Message "Активен Ethernet: $ip (eth0)" -Level "Info"
            return [PSCustomObject]$result
        }
    }

    Write-Log -Message "Активный интерфейс не определён" -Level "Warning"
    return [PSCustomObject]$result
}

# ===== ПОЛУЧЕНИЕ ИНФОРМАЦИИ О ТЕКУЩЕЙ СЕТИ =====
function Get-WifiInfo {
    Write-Log -Message "Читаю информацию о Wi-Fi..." -Level "Info"

    $info = [ordered]@{
        Enabled      = $false
        State        = "—"
        Ssid         = "—"
        Bssid        = "—"
        Ip           = "—"
        Mac          = "—"
        Frequency    = "—"
        LinkSpeed    = "—"
        Signal       = "—"
        SignalPct    = 0
        Gateway      = "—"
        Dns          = "—"
        ActiveIfType = "—"
        ActiveIfName = "—"
        ActiveIfIp   = "—"
        ActiveIfMac  = "—"
    }

    try {
        # =====================================================================
        # 1. Enabled/State через dumpsys wifi
        # =====================================================================
        $dumpText = Invoke-WifiAdb @("shell", "dumpsys", "wifi")

        if ($dumpText) {
            if ($dumpText -match 'Wi-Fi is\s+(\w+)') {
                $info.State   = $matches[1]
                $info.Enabled = ($matches[1] -match 'enabled|connected')
            }
            elseif ($dumpText -match 'mWifiEnabled[:\s=]+(true|false)') {
                $info.Enabled = ($matches[1] -eq "true")
                $info.State   = if ($info.Enabled) { "enabled" } else { "disabled" }
            }
        }

        # =====================================================================
        # 2. Fallback через settings
        # =====================================================================
        if ($info.State -eq "—") {
            $wifiState = Invoke-WifiAdb @("shell", "settings", "get", "global", "wifi_on")
            $wifiStateClean = ($wifiState -replace '[^\d]', '')
            if ($wifiStateClean -eq "1") {
                $info.Enabled = $true
                $info.State   = "enabled (settings)"
            } elseif ($wifiStateClean -eq "0") {
                $info.Enabled = $false
                $info.State   = "disabled (settings)"
            }
        }

        # =====================================================================
        # 3. IP на wlan0 = Wi-Fi работает
        # =====================================================================
        $wlanOut = Invoke-WifiAdb @("shell", "ip", "addr", "show", "wlan0")
        if ($wlanOut -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
            $info.Ip = $matches[1]
            if (-not $info.Enabled) {
                $info.Enabled = $true
                if ($info.State -notmatch 'enabled') {
                    $info.State = "enabled (по IP-адресу)"
                }
            }
        }

        # =====================================================================
        # 4. SSID — аккуратный парсинг
        # =====================================================================
        if ($dumpText) {
            $ssid = $null

            if ($dumpText -match 'SSID:\s*"?([^",\r\n]+?)"?\s+(?:BSSID|nid|state)') {
                $ssid = $matches[1].Trim()
            }
            elseif ($dumpText -match 'SSID:\s*"([^"]+)"') {
                $ssid = $matches[1].Trim()
            }
            elseif ($dumpText -match 'SSID:\s*([^\s,\r\n]+)') {
                $ssid = $matches[1].Trim()
            }

            if ($ssid -and $ssid -notmatch '<unknown' -and $ssid.Length -gt 0) {
                $info.Ssid = $ssid
            }

            if ($dumpText -match 'BSSID:\s*([0-9a-fA-F:]{17})') {
                $bssidVal = $matches[1]
                if ($bssidVal -ne "00:00:00:00:00:00") {
                    $info.Bssid = $bssidVal
                }
            }
            if ($dumpText -match 'IP:\s*/(\d+\.\d+\.\d+\.\d+)') {
                if ($info.Ip -eq "—") { $info.Ip = $matches[1] }
            }
            if ($dumpText -match 'MacAddress:\s*([0-9a-fA-F:]{17})') {
                $info.Mac = $matches[1]
            }
            if ($dumpText -match 'Frequency:\s*(\d+)') {
                $info.Frequency = "$($matches[1]) МГц"
            }
            if ($dumpText -match 'Link speed:\s*(\d+)\s*Mbps') {
                $info.LinkSpeed = "$($matches[1]) Мбит/с"
            }
            if ($dumpText -match 'RSSI:\s*(-?\d+)') {
                $rssi = [int]$matches[1]
                $info.Signal = "$rssi dBm"
                $pct = [math]::Max(0, [math]::Min(100, 2 * ($rssi + 100)))
                $info.SignalPct = $pct
            }
        }

        # =====================================================================
        # 5. MAC из /sys
        # =====================================================================
        if ($info.Mac -eq "—") {
            $macOut = Invoke-WifiAdb @("shell", "cat", "/sys/class/net/wlan0/address")
            if ($macOut -match '([0-9a-fA-F:]{17})') {
                $info.Mac = $matches[1]
            }
        }

        # =====================================================================
        # 6. Шлюз
        # =====================================================================
        $routeOut = Invoke-WifiAdb @("shell", "ip", "route")
        if ($routeOut) {
            foreach ($line in ($routeOut -split "`r?`n")) {
                if ($line -match 'default via (\d+\.\d+\.\d+\.\d+)') {
                    $info.Gateway = $matches[1]
                    break
                }
            }
        }

        # =====================================================================
        # 7. DNS
        # =====================================================================
        $dnsOut = Invoke-WifiAdb @("shell", "getprop")
        if ($dnsOut) {
            $dnsList = @()
            foreach ($line in ($dnsOut -split "`r?`n")) {
                if ($line -match '\[net\.dns\d+\]:\s*\[(\d+\.\d+\.\d+\.\d+)\]') {
                    $dnsList += $matches[1]
                }
            }
            if ($dnsList.Count -gt 0) {
                $info.Dns = ($dnsList -join ", ")
            }
        }

        # =====================================================================
        # 8. Активный интерфейс
        # =====================================================================
        $iface = Get-ActiveNetworkInterface
        $info.ActiveIfType = $iface.Type
        $info.ActiveIfName = $iface.Name
        $info.ActiveIfIp   = $iface.Ip
        $info.ActiveIfMac  = $iface.Mac

        Write-Log -Message "Wi-Fi Enabled=$($info.Enabled), State=$($info.State), SSID='$($info.Ssid)', IF=$($info.ActiveIfType) ($($info.ActiveIfIp))" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения Wi-Fi: $_" -Level "Error"
    }

    return [PSCustomObject]$info
}

# ===== СПИСОК ДОСТУПНЫХ СЕТЕЙ =====
function Get-WifiNetworks {
    Write-Log -Message "Сканирую Wi-Fi сети..." -Level "Info"

    try {
        & $script:adbPath shell cmd -w wifi start-scan 2>&1 | Out-Null
    } catch { }

    Start-Sleep -Seconds 5

    $dumpText = Invoke-WifiAdb @("shell", "dumpsys", "wifi")

    $networks = @()
    $seen = @{}

    if (-not $dumpText) {
        Write-Log -Message "Не удалось получить dumpsys wifi" -Level "Warning"
        return ,$networks
    }

    foreach ($line in ($dumpText -split "`r?`n")) {
        if ($line -match 'SSID:\s*"([^"]+)"' -and $line -match 'BSSID:\s*([0-9a-fA-F:]{17})') {
            $ssid  = $matches[1]
            $bssid = $matches[2]

            if ($seen.ContainsKey($ssid)) { continue }
            $seen[$ssid] = $true

            $level = "—"
            if ($line -match 'level:\s*(-?\d+)') {
                $level = "$($matches[1]) dBm"
            }

            $freq = "—"
            if ($line -match 'freq:\s*(\d+)') {
                $freq = "$($matches[1]) МГц"
            }

            $networks += [PSCustomObject]@{
                Ssid  = $ssid
                Bssid = $bssid
                Level = $level
                Freq  = $freq
            }
        }
    }

    if ($networks.Count -eq 0) {
        Write-Log -Message "Сети не найдены (возможно, сканирование ограничено)" -Level "Warning"
    } else {
        Write-Log -Message "Найдено сетей: $($networks.Count)" -Level "Success"
    }

    return ,$networks
}

# ===== ОСНОВНОЙ ЭКРАН =====
function Show-WifiView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Wi-Fi"
    $mainStack.Children.Add($header) | Out-Null

    # ===== ПРОВЕРКА ПОДКЛЮЧЕНИЯ =====
    if (-not $script:connected) {
        $warnCard = New-Object System.Windows.Controls.Border
        $warnCard.Background = "#FFF3CD"
        $warnCard.BorderBrush = "#FFB74D"
        $warnCard.BorderThickness = "1"
        $warnCard.CornerRadius = "8"
        $warnCard.Padding = "12"
        $warnCard.Margin = "0,0,0,15"

        $warnText = New-Object System.Windows.Controls.TextBlock
        $warnText.Text = "Нет связи с телевизором. Подключитесь в разделе «Настройка»."
        $warnText.TextWrapping = "Wrap"
        $warnText.FontSize = 12
        $warnText.Foreground = "#856404"
        $warnCard.Child = $warnText
        $mainStack.Children.Add($warnCard) | Out-Null

        $btnReconnect = New-ViewButton -Text "Переподключиться" -ColorType "Primary" -OnClick {
            $lastIp = Get-ConfigValue -Key "LastIp"
            if ($lastIp) {
                $result = Connect-AdbDevice -Ip $lastIp
                if ($result.Success) {
                    Switch-View -ViewName "Wifi"
                } else {
                    Write-Log -Message "Не удалось: $($result.Message)" -Level "Error"
                }
            } else {
                Write-Log -Message "Нет сохранённого IP" -Level "Warning"
            }
        }
        $mainStack.Children.Add($btnReconnect) | Out-Null

        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ЗАГРУЗКА =====
    $info = Get-WifiInfo

    # --- Строка про активный интерфейс ---
    $ifaceCard = New-Object System.Windows.Controls.Border
    $ifaceCard.Background = "White"
    $ifaceCard.BorderBrush = "#E1E1E6"
    $ifaceCard.BorderThickness = "1"
    $ifaceCard.CornerRadius = "8"
    $ifaceCard.Padding = "12,10"
    $ifaceCard.Margin = "0,0,0,12"

    $ifaceStack = New-Object System.Windows.Controls.StackPanel
    $ifaceStack.Orientation = "Horizontal"

    $ifaceIcon = New-Object System.Windows.Controls.TextBlock
    $ifaceIcon.FontSize = 14
    $ifaceIcon.FontWeight = "Bold"
    $ifaceIcon.VerticalAlignment = "Center"
    $ifaceIcon.Margin = "0,0,10,0"
    if ($info.ActiveIfType -eq "Wi-Fi") {
        $ifaceIcon.Text = "[Wi-Fi]"
        $ifaceIcon.Foreground = "#2E7D32"
    } elseif ($info.ActiveIfType -eq "Ethernet") {
        $ifaceIcon.Text = "[LAN]"
        $ifaceIcon.Foreground = "#1565C0"
    } else {
        $ifaceIcon.Text = "[ ? ]"
        $ifaceIcon.Foreground = "#96969B"
    }
    $ifaceStack.Children.Add($ifaceIcon) | Out-Null

    $ifaceText = New-Object System.Windows.Controls.TextBlock
    $ifaceText.FontSize = 13
    $ifaceText.VerticalAlignment = "Center"
    $ifaceText.TextWrapping = "Wrap"
    if ($info.ActiveIfType -ne "—") {
        $ifaceText.Text = "Активное подключение: $($info.ActiveIfType) ($($info.ActiveIfName)) — $($info.ActiveIfIp)"
        $ifaceText.Foreground = "#2D2D30"
    } else {
        $ifaceText.Text = "Активное подключение не определено"
        $ifaceText.Foreground = "#96969B"
    }
    $ifaceStack.Children.Add($ifaceText) | Out-Null

    $ifaceCard.Child = $ifaceStack
    $mainStack.Children.Add($ifaceCard) | Out-Null

    # --- Статус-карточка ---
    $statusCard = New-Object System.Windows.Controls.Border
    $statusCard.Background = if ($info.Enabled) { "#E8F5E9" } else { "#FFEBEE" }
    $statusCard.BorderBrush = if ($info.Enabled) { "#66BB6A" } else { "#E57373" }
    $statusCard.BorderThickness = "1"
    $statusCard.CornerRadius = "8"
    $statusCard.Padding = "15"
    $statusCard.Margin = "0,0,0,15"

    $statusStack = New-Object System.Windows.Controls.StackPanel

    $statusLine = New-Object System.Windows.Controls.TextBlock
    $statusLine.FontSize = 16
    $statusLine.FontWeight = "Bold"

    if ($info.Enabled) {
        $stateInfo = ""
        if ($info.State -match 'settings') { $stateInfo = " (по settings)" }
        elseif ($info.State -match 'IP')   { $stateInfo = " (по IP-адресу)" }
        $statusLine.Text = "Wi-Fi включён$stateInfo"
        $statusLine.Foreground = "#2E7D32"
    }
    elseif ($info.State -eq "—") {
        $statusLine.Text = "Состояние Wi-Fi неизвестно"
        $statusLine.Foreground = "#F57C00"
    }
    else {
        $statusLine.Text = "Wi-Fi выключен"
        $statusLine.Foreground = "#C62828"
    }
    $statusStack.Children.Add($statusLine) | Out-Null

    if ($info.Enabled -and $info.Ssid -ne "—") {
        $connLine = New-Object System.Windows.Controls.TextBlock
        $connLine.FontSize = 13
        $connLine.Foreground = "#2D2D30"
        $connLine.Margin = "0,5,0,0"
        $connLine.Text = "Подключено к: $($info.Ssid)"
        $statusStack.Children.Add($connLine) | Out-Null
    }

    $statusCard.Child = $statusStack
    $mainStack.Children.Add($statusCard) | Out-Null

    # ===== КНОПКИ =====
    $actionsPanel = New-Object System.Windows.Controls.StackPanel
    $actionsPanel.Orientation = "Horizontal"
    $actionsPanel.Margin = "0,0,0,15"

    $btnRefresh = New-ViewButton -Text "Обновить" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Wifi"
    }
    $actionsPanel.Children.Add($btnRefresh) | Out-Null

    $btnSystemSettings = New-ViewButton -Text "Открыть настройки Wi-Fi на ТВ" -ColorType "Neutral" -OnClick {
        Write-Log -Message "Открываю настройки Wi-Fi на ТВ..." -Level "Info"
        try {
            & $script:adbPath shell am start -a android.settings.WIFI_SETTINGS 2>&1 | Out-Null
            Write-Log -Message "OK" -Level "Success"
        } catch {
            Write-Log -Message "Ошибка: $_" -Level "Error"
        }
    }
    $actionsPanel.Children.Add($btnSystemSettings) | Out-Null

    $mainStack.Children.Add($actionsPanel) | Out-Null

    # --- Информационная сноска ---
    $note = New-Object System.Windows.Controls.TextBlock
    $note.Text = "Примечание: включение и выключение Wi-Fi из приложения не поддерживается. Если ТВ подключён по Wi-Fi, любая смена состояния оборвёт соединение. Меняйте Wi-Fi через настройки на телевизоре."
    $note.FontSize = 11
    $note.Foreground = "#96969B"
    $note.TextWrapping = "Wrap"
    $note.Margin = "0,0,0,15"
    $mainStack.Children.Add($note) | Out-Null

    # ===== ИНФОРМАЦИЯ О СЕТИ =====
    if ($info.Enabled) {
        $mainStack.Children.Add((New-StepTitle -Text "Текущее подключение")) | Out-Null

        $rows = @(
            @{ Label = "SSID";       Value = $info.Ssid }
            @{ Label = "BSSID";      Value = $info.Bssid }
            @{ Label = "IP-адрес";   Value = $info.Ip }
            @{ Label = "MAC-адрес";  Value = $info.Mac }
            @{ Label = "Шлюз";       Value = $info.Gateway }
            @{ Label = "DNS";        Value = $info.Dns }
            @{ Label = "Частота";    Value = $info.Frequency }
            @{ Label = "Скорость";   Value = $info.LinkSpeed }
            @{ Label = "Сигнал";     Value = if ($info.Signal -ne "—") { "$($info.Signal)  ($($info.SignalPct)%)" } else { "—" } }
        )

        $infoCard = New-Object System.Windows.Controls.Border
        $infoCard.Background = "White"
        $infoCard.BorderBrush = "#E1E1E6"
        $infoCard.BorderThickness = "1"
        $infoCard.CornerRadius = "8"
        $infoCard.Padding = "15"
        $infoCard.Margin = "0,5,0,15"

        $infoStack = New-Object System.Windows.Controls.StackPanel

        foreach ($row in $rows) {
            $grid = New-Object System.Windows.Controls.Grid
            $grid.Margin = "0,3,0,3"

            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = "150"
            $col2 = New-Object System.Windows.Controls.ColumnDefinition
            $col2.Width = "*"
            $grid.ColumnDefinitions.Add($col1)
            $grid.ColumnDefinitions.Add($col2)

            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $row.Label
            $lbl.FontSize = 13
            $lbl.Foreground = "#96969B"
            [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
            $grid.Children.Add($lbl) | Out-Null

            $val = New-Object System.Windows.Controls.TextBlock
            $val.Text = if ($row.Value) { $row.Value } else { "—" }
            $val.FontSize = 13
            $val.Foreground = "#2D2D30"
            $val.FontFamily = "Consolas"
            $val.TextWrapping = "Wrap"
            [System.Windows.Controls.Grid]::SetColumn($val, 1)
            $grid.Children.Add($val) | Out-Null

            $infoStack.Children.Add($grid) | Out-Null
        }

        $infoCard.Child = $infoStack
        $mainStack.Children.Add($infoCard) | Out-Null
    }

    # ===== СПИСОК СЕТЕЙ =====
    $mainStack.Children.Add((New-StepTitle -Text "Доступные сети")) | Out-Null

    $script:WifiNetworksContainer = New-Object System.Windows.Controls.StackPanel
    $script:WifiNetworksContainer.Margin = "0,5,0,0"
    $mainStack.Children.Add($script:WifiNetworksContainer) | Out-Null

    $hint = New-ViewLabel -Text "Нажмите «Просканировать сети» внизу экрана." -Light
    $script:WifiNetworksContainer.Children.Add($hint) | Out-Null

    # ===== ROOT + КНОПКИ =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    $buttons = @()

    $btnScan = New-Object System.Windows.Controls.Button
    $btnScan.Content = "Просканировать сети"
    $btnScan.Style = $window.Resources["RoundedButton"]
    $btnScan.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnScan.Padding = "12,6"
    $btnScan.Margin = "0,0,8,0"
    $btnScan.Add_Click({
        try {
            if (-not $script:WifiNetworksContainer) { return }

            $script:WifiNetworksContainer.Children.Clear()
            $loading = New-ViewLabel -Text "Сканирую... (займёт ~5 сек)" -Light
            $script:WifiNetworksContainer.Children.Add($loading) | Out-Null

            $networks = Get-WifiNetworks
            $script:WifiNetworksContainer.Children.Clear()

            if ($networks.Count -eq 0) {
                $empty = New-ViewLabel -Text "Сети не найдены." -Light
                $script:WifiNetworksContainer.Children.Add($empty) | Out-Null
                return
            }

            foreach ($net in $networks) {
                $row = New-Object System.Windows.Controls.Border
                $row.Background = "White"
                $row.BorderBrush = "#E1E1E6"
                $row.BorderThickness = "1"
                $row.CornerRadius = "6"
                $row.Padding = "10"
                $row.Margin = "0,0,0,6"

                $grid = New-Object System.Windows.Controls.Grid
                $c1 = New-Object System.Windows.Controls.ColumnDefinition
                $c1.Width = "*"
                $c2 = New-Object System.Windows.Controls.ColumnDefinition
                $c2.Width = "Auto"
                $grid.ColumnDefinitions.Add($c1)
                $grid.ColumnDefinitions.Add($c2)

                $textStack = New-Object System.Windows.Controls.StackPanel
                [System.Windows.Controls.Grid]::SetColumn($textStack, 0)

                $ssidTb = New-Object System.Windows.Controls.TextBlock
                $ssidTb.Text = $net.Ssid
                $ssidTb.FontSize = 13
                $ssidTb.FontWeight = "Bold"
                $ssidTb.Foreground = "#2D2D30"
                $textStack.Children.Add($ssidTb) | Out-Null

                $detailTb = New-Object System.Windows.Controls.TextBlock
                $detailTb.Text = "$($net.Bssid)   |   $($net.Level)   |   $($net.Freq)"
                $detailTb.FontFamily = "Consolas"
                $detailTb.FontSize = 11
                $detailTb.Foreground = "#96969B"
                $detailTb.Margin = "0,2,0,0"
                $textStack.Children.Add($detailTb) | Out-Null

                $grid.Children.Add($textStack) | Out-Null

                $btnConnect = New-Object System.Windows.Controls.Button
                $btnConnect.Content = "Открыть настройки"
                $btnConnect.Style = $window.Resources["RoundedButton"]
                $btnConnect.Background = New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#64B5F6")
                )
                $btnConnect.Padding = "10,5"
                $btnConnect.FontSize = 11
                $btnConnect.VerticalAlignment = "Center"

                $ssidLocal = $net.Ssid
                $btnConnect.Add_Click({
                    try {
                        & $script:adbPath shell am start -a android.settings.WIFI_SETTINGS 2>&1 | Out-Null
                        Write-Log -Message "Открываю настройки Wi-Fi для подключения к '$ssidLocal'" -Level "Info"
                    } catch {
                        Write-Log -Message "Ошибка: $_" -Level "Error"
                    }
                }.GetNewClosure())
                [System.Windows.Controls.Grid]::SetColumn($btnConnect, 1)
                $grid.Children.Add($btnConnect) | Out-Null

                $row.Child = $grid
                $script:WifiNetworksContainer.Children.Add($row) | Out-Null
            }
        } catch {
            Write-Log -Message "Ошибка сканирования: $_" -Level "Error"
        }
    })
    $buttons += $btnScan

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран Wi-Fi" -Level "Info"
}