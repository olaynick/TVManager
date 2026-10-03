# ===== ИНЛАЙН-СПИСОК УСТРОЙСТВ =====
function Show-DeviceListInline {
    param([array]$Devices)

    $script:DeviceListContainer.Children.Clear()

    if ($Devices.Count -eq 0) {
        $script:DeviceListContainer.Children.Add((New-ViewLabel -Text "Устройства не найдены.")) | Out-Null
        return
    }

    $listHeader = New-Object System.Windows.Controls.TextBlock
    $listHeader.Text = "Найденные устройства:"
    $listHeader.FontSize = 14
    $listHeader.FontWeight = "SemiBold"
    $listHeader.Margin = "0,0,0,8"
    $script:DeviceListContainer.Children.Add($listHeader) | Out-Null

    $script:DeviceListBox = New-Object System.Windows.Controls.ListBox
    $script:DeviceListBox.FontSize = 13
    $script:DeviceListBox.BorderThickness = "1"
    $script:DeviceListBox.BorderBrush = "#3A3A3A"
    $script:DeviceListBox.MaxHeight = 180
    $script:DeviceListBox.Padding = "5"

    $myIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169'
    } | Select-Object -First 1).IPAddress

    foreach ($d in $Devices) {
        $item = New-Object System.Windows.Controls.ListBoxItem

        $label = ""
        if ($d.Source -eq "ADB") {
            $label = "  ★ ВЕРОЯТНО ЭТО ТЕЛЕВИЗОР"
            $item.Foreground = [System.Windows.Media.Brushes]::SeaGreen
            $item.FontWeight = "Bold"
        } elseif ($d.IP -eq $myIp) {
            $label = "  (ПК)"
            $item.Foreground = [System.Windows.Media.Brushes]::SteelBlue
        } elseif ($d.IP -match '\.1$') {
            $label = "  (Роутер)"
            $item.Foreground = [System.Windows.Media.Brushes]::DarkOrange
        } else {
            $item.Foreground = [System.Windows.Media.Brushes]::Gray
        }

        $item.Content = "$($d.IP)$label"
        $item.Tag = $d.IP
        $item.Padding = "5"
        [void]$script:DeviceListBox.Items.Add($item)
    }
    if ($script:DeviceListBox.Items.Count -gt 0) { $script:DeviceListBox.SelectedIndex = 0 }

    $script:DeviceListContainer.Children.Add($script:DeviceListBox) | Out-Null

    $hint = New-ViewLabel -Text "Выберите устройство и нажмите «Подключиться»." -Light
    $script:DeviceListContainer.Children.Add($hint) | Out-Null

    $btnConnectSelected = New-ViewButton -Text "Подключиться к выбранному" -Color "#C8C8C8" -OnClick {
        if ($script:DeviceListBox.SelectedItem) {
            $ip = $script:DeviceListBox.SelectedItem.Tag
            if ($ip) {
                $result = Connect-AdbDevice -Ip $ip
                if ($result.Success) {
                    Set-ConfigValue -Key "LastIp" -Value $ip
                    Update-StatusBar
                    Check-OtaState
                    Switch-View -ViewName "Setup"
                }
            }
        } else {
            Write-Log -Message "Устройство не выбрано" -Level "Warning"
        }
    }
    $script:DeviceListContainer.Children.Add($btnConnectSelected) | Out-Null
}

# ===== ФОНОВОЕ СКАНИРОВАНИЕ =====
function Start-NetworkScan {
    Write-Log -Message "=== Запуск сканирования сети ===" -Level "Info"

    $subnet = Get-LocalSubnet
    if (-not $subnet) {
        Write-Log -Message "Не удалось определить подсеть" -Level "Error"
        return
    }

    Write-Log -Message "Подсеть: $($subnet.Subnet).0/24" -Level "Info"

    $script:DeviceListContainer.Children.Clear()
    $script:SetupBtnScan.IsEnabled = $false
    $script:SetupBtnScan.Content = "Сканирую..."

    $logBoxRef = $script:LogBox

    $script:ScanRunspace = [runspacefactory]::CreateRunspace()
    $script:ScanRunspace.ApartmentState = "STA"
    $script:ScanRunspace.ThreadOptions = "ReuseThread"
    $script:ScanRunspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $script:ScanRunspace

    $ps.AddScript({
        param($dispatcher, $subnetStr, $logBox)

        function Write-BgLog {
            param($msg, $lvl = "Info")
            if (-not $logBox) { return }
            try {
                $logBox.Dispatcher.Invoke([action]{
                    $time = Get-Date -Format "HH:mm:ss"
                    $prefix = switch ($lvl) {
                        "Error"   { "[ОШИБКА]" }
                        "Warning" { "[!]" }
                        "Success" { "[OK]" }
                        default   { "[i]" }
                    }
                    $line = "$time $prefix $msg"

                    $para = New-Object System.Windows.Documents.Paragraph
                    $para.Margin = New-Object System.Windows.Thickness(0)
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = "$line`r`n"
                    $color = switch ($lvl) {
                        "Error"   { [System.Windows.Media.Brushes]::LightCoral }
                        "Warning" { [System.Windows.Media.Brushes]::Khaki }
                        "Success" { [System.Windows.Media.Brushes]::LightGreen }
                        default   { [System.Windows.Media.Brushes]::LightGray }
                    }
                    $run.Foreground = $color
                    $para.Inlines.Add($run)
                    $logBox.Document.Blocks.Add($para)
                    $logBox.ScrollToEnd()
                })
            } catch { }
            Start-Sleep -Milliseconds 80
        }

        function Scan-Internal {
            param($Subnet)
            $devices = @()

            Write-BgLog "Шаг 1/3: Чтение ARP-таблицы..."
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
                    Write-BgLog "  ARP: $arpIp"
                }
            }
            Write-BgLog "  Итого из ARP: $($devices.Count)" "Success"

            Write-BgLog "Шаг 2/3: Асинхронный ping 254 адресов..."
            $pingTasks = @()
            foreach ($i in 1..254) {
                $ip = "$Subnet.$i"
                $ping = New-Object System.Net.NetworkInformation.Ping
                $task = $ping.SendPingAsync($ip, 200)
                $pingTasks += [PSCustomObject]@{ Ping = $ping; IP = $ip; Task = $task }
            }
            try { [System.Threading.Tasks.Task]::WaitAll(($pingTasks | ForEach-Object { $_.Task }), 3000) | Out-Null } catch { }
            foreach ($t in $pingTasks) {
                try {
                    if ($t.Task.IsCompleted -and $t.Task.Result.Status -eq "Success") {
                        if (-not ($devices | Where-Object { $_.IP -eq $t.IP })) {
                            $devices += [PSCustomObject]@{ IP = $t.IP; Source = "ping" }
                            Write-BgLog "  ping: $($t.IP)"
                        }
                    }
                } catch { }
                $t.Ping.Dispose()
            }
            Write-BgLog "  Итого после ping: $($devices.Count)" "Success"

            Write-BgLog "Шаг 3/3: Проверка порта 5555..."

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
                        Write-BgLog "  ★ ADB на $($t.Device.IP)" "Success"
                    }
                } catch { }
                $t.Tcp.Dispose()
            }

            $knownIps = $devices | ForEach-Object { $_.IP }
            $silentIps = @()
            foreach ($i in 1..254) {
                $ip = "$Subnet.$i"
                if ($ip -notin $knownIps) { $silentIps += $ip }
            }

            Write-BgLog "  Проверка оставшихся $($silentIps.Count) адресов..."
            $silentTasks = @()
            foreach ($ip in $silentIps) {
                $tcp = New-Object System.Net.Sockets.TcpClient
                try {
                    $task = $tcp.ConnectAsync($ip, 5555)
                    $silentTasks += [PSCustomObject]@{ Tcp = $tcp; IP = $ip; Task = $task }
                } catch { $tcp.Dispose() }
            }
            Start-Sleep -Milliseconds 2000
            foreach ($t in $silentTasks) {
                try {
                    if ($t.Tcp.Connected) {
                        $devices += [PSCustomObject]@{ IP = $t.IP; Source = "ADB" }
                        Write-BgLog "  ★ ADB (молчащий): $($t.IP)" "Success"
                    }
                } catch { }
                $t.Tcp.Dispose()
            }

            $devices = $devices | Sort-Object @{Expression={ if ($_.Source -eq "ADB") { 0 } else { 1 } }}, @{Expression={ [version]$_.IP }}
            return ,$devices
        }

        $result = Scan-Internal -Subnet $subnetStr
        return $result
    })

    $ps.AddArgument($window.Dispatcher)
    $ps.AddArgument($subnet.Subnet)
    $ps.AddArgument($logBoxRef)

    $script:ScanPS = $ps
    $script:ScanHandle = $ps.BeginInvoke()

    $script:ScanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $script:ScanTimer.Add_Tick({
        if ($script:ScanHandle.IsCompleted) {
            $script:ScanTimer.Stop()
            try {
                $result = $script:ScanPS.EndInvoke($script:ScanHandle)
            } catch {
                Write-Log -Message "Ошибка сканирования: $_" -Level "Error"
                $result = @()
            }
            $script:ScanPS.Dispose()

            $script:SetupBtnScan.IsEnabled = $true
            $script:SetupBtnScan.Content = "Сканировать"

            Write-Log -Message "Сканирование завершено. Найдено: $($result.Count)" -Level "Success"
            foreach ($d in $result) {
                $marker = if ($d.Source -eq "ADB") { "★" } else { " " }
                Write-Log -Message "  $marker $($d.IP) [$($d.Source)]" -Level "Info"
            }

            $script:FoundDevices = $result
            Show-DeviceListInline -Devices $result
        }
    })
    $script:ScanTimer.Start()
}