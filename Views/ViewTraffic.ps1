# ============================================================================
#  Экран: Мониторинг трафика
#  Вкладки: Обзор / График / Приложения
# ============================================================================

function Show-TrafficView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Мониторинг трафика"
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
                if ($result.Success) { Switch-View -ViewName "Traffic" }
            }
        }
        $mainStack.Children.Add($btnReconnect) | Out-Null

        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ОПРЕДЕЛЯЕМ АКТИВНЫЙ ИНТЕРФЕЙС =====
    $activeIface = Get-ActiveTrafficInterface
    if (-not $activeIface) {
        $mainStack.Children.Add((New-ViewLabel -Text "Не удалось определить сетевой интерфейс.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    Write-Log -Message "Активный интерфейс для мониторинга: $activeIface" -Level "Info"

    # ===== ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,5,0,0"

    # =========================================================================
    #  ВКЛАДКА 1: ОБЗОР
    # =========================================================================
    $tabOverview = New-Object System.Windows.Controls.TabItem
    $tabOverview.Header = "Обзор"
    $tabOverview.Style = $window.Resources["MiuiTabItem"]

    $overviewPanel = New-Object System.Windows.Controls.StackPanel
    $overviewPanel.Margin = "15"

    # --- Интерфейс ---
    $ifaceCard = New-Object System.Windows.Controls.Border
    $ifaceCard.Background = "#2B2B2B"
    $ifaceCard.BorderBrush = "#3A3A3A"
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
    if ($activeIface -eq "wlan0") {
        $ifaceIcon.Text = "[Wi-Fi]"
        $ifaceIcon.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } elseif ($activeIface -eq "eth0") {
        $ifaceIcon.Text = "[LAN]"
        $ifaceIcon.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
        )
    } else {
        $ifaceIcon.Text = "[NET]"
        $ifaceIcon.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
    }
    $ifaceStack.Children.Add($ifaceIcon) | Out-Null

    $ifaceText = New-Object System.Windows.Controls.TextBlock
    $ifaceText.FontSize = 13
    $ifaceText.VerticalAlignment = "Center"
    $ifaceText.Text = "Активный интерфейс: $activeIface"
    $ifaceText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $ifaceStack.Children.Add($ifaceText) | Out-Null

    $ifaceCard.Child = $ifaceStack
    $overviewPanel.Children.Add($ifaceCard) | Out-Null

    # --- Скорость в реальном времени ---
    $mainStack.Children.Add($tabControl) | Out-Null  # добавим позже

    $liveCard = New-Object System.Windows.Controls.Border
    $liveCard.Background = "#1F3A1F"
    $liveCard.BorderBrush = "#3A5A3A"
    $liveCard.BorderThickness = "1"
    $liveCard.CornerRadius = "8"
    $liveCard.Padding = "15"
    $liveCard.Margin = "0,0,0,12"

    $liveStack = New-Object System.Windows.Controls.StackPanel

    $liveTitle = New-Object System.Windows.Controls.TextBlock
    $liveTitle.Text = "Скорость сейчас"
    $liveTitle.FontSize = 13
    $liveTitle.FontWeight = "Bold"
    $liveTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    $liveTitle.Margin = "0,0,0,8"
    $liveStack.Children.Add($liveTitle) | Out-Null

    # Rx
    $rxLine = New-Object System.Windows.Controls.TextBlock
    $rxLine.FontSize = 15
    $rxLine.FontFamily = "Consolas"
    $rxLine.FontWeight = "Bold"
    $rxLine.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $rxLine.Text = "↓ Загрузка:   —"
    $liveStack.Children.Add($rxLine) | Out-Null

    # Tx
    $txLine = New-Object System.Windows.Controls.TextBlock
    $txLine.FontSize = 15
    $txLine.FontFamily = "Consolas"
    $txLine.FontWeight = "Bold"
    $txLine.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $txLine.Text = "↑ Отдача:     —"
    $txLine.Margin = "0,4,0,0"
    $liveStack.Children.Add($txLine) | Out-Null

    $liveCard.Child = $liveStack
    $overviewPanel.Children.Add($liveCard) | Out-Null

    # --- Общие счётчики с момента включения ---
    $totalCard = New-Object System.Windows.Controls.Border
    $totalCard.Background = "#2B2B2B"
    $totalCard.BorderBrush = "#3A3A3A"
    $totalCard.BorderThickness = "1"
    $totalCard.CornerRadius = "8"
    $totalCard.Padding = "15"
    $totalCard.Margin = "0,0,0,12"

    $totalStack = New-Object System.Windows.Controls.StackPanel

    $totalTitle = New-Object System.Windows.Controls.TextBlock
    $totalTitle.Text = "Всего с момента включения ТВ"
    $totalTitle.FontSize = 13
    $totalTitle.FontWeight = "Bold"
    $totalTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $totalTitle.Margin = "0,0,0,8"
    $totalStack.Children.Add($totalTitle) | Out-Null

    $stats = Get-InterfaceStats -Interface $activeIface

    $totalRxLine = New-Object System.Windows.Controls.TextBlock
    $totalRxLine.FontSize = 13
    $totalRxLine.FontFamily = "Consolas"
    $totalRxLine.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $totalRxLine.Text = "Принято:  $(Format-Bytes -Bytes $stats.RxBytes)"
    $totalStack.Children.Add($totalRxLine) | Out-Null

    $totalTxLine = New-Object System.Windows.Controls.TextBlock
    $totalTxLine.FontSize = 13
    $totalTxLine.FontFamily = "Consolas"
    $totalTxLine.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $totalTxLine.Text = "Отправлено: $(Format-Bytes -Bytes $stats.TxBytes)"
    $totalTxLine.Margin = "0,3,0,0"
    $totalStack.Children.Add($totalTxLine) | Out-Null

    $totalCard.Child = $totalStack
    $overviewPanel.Children.Add($totalCard) | Out-Null

    $tabOverview.Content = $overviewPanel
    $tabControl.Items.Add($tabOverview) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 2: ГРАФИК
    # =========================================================================
    $tabChart = New-Object System.Windows.Controls.TabItem
    $tabChart.Header = "График"
    $tabChart.Style = $window.Resources["MiuiTabItem"]

    $chartPanel = New-Object System.Windows.Controls.StackPanel
    $chartPanel.Margin = "15"

    $chartInfo = New-ViewLabel -Text "График скорости за последние 2 минуты. Обновляется каждые 2 секунды. Нажмите «Стоп», чтобы остановить." -Light
    $chartInfo.TextWrapping = "Wrap"
    $chartInfo.Margin = "0,0,0,10"
    $chartPanel.Children.Add($chartInfo) | Out-Null

    # Легенда
    $legendPanel = New-Object System.Windows.Controls.StackPanel
    $legendPanel.Orientation = "Horizontal"
    $legendPanel.Margin = "0,0,0,8"

    $rxLegend = New-Object System.Windows.Controls.TextBlock
    $rxLegend.Text = "■ Загрузка (Rx)"
    $rxLegend.FontSize = 11
    $rxLegend.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $rxLegend.Margin = "0,0,15,0"
    $legendPanel.Children.Add($rxLegend) | Out-Null

    $txLegend = New-Object System.Windows.Controls.TextBlock
    $txLegend.Text = "■ Отдача (Tx)"
    $txLegend.FontSize = 11
    $txLegend.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $legendPanel.Children.Add($txLegend) | Out-Null

    $chartPanel.Children.Add($legendPanel) | Out-Null

    # Канвас для графика
    $script:TrafficChartCanvas = New-Object System.Windows.Controls.Canvas
    $script:TrafficChartCanvas.Background = "#1F1F1F"
    $script:TrafficChartCanvas.Height = 220
    $script:TrafficChartCanvas.Width = 700
    $script:TrafficChartCanvas.Margin = "0,0,0,10"
    $chartPanel.Children.Add($script:TrafficChartCanvas) | Out-Null

    # Текущая шкала
    $script:TrafficChartMaxLabel = New-Object System.Windows.Controls.TextBlock
    $script:TrafficChartMaxLabel.FontSize = 11
    $script:TrafficChartMaxLabel.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $script:TrafficChartMaxLabel.Text = "Максимум на графике: —"
    $chartPanel.Children.Add($script:TrafficChartMaxLabel) | Out-Null

    $tabChart.Content = $chartPanel
    $tabControl.Items.Add($tabChart) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 3: ПРИЛОЖЕНИЯ
    # =========================================================================
    $tabApps = New-Object System.Windows.Controls.TabItem
    $tabApps.Header = "Приложения"
    $tabApps.Style = $window.Resources["MiuiTabItem"]

    $appsPanel = New-Object System.Windows.Controls.StackPanel
    $appsPanel.Margin = "15"

    $appsInfo = New-ViewLabel -Text "Топ приложений по сетевому трафику. Данные берутся из dumpsys netstats — обновляются реже, чем общий счётчик, и не все прошивки их отдают." -Light
    $appsInfo.TextWrapping = "Wrap"
    $appsInfo.Margin = "0,0,0,10"
    $appsPanel.Children.Add($appsInfo) | Out-Null

    $script:TrafficAppsContainer = New-Object System.Windows.Controls.StackPanel
    $appsPanel.Children.Add($script:TrafficAppsContainer) | Out-Null

    # Плейсхолдер
    $loadingHint = New-ViewLabel -Text "Нажмите «Загрузить статистику по приложениям» внизу экрана." -Light
    $script:TrafficAppsContainer.Children.Add($loadingHint) | Out-Null

    $tabApps.Content = $appsPanel
    $tabControl.Items.Add($tabApps) | Out-Null

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack {
        Stop-TrafficWatcher
        Switch-View -ViewName "Setup"
    }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # =========================================================================
    #  ЖИВОЕ ОБНОВЛЕНИЕ
    # =========================================================================

    # История для графика (пары Rx/Tx)
    $script:TrafficHistory = @()
    $script:TrafficHistoryMax = 60   # 60 точек × 2 сек = 2 минуты
    $script:TrafficPrevCounters = Get-NetworkCounters
    $script:TrafficLastSampleTime = Get-Date
    $script:TrafficActiveIface = $activeIface

    # Ссылки на элементы для обновления
    $script:TrafficRxLine = $rxLine
    $script:TrafficTxLine = $txLine
    $script:TrafficTotalRxLine = $totalRxLine
    $script:TrafficTotalTxLine = $totalTxLine

    # Таймер
    $script:TrafficWatcherRunning = $true
    $script:TrafficRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:TrafficRefreshTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:TrafficRefreshTimer.Add_Tick({
        try {
            if (-not $script:connected) {
                Stop-TrafficWatcher
                return
            }
            Update-TrafficLive
        } catch {
            Write-Log -Message "Ошибка обновления трафика: $_" -Level "Warning"
        }
    })
    $script:TrafficRefreshTimer.Start()

    # Первое обновление сразу
    Update-TrafficLive

    # ===== КНОПКИ BOTTOM BAR =====
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
    $btnRefresh.Add_Click({
        Update-TrafficLive
        Switch-View -ViewName "Traffic"
    })
    $buttons += $btnRefresh

    # --- Start/Stop ---
    $script:TrafficBtnToggle = New-Object System.Windows.Controls.Button
    $script:TrafficBtnToggle.Content = "Стоп"
    $script:TrafficBtnToggle.Style = $window.Resources["RoundedButton"]
    $script:TrafficBtnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
    )
    $script:TrafficBtnToggle.Padding = "12,6"
    $script:TrafficBtnToggle.Margin = "0,0,8,0"
    $script:TrafficBtnToggle.Add_Click({
        if ($script:TrafficWatcherRunning) {
            Stop-TrafficWatcher
        } else {
            Start-TrafficWatcher
        }
    })
    $buttons += $script:TrafficBtnToggle

    # --- Загрузить топ приложений ---
    $btnApps = New-Object System.Windows.Controls.Button
    $btnApps.Content = "Статистика по приложениям"
    $btnApps.Style = $window.Resources["RoundedButton"]
    $btnApps.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6c547e")
    )
    $btnApps.Padding = "12,6"
    $btnApps.Margin = "0,0,8,0"
    $btnApps.Add_Click({
        Load-TrafficAppsStats
    })
    $buttons += $btnApps

    # --- Сбросить график ---
    $btnResetChart = New-Object System.Windows.Controls.Button
    $btnResetChart.Content = "Сбросить график"
    $btnResetChart.Style = $window.Resources["RoundedButton"]
    $btnResetChart.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnResetChart.Padding = "12,6"
    $btnResetChart.Margin = "0,0,8,0"
    $btnResetChart.Add_Click({
        $script:TrafficHistory = @()
        if ($script:TrafficChartCanvas) { $script:TrafficChartCanvas.Children.Clear() }
        if ($script:TrafficChartMaxLabel) { $script:TrafficChartMaxLabel.Text = "Максимум на графике: —" }
        Write-Log -Message "График трафика сброшен" -Level "Info"
    })
    $buttons += $btnResetChart

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран трафика" -Level "Info"
}

# ============================================================================
#  ОБНОВЛЕНИЕ ЖИВЫХ ЗНАЧЕНИЙ
# ============================================================================
function Update-TrafficLive {
    if (-not $script:TrafficActiveIface) { return }
    if (-not $script:TrafficRxLine) { return }

    $now = Get-Date
    $elapsed = ($now - $script:TrafficLastSampleTime).TotalSeconds
    if ($elapsed -le 0) { $elapsed = 2 }

    $speed = Get-TrafficSpeed `
        -PrevCounters $script:TrafficPrevCounters `
        -Interface $script:TrafficActiveIface `
        -ElapsedSeconds $elapsed

    # Обновляем строки
    $script:TrafficRxLine.Text = "↓ Загрузка:   $(Format-ByteRate -BytesPerSecond $speed.RxBps)"
    $script:TrafficTxLine.Text = "↑ Отдача:     $(Format-ByteRate -BytesPerSecond $speed.TxBps)"

    if ($script:TrafficTotalRxLine) {
        $script:TrafficTotalRxLine.Text = "Принято:  $(Format-Bytes -Bytes $speed.TotalRx)"
    }
    if ($script:TrafficTotalTxLine) {
        $script:TrafficTotalTxLine.Text = "Отправлено: $(Format-Bytes -Bytes $speed.TotalTx)"
    }

    # Пушим точку в историю
    $script:TrafficHistory += [PSCustomObject]@{
        Time = $now
        Rx   = $speed.RxBps
        Tx   = $speed.TxBps
    }
    if ($script:TrafficHistory.Count -gt $script:TrafficHistoryMax) {
        $script:TrafficHistory = $script:TrafficHistory[-$script:TrafficHistoryMax..-1]
    }

    # Обновляем prev counters и время
    $script:TrafficPrevCounters = Get-NetworkCounters
    $script:TrafficLastSampleTime = $now

    # Перерисовываем график
    Update-TrafficChart
}

# ============================================================================
#  ГРАФИК
# ============================================================================
function Update-TrafficChart {
    if (-not $script:TrafficChartCanvas) { return }
    $canvas = $script:TrafficChartCanvas
    $canvas.Children.Clear()

    $history = $script:TrafficHistory
    if ($history.Count -lt 2) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "Собираю данные..."
        $empty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
        )
        $empty.FontSize = 12
        [System.Windows.Controls.Canvas]::SetLeft($empty, 20)
        [System.Windows.Controls.Canvas]::SetTop($empty, 100)
        $canvas.Children.Add($empty) | Out-Null
        return
    }

    $width = 700
    $height = 220
    $paddingLeft = 60
    $paddingRight = 15
    $paddingTop = 20
    $paddingBottom = 30

    # Максимум по обеим сериям (с запасом)
    $maxRx = ($history | Measure-Object -Property Rx -Maximum).Maximum
    $maxTx = ($history | Measure-Object -Property Tx -Maximum).Maximum
    $maxVal = [math]::Max($maxRx, $maxTx)
    if ($maxVal -lt 1024) { $maxVal = 1024 }   # минимум 1 КБ/с для масштаба
    $maxVal = $maxVal * 1.15                    # запас 15%

    $stepX = ($width - $paddingLeft - $paddingRight) / [math]::Max($history.Count - 1, 1)

    # Сетка (горизонтальные линии)
    for ($i = 0; $i -le 4; $i++) {
        $y = $paddingTop + ($height - $paddingTop - $paddingBottom) * ($i / 4)
        $line = New-Object System.Windows.Shapes.Line
        $line.X1 = $paddingLeft
        $line.Y1 = $y
        $line.X2 = $width - $paddingRight
        $line.Y2 = $y
        $line.Stroke = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
        )
        $line.StrokeThickness = 1
        $canvas.Children.Add($line) | Out-Null

        # Подписи шкалы
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = Format-ByteRate -BytesPerSecond ($maxVal * (1 - $i / 4))
        $lbl.FontSize = 10
        $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
        )
        [System.Windows.Controls.Canvas]::SetLeft($lbl, 5)
        [System.Windows.Controls.Canvas]::SetTop($lbl, $y - 7)
        $canvas.Children.Add($lbl) | Out-Null
    }

    # Функция: нарисовать серию
    $drawSeries = {
        param([string]$Field, [string]$Color)

        $polyline = New-Object System.Windows.Shapes.Polyline
        $polyline.Stroke = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
        )
        $polyline.StrokeThickness = 2
        $polyline.StrokeLineJoin = "Round"

        for ($i = 0; $i -lt $history.Count; $i++) {
            $val = $history[$i].$Field
            $x = $paddingLeft + ($i * $stepX)
            $y = $height - $paddingBottom - (($val / $maxVal) * ($height - $paddingTop - $paddingBottom))
            $polyline.Points.Add((New-Object System.Windows.Point($x, $y)))
        }
        $canvas.Children.Add($polyline) | Out-Null
    }

    & $drawSeries "Rx" "#60CDFF"
    & $drawSeries "Tx" "#FFC83D"

    # Обновляем метку максимума
    if ($script:TrafficChartMaxLabel) {
        $script:TrafficChartMaxLabel.Text = "Максимум на графике: $(Format-ByteRate -BytesPerSecond $maxVal)   |   точек: $($history.Count)"
    }
}

# ============================================================================
#  СТАТИСТИКА ПО ПРИЛОЖЕНИЯМ
# ============================================================================
function Load-TrafficAppsStats {
    if (-not $script:TrafficAppsContainer) { return }

    $script:TrafficAppsContainer.Children.Clear()
    $loading = New-ViewLabel -Text "Загружаю статистику (может занять несколько секунд)..." -Light
    $script:TrafficAppsContainer.Children.Add($loading) | Out-Null

    # Форсируем перерисовку
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{}
    )

    $apps = Get-TopTrafficApps -TopN 20

    $script:TrafficAppsContainer.Children.Clear()

    if ($apps.Count -eq 0) {
        $empty = New-ViewLabel -Text "Статистика по приложениям недоступна на этой прошивке, либо ещё не накоплена.`nПопробуйте позже или проверьте общий счётчик во вкладке «Обзор»." -Light
        $empty.TextWrapping = "Wrap"
        $script:TrafficAppsContainer.Children.Add($empty) | Out-Null
        return
    }

    # Заголовок
    $headerRow = New-Object System.Windows.Controls.Grid
    $headerRow.Margin = "8,0,8,5"

    $hc1 = New-Object System.Windows.Controls.ColumnDefinition; $hc1.Width = "*"
    $hc2 = New-Object System.Windows.Controls.ColumnDefinition; $hc2.Width = "100"
    $hc3 = New-Object System.Windows.Controls.ColumnDefinition; $hc3.Width = "100"
    $hc4 = New-Object System.Windows.Controls.ColumnDefinition; $hc4.Width = "100"
    $headerRow.ColumnDefinitions.Add($hc1)
    $headerRow.ColumnDefinitions.Add($hc2)
    $headerRow.ColumnDefinitions.Add($hc3)
    $headerRow.ColumnDefinitions.Add($hc4)

    $headers = @("Приложение", "Загрузка", "Отдача", "Всего")
    for ($i = 0; $i -lt 4; $i++) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $headers[$i]
        $tb.FontSize = 11
        $tb.FontWeight = "Bold"
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        [System.Windows.Controls.Grid]::SetColumn($tb, $i)
        $headerRow.Children.Add($tb) | Out-Null
    }
    $script:TrafficAppsContainer.Children.Add($headerRow) | Out-Null

    # Строки
    foreach ($app in $apps) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "#2B2B2B"
        $row.BorderBrush = "#3A3A3A"
        $row.BorderThickness = "0,0,0,1"
        $row.Padding = "8,6"

        $g = New-Object System.Windows.Controls.Grid
        $gc1 = New-Object System.Windows.Controls.ColumnDefinition; $gc1.Width = "*"
        $gc2 = New-Object System.Windows.Controls.ColumnDefinition; $gc2.Width = "100"
        $gc3 = New-Object System.Windows.Controls.ColumnDefinition; $gc3.Width = "100"
        $gc4 = New-Object System.Windows.Controls.ColumnDefinition; $gc4.Width = "100"
        $g.ColumnDefinitions.Add($gc1)
        $g.ColumnDefinitions.Add($gc2)
        $g.ColumnDefinitions.Add($gc3)
        $g.ColumnDefinitions.Add($gc4)

        # Имя
        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = $app.Name
        $nameTb.FontSize = 12
        $nameTb.FontFamily = "Consolas"
        $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
        )
        $nameTb.TextTrimming = "CharacterEllipsis"
        $nameTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($nameTb, 0)
        $g.Children.Add($nameTb) | Out-Null

        # Rx
        $rxTb = New-Object System.Windows.Controls.TextBlock
        $rxTb.Text = Format-Bytes -Bytes $app.Rx
        $rxTb.FontSize = 11
        $rxTb.FontFamily = "Consolas"
        $rxTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
        )
        $rxTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($rxTb, 1)
        $g.Children.Add($rxTb) | Out-Null

        # Tx
        $txTb = New-Object System.Windows.Controls.TextBlock
        $txTb.Text = Format-Bytes -Bytes $app.Tx
        $txTb.FontSize = 11
        $txTb.FontFamily = "Consolas"
        $txTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $txTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($txTb, 2)
        $g.Children.Add($txTb) | Out-Null

        # Total
        $totalTb = New-Object System.Windows.Controls.TextBlock
        $totalTb.Text = Format-Bytes -Bytes $app.Total
        $totalTb.FontSize = 11
        $totalTb.FontFamily = "Consolas"
        $totalTb.FontWeight = "Bold"
        $totalTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
        )
        $totalTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($totalTb, 3)
        $g.Children.Add($totalTb) | Out-Null

        $row.Child = $g
        $script:TrafficAppsContainer.Children.Add($row) | Out-Null
    }

    Write-Log -Message "Загружено приложений: $($apps.Count)" -Level "Success"
}

# ============================================================================
#  СТОП / СТАРТ МОНИТОРИНГА
# ============================================================================
function Stop-TrafficWatcher {
    if ($script:TrafficRefreshTimer) {
        $script:TrafficRefreshTimer.Stop()
    }
    $script:TrafficWatcherRunning = $false
    if ($script:TrafficBtnToggle) {
        $script:TrafficBtnToggle.Content = "Запустить"
        $script:TrafficBtnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
    }
    Write-Log -Message "Мониторинг трафика остановлен" -Level "Info"
}

function Start-TrafficWatcher {
    if (-not $script:TrafficRefreshTimer) { return }

    # Сбрасываем точку отсчёта, чтобы не было скачка
    $script:TrafficPrevCounters = Get-NetworkCounters
    $script:TrafficLastSampleTime = Get-Date

    $script:TrafficRefreshTimer.Start()
    $script:TrafficWatcherRunning = $true
    if ($script:TrafficBtnToggle) {
        $script:TrafficBtnToggle.Content = "Стоп"
        $script:TrafficBtnToggle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
    }
    Write-Log -Message "Мониторинг трафика запущен" -Level "Info"
}