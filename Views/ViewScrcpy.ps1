# ============================================================================
#  Экран: Трансляция экрана (scrcpy)
# ============================================================================
function Show-ScrcpyView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Трансляция экрана (scrcpy)"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $warnCard = New-Object System.Windows.Controls.Border
        $warnCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3D3520")
        )
        $warnCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#5A4A2A")
        )
        $warnCard.BorderThickness = "1"
        $warnCard.CornerRadius = "8"
        $warnCard.Padding = "12"
        $warnCard.Margin = "0,0,0,15"

        $warnText = New-Object System.Windows.Controls.TextBlock
        $warnText.Text = "Сначала подключитесь к телевизору в разделе «Настройка»."
        $warnText.TextWrapping = "Wrap"
        $warnText.FontSize = 12
        $warnText.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $warnCard.Child = $warnText
        $mainStack.Children.Add($warnCard) | Out-Null

        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    $isInstalled = Test-ScrcpyAvailable

    # ---- Статус ----
    $statusCard = New-Object System.Windows.Controls.Border
    if ($isInstalled) {
        $statusCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#1F3A1F")
        )
        $statusCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A5A3A")
        )
    } else {
        $statusCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A1F1F")
        )
        $statusCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#5A3A3A")
        )
    }
    $statusCard.BorderThickness = "1"
    $statusCard.CornerRadius = "8"
    $statusCard.Padding = "15"
    $statusCard.Margin = "0,0,0,15"

    $statusStack = New-Object System.Windows.Controls.StackPanel

    $statusTitle = New-Object System.Windows.Controls.TextBlock
    $statusTitle.FontSize = 14
    $statusTitle.FontWeight = "Bold"
    $statusTitle.Margin = "0,0,0,6"

    if ($isInstalled) {
        $statusTitle.Text = "✓ scrcpy установлен"
        $statusTitle.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } else {
        $statusTitle.Text = "✗ scrcpy не найден"
        $statusTitle.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FF6B6B")
        )
    }
    $statusStack.Children.Add($statusTitle) | Out-Null

    $statusDetail = New-Object System.Windows.Controls.TextBlock
    $statusDetail.FontSize = 11
    $statusDetail.TextWrapping = "Wrap"
    $statusDetail.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    if ($isInstalled) {
        $statusDetail.Text = "Путь: $($script:ScrcpyExe)"
    } else {
        $statusDetail.Text = "Для трансляции экрана нужен scrcpy. Нажмите «Установить scrcpy» внизу — программа покажет инструкцию и поможет добавить в PATH."
    }
    $statusStack.Children.Add($statusDetail) | Out-Null

    $statusCard.Child = $statusStack
    $mainStack.Children.Add($statusCard) | Out-Null

    # ---- Что даёт scrcpy ----
    $mainStack.Children.Add((New-ViewLabel -Text "Что даёт трансляция:" -Light)) | Out-Null

    $features = @(
        "• Живой экран ТВ на ПК — без задержек, ~30-60 FPS",
        "• Управление мышью и клавиатурой",
        "• Трансляция звука (опционально)",
        "• Возможность записать экран ТВ в MP4",
        "• Работает через уже подключённый ADB — на ТВ ничего настраивать не нужно"
    )
    foreach ($f in $features) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $f
        $tb.FontSize = 12
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $tb.TextWrapping = "Wrap"
        $tb.Margin = "0,2,0,2"
        $mainStack.Children.Add($tb) | Out-Null
    }

    # ========================================================================
    #  КАК УПРАВЛЯТЬ В ОКНЕ SCRCPY (3 КОЛОНКИ)
    # ========================================================================
    $mainStack.Children.Add((New-StepTitle -Text "Управление в окне scrcpy")) | Out-Null

    $controlCard = New-Object System.Windows.Controls.Border
    $controlCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $controlCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $controlCard.BorderThickness = "1"
    $controlCard.CornerRadius = "8"
    $controlCard.Padding = "14"
    $controlCard.Margin = "0,5,0,15"

    # Сетка: 3 колонки равной ширины
    $ctrlGrid = New-Object System.Windows.Controls.Grid
    $cg1 = New-Object System.Windows.Controls.ColumnDefinition; $cg1.Width = "*"
    $cg2 = New-Object System.Windows.Controls.ColumnDefinition; $cg2.Width = "15"
    $cg3 = New-Object System.Windows.Controls.ColumnDefinition; $cg3.Width = "*"
    $cg4 = New-Object System.Windows.Controls.ColumnDefinition; $cg4.Width = "15"
    $cg5 = New-Object System.Windows.Controls.ColumnDefinition; $cg5.Width = "*"
    $ctrlGrid.ColumnDefinitions.Add($cg1)
    $ctrlGrid.ColumnDefinitions.Add($cg2)
    $ctrlGrid.ColumnDefinitions.Add($cg3)
    $ctrlGrid.ColumnDefinitions.Add($cg4)
    $ctrlGrid.ColumnDefinitions.Add($cg5)

    # ============================================================
    #  КОЛОНКА 1: МЫШЬ
    # ============================================================
    $mouseCol = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($mouseCol, 0)

    $mouseHeader = New-Object System.Windows.Controls.TextBlock
    $mouseHeader.Text = "🖱 Мышь"
    $mouseHeader.FontSize = 13
    $mouseHeader.FontWeight = "Bold"
    $mouseHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $mouseHeader.Margin = "0,0,0,8"
    $mouseCol.Children.Add($mouseHeader) | Out-Null

    $mouseItems = @(
        @{ Key = "ЛКМ"; Action = "нажать (OK)" }
        @{ Key = "ПКМ"; Action = "Назад" }
        @{ Key = "Средняя кн."; Action = "Home" }
        @{ Key = "Колесо"; Action = "прокрутка" }
        @{ Key = "Ctrl + клик"; Action = "тап в точку" }
        @{ Key = "Двойной ЛКМ"; Action = "на весь экран" }
    )

    foreach ($item in $mouseItems) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = "0,0,0,5"

        $keyTb = New-Object System.Windows.Controls.TextBlock
        $keyTb.Text = $item.Key
        $keyTb.FontSize = 11
        $keyTb.FontFamily = "Consolas"
        $keyTb.FontWeight = "Bold"
        $keyTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $row.Children.Add($keyTb) | Out-Null

        $actTb = New-Object System.Windows.Controls.TextBlock
        $actTb.Text = $item.Action
        $actTb.FontSize = 10
        $actTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $actTb.TextWrapping = "Wrap"
        $row.Children.Add($actTb) | Out-Null

        $mouseCol.Children.Add($row) | Out-Null
    }

    $ctrlGrid.Children.Add($mouseCol) | Out-Null

    # ============================================================
    #  КОЛОНКА 2: КЛАВИАТУРА
    # ============================================================
    $kbCol = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($kbCol, 2)

    $kbHeader = New-Object System.Windows.Controls.TextBlock
    $kbHeader.Text = "⌨ Клавиатура"
    $kbHeader.FontSize = 13
    $kbHeader.FontWeight = "Bold"
    $kbHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $kbHeader.Margin = "0,0,0,8"
    $kbCol.Children.Add($kbHeader) | Out-Null

    $kbItems = @(
        @{ Key = "↑ ↓ ← →"; Action = "навигация" }
        @{ Key = "Enter"; Action = "OK" }
        @{ Key = "Esc"; Action = "Назад" }
        @{ Key = "Home"; Action = "Домой" }
        @{ Key = "Пробел"; Action = "Play / Pause" }
    )

    foreach ($item in $kbItems) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = "0,0,0,5"

        $keyTb = New-Object System.Windows.Controls.TextBlock
        $keyTb.Text = $item.Key
        $keyTb.FontSize = 11
        $keyTb.FontFamily = "Consolas"
        $keyTb.FontWeight = "Bold"
        $keyTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $row.Children.Add($keyTb) | Out-Null

        $actTb = New-Object System.Windows.Controls.TextBlock
        $actTb.Text = $item.Action
        $actTb.FontSize = 10
        $actTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $actTb.TextWrapping = "Wrap"
        $row.Children.Add($actTb) | Out-Null

        $kbCol.Children.Add($row) | Out-Null
    }

    $ctrlGrid.Children.Add($kbCol) | Out-Null

    # ============================================================
    #  КОЛОНКА 3: CTRL + КЛАВИША
    # ============================================================
    $ctrlCol = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($ctrlCol, 4)

    $ctrlHeader = New-Object System.Windows.Controls.TextBlock
    $ctrlHeader.Text = "⚙ Ctrl + клавиша"
    $ctrlHeader.FontSize = 13
    $ctrlHeader.FontWeight = "Bold"
    $ctrlHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $ctrlHeader.Margin = "0,0,0,8"
    $ctrlCol.Children.Add($ctrlHeader) | Out-Null

    $ctrlItems = @(
        @{ Key = "Ctrl+H"; Action = "Home" }
        @{ Key = "Ctrl+B"; Action = "Назад" }
        @{ Key = "Ctrl+P"; Action = "Питание" }
        @{ Key = "Ctrl+O"; Action = "Погасить экран" }
        @{ Key = "Ctrl+Shift+O"; Action = "Включить экран" }
        @{ Key = "Ctrl+R"; Action = "Повернуть" }
        @{ Key = "Ctrl+F"; Action = "На весь экран" }
        @{ Key = "Ctrl+S"; Action = "Скриншот" }
        @{ Key = "Ctrl+W"; Action = "Убрать полосы" }
        @{ Key = "Ctrl+N"; Action = "Свернуть" }
    )

    foreach ($item in $ctrlItems) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = "0,0,0,4"

        $keyTb = New-Object System.Windows.Controls.TextBlock
        $keyTb.Text = $item.Key
        $keyTb.FontSize = 11
        $keyTb.FontFamily = "Consolas"
        $keyTb.FontWeight = "Bold"
        $keyTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $row.Children.Add($keyTb) | Out-Null

        $actTb = New-Object System.Windows.Controls.TextBlock
        $actTb.Text = $item.Action
        $actTb.FontSize = 10
        $actTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $actTb.TextWrapping = "Wrap"
        $row.Children.Add($actTb) | Out-Null

        $ctrlCol.Children.Add($row) | Out-Null
    }

    $ctrlGrid.Children.Add($ctrlCol) | Out-Null

    $controlCard.Child = $ctrlGrid
    $mainStack.Children.Add($controlCard) | Out-Null

    # ---- Требования ----
    $reqCard = New-Object System.Windows.Controls.Border
    $reqCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $reqCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $reqCard.BorderThickness = "1"
    $reqCard.CornerRadius = "8"
    $reqCard.Padding = "12"
    $reqCard.Margin = "0,15,0,0"

    $reqText = New-Object System.Windows.Controls.TextBlock
    $reqText.Text = "Для комфортной трансляции: ТВ и ПК в одной Wi-Fi сети 5 ГГц (или Ethernet). На 2.4 ГГц возможны подтормаживания."
    $reqText.FontSize = 11
    $reqText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $reqText.TextWrapping = "Wrap"
    $reqCard.Child = $reqText
    $mainStack.Children.Add($reqCard) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    $btnStart = New-Object System.Windows.Controls.Button
    if ($isInstalled) {
        $btnStart.Content = "Настройки и запуск"
        $btnStart.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
    } else {
        $btnStart.Content = "Установить scrcpy"
        $btnStart.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
    }
    $btnStart.Style = $window.Resources["RoundedButton"]
    $btnStart.Padding = "12,6"
    $btnStart.Margin = "0,0,8,0"
    $btnStart.Add_Click({ Show-ScrcpyDialog })
    $buttons += $btnStart

    if (Test-ScrcpyRunning) {
        $btnStop = New-Object System.Windows.Controls.Button
        $btnStop.Content = "Остановить трансляцию"
        $btnStop.Style = $window.Resources["RoundedButton"]
        $btnStop.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
        $btnStop.Padding = "12,6"
        $btnStop.Margin = "0,0,8,0"
        $btnStop.Add_Click({
            Stop-Scrcpy | Out-Null
            Switch-View -ViewName "Scrcpy"
        })
        $buttons += $btnStop
    }

    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({
        Test-ScrcpyAvailable -Force | Out-Null
        Switch-View -ViewName "Scrcpy"
    })
    $buttons += $btnRefresh

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран scrcpy (installed=$isInstalled)" -Level "Info"
}