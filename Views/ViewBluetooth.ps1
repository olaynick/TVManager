# ============================================================================
#  Экран: Bluetooth
#  Вкладки: Состояние / Сопряжённые / Поиск
# ============================================================================

function Show-BluetoothView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Bluetooth"
    $mainStack.Children.Add($header) | Out-Null

    # ===== ПРОВЕРКА ПОДКЛЮЧЕНИЯ =====
    if (-not $script:connected) {
        $warnCard = New-Object System.Windows.Controls.Border
        $warnCard.Background = "#3D3520"
        $warnCard.BorderBrush = "#C8C8C8"
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
                if ($result.Success) { Switch-View -ViewName "Bluetooth" }
            }
        }
        $mainStack.Children.Add($btnReconnect) | Out-Null

        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ЗАГРУЗКА ДАННЫХ =====
    $info = Get-BluetoothInfo

    # ===== ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,5,0,0"

    # =========================================================================
    #  ВКЛАДКА 1: СОСТОЯНИЕ
    # =========================================================================
    $tabState = New-Object System.Windows.Controls.TabItem
    $tabState.Header = "Состояние"
    $tabState.Style = $window.Resources["MiuiTabItem"]

    $statePanel = New-Object System.Windows.Controls.StackPanel
    $statePanel.Margin = "15"

    # --- Карточка статуса ---
    $statusCard = New-Object System.Windows.Controls.Border
    $statusCard.Background = if ($info.Enabled) { "#1F3A1F" } else { "#2B2B2B" }
    $statusCard.BorderBrush = "#3A3A3A"
    $statusCard.BorderThickness = "1"
    $statusCard.CornerRadius = "8"
    $statusCard.Padding = "15"
    $statusCard.Margin = "0,0,0,15"

    $statusStack = New-Object System.Windows.Controls.StackPanel

    $statusLine = New-Object System.Windows.Controls.TextBlock
    $statusLine.FontSize = 16
    $statusLine.FontWeight = "Bold"
    if ($info.Enabled) {
        $statusLine.Text = "Bluetooth включён"
        $statusLine.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } else {
        $statusLine.Text = "Bluetooth выключен"
        $statusLine.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
    }
    $statusStack.Children.Add($statusLine) | Out-Null

    $statusCard.Child = $statusStack
    $statePanel.Children.Add($statusCard) | Out-Null

    # --- Таблица информации ---
    $rows = @(
        @{ Label = "Имя устройства";  Value = $info.Name }
        @{ Label = "MAC-адрес";       Value = $info.Address }
        @{ Label = "Режим сканирования"; Value = $info.ScanMode }
        @{ Label = "Сопряжено";       Value = "$($info.BondedCount)" }
        @{ Label = "Подключено сейчас"; Value = "$($info.ConnectedCount)" }
    )

    $infoCard = New-Object System.Windows.Controls.Border
    $infoCard.Background = "#2B2B2B"
    $infoCard.BorderBrush = "#3A3A3A"
    $infoCard.BorderThickness = "1"
    $infoCard.CornerRadius = "8"
    $infoCard.Padding = "15"
    $infoCard.Margin = "0,0,0,15"

    $infoStack = New-Object System.Windows.Controls.StackPanel
    foreach ($row in $rows) {
        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = "0,3,0,3"

        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = "180"
        $col2 = New-Object System.Windows.Controls.ColumnDefinition
        $col2.Width = "*"
        $grid.ColumnDefinitions.Add($col1)
        $grid.ColumnDefinitions.Add($col2)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $row.Label
        $lbl.FontSize = 13
        $lbl.Foreground = "#A0A0A0"
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        $grid.Children.Add($lbl) | Out-Null

        $val = New-Object System.Windows.Controls.TextBlock
        $val.Text = if ($row.Value) { $row.Value } else { "—" }
        $val.FontSize = 13
        $val.Foreground = "#FFFFFF"
        $val.FontFamily = "Consolas"
        $val.TextWrapping = "Wrap"
        [System.Windows.Controls.Grid]::SetColumn($val, 1)
        $grid.Children.Add($val) | Out-Null

        $infoStack.Children.Add($grid) | Out-Null
    }

    $infoCard.Child = $infoStack
    $statePanel.Children.Add($infoCard) | Out-Null

    # --- Предупреждение ---
    $note = New-Object System.Windows.Controls.TextBlock
    $note.Text = "Примечание: TVManager не выключает Bluetooth автоматически — если к ТВ подключён BT-пульт, геймпад или звуковая система, они потеряют связь. При необходимости меняйте состояние через настройки ТВ."
    $note.FontSize = 11
    $note.Foreground = "#A0A0A0"
    $note.TextWrapping = "Wrap"
    $note.Margin = "0,0,0,10"
    $statePanel.Children.Add($note) | Out-Null

    $tabState.Content = $statePanel
    $tabControl.Items.Add($tabState) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 2: СОПРЯЖЁННЫЕ
    # =========================================================================
    $tabBonded = New-Object System.Windows.Controls.TabItem
    $tabBonded.Header = "Сопряжённые"
    $tabBonded.Style = $window.Resources["MiuiTabItem"]

    $bondedPanel = New-Object System.Windows.Controls.StackPanel
    $bondedPanel.Margin = "15"

    if (-not $info.Enabled) {
        $noBt = New-ViewLabel -Text "Bluetooth выключен — сопряжённые устройства недоступны." -Light
        $bondedPanel.Children.Add($noBt) | Out-Null
    } else {
        Write-Log -Message "Загружаю сопряжённые устройства..." -Level "Info"
        $bonded = Get-BluetoothBondedDevices

        if ($bonded.Count -eq 0) {
            $empty = New-ViewLabel -Text "Нет сопряжённых устройств." -Light
            $bondedPanel.Children.Add($empty) | Out-Null
        } else {
            foreach ($dev in $bonded) {
                $row = New-Object System.Windows.Controls.Border
                $row.Background = "#2B2B2B"
                $row.BorderBrush = "#3A3A3A"
                $row.BorderThickness = "1"
                $row.CornerRadius = "6"
                $row.Padding = "10"
                $row.Margin = "0,0,0,6"

                $grid = New-Object System.Windows.Controls.Grid
                $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "*"
                $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "Auto"
                $grid.ColumnDefinitions.Add($c1)
                $grid.ColumnDefinitions.Add($c2)

                $leftStack = New-Object System.Windows.Controls.StackPanel
                [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)

                $nameTb = New-Object System.Windows.Controls.TextBlock
                $nameTb.FontSize = 13
                $nameTb.FontWeight = "Bold"

                $badge = ""
                if ($dev.Connected) { $badge += "  [ПОДКЛЮЧЕНО]" }
                if ($dev.IsLE)      { $badge += "  [LE]" }

                $nameTb.Text = "$($dev.Name)$badge"

                if ($dev.Connected) {
                    $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
                    )
                } else {
                    $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
                    )
                }
                $leftStack.Children.Add($nameTb) | Out-Null

                $macTb = New-Object System.Windows.Controls.TextBlock
                $macTb.Text = $dev.Mac
                $macTb.FontFamily = "Consolas"
                $macTb.FontSize = 11
                $macTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#909090")
                )
                $macTb.Margin = "0,3,0,0"
                $leftStack.Children.Add($macTb) | Out-Null

                $grid.Children.Add($leftStack) | Out-Null

                # Кнопка "Отключить сопряжение"
                $btnUnpair = New-Object System.Windows.Controls.Button
                $btnUnpair.Content = "Отключить"
                $btnUnpair.Style = $window.Resources["RoundedButton"]
                $btnUnpair.Background = New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
                )
                $btnUnpair.Height = 30
                $btnUnpair.FontSize = 11
                $btnUnpair.Padding = New-Object System.Windows.Thickness(10, 0, 10, 0)
                $btnUnpair.VerticalAlignment = "Center"

                $btnUnpair.Tag = [PSCustomObject]@{
                    Mac  = $dev.Mac
                    Name = $dev.Name
                }

                $btnUnpair.Add_Click({
                    param($sender, $e)
                    $data = $sender.Tag
                    $confirm = [System.Windows.MessageBox]::Show(
                        "Отключить сопряжение с «$($data.Name)»?`n`n$($data.Mac)`n`nУстройство перестанет автоматически подключаться к ТВ.",
                        "Подтверждение",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Warning)

                    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

                    $ok = Remove-BluetoothBond -Mac $data.Mac
                    if ($ok) {
                        Switch-View -ViewName "Bluetooth"
                    } else {
                        [System.Windows.MessageBox]::Show(
                            "Не удалось отключить сопряжение.`n`nСкорее всего, прошивка не поддерживает команду unpair из ADB.`nПопробуйте вручную в настройках Bluetooth на телевизоре.",
                            "Не поддерживается",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    }
                })

                [System.Windows.Controls.Grid]::SetColumn($btnUnpair, 1)
                $grid.Children.Add($btnUnpair) | Out-Null

                $row.Child = $grid
                $bondedPanel.Children.Add($row) | Out-Null
            }
        }
    }

    $tabBonded.Content = $bondedPanel
    $tabControl.Items.Add($tabBonded) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 3: ПОИСК
    # =========================================================================
    $tabScan = New-Object System.Windows.Controls.TabItem
    $tabScan.Header = "Поиск новых"
    $tabScan.Style = $window.Resources["MiuiTabItem"]

    $scanPanel = New-Object System.Windows.Controls.StackPanel
    $scanPanel.Margin = "15"

    $scanInfo = New-ViewLabel -Text "Нажмите «Начать поиск» внизу. Сканирование занимает около 12 секунд. Найденные устройства появятся в списке." -Light
    $scanInfo.TextWrapping = "Wrap"
    $scanInfo.Margin = "0,0,0,10"
    $scanPanel.Children.Add($scanInfo) | Out-Null

    if (-not $info.Enabled) {
        $noBtScan = New-ViewLabel -Text "Bluetooth выключен — сканирование невозможно. Включите BT в настройках ТВ." -Light
        $scanPanel.Children.Add($noBtScan) | Out-Null
    }

    $script:BtScanResultsContainer = New-Object System.Windows.Controls.StackPanel
    $script:BtScanResultsContainer.Margin = "0,5,0,0"
    $scanPanel.Children.Add($script:BtScanResultsContainer) | Out-Null

    # Если есть сохранённые результаты — покажем
    if ($script:BtScanResults -and $script:BtScanResults.Count -gt 0) {
        foreach ($dev in $script:BtScanResults) {
            $row = New-Object System.Windows.Controls.Border
            $row.Background = "#2B2B2B"
            $row.BorderBrush = "#3A3A3A"
            $row.BorderThickness = "1"
            $row.CornerRadius = "6"
            $row.Padding = "10"
            $row.Margin = "0,0,0,6"

            $grid = New-Object System.Windows.Controls.Grid
            $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "*"
            $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "Auto"
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)

            $leftStack = New-Object System.Windows.Controls.StackPanel
            [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)

            $nameTb = New-Object System.Windows.Controls.TextBlock
            $nameTb.Text = $dev.Name
            $nameTb.FontSize = 13
            $nameTb.FontWeight = "Bold"
            $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
            )
            $leftStack.Children.Add($nameTb) | Out-Null

            $macTb = New-Object System.Windows.Controls.TextBlock
            $macTb.Text = $dev.Mac
            $macTb.FontFamily = "Consolas"
            $macTb.FontSize = 11
            $macTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#909090")
            )
            $macTb.Margin = "0,3,0,0"
            $leftStack.Children.Add($macTb) | Out-Null

            $grid.Children.Add($leftStack) | Out-Null

            $hintTb = New-Object System.Windows.Controls.TextBlock
            $hintTb.Text = "Сопряжение — на ТВ"
            $hintTb.FontSize = 11
            $hintTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
            )
            $hintTb.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($hintTb, 1)
            $grid.Children.Add($hintTb) | Out-Null

            $row.Child = $grid
            $script:BtScanResultsContainer.Children.Add($row) | Out-Null
        }
    } else {
        $emptyHint = New-ViewLabel -Text "Пока ничего не найдено." -Light
        $script:BtScanResultsContainer.Children.Add($emptyHint) | Out-Null
    }

    $tabScan.Content = $scanPanel
    $tabControl.Items.Add($tabScan) | Out-Null

    $mainStack.Children.Add($tabControl) | Out-Null

    # ===== ROOT + BOTTOM BAR =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    $buttons = @()

    # --- Обновить ---
    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({ Switch-View -ViewName "Bluetooth" })
    $buttons += $btnRefresh

    # --- Открыть настройки BT на ТВ ---
    $btnSettings = New-Object System.Windows.Controls.Button
    $btnSettings.Content = "Открыть настройки BT на ТВ"
    $btnSettings.Style = $window.Resources["RoundedButton"]
    $btnSettings.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnSettings.Padding = "12,6"
    $btnSettings.Margin = "0,0,8,0"
    $btnSettings.Add_Click({ Open-BluetoothSettings | Out-Null })
    $buttons += $btnSettings

    # --- Включить/выключить BT (с осторожностью) ---
    if ($info.Enabled) {
        $btnToggle = New-Object System.Windows.Controls.Button
        $btnToggle.Content = "Выключить BT"
        $btnToggle.Style = $window.Resources["RoundedButton"]
        $btnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
        $btnToggle.Padding = "12,6"
        $btnToggle.Margin = "0,0,8,0"
        $btnToggle.Add_Click({
            $confirm = [System.Windows.MessageBox]::Show(
                "Выключить Bluetooth на телевизоре?`n`nВНИМАНИЕ: если к ТВ подключён BT-пульт, геймпад или звуковая система — они потеряют связь.`n`nПродолжить?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                Disable-Bluetooth | Out-Null
                Switch-View -ViewName "Bluetooth"
            }
        })
        $buttons += $btnToggle
    } else {
        $btnToggle = New-Object System.Windows.Controls.Button
        $btnToggle.Content = "Включить BT"
        $btnToggle.Style = $window.Resources["RoundedButton"]
        $btnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
        $btnToggle.Padding = "12,6"
        $btnToggle.Margin = "0,0,8,0"
        $btnToggle.Add_Click({
            Enable-Bluetooth | Out-Null
            Switch-View -ViewName "Bluetooth"
        })
        $buttons += $btnToggle
    }

    # --- Сканировать ---
    if ($info.Enabled) {
        $btnScan = New-Object System.Windows.Controls.Button
        $btnScan.Content = "Начать поиск"
        $btnScan.Style = $window.Resources["RoundedButton"]
        $btnScan.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
        $btnScan.Padding = "12,6"
        $btnScan.Margin = "0,0,8,0"
        $btnScan.Tag = $btnScan
        $btnScan.Add_Click({
            param($sender, $e)
            $sender.IsEnabled = $false
            $sender.Content = "Сканирую..."

            Write-Log -Message "=== Сканирование Bluetooth ===" -Level "Info"
            $found = Get-BluetoothDiscoverableDevices -ScanSeconds 12
            $script:BtScanResults = $found

            Write-Log -Message "Найдено: $($found.Count)" -Level "Success"
            Switch-View -ViewName "Bluetooth"
        })
        $buttons += $btnScan
    }

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран Bluetooth" -Level "Info"
}