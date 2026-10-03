# ============================================================================
#  Экран: Мониторинг температуры
# ============================================================================

function Show-ThermalView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Температура ТВ"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Мониторинг температурных датчиков. Обновляется каждые 2 секунды. Нажмите «Стоп» чтобы остановить опрос." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,10"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ТЕКУЩИЕ ДАТЧИКИ =====
    $mainStack.Children.Add((New-StepTitle -Text "Датчики")) | Out-Null

    $script:ThermalZonesContainer = New-Object System.Windows.Controls.StackPanel
    $script:ThermalZonesContainer.Margin = "0,5,0,15"
    $mainStack.Children.Add($script:ThermalZonesContainer) | Out-Null

    Update-ThermalZones

    # ===== ГРАФИК =====
    $mainStack.Children.Add((New-StepTitle -Text "График за 5 минут")) | Out-Null

    $script:ThermalChartCanvas = New-Object System.Windows.Controls.Canvas
    $script:ThermalChartCanvas.Background = "#1F1F1F"
    $script:ThermalChartCanvas.Height = 180
    $script:ThermalChartCanvas.Margin = "0,5,0,15"
    $script:ThermalChartCanvas.Width = 700

    $mainStack.Children.Add($script:ThermalChartCanvas) | Out-Null

    # Данные графика
    $script:ThermalHistory = @()       # массив температур
    $script:ThermalHistoryMax = 150    # 5 мин при обновлении раз в 2 сек

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack {
        Stop-ThermalWatcher
        Switch-View -ViewName "Setup"
    }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    $script:ThermalWatcherRunning = $true
    $script:ThermalRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ThermalRefreshTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:ThermalRefreshTimer.Add_Tick({
        try {
            if (-not $script:connected) {
                Stop-ThermalWatcher
                return
            }
            Update-ThermalZones
            Update-ThermalChart
        } catch { }
    })
    $script:ThermalRefreshTimer.Start()

    # Кнопка Start/Stop
    $script:ThermalBtnToggle = New-Object System.Windows.Controls.Button
    $script:ThermalBtnToggle.Content = "Стоп"
    $script:ThermalBtnToggle.Style = $window.Resources["RoundedButton"]
    $script:ThermalBtnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
    )
    $script:ThermalBtnToggle.Padding = "12,6"
    $script:ThermalBtnToggle.Margin = "0,0,8,0"
    $script:ThermalBtnToggle.Add_Click({
        if ($script:ThermalWatcherRunning) {
            Stop-ThermalWatcher
        } else {
            Start-ThermalWatcher
        }
    })
    $buttons += $script:ThermalBtnToggle

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран температуры" -Level "Info"
}

function Update-ThermalZones {
    if (-not $script:ThermalZonesContainer) { return }

    $zones = Get-ThermalZones
    $script:ThermalZonesContainer.Children.Clear()

    if ($zones.Count -eq 0) {
        $empty = New-ViewLabel -Text "Датчики не найдены или недоступны." -Light
        $script:ThermalZonesContainer.Children.Add($empty) | Out-Null
        return
    }

    # Обновляем график
    $cpuTemp = ($zones | Where-Object { $_.Type -match 'cpu|soc|ap' } | Select-Object -First 1).TempC
    if ($cpuTemp) {
        $script:ThermalHistory += $cpuTemp
        if ($script:ThermalHistory.Count -gt $script:ThermalHistoryMax) {
            $script:ThermalHistory = $script:ThermalHistory[-$script:ThermalHistoryMax..-1]
        }
    }

    # Строим карточки
    foreach ($z in $zones) {
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

        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = "$($z.Type)  ($($z.Zone))"
        $nameTb.FontSize = 12
        $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $nameTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($nameTb, 0)
        $grid.Children.Add($nameTb) | Out-Null

        # Цвет по температуре
        $tempColor = if ($z.TempC -gt 80) { "#FF6B6B" }
                     elseif ($z.TempC -gt 60) { "#FFC83D" }
                     elseif ($z.TempC -gt 40) { "#6CCB5F" }
                     else { "#60CDFF" }

        $tempTb = New-Object System.Windows.Controls.TextBlock
        $tempTb.Text = "$($z.TempC) °C"
        $tempTb.FontSize = 15
        $tempTb.FontWeight = "Bold"
        $tempTb.FontFamily = "Consolas"
        $tempTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString($tempColor)
        )
        $tempTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($tempTb, 1)
        $grid.Children.Add($tempTb) | Out-Null

        $row.Child = $grid
        $script:ThermalZonesContainer.Children.Add($row) | Out-Null
    }

    Update-ThermalChart
}

function Update-ThermalChart {
    if (-not $script:ThermalChartCanvas) { return }
    $canvas = $script:ThermalChartCanvas
    $canvas.Children.Clear()

    $history = $script:ThermalHistory
    if ($history.Count -lt 2) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "Собираю данные..."
        $empty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
        )
        $empty.FontSize = 12
        [System.Windows.Controls.Canvas]::SetLeft($empty, 20)
        [System.Windows.Controls.Canvas]::SetTop($empty, 80)
        $canvas.Children.Add($empty) | Out-Null
        return
    }

    # Параметры графика
    $width = 700
    $height = 180
    $padding = 30

    $minTemp = ($history | Measure-Object -Minimum).Minimum - 2
    $maxTemp = ($history | Measure-Object -Maximum).Maximum + 2
    if ($maxTemp - $minTemp -lt 10) { $maxTemp = $minTemp + 10 }

    $stepX = ($width - $padding * 2) / [math]::Max($history.Count - 1, 1)

    # Рисуем линию
    $polyline = New-Object System.Windows.Shapes.Polyline
    $polyline.Stroke = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $polyline.StrokeThickness = 2
    $polyline.StrokeLineJoin = "Round"

    for ($i = 0; $i -lt $history.Count; $i++) {
        $temp = $history[$i]
        $x = $padding + ($i * $stepX)
        $y = $height - $padding - (($temp - $minTemp) / ($maxTemp - $minTemp)) * ($height - $padding * 2)
        $polyline.Points.Add((New-Object System.Windows.Point($x, $y)))
    }
    $canvas.Children.Add($polyline) | Out-Null

    # Подписи min/max
    $minLabel = New-Object System.Windows.Controls.TextBlock
    $minLabel.Text = "$([math]::Round($minTemp, 1))°"
    $minLabel.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
    )
    $minLabel.FontSize = 10
    [System.Windows.Controls.Canvas]::SetLeft($minLabel, 5)
    [System.Windows.Controls.Canvas]::SetTop($minLabel, $height - $padding - 5)
    $canvas.Children.Add($minLabel) | Out-Null

    $maxLabel = New-Object System.Windows.Controls.TextBlock
    $maxLabel.Text = "$([math]::Round($maxTemp, 1))°"
    $maxLabel.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
    )
    $maxLabel.FontSize = 10
    [System.Windows.Controls.Canvas]::SetLeft($maxLabel, 5)
    [System.Windows.Controls.Canvas]::SetTop($maxLabel, $padding - 5)
    $canvas.Children.Add($maxLabel) | Out-Null
}

function Stop-ThermalWatcher {
    if ($script:ThermalRefreshTimer) {
        $script:ThermalRefreshTimer.Stop()
    }
    $script:ThermalWatcherRunning = $false
    if ($script:ThermalBtnToggle) {
        $script:ThermalBtnToggle.Content = "Запустить"
        $script:ThermalBtnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
    }
    Write-Log -Message "Мониторинг температуры остановлен" -Level "Info"
}

function Start-ThermalWatcher {
    if ($script:ThermalRefreshTimer) {
        $script:ThermalRefreshTimer.Start()
    }
    $script:ThermalWatcherRunning = $true
    if ($script:ThermalBtnToggle) {
        $script:ThermalBtnToggle.Content = "Стоп"
        $script:ThermalBtnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
    }
    Write-Log -Message "Мониторинг температуры запущен" -Level "Info"
}