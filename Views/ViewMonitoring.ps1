# ============================================================================
#  Экран: Мониторинг ТВ
#  Асинхронный сбор: трафик — 2 сек, остальное — 15 сек.
# ============================================================================

function Show-MonitoringView {
    Write-Log -Message "Monitor: START построения экрана" -Level "Info"

    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Мониторинг ТВ"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Живые метрики состояния телевизора. Трафик обновляется каждые 2 секунды, системные метрики — каждые 15 секунд." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,5,0,0"

    # ===== ВКЛАДКА 1: ОБЗОР =====
    $tabOverview = New-Object System.Windows.Controls.TabItem
    $tabOverview.Header = "Обзор"
    $tabOverview.Style = $window.Resources["MiuiTabItem"]

    $overviewPanel = New-Object System.Windows.Controls.StackPanel
    $overviewPanel.Margin = "15"

    # --- CPU ---
    $cpuCard = New-Object System.Windows.Controls.Border
    $cpuCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $cpuCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $cpuCard.BorderThickness = "1"
    $cpuCard.CornerRadius = "8"
    $cpuCard.Padding = "12"
    $cpuCard.Margin = "0,0,0,10"

    $cpuStack = New-Object System.Windows.Controls.StackPanel

    $cpuHeader = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "*"
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "Auto"
    $cpuHeader.ColumnDefinitions.Add($c1)
    $cpuHeader.ColumnDefinitions.Add($c2)

    $cpuTitle = New-Object System.Windows.Controls.TextBlock
    $cpuTitle.Text = "CPU"
    $cpuTitle.FontSize = 13
    $cpuTitle.FontWeight = "Bold"
    $cpuTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    [System.Windows.Controls.Grid]::SetColumn($cpuTitle, 0)
    $cpuHeader.Children.Add($cpuTitle) | Out-Null

    $script:MonCpuVal = New-Object System.Windows.Controls.TextBlock
    $script:MonCpuVal.Text = "—"
    $script:MonCpuVal.FontSize = 14
    $script:MonCpuVal.FontWeight = "Bold"
    $script:MonCpuVal.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    [System.Windows.Controls.Grid]::SetColumn($script:MonCpuVal, 1)
    $cpuHeader.Children.Add($script:MonCpuVal) | Out-Null

    $cpuStack.Children.Add($cpuHeader) | Out-Null

    $script:MonCpuBar = New-Object System.Windows.Controls.ProgressBar
    $script:MonCpuBar.Height = 8
    $script:MonCpuBar.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $script:MonCpuBar.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    $script:MonCpuBar.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1A1A1A")
    )
    $script:MonCpuBar.BorderThickness = "0"
    $script:MonCpuBar.Minimum = 0
    $script:MonCpuBar.Maximum = 100
    $cpuStack.Children.Add($script:MonCpuBar) | Out-Null

    $script:MonCpuMeta = New-Object System.Windows.Controls.TextBlock
    $script:MonCpuMeta.Text = "—"
    $script:MonCpuMeta.FontSize = 10
    $script:MonCpuMeta.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
    )
    $script:MonCpuMeta.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0)
    $cpuStack.Children.Add($script:MonCpuMeta) | Out-Null

    $cpuCard.Child = $cpuStack
    $overviewPanel.Children.Add($cpuCard) | Out-Null

    # --- RAM ---
    $ramCard = New-Object System.Windows.Controls.Border
    $ramCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $ramCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $ramCard.BorderThickness = "1"
    $ramCard.CornerRadius = "8"
    $ramCard.Padding = "12"
    $ramCard.Margin = "0,0,0,10"

    $ramStack = New-Object System.Windows.Controls.StackPanel

    $ramHeader = New-Object System.Windows.Controls.Grid
    $rc1 = New-Object System.Windows.Controls.ColumnDefinition; $rc1.Width = "*"
    $rc2 = New-Object System.Windows.Controls.ColumnDefinition; $rc2.Width = "Auto"
    $ramHeader.ColumnDefinitions.Add($rc1)
    $ramHeader.ColumnDefinitions.Add($rc2)

    $ramTitle = New-Object System.Windows.Controls.TextBlock
    $ramTitle.Text = "RAM"
    $ramTitle.FontSize = 13
    $ramTitle.FontWeight = "Bold"
    $ramTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    [System.Windows.Controls.Grid]::SetColumn($ramTitle, 0)
    $ramHeader.Children.Add($ramTitle) | Out-Null

    $script:MonRamVal = New-Object System.Windows.Controls.TextBlock
    $script:MonRamVal.Text = "—"
    $script:MonRamVal.FontSize = 14
    $script:MonRamVal.FontWeight = "Bold"
    $script:MonRamVal.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    [System.Windows.Controls.Grid]::SetColumn($script:MonRamVal, 1)
    $ramHeader.Children.Add($script:MonRamVal) | Out-Null

    $ramStack.Children.Add($ramHeader) | Out-Null

    $script:MonRamBar = New-Object System.Windows.Controls.ProgressBar
    $script:MonRamBar.Height = 8
    $script:MonRamBar.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $script:MonRamBar.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $script:MonRamBar.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1A1A1A")
    )
    $script:MonRamBar.BorderThickness = "0"
    $script:MonRamBar.Minimum = 0
    $script:MonRamBar.Maximum = 100
    $ramStack.Children.Add($script:MonRamBar) | Out-Null

    $script:MonRamMeta = New-Object System.Windows.Controls.TextBlock
    $script:MonRamMeta.Text = "—"
    $script:MonRamMeta.FontSize = 10
    $script:MonRamMeta.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
    )
    $script:MonRamMeta.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0)
    $ramStack.Children.Add($script:MonRamMeta) | Out-Null

    $ramCard.Child = $ramStack
    $overviewPanel.Children.Add($ramCard) | Out-Null

    # --- Storage ---
    $storCard = New-Object System.Windows.Controls.Border
    $storCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $storCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $storCard.BorderThickness = "1"
    $storCard.CornerRadius = "8"
    $storCard.Padding = "12"
    $storCard.Margin = "0,0,0,10"

    $storStack = New-Object System.Windows.Controls.StackPanel

    $storHeader = New-Object System.Windows.Controls.Grid
    $sc1 = New-Object System.Windows.Controls.ColumnDefinition; $sc1.Width = "*"
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition; $sc2.Width = "Auto"
    $storHeader.ColumnDefinitions.Add($sc1)
    $storHeader.ColumnDefinitions.Add($sc2)

    $storTitle = New-Object System.Windows.Controls.TextBlock
    $storTitle.Text = "Storage"
    $storTitle.FontSize = 13
    $storTitle.FontWeight = "Bold"
    $storTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    [System.Windows.Controls.Grid]::SetColumn($storTitle, 0)
    $storHeader.Children.Add($storTitle) | Out-Null

    $script:MonStorVal = New-Object System.Windows.Controls.TextBlock
    $script:MonStorVal.Text = "—"
    $script:MonStorVal.FontSize = 14
    $script:MonStorVal.FontWeight = "Bold"
    $script:MonStorVal.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    [System.Windows.Controls.Grid]::SetColumn($script:MonStorVal, 1)
    $storHeader.Children.Add($script:MonStorVal) | Out-Null

    $storStack.Children.Add($storHeader) | Out-Null

    $script:MonStorBar = New-Object System.Windows.Controls.ProgressBar
    $script:MonStorBar.Height = 8
    $script:MonStorBar.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $script:MonStorBar.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $script:MonStorBar.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1A1A1A")
    )
    $script:MonStorBar.BorderThickness = "0"
    $script:MonStorBar.Minimum = 0
    $script:MonStorBar.Maximum = 100
    $storStack.Children.Add($script:MonStorBar) | Out-Null

    $script:MonStorMeta = New-Object System.Windows.Controls.TextBlock
    $script:MonStorMeta.Text = "—"
    $script:MonStorMeta.FontSize = 10
    $script:MonStorMeta.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
    )
    $script:MonStorMeta.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0)
    $storStack.Children.Add($script:MonStorMeta) | Out-Null

    $storCard.Child = $storStack
    $overviewPanel.Children.Add($storCard) | Out-Null

    # --- Temperature / Uptime / Load ---
    $miscCard = New-Object System.Windows.Controls.Border
    $miscCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $miscCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $miscCard.BorderThickness = "1"
    $miscCard.CornerRadius = "8"
    $miscCard.Padding = "12"
    $miscCard.Margin = "0,0,0,10"

    $miscStack = New-Object System.Windows.Controls.StackPanel

    $tempHeader = New-Object System.Windows.Controls.Grid
    $tc1 = New-Object System.Windows.Controls.ColumnDefinition; $tc1.Width = "*"
    $tc2 = New-Object System.Windows.Controls.ColumnDefinition; $tc2.Width = "Auto"
    $tempHeader.ColumnDefinitions.Add($tc1)
    $tempHeader.ColumnDefinitions.Add($tc2)

    $tempTitle = New-Object System.Windows.Controls.TextBlock
    $tempTitle.Text = "Температура"
    $tempTitle.FontSize = 13
    $tempTitle.FontWeight = "Bold"
    $tempTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    [System.Windows.Controls.Grid]::SetColumn($tempTitle, 0)
    $tempHeader.Children.Add($tempTitle) | Out-Null

    $script:MonTempVal = New-Object System.Windows.Controls.TextBlock
    $script:MonTempVal.Text = "—"
    $script:MonTempVal.FontSize = 14
    $script:MonTempVal.FontWeight = "Bold"
    $script:MonTempVal.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    [System.Windows.Controls.Grid]::SetColumn($script:MonTempVal, 1)
    $tempHeader.Children.Add($script:MonTempVal) | Out-Null

    $miscStack.Children.Add($tempHeader) | Out-Null

    $script:MonTempBar = New-Object System.Windows.Controls.ProgressBar
    $script:MonTempBar.Height = 8
    $script:MonTempBar.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $script:MonTempBar.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    $script:MonTempBar.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1A1A1A")
    )
    $script:MonTempBar.BorderThickness = "0"
    $script:MonTempBar.Minimum = 0
    $script:MonTempBar.Maximum = 100
    $miscStack.Children.Add($script:MonTempBar) | Out-Null

    $script:MonMiscInfo = New-Object System.Windows.Controls.TextBlock
    $script:MonMiscInfo.Text = "Uptime: —   |   Load avg: —"
    $script:MonMiscInfo.FontSize = 11
    $script:MonMiscInfo.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $script:MonMiscInfo.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
    $script:MonMiscInfo.TextWrapping = "Wrap"
    $miscStack.Children.Add($script:MonMiscInfo) | Out-Null

    $miscCard.Child = $miscStack
    $overviewPanel.Children.Add($miscCard) | Out-Null

    $tabOverview.Content = $overviewPanel
    $tabControl.Items.Add($tabOverview) | Out-Null

    # ===== ВКЛАДКА 2: ПРОЦЕССЫ =====
    $tabProcesses = New-Object System.Windows.Controls.TabItem
    $tabProcesses.Header = "Процессы"
    $tabProcesses.Style = $window.Resources["MiuiTabItem"]

    $procPanel = New-Object System.Windows.Controls.StackPanel
    $procPanel.Margin = "15"

    $procInfo = New-Object System.Windows.Controls.TextBlock
    $procInfo.Text = "Топ-15 процессов по загрузке CPU. Обновляется каждые 15 секунд."
    $procInfo.FontSize = 11
    $procInfo.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $procInfo.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $procInfo.TextWrapping = "Wrap"
    $procPanel.Children.Add($procInfo) | Out-Null

    $script:MonProcContainer = New-Object System.Windows.Controls.StackPanel
    $procPanel.Children.Add($script:MonProcContainer) | Out-Null

    $tabProcesses.Content = $procPanel
    $tabControl.Items.Add($tabProcesses) | Out-Null

    # ===== ВКЛАДКА 3: СЕТЬ =====
    $tabNetwork = New-Object System.Windows.Controls.TabItem
    $tabNetwork.Header = "Сеть"
    $tabNetwork.Style = $window.Resources["MiuiTabItem"]

    $netPanel = New-Object System.Windows.Controls.StackPanel
    $netPanel.Margin = "15"

    $script:MonNetContainer = New-Object System.Windows.Controls.StackPanel
    $netPanel.Children.Add($script:MonNetContainer) | Out-Null

    $tabNetwork.Content = $netPanel
    $tabControl.Items.Add($tabNetwork) | Out-Null

    # ===== ВКЛАДКА 4: BLUETOOTH =====
    $tabBt = New-Object System.Windows.Controls.TabItem
    $tabBt.Header = "Bluetooth"
    $tabBt.Style = $window.Resources["MiuiTabItem"]

    $btPanel = New-Object System.Windows.Controls.StackPanel
    $btPanel.Margin = "15"

    $script:MonBtContainer = New-Object System.Windows.Controls.StackPanel
    $btPanel.Children.Add($script:MonBtContainer) | Out-Null

    $tabBt.Content = $btPanel
    $tabControl.Items.Add($tabBt) | Out-Null

    # ===== ВКЛАДКА 5: ТЕМПЕРАТУРА =====
    $tabTemp = New-Object System.Windows.Controls.TabItem
    $tabTemp.Header = "Температура"
    $tabTemp.Style = $window.Resources["MiuiTabItem"]

    $tempPanel = New-Object System.Windows.Controls.StackPanel
    $tempPanel.Margin = "15"

    $tempInfoTb = New-Object System.Windows.Controls.TextBlock
    $tempInfoTb.Text = "Термодатчики ТВ. График показывает изменение температуры CPU за последние 15 минут."
    $tempInfoTb.FontSize = 11
    $tempInfoTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $tempInfoTb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $tempInfoTb.TextWrapping = "Wrap"
    $tempPanel.Children.Add($tempInfoTb) | Out-Null

    $script:MonThermalZonesContainer = New-Object System.Windows.Controls.StackPanel
    $script:MonThermalZonesContainer.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $tempPanel.Children.Add($script:MonThermalZonesContainer) | Out-Null

    $script:MonTempChartCanvas = New-Object System.Windows.Controls.Canvas
    $script:MonTempChartCanvas.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1F1F1F")
    )
    $script:MonTempChartCanvas.Height = 180
    $script:MonTempChartCanvas.Width = 700
    $tempPanel.Children.Add($script:MonTempChartCanvas) | Out-Null

    $tabTemp.Content = $tempPanel
    $tabControl.Items.Add($tabTemp) | Out-Null

    # ===== ВКЛАДКА 6: ТРАФИК =====
    $tabTraffic = New-Object System.Windows.Controls.TabItem
    $tabTraffic.Header = "Трафик"
    $tabTraffic.Style = $window.Resources["MiuiTabItem"]

    $trafficPanel = New-Object System.Windows.Controls.StackPanel
    $trafficPanel.Margin = "15"

    $trafficInfoTb = New-Object System.Windows.Controls.TextBlock
    $trafficInfoTb.Text = "Скорость сетевого обмена по активному интерфейсу. Обновляется каждые 2 секунды."
    $trafficInfoTb.FontSize = 11
    $trafficInfoTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $trafficInfoTb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $trafficInfoTb.TextWrapping = "Wrap"
    $trafficPanel.Children.Add($trafficInfoTb) | Out-Null

    $speedCard = New-Object System.Windows.Controls.Border
    $speedCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1F3A1F")
    )
    $speedCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A5A3A")
    )
    $speedCard.BorderThickness = "1"
    $speedCard.CornerRadius = "8"
    $speedCard.Padding = "15"
    $speedCard.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)

    $speedStack = New-Object System.Windows.Controls.StackPanel

    $script:MonTrafficRx = New-Object System.Windows.Controls.TextBlock
    $script:MonTrafficRx.Text = "↓ Загрузка:   —"
    $script:MonTrafficRx.FontSize = 15
    $script:MonTrafficRx.FontFamily = "Consolas"
    $script:MonTrafficRx.FontWeight = "Bold"
    $script:MonTrafficRx.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $speedStack.Children.Add($script:MonTrafficRx) | Out-Null

    $script:MonTrafficTx = New-Object System.Windows.Controls.TextBlock
    $script:MonTrafficTx.Text = "↑ Отдача:     —"
    $script:MonTrafficTx.FontSize = 15
    $script:MonTrafficTx.FontFamily = "Consolas"
    $script:MonTrafficTx.FontWeight = "Bold"
    $script:MonTrafficTx.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $script:MonTrafficTx.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
    $speedStack.Children.Add($script:MonTrafficTx) | Out-Null

    $script:MonTrafficTotal = New-Object System.Windows.Controls.TextBlock
    $script:MonTrafficTotal.Text = "Всего:  ↓ —   ↑ —"
    $script:MonTrafficTotal.FontSize = 11
    $script:MonTrafficTotal.FontFamily = "Consolas"
    $script:MonTrafficTotal.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $script:MonTrafficTotal.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $speedStack.Children.Add($script:MonTrafficTotal) | Out-Null

    $speedCard.Child = $speedStack
    $trafficPanel.Children.Add($speedCard) | Out-Null

    $script:MonTrafficChartCanvas = New-Object System.Windows.Controls.Canvas
    $script:MonTrafficChartCanvas.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#1F1F1F")
    )
    $script:MonTrafficChartCanvas.Height = 200
    $script:MonTrafficChartCanvas.Width = 700
    $trafficPanel.Children.Add($script:MonTrafficChartCanvas) | Out-Null

    $script:MonTrafficMaxLabel = New-Object System.Windows.Controls.TextBlock
    $script:MonTrafficMaxLabel.Text = "Максимум: —"
    $script:MonTrafficMaxLabel.FontSize = 11
    $script:MonTrafficMaxLabel.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $script:MonTrafficMaxLabel.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $trafficPanel.Children.Add($script:MonTrafficMaxLabel) | Out-Null

    $tabTraffic.Content = $trafficPanel
    $tabControl.Items.Add($tabTraffic) | Out-Null

    # ===== СОХРАНЯЕМ ССЫЛКИ =====
    $script:MonitoringTabControl = $tabControl

    $mainStack.Children.Add($tabControl) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack {
        Stop-MonitoringWatcher
        Switch-View -ViewName "Setup"
    }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== СБРОС ИСТОРИИ =====
    $script:MonitoringHistoryTemp      = @()
    $script:MonitoringHistoryTrafficRx = @()
    $script:MonitoringHistoryTrafficTx = @()
    $script:MonitoringPrevCounters     = $null
    $script:MonitoringLastSampleTime   = (Get-Date)
    $script:MonitoringActiveIface      = ""
    $script:MonitoringTrafficBusy      = $false
    $script:MonitoringSlowBusy         = $false

    # ===== ТАЙМЕР: БЫСТРЫЙ (трафик, каждые 2 сек) =====
    $script:MonitoringTrafficTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:MonitoringTrafficTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:MonitoringTrafficTimer.Add_Tick({
        try {
            if (-not $script:connected) { return }
            Update-MonitoringTrafficAsync
        } catch {
            Write-Log -Message "Ошибка таймера трафика: $_" -Level "Warning"
        }
    })
    $script:MonitoringTrafficTimer.Start()

    # ===== ТАЙМЕР: МЕДЛЕННЫЙ (система/сеть/BT/темп, каждые 15 сек) =====
    $script:MonitoringRunning = $true
    $script:MonitoringRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:MonitoringRefreshTimer.Interval = [TimeSpan]::FromSeconds(15)
    $script:MonitoringRefreshTimer.Add_Tick({
        try {
            if (-not $script:connected) {
                Stop-MonitoringWatcher
                return
            }
            Update-MonitoringSlowAsync
        } catch {
            Write-Log -Message "Ошибка таймера мониторинга: $_" -Level "Warning"
        }
    })
    $script:MonitoringRefreshTimer.Start()

    $script:MonitoringRefreshTimer.Start()

    # ===== РЕГИСТРАЦИЯ RUNSPACE =====
    #  Monitoring не останавливается при переключении экранов —
    #  пользователь останавливает вручную через кнопку "Пауза".
    Register-ScreenRunspace -Name "monitoring" `
        -Timer $script:MonitoringTrafficTimer `
        -OnCleanup {
            try { if ($script:MonitoringRefreshTimer) { $script:MonitoringRefreshTimer.Stop() } } catch { }
            try { if ($script:MonitoringTrafficTimer) { $script:MonitoringTrafficTimer.Stop() } } catch { }
            try { if ($script:MonTrafTimer) { $script:MonTrafTimer.Stop() } } catch { }
            try { if ($script:MonSlowTimer) { $script:MonSlowTimer.Stop() } } catch { }
        }

    # ===== КНОПКИ BOTTOM BAR =====

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({
        $script:MonitoringTrafficBusy = $false
        $script:MonitoringSlowBusy    = $false
        Update-MonitoringSlowAsync
        Update-MonitoringTrafficAsync
    })
    $buttons += $btnRefresh

    $script:MonitoringBtnToggle = New-Object System.Windows.Controls.Button
    $script:MonitoringBtnToggle.Content = "Пауза"
    $script:MonitoringBtnToggle.Style = $window.Resources["RoundedButton"]
    $script:MonitoringBtnToggle.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
    )
    $script:MonitoringBtnToggle.Padding = "12,6"
    $script:MonitoringBtnToggle.Margin = "0,0,8,0"
    $script:MonitoringBtnToggle.Add_Click({
        if ($script:MonitoringRunning) {
            Stop-MonitoringWatcher
        } else {
            Start-MonitoringWatcher
        }
    })
    $buttons += $script:MonitoringBtnToggle

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран мониторинга" -Level "Info"

    # ===== ПЕРВЫЙ СБОР (в конце, после построения UI) =====
    Write-Log -Message "Monitor: запускаю первый сбор" -Level "Info"

    try {
        $testMetrics = Get-SystemMetrics
        Write-Log -Message "Monitor: Get-SystemMetrics вернул CPU=$($testMetrics.Cpu.Usage)%, RAM=$($testMetrics.Ram.UsedPct)%" -Level "Info"
    } catch {
        Write-Log -Message "Monitor: ошибка Get-SystemMetrics: $_" -Level "Error"
    }

    Update-MonitoringSlowAsync
    Start-Sleep -Milliseconds 100
    Update-MonitoringTrafficAsync

    Write-Log -Message "Monitor: первый сбор запущен" -Level "Info"
}

# ============================================================================
#  АСИНХРОННОЕ ОБНОВЛЕНИЕ: ТРАФИК (каждые 2 сек)
# ============================================================================
function Update-MonitoringTrafficAsync {
    if ($script:MonitoringTrafficBusy) { return }
    if (-not $script:connected) { return }
    if (-not $script:MonitoringActiveIface) { return }

    $script:MonitoringTrafficBusy = $true

    $script:MonTrafAdbPath  = $script:adbPath
    $script:MonTrafIface    = $script:MonitoringActiveIface
    $script:MonTrafPrev     = $script:MonitoringPrevCounters
    $script:MonTrafLastTime = $script:MonitoringLastSampleTime

    $script:MonTrafRunspace = [runspacefactory]::CreateRunspace()
    $script:MonTrafRunspace.ApartmentState = "MTA"
    $script:MonTrafRunspace.ThreadOptions = "ReuseThread"
    $script:MonTrafRunspace.Open()

    $script:MonTrafPS = [powershell]::Create()
    $script:MonTrafPS.Runspace = $script:MonTrafRunspace

    $script:MonTrafPS.AddScript({
        param($adbPath, $iface, $prevCounters, $lastSampleTime)

        $result = @{
            RxBps = 0; TxBps = 0
            TotalRx = 0; TotalTx = 0
            Counters = $null
            SampleTime = (Get-Date)
            Error = ""
        }

        try {
            $raw = & $adbPath shell cat /proc/net/dev 2>&1
            $rawText = ($raw | Out-String)

            $curr = @{}
            foreach ($line in ($rawText -split "`r?`n")) {
                if ($line -match '^\s*([a-zA-Z0-9_]+):\s+(.+)$') {
                    $ifaceName = $matches[1]
                    $fields = ($matches[2] -split '\s+') | Where-Object { $_ -ne "" }
                    if ($fields.Count -ge 16) {
                        $curr[$ifaceName] = @{
                            RxBytes = [int64]$fields[0]
                            TxBytes = [int64]$fields[8]
                        }
                    }
                }
            }

            if (-not $curr.ContainsKey($iface)) {
                $result.Counters = $curr
                return $result
            }

            $result.TotalRx = $curr[$iface].RxBytes
            $result.TotalTx = $curr[$iface].TxBytes

            if ($prevCounters -and $prevCounters.ContainsKey($iface)) {
                $elapsed = ((Get-Date) - $lastSampleTime).TotalSeconds
                if ($elapsed -le 0) { $elapsed = 2 }

                $rxDelta = $curr[$iface].RxBytes - $prevCounters[$iface].RxBytes
                $txDelta = $curr[$iface].TxBytes - $prevCounters[$iface].TxBytes
                if ($rxDelta -lt 0) { $rxDelta = 0 }
                if ($txDelta -lt 0) { $txDelta = 0 }

                $result.RxBps = [math]::Round($rxDelta / $elapsed, 0)
                $result.TxBps = [math]::Round($txDelta / $elapsed, 0)
            }

            $result.Counters = $curr
        } catch {
            $result.Error = "$_"
        }

        return $result
    }) | Out-Null

    $script:MonTrafPS.AddArgument($script:MonTrafAdbPath)
    $script:MonTrafPS.AddArgument($script:MonTrafIface)
    $script:MonTrafPS.AddArgument($script:MonTrafPrev)
    $script:MonTrafPS.AddArgument($script:MonTrafLastTime)

    $script:MonTrafHandle = $script:MonTrafPS.BeginInvoke()

    $script:MonTrafTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:MonTrafTimer.Interval = [TimeSpan]::FromMilliseconds(100)
    $script:MonTrafTimer.Add_Tick({
        if ($script:MonTrafHandle.IsCompleted) {
            $script:MonTrafTimer.Stop()

            try {
                $result = $script:MonTrafPS.EndInvoke($script:MonTrafHandle)
                if ($result -and $result.Count -gt 0) {
                    $speed = $result[0]

                    if ($speed.Error) {
                        Write-Log -Message "Ошибка трафика: $($speed.Error)" -Level "Warning"
                    } else {
                        if ($script:MonTrafficRx) {
                            $script:MonTrafficRx.Text = "↓ Загрузка:   $(Format-MonRate -BytesPerSecond $speed.RxBps)"
                            $script:MonTrafficTx.Text = "↑ Отдача:     $(Format-MonRate -BytesPerSecond $speed.TxBps)"
                            $script:MonTrafficTotal.Text = "Всего:  ↓ $(Format-MonBytes -Bytes $speed.TotalRx)   ↑ $(Format-MonBytes -Bytes $speed.TotalTx)"
                        }

                        $script:MonitoringHistoryTrafficRx += $speed.RxBps
                        $script:MonitoringHistoryTrafficTx += $speed.TxBps

                        if ($script:MonitoringHistoryTrafficRx.Count -gt $script:MonitoringMaxHistoryPoints) {
                            $script:MonitoringHistoryTrafficRx = $script:MonitoringHistoryTrafficRx[-$script:MonitoringMaxHistoryPoints..-1]
                            $script:MonitoringHistoryTrafficTx = $script:MonitoringHistoryTrafficTx[-$script:MonitoringMaxHistoryPoints..-1]
                        }

                        if ($speed.Counters) {
                            $script:MonitoringPrevCounters = $speed.Counters
                        }
                        $script:MonitoringLastSampleTime = $speed.SampleTime

                        Update-MonitoringTrafficChart
                    }
                }
            } catch {
                Write-Log -Message "Ошибка обработки трафика: $_" -Level "Warning"
            }

            try { $script:MonTrafPS.Dispose() } catch { }
            $script:MonitoringTrafficBusy = $false
        }
    })
    $script:MonTrafTimer.Start()
}

# ============================================================================
#  АСИНХРОННОЕ ОБНОВЛЕНИЕ: МЕДЛЕННЫЙ БЛОК (каждые 15 сек)
# ============================================================================
function Update-MonitoringSlowAsync {
    if ($script:MonitoringSlowBusy) { return }
    if (-not $script:connected) { return }

    $script:MonitoringSlowBusy = $true

    $script:MonSlowAdbPath = $script:adbPath

    $script:MonSlowRunspace = [runspacefactory]::CreateRunspace()
    $script:MonSlowRunspace.ApartmentState = "MTA"
    $script:MonSlowRunspace.ThreadOptions = "ReuseThread"
    $script:MonSlowRunspace.Open()

    $script:MonSlowPS = [powershell]::Create()
    $script:MonSlowPS.Runspace = $script:MonSlowRunspace

    $script:MonSlowPS.AddScript({
        param($adbPath)

        $data = @{
            Metrics = $null
            Processes = $null
            Network = $null
            Bluetooth = $null
            Zones = @()
            Error = ""
        }

        try {
            # ===== Системные метрики =====
            $metrics = [ordered]@{
                Cpu = [ordered]@{ Usage = 0; Cores = 0; MaxFreq = ""; CurFreq = "" }
                Ram = [ordered]@{ Total = 0; Free = 0; Available = 0; UsedPct = 0 }
                Storage = [ordered]@{ Total = 0; Used = 0; Free = 0; UsedPct = 0 }
                Uptime = ""
                LoadAvg = ""
                Temperature = -1
            }

            $cpuOut = & $adbPath shell top -n 1 -b 2>&1
            $cpuText = ($cpuOut | Out-String)

            if ($cpuText -match '(\d+)%cpu\s+([\d\.]+)%user\s+([\d\.]+)%nice\s+([\d\.]+)%sys') {
                $totalCpuPercent = [int]$matches[1]
                $userCpu = [double]$matches[2]
                $sysCpu  = [double]$matches[4]
                $cores = [int]($totalCpuPercent / 100)
                if ($cores -lt 1) { $cores = 1 }
                $metrics.Cpu.Usage = [math]::Round(($userCpu + $sysCpu) / $cores, 1)
                $metrics.Cpu.Cores = $cores
            }

            $maxFreqOut = & $adbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>&1
            $maxFreqText = ($maxFreqOut | Out-String).Trim()
            if ($maxFreqText -match '^\d+$') {
                $metrics.Cpu.MaxFreq = "$([math]::Round([int]$maxFreqText / 1000)) МГц"
            }

            $curFreqOut = & $adbPath shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>&1
            $curFreqText = ($curFreqOut | Out-String).Trim()
            if ($curFreqText -match '^\d+$') {
                $metrics.Cpu.CurFreq = "$([math]::Round([int]$curFreqText / 1000)) МГц"
            }

            $memOut = & $adbPath shell cat /proc/meminfo 2>&1
            $memText = ($memOut | Out-String)
            if ($memText -match 'MemTotal:\s+(\d+)\s+kB')     { $metrics.Ram.Total     = [int64]$matches[1] * 1024 }
            if ($memText -match 'MemFree:\s+(\d+)\s+kB')      { $metrics.Ram.Free      = [int64]$matches[1] * 1024 }
            if ($memText -match 'MemAvailable:\s+(\d+)\s+kB') { $metrics.Ram.Available = [int64]$matches[1] * 1024 }

            if ($metrics.Ram.Total -gt 0) {
                $used = $metrics.Ram.Total - $metrics.Ram.Available
                $metrics.Ram.UsedPct = [math]::Round($used / $metrics.Ram.Total * 100, 1)
            }

            $dfOut = & $adbPath shell df /data 2>&1
            $dfText = ($dfOut | Out-String)
            foreach ($line in ($dfText -split "`r?`n")) {
                if ($line -match '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%') {
                    $metrics.Storage.Total = [int64]$matches[1] * 1024
                    $metrics.Storage.Used  = [int64]$matches[2] * 1024
                    $metrics.Storage.Free  = [int64]$matches[3] * 1024
                    $metrics.Storage.UsedPct = [int]$matches[4]
                    break
                }
            }

            $uptimeOut = & $adbPath shell cat /proc/uptime 2>&1
            $uptimeText = ($uptimeOut | Out-String).Trim()
            if ($uptimeText -match '^([\d\.]+)') {
                $sec = [math]::Round([double]$matches[1])
                $h = [math]::Floor($sec / 3600)
                $m = [math]::Floor(($sec % 3600) / 60)
                $metrics.Uptime = "$h ч $m мин"
            }

            $loadOut = & $adbPath shell cat /proc/loadavg 2>&1
            $loadText = ($loadOut | Out-String).Trim()
            if ($loadText -match '^([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)') {
                $metrics.LoadAvg = "$($matches[1]) / $($matches[2]) / $($matches[3])"
            }

            # Температура + зоны
            $tempOut = & $adbPath shell ls /sys/class/thermal/ 2>&1
            $tempText = ($tempOut | Out-String)
            $zones = @()
            foreach ($zone in ($tempText -split "`r?`n")) {
                if ($zone -match 'thermal_zone(\d+)') {
                    $zoneName = "thermal_zone$($matches[1])"
                    $typeOut = & $adbPath shell cat "/sys/class/thermal/$zoneName/type" 2>&1
                    $typeText = ($typeOut | Out-String).Trim()
                    $tOut = & $adbPath shell cat "/sys/class/thermal/$zoneName/temp" 2>&1
                    $tText = ($tOut | Out-String).Trim()

                    if ($tText -match '^-?\d+$') {
                        $tempC = [math]::Round([int]$tText / 1000.0, 1)
                        $zones += [PSCustomObject]@{
                            Zone = $zoneName
                            Type = $typeText
                            TempC = $tempC
                        }
                        if ($typeText -match 'cpu|soc|ap|big' -and $metrics.Temperature -lt 0) {
                            $metrics.Temperature = $tempC
                        }
                    }
                }
            }

            $data.Metrics = [PSCustomObject]$metrics
            $data.Zones = $zones

            # ===== Процессы =====
            $procs = @()
            $out = & $adbPath shell top -n 1 -b -o %CPU,RES,CMDLINE 2>&1
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

                    $procs += [PSCustomObject]@{
                        CPU = [math]::Round($cpu, 1)
                        MemMb = [math]::Round($memKb / 1024, 1)
                        Name = $name
                    }
                }
            }

            $data.Processes = @($procs | Sort-Object -Property CPU -Descending | Select-Object -First 15)

            # ===== Сеть =====
            $net = [ordered]@{
                ActiveIfType = "—"
                ActiveIfName = "—"
                ActiveIfIp   = "—"
                ActiveIfMac  = "—"
                WifiEnabled  = $false
                WifiSsid     = ""
                WifiBssid    = ""
                WifiIp       = ""
                WifiMac      = ""
                WifiGateway  = ""
                WifiDns      = ""
                WifiFrequency = ""
                WifiSignal   = -1
                WifiLinkSpeed = ""
            }

            $wlanOut = & $adbPath shell ip addr show wlan0 2>&1
            $wlanText = ($wlanOut | Out-String)
            if ($wlanText -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                $net.WifiIp = $matches[1]
                $net.WifiEnabled = $true
                $net.ActiveIfType = "Wi-Fi"
                $net.ActiveIfName = "wlan0"
                $net.ActiveIfIp = $matches[1]
            }
            if ($wlanText -match 'link/ether\s+([0-9a-fA-F:]{17})') {
                $net.WifiMac = $matches[1]
                $net.ActiveIfMac = $matches[1]
            }

            $dumpOut = & $adbPath shell dumpsys wifi 2>&1
            $dumpText = ($dumpOut | Out-String)
            if ($dumpText -match 'SSID:\s*"([^"]+)"') { $net.WifiSsid = $matches[1] }
            if ($dumpText -match 'BSSID:\s*([0-9a-fA-F:]{17})') { $net.WifiBssid = $matches[1] }
            if ($dumpText -match 'Frequency:\s*(\d+)') { $net.WifiFrequency = "$($matches[1]) МГц" }
            if ($dumpText -match 'Link speed:\s*(\d+)\s*Mbps') { $net.WifiLinkSpeed = "$($matches[1]) Мбит/с" }
            if ($dumpText -match 'RSSI:\s*(-?\d+)') { $net.WifiSignal = [int]$matches[1] }

            $routeOut = & $adbPath shell ip route 2>&1
            $routeText = ($routeOut | Out-String)
            if ($routeText -match 'default via (\d+\.\d+\.\d+\.\d+)') {
                $net.WifiGateway = $matches[1]
            }

            if ($net.ActiveIfName -eq "—") {
                $ethOut = & $adbPath shell ip addr show eth0 2>&1
                $ethText = ($ethOut | Out-String)
                if ($ethText -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') {
                    $net.ActiveIfType = "Ethernet"
                    $net.ActiveIfName = "eth0"
                    $net.ActiveIfIp = $matches[1]
                    if ($ethText -match 'link/ether\s+([0-9a-fA-F:]{17})') {
                        $net.ActiveIfMac = $matches[1]
                    }
                }
            }

            $data.Network = [PSCustomObject]$net

            # ===== Bluetooth =====
            $bt = [ordered]@{
                Enabled = $false
                Name = ""
                Address = ""
                Bonded = @()
            }

            $btDump = & $adbPath shell dumpsys bluetooth_manager 2>&1
            $btText = ($btDump | Out-String)

            if ($btText -match 'enabled:\s*(true|false)') {
                $bt.Enabled = ($matches[1] -eq "true")
            }
            if ($btText -match 'name:\s*([^\r\n]+)') {
                $bt.Name = $matches[1].Trim()
            }
            if ($btText -match 'address:\s*([0-9A-Fa-f:]{17})') {
                $addrVal = $matches[1]
                if ($addrVal -ne "00:00:00:00:00:00") { $bt.Address = $addrVal }
            }

            $bondedSection = ""
            if ($btText -match '(?s)Bonded devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:|$)') {
                $bondedSection = $matches[1]
            }
            if ($bondedSection) {
                foreach ($line in ($bondedSection -split "`r?`n")) {
                    if ($line -match '([0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5})') {
                        $mac = $matches[1]
                        $name = "—"
                        $rest = $line.Substring($line.IndexOf($mac) + $mac.Length).Trim()
                        $rest = $rest -replace '\s*\[[^\]]*\]', ''
                        $rest = $rest.Trim()
                        if ($rest) { $name = $rest }
                        $bt.Bonded += [PSCustomObject]@{
                            Mac = $mac
                            Name = $name
                            Connected = ($line -match '^\s*\*')
                        }
                    }
                }
            }

            $data.Bluetooth = [PSCustomObject]$bt
        } catch {
            $data.Error = "$_"
        }

        return $data
    }) | Out-Null

    $script:MonSlowPS.AddArgument($script:MonSlowAdbPath)

    $script:MonSlowHandle = $script:MonSlowPS.BeginInvoke()

    $script:MonSlowTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:MonSlowTimer.Interval = [TimeSpan]::FromMilliseconds(150)
    $script:MonSlowTimer.Add_Tick({
        if ($script:MonSlowHandle.IsCompleted) {
            $script:MonSlowTimer.Stop()

            try {
                $result = $script:MonSlowPS.EndInvoke($script:MonSlowHandle)
                if ($result -and $result.Count -gt 0) {
                    $data = $result[0]

                    if ($data.Error) {
                        Write-Log -Message "Ошибка медленного сбора: $($data.Error)" -Level "Warning"
                    } else {
                        Apply-MonitoringSlowData -Data $data
                    }
                }
            } catch {
                Write-Log -Message "Ошибка обработки медленных данных: $_" -Level "Warning"
            }

            try { $script:MonSlowPS.Dispose() } catch { }
            $script:MonitoringSlowBusy = $false
        }
    })
    $script:MonSlowTimer.Start()
}

# ============================================================================
#  ПРИМЕНЕНИЕ МЕДЛЕННЫХ ДАННЫХ К UI
# ============================================================================
function Apply-MonitoringSlowData {
    param([hashtable]$Data)

    if ($Data.Metrics) {
        $metrics = $Data.Metrics

        if ($script:MonCpuVal) {
            $cpuPct = [math]::Round($metrics.Cpu.Usage, 1)
            $script:MonCpuVal.Text = "$cpuPct%"
            $script:MonCpuBar.Value = [math]::Min($cpuPct, 100)

            $cpuMeta = "Ядер: $($metrics.Cpu.Cores)"
            if ($metrics.Cpu.MaxFreq) { $cpuMeta += "  ·  Макс: $($metrics.Cpu.MaxFreq)" }
            if ($metrics.Cpu.CurFreq) { $cpuMeta += "  ·  Тек: $($metrics.Cpu.CurFreq)" }
            $script:MonCpuMeta.Text = $cpuMeta
        }

        if ($script:MonRamVal) {
            $script:MonRamVal.Text = "$($metrics.Ram.UsedPct)%"
            $script:MonRamBar.Value = $metrics.Ram.UsedPct

            $totalGb = [math]::Round($metrics.Ram.Total / 1GB, 2)
            $availGb = [math]::Round($metrics.Ram.Available / 1GB, 2)
            $script:MonRamMeta.Text = "Всего: $totalGb ГБ  ·  Свободно: $availGb ГБ"
        }

        if ($script:MonStorVal) {
            $script:MonStorVal.Text = "$($metrics.Storage.UsedPct)%"
            $script:MonStorBar.Value = $metrics.Storage.UsedPct

            $totalGb = [math]::Round($metrics.Storage.Total / 1GB, 2)
            $freeGb  = [math]::Round($metrics.Storage.Free  / 1GB, 2)
            $script:MonStorMeta.Text = "Всего: $totalGb ГБ  ·  Свободно: $freeGb ГБ"
        }

        if ($script:MonTempVal) {
            if ($metrics.Temperature -ge 0) {
                $temp = $metrics.Temperature
                $script:MonTempVal.Text = "$temp °C"
                $script:MonTempBar.Value = [math]::Min($temp * 1.25, 100)

                $color = "#6CCB5F"
                if ($temp -gt 80) { $color = "#FF6B6B" }
                elseif ($temp -gt 60) { $color = "#FFC83D" }

                $brush = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString($color)
                )
                $script:MonTempVal.Foreground = $brush
                $script:MonTempBar.Foreground = $brush

                $script:MonitoringHistoryTemp += $temp
                if ($script:MonitoringHistoryTemp.Count -gt $script:MonitoringMaxHistoryPoints) {
                    $script:MonitoringHistoryTemp = $script:MonitoringHistoryTemp[-$script:MonitoringMaxHistoryPoints..-1]
                }
            } else {
                $script:MonTempVal.Text = "н/д"
                $script:MonTempBar.Value = 0
            }
        }

        if ($script:MonMiscInfo) {
            $script:MonMiscInfo.Text = "Uptime: $($metrics.Uptime)   |   Load avg: $($metrics.LoadAvg)"
        }
    }

    if ($Data.Zones) {
        Update-MonitoringThermalZones -Zones $Data.Zones
        Update-MonitoringTemperatureChart
    }

    if ($Data.Processes) {
        Update-MonitoringProcessesList -Processes $Data.Processes
    }

    if ($Data.Network) {
        if (-not $script:MonitoringActiveIface) {
            if ($Data.Network.WifiEnabled -and $Data.Network.WifiIp) {
                $script:MonitoringActiveIface = "wlan0"
            } elseif ($Data.Network.ActiveIfName -and $Data.Network.ActiveIfName -ne "—") {
                $script:MonitoringActiveIface = $Data.Network.ActiveIfName
            } else {
                $script:MonitoringActiveIface = "wlan0"
            }
        }
        Update-MonitoringNetworkPanel -Network $Data.Network
    }

    if ($Data.Bluetooth) {
        Update-MonitoringBluetoothPanel -Bluetooth $Data.Bluetooth
    }

    Write-Log -Message "Мониторинг обновлён (медленный блок)" -Level "Info"
}

# ============================================================================
#  ОБНОВЛЕНИЕ: СПИСОК ПРОЦЕССОВ
# ============================================================================
function Update-MonitoringProcessesList {
    param([array]$Processes)

    if (-not $script:MonProcContainer) { return }

    $script:MonProcContainer.Children.Clear()

    if (-not $Processes -or $Processes.Count -eq 0) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "Нет данных"
        $empty.FontSize = 12
        $empty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $script:MonProcContainer.Children.Add($empty) | Out-Null
        return
    }

    foreach ($p in $Processes) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
        )
        $row.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )
        $row.BorderThickness = "1"
        $row.CornerRadius = "6"
        $row.Padding = "10"
        $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "*"
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "80"
        $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = "80"
        $grid.ColumnDefinitions.Add($c1)
        $grid.ColumnDefinitions.Add($c2)
        $grid.ColumnDefinitions.Add($c3)

        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = $p.Name
        $nameTb.FontFamily = "Consolas"
        $nameTb.FontSize = 11
        $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
        )
        $nameTb.TextTrimming = "CharacterEllipsis"
        $nameTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($nameTb, 0)
        $grid.Children.Add($nameTb) | Out-Null

        $cpuTb = New-Object System.Windows.Controls.TextBlock
        $cpuTb.Text = "$($p.CPU)%"
        $cpuTb.FontFamily = "Consolas"
        $cpuTb.FontSize = 11
        $cpuTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $cpuTb.TextAlignment = "Right"
        $cpuTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($cpuTb, 1)
        $grid.Children.Add($cpuTb) | Out-Null

        $memTb = New-Object System.Windows.Controls.TextBlock
        $memTb.Text = "$($p.MemMb) МБ"
        $memTb.FontFamily = "Consolas"
        $memTb.FontSize = 11
        $memTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
        )
        $memTb.TextAlignment = "Right"
        $memTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($memTb, 2)
        $grid.Children.Add($memTb) | Out-Null

        $row.Child = $grid
        $script:MonProcContainer.Children.Add($row) | Out-Null
    }
}

# ============================================================================
#  ОБНОВЛЕНИЕ: СЕТЬ
# ============================================================================
function Update-MonitoringNetworkPanel {
    param([PSCustomObject]$Network)

    if (-not $script:MonNetContainer) { return }

    $script:MonNetContainer.Children.Clear()

    # --- Активное подключение ---
    $ifaceCard = New-Object System.Windows.Controls.Border
    $ifaceCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $ifaceCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $ifaceCard.BorderThickness = "1"
    $ifaceCard.CornerRadius = "8"
    $ifaceCard.Padding = "12"
    $ifaceCard.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)

    $ifaceStack = New-Object System.Windows.Controls.StackPanel

    $ifaceTitle = New-Object System.Windows.Controls.TextBlock
    $ifaceTitle.Text = "Активное подключение"
    $ifaceTitle.FontSize = 12
    $ifaceTitle.FontWeight = "Bold"
    $ifaceTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $ifaceTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $ifaceStack.Children.Add($ifaceTitle) | Out-Null

    $ifaceType = if ($Network.ActiveIfType -and $Network.ActiveIfType -ne "—") { $Network.ActiveIfType } else { "—" }
    $ifaceName = if ($Network.ActiveIfName -and $Network.ActiveIfName -ne "—") { $Network.ActiveIfName } else { "" }
    $ifaceIp   = if ($Network.ActiveIfIp   -and $Network.ActiveIfIp   -ne "—") { $Network.ActiveIfIp   } else { "—" }

    $ifaceLine = New-Object System.Windows.Controls.TextBlock
    $ifaceLine.FontSize = 13
    $ifaceLine.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $ifaceLine.Text = if ($ifaceName) { "$ifaceType ($ifaceName) — $ifaceIp" } else { "$ifaceType — $ifaceIp" }
    $ifaceStack.Children.Add($ifaceLine) | Out-Null

    $ifaceCard.Child = $ifaceStack
    $script:MonNetContainer.Children.Add($ifaceCard) | Out-Null

    # --- Wi-Fi ---
    $wifiCard = New-Object System.Windows.Controls.Border
    $wifiCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $wifiCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $wifiCard.BorderThickness = "1"
    $wifiCard.CornerRadius = "8"
    $wifiCard.Padding = "12"

    $wifiStack = New-Object System.Windows.Controls.StackPanel

    $wifiTitle = New-Object System.Windows.Controls.TextBlock
    $wifiTitle.Text = "Wi-Fi"
    $wifiTitle.FontSize = 12
    $wifiTitle.FontWeight = "Bold"
    $wifiTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $wifiTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $wifiStack.Children.Add($wifiTitle) | Out-Null

    $wifiState = if ($Network.WifiEnabled) { "включён" } else { "выключен" }
    $wifiRows = @(
        @{ Label = "Состояние"; Value = $wifiState }
    )

    if ($Network.WifiSsid)      { $wifiRows += @{ Label = "SSID";      Value = $Network.WifiSsid } }
    if ($Network.WifiBssid)     { $wifiRows += @{ Label = "BSSID";     Value = $Network.WifiBssid } }
    if ($Network.WifiIp)        { $wifiRows += @{ Label = "IP";        Value = $Network.WifiIp } }
    if ($Network.WifiMac)       { $wifiRows += @{ Label = "MAC";       Value = $Network.WifiMac } }
    if ($Network.WifiGateway)   { $wifiRows += @{ Label = "Шлюз";      Value = $Network.WifiGateway } }
    if ($Network.WifiDns)       { $wifiRows += @{ Label = "DNS";       Value = $Network.WifiDns } }
    if ($Network.WifiFrequency) { $wifiRows += @{ Label = "Частота";   Value = $Network.WifiFrequency } }
    if ($Network.WifiLinkSpeed) { $wifiRows += @{ Label = "Скорость";  Value = $Network.WifiLinkSpeed } }
    if ($Network.WifiSignal -gt -1) {
        $wifiRows += @{ Label = "Сигнал"; Value = "$($Network.WifiSignal) dBm" }
    }

    foreach ($row in $wifiRows) {
        $line = New-Object System.Windows.Controls.Grid
        $line.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)

        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "150"
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "*"
        $line.ColumnDefinitions.Add($c1)
        $line.ColumnDefinitions.Add($c2)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $row.Label
        $lbl.FontSize = 12
        $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        $line.Children.Add($lbl) | Out-Null

        $val = New-Object System.Windows.Controls.TextBlock
        $val.Text = [string]$row.Value
        $val.FontSize = 12
        $val.FontFamily = "Consolas"
        $val.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $val.TextWrapping = "Wrap"
        [System.Windows.Controls.Grid]::SetColumn($val, 1)
        $line.Children.Add($val) | Out-Null

        $wifiStack.Children.Add($line) | Out-Null
    }

    $wifiCard.Child = $wifiStack
    $script:MonNetContainer.Children.Add($wifiCard) | Out-Null
}

# ============================================================================
#  ОБНОВЛЕНИЕ: BLUETOOTH
# ============================================================================
function Update-MonitoringBluetoothPanel {
    param([PSCustomObject]$Bluetooth)

    if (-not $script:MonBtContainer) { return }

    $script:MonBtContainer.Children.Clear()

    $btCard = New-Object System.Windows.Controls.Border
    $btCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $btCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $btCard.BorderThickness = "1"
    $btCard.CornerRadius = "8"
    $btCard.Padding = "12"
    $btCard.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)

    $btStack = New-Object System.Windows.Controls.StackPanel

    $btTitle = New-Object System.Windows.Controls.TextBlock
    $btTitle.Text = "Bluetooth"
    $btTitle.FontSize = 12
    $btTitle.FontWeight = "Bold"
    $btTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $btStack.Children.Add($btTitle) | Out-Null

    $btState = if ($Bluetooth.Enabled) { "включён" } else { "выключен" }
    $btRows = @(
        @{ Label = "Состояние"; Value = $btState }
    )
    if ($Bluetooth.Name)    { $btRows += @{ Label = "Имя"; Value = $Bluetooth.Name } }
    if ($Bluetooth.Address) { $btRows += @{ Label = "MAC"; Value = $Bluetooth.Address } }
    $btRows += @{ Label = "Сопряжено"; Value = "$(@($Bluetooth.Bonded).Count)" }

    foreach ($row in $btRows) {
        $line = New-Object System.Windows.Controls.Grid
        $line.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)

        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "150"
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "*"
        $line.ColumnDefinitions.Add($c1)
        $line.ColumnDefinitions.Add($c2)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $row.Label
        $lbl.FontSize = 12
        $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        $line.Children.Add($lbl) | Out-Null

        $val = New-Object System.Windows.Controls.TextBlock
        $val.Text = [string]$row.Value
        $val.FontSize = 12
        $val.FontFamily = "Consolas"
        $val.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $val.TextWrapping = "Wrap"
        [System.Windows.Controls.Grid]::SetColumn($val, 1)
        $line.Children.Add($val) | Out-Null

        $btStack.Children.Add($line) | Out-Null
    }

    $btCard.Child = $btStack
    $script:MonBtContainer.Children.Add($btCard) | Out-Null

    if (@($Bluetooth.Bonded).Count -gt 0) {
        $bondedTitle = New-Object System.Windows.Controls.TextBlock
        $bondedTitle.Text = "Сопряжённые устройства"
        $bondedTitle.FontSize = 12
        $bondedTitle.FontWeight = "Bold"
        $bondedTitle.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $bondedTitle.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
        $script:MonBtContainer.Children.Add($bondedTitle) | Out-Null

        foreach ($dev in $Bluetooth.Bonded) {
            $devRow = New-Object System.Windows.Controls.Border
            $devRow.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
            )
            $devRow.BorderBrush = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
            )
            $devRow.BorderThickness = "1"
            $devRow.CornerRadius = "6"
            $devRow.Padding = "10"
            $devRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

            $devStack = New-Object System.Windows.Controls.StackPanel

            $devName = New-Object System.Windows.Controls.TextBlock
            $devName.Text = if ($dev.Name -and $dev.Name -ne "—") { $dev.Name } else { "(без имени)" }
            $devName.FontSize = 12
            $devName.FontWeight = "Bold"
            $devName.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
            )
            $devStack.Children.Add($devName) | Out-Null

            $devMac = New-Object System.Windows.Controls.TextBlock
            $devMac.Text = $dev.Mac
            $devMac.FontFamily = "Consolas"
            $devMac.FontSize = 10
            $devMac.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
            )
            $devMac.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)
            $devStack.Children.Add($devMac) | Out-Null

            if ($dev.Connected) {
                $devConnected = New-Object System.Windows.Controls.TextBlock
                $devConnected.Text = "подключено"
                $devConnected.FontSize = 10
                $devConnected.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
                )
                $devConnected.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)
                $devStack.Children.Add($devConnected) | Out-Null
            }

            $devRow.Child = $devStack
            $script:MonBtContainer.Children.Add($devRow) | Out-Null
        }
    }
}

# ============================================================================
#  ОБНОВЛЕНИЕ: ТЕРМОДАТЧИКИ
# ============================================================================
function Update-MonitoringThermalZones {
    param([array]$Zones)

    if (-not $script:MonThermalZonesContainer) { return }

    $script:MonThermalZonesContainer.Children.Clear()

    if (-not $Zones -or $Zones.Count -eq 0) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "Датчики не найдены"
        $empty.FontSize = 12
        $empty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $script:MonThermalZonesContainer.Children.Add($empty) | Out-Null
        return
    }

    foreach ($z in $Zones) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
        )
        $row.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )
        $row.BorderThickness = "1"
        $row.CornerRadius = "6"
        $row.Padding = "10"
        $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

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

        $tempColor = "#6CCB5F"
        if ($z.TempC -gt 80) { $tempColor = "#FF6B6B" }
        elseif ($z.TempC -gt 60) { $tempColor = "#FFC83D" }
        elseif ($z.TempC -lt 40) { $tempColor = "#60CDFF" }

        $tempTb = New-Object System.Windows.Controls.TextBlock
        $tempTb.Text = "$($z.TempC) °C"
        $tempTb.FontSize = 14
        $tempTb.FontWeight = "Bold"
        $tempTb.FontFamily = "Consolas"
        $tempTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString($tempColor)
        )
        $tempTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($tempTb, 1)
        $grid.Children.Add($tempTb) | Out-Null

        $row.Child = $grid
        $script:MonThermalZonesContainer.Children.Add($row) | Out-Null
    }
}

# ============================================================================
#  ГРАФИК ТЕМПЕРАТУРЫ
# ============================================================================
function Update-MonitoringTemperatureChart {
    if (-not $script:MonTempChartCanvas) { return }
    $canvas = $script:MonTempChartCanvas
    $canvas.Children.Clear()

    $history = $script:MonitoringHistoryTemp
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

    $width = 700
    $height = 180
    $padding = 30

    $minTemp = ($history | Measure-Object -Minimum).Minimum - 2
    $maxTemp = ($history | Measure-Object -Maximum).Maximum + 2
    if ($maxTemp - $minTemp -lt 10) { $maxTemp = $minTemp + 10 }

    $stepX = ($width - $padding * 2) / [math]::Max($history.Count - 1, 1)

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

# ============================================================================
#  ГРАФИК ТРАФИКА
# ============================================================================
function Update-MonitoringTrafficChart {
    if (-not $script:MonTrafficChartCanvas) { return }
    $canvas = $script:MonTrafficChartCanvas
    $canvas.Children.Clear()

    $rxHistory = $script:MonitoringHistoryTrafficRx
    $txHistory = $script:MonitoringHistoryTrafficTx

    if ($rxHistory.Count -lt 2) {
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
    $height = 200
    $paddingLeft = 60
    $paddingRight = 15
    $paddingTop = 20
    $paddingBottom = 30

    $maxRx = ($rxHistory | Measure-Object -Maximum).Maximum
    $maxTx = ($txHistory | Measure-Object -Maximum).Maximum
    $maxVal = [math]::Max($maxRx, $maxTx)
    if ($maxVal -lt 1024) { $maxVal = 1024 }
    $maxVal = $maxVal * 1.15

    $stepX = ($width - $paddingLeft - $paddingRight) / [math]::Max($rxHistory.Count - 1, 1)

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

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = Format-MonRate -BytesPerSecond ($maxVal * (1 - $i / 4))
        $lbl.FontSize = 10
        $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
        )
        [System.Windows.Controls.Canvas]::SetLeft($lbl, 5)
        [System.Windows.Controls.Canvas]::SetTop($lbl, $y - 7)
        $canvas.Children.Add($lbl) | Out-Null
    }

    $rxLine = New-Object System.Windows.Shapes.Polyline
    $rxLine.Stroke = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $rxLine.StrokeThickness = 2
    $rxLine.StrokeLineJoin = "Round"

    for ($i = 0; $i -lt $rxHistory.Count; $i++) {
        $val = $rxHistory[$i]
        $x = $paddingLeft + ($i * $stepX)
        $y = $height - $paddingBottom - (($val / $maxVal) * ($height - $paddingTop - $paddingBottom))
        $rxLine.Points.Add((New-Object System.Windows.Point($x, $y)))
    }
    $canvas.Children.Add($rxLine) | Out-Null

    $txLine = New-Object System.Windows.Shapes.Polyline
    $txLine.Stroke = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $txLine.StrokeThickness = 2
    $txLine.StrokeLineJoin = "Round"

    for ($i = 0; $i -lt $txHistory.Count; $i++) {
        $val = $txHistory[$i]
        $x = $paddingLeft + ($i * $stepX)
        $y = $height - $paddingBottom - (($val / $maxVal) * ($height - $paddingTop - $paddingBottom))
        $txLine.Points.Add((New-Object System.Windows.Point($x, $y)))
    }
    $canvas.Children.Add($txLine) | Out-Null

    if ($script:MonTrafficMaxLabel) {
        $script:MonTrafficMaxLabel.Text = "Максимум: $(Format-MonRate -BytesPerSecond $maxVal)   |   точек: $($rxHistory.Count)"
    }
}

# ============================================================================
#  СТОП / СТАРТ
# ============================================================================
function Stop-MonitoringWatcher {
    if ($script:MonitoringRefreshTimer) {
        $script:MonitoringRefreshTimer.Stop()
    }
    if ($script:MonitoringTrafficTimer) {
        $script:MonitoringTrafficTimer.Stop()
    }
    $script:MonitoringRunning = $false
    if ($script:MonitoringBtnToggle) {
        $script:MonitoringBtnToggle.Content = "Запустить"
        $script:MonitoringBtnToggle.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
    }
    Write-Log -Message "Мониторинг остановлен" -Level "Info"
}

function Start-MonitoringWatcher {
    $script:MonitoringPrevCounters = $null
    $script:MonitoringLastSampleTime = Get-Date

    if ($script:MonitoringRefreshTimer) {
        $script:MonitoringRefreshTimer.Start()
    }
    if ($script:MonitoringTrafficTimer) {
        $script:MonitoringTrafficTimer.Start()
    }

    $script:MonitoringRunning = $true
    if ($script:MonitoringBtnToggle) {
        $script:MonitoringBtnToggle.Content = "Пауза"
        $script:MonitoringBtnToggle.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
    }
    Write-Log -Message "Мониторинг запущен" -Level "Info"
}