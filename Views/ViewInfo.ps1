function Show-InfoView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "30,25,30,25"

    $header = New-ViewHeader -Text "Сведения о телевизоре"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== КНОПКИ ВЕРХНЕЙ ПАНЕЛИ =====
    $topPanel = New-Object System.Windows.Controls.StackPanel
    $topPanel.Orientation = "Horizontal"
    $topPanel.Margin = "0,0,0,15"

    # --- Обновить ---
    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить сведения"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnRefresh.Padding = "15,8"
    $btnRefresh.Margin = "0,0,10,0"
    $btnRefresh.Add_Click({
        $script:DeviceInfo = Get-DeviceInfo
        Switch-View -ViewName "Info"
    })
    $topPanel.Children.Add($btnRefresh) | Out-Null

    # --- Копировать всё ---
    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content = "Копировать всё"
    $btnCopy.Style = $window.Resources["RoundedButton"]
    $btnCopy.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#607D8B")
    )
    $btnCopy.Padding = "15,8"
    $btnCopy.Margin = "0,0,10,0"
    $btnCopy.Add_Click({
        if ($script:DeviceInfo) {
            $text = ""
            foreach ($prop in $script:DeviceInfo.PSObject.Properties) {
                $text += "$($prop.Name): $($prop.Value)`r`n"
            }
            [System.Windows.Clipboard]::SetText($text)
            Write-Log -Message "Сведения скопированы в буфер обмена" -Level "Success"
        }
    })
    $topPanel.Children.Add($btnCopy) | Out-Null

    # --- Экспорт в файл ---
    $btnExport = New-Object System.Windows.Controls.Button
    $btnExport.Content = "Экспорт в файл"
    $btnExport.Style = $window.Resources["RoundedButton"]
    $btnExport.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9C27B0")
    )
    $btnExport.Padding = "15,8"
    $btnExport.Add_Click({
        Show-ExportDeviceDumpDialog
    })
    $topPanel.Children.Add($btnExport) | Out-Null

    $mainStack.Children.Add($topPanel) | Out-Null

    # ===== ЗАГРУЗКА ДАННЫХ =====
    if (-not $script:DeviceInfo) {
        Write-Log -Message "Загружаю сведения об устройстве..." -Level "Info"
        $script:DeviceInfo = Get-DeviceInfo
    }

    $info = $script:DeviceInfo

    # ===== БЛОКИ ИНФОРМАЦИИ =====
    $blocks = @(
        @{
            Title = "Устройство"
            Color = "#4A90E2"
            Rows = @(
                @{ Label = "Модель";         Value = $info.Model },
                @{ Label = "Производитель";  Value = $info.Manufacturer },
                @{ Label = "Серийный номер"; Value = $info.SerialNumber },
                @{ Label = "MAC-адрес";      Value = $info.MacAddress }
            )
        },
        @{
            Title = "Система"
            Color = "#66BB6A"
            Rows = @(
                @{ Label = "Версия Android";    Value = $info.AndroidVersion },
                @{ Label = "Номер сборки";      Value = $info.BuildNumber },
                @{ Label = "Ядро";              Value = $info.KernelVersion },
                @{ Label = "Патч безопасности"; Value = $info.SecurityPatch },
                @{ Label = "Bootloader";        Value = $info.Bootloader }
            )
        },
        @{
            Title = "Процессор и GPU"
            Color = "#9C27B0"
            Rows = @(
                @{ Label = "Процессор";   Value = $info.CpuModel },
                @{ Label = "Ядер CPU";    Value = $info.CpuCores },
                @{ Label = "Архитектура"; Value = $info.CpuAbi },
                @{ Label = "GPU";         Value = $info.GpuInfo }
            )
        },
        @{
            Title = "Память"
            Color = "#FFB74D"
            Rows = @(
                @{ Label = "Всего RAM";        Value = $info.TotalRam },
                @{ Label = "Свободно RAM";     Value = $info.AvailableRam },
                @{ Label = "Всего Storage";    Value = $info.TotalStorage },
                @{ Label = "Свободно Storage"; Value = $info.AvailableStorage }
            )
        },
        @{
            Title = "Экран и сеть"
            Color = "#00BCD4"
            Rows = @(
                @{ Label = "Разрешение";   Value = $info.ScreenResolution },
                @{ Label = "Плотность";    Value = $info.ScreenDensity },
                @{ Label = "IP-адрес";     Value = $info.IpAddress },
                @{ Label = "Время работы"; Value = $info.Uptime }
            )
        }
    )

    foreach ($block in $blocks) {
        $card = New-Object System.Windows.Controls.Border
        $card.Background = "White"
        $card.BorderBrush = "#E1E1E6"
        $card.BorderThickness = "1"
        $card.CornerRadius = "10"
        $card.Padding = "15"
        $card.Margin = "0,0,0,15"

        $cardStack = New-Object System.Windows.Controls.StackPanel

        $cardHeader = New-Object System.Windows.Controls.TextBlock
        $cardHeader.Text = $block.Title
        $cardHeader.FontSize = 15
        $cardHeader.FontWeight = "Bold"
        $cardHeader.Foreground = $block.Color
        $cardHeader.Margin = "0,0,0,10"
        $cardStack.Children.Add($cardHeader) | Out-Null

        foreach ($row in $block.Rows) {
            $grid = New-Object System.Windows.Controls.Grid
            $grid.Margin = "0,3,0,3"

            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = "200"
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

            $cardStack.Children.Add($grid) | Out-Null
        }

        $card.Child = $cardStack
        $mainStack.Children.Add($card) | Out-Null
    }

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран сведений" -Level "Info"
}