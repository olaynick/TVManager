function Show-MainView {
    $outerGrid = New-Object System.Windows.Controls.Grid

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.HorizontalAlignment = "Center"
    $stack.VerticalAlignment = "Center"
    $stack.Width = 500

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "TCL TV Manager"
    $title.FontSize = 34
    $title.FontWeight = "Bold"
    $title.HorizontalAlignment = "Center"
    $title.Margin = "0,0,0,10"
    $stack.Children.Add($title) | Out-Null

    $subtitle = New-Object System.Windows.Controls.TextBlock
    $subtitle.Text = "Управление телевизором через ADB"
    $subtitle.FontSize = 14
    $subtitle.Foreground = "#96969B"
    $subtitle.HorizontalAlignment = "Center"
    $subtitle.Margin = "0,0,0,30"
    $stack.Children.Add($subtitle) | Out-Null

    # ===== ИНФОРМАЦИЯ О ADB =====
    $adbReady = Test-AdbInPath

    $adbInfo = New-Object System.Windows.Controls.TextBlock
    $adbInfo.Text = "Для работы необходим установленный ADB"
    $adbInfo.FontSize = 13
    $adbInfo.HorizontalAlignment = "Center"
    $adbInfo.Margin = "0,0,0,8"
    if ($adbReady) {
        $adbInfo.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
        )
        $adbInfo.Text = "ADB найден — программа готова к работе"
    } else {
        $adbInfo.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
        )
    }
    $stack.Children.Add($adbInfo) | Out-Null

    # Кнопка "Как установить ADB"
    $btnAdbHelp = New-Object System.Windows.Controls.Button
    $btnAdbHelp.Content = "Как установить ADB?"
    $btnAdbHelp.Style = $window.Resources["RoundedButton"]
    if ($adbReady) {
        $btnAdbHelp.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
        )
    } else {
        $btnAdbHelp.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
        )
    }
    $btnAdbHelp.Padding = "15,8"
    $btnAdbHelp.Margin = "0,0,0,30"
    $btnAdbHelp.HorizontalAlignment = "Center"
    $btnAdbHelp.Add_Click({
        Show-AdbHelpDialog
    })
    $stack.Children.Add($btnAdbHelp) | Out-Null

    # ===== КНОПКИ МЕНЮ =====
    $btnSetup = New-Object System.Windows.Controls.Button
    $btnSetup.Content = "Настройка"
    $btnSetup.Style = $window.Resources["RoundedButton"]
    $btnSetup.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnSetup.Width = 400
    $btnSetup.Height = 55
    $btnSetup.FontSize = 15
    $btnSetup.Margin = "0,0,0,12"
    $btnSetup.HorizontalAlignment = "Center"
    $btnSetup.Add_Click({ Switch-View -ViewName "Setup" })
    $stack.Children.Add($btnSetup) | Out-Null

    $btnRollback = New-Object System.Windows.Controls.Button
    $btnRollback.Content = "Откат изменений"
    $btnRollback.Style = $window.Resources["RoundedButton"]
    $btnRollback.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
    )
    $btnRollback.Width = 400
    $btnRollback.Height = 55
    $btnRollback.FontSize = 15
    $btnRollback.Margin = "0,0,0,12"
    $btnRollback.HorizontalAlignment = "Center"
    $btnRollback.Add_Click({ Switch-View -ViewName "Rollback" })
    $stack.Children.Add($btnRollback) | Out-Null

    $btnAppSettings = New-Object System.Windows.Controls.Button
    $btnAppSettings.Content = "Настройки приложения"
    $btnAppSettings.Style = $window.Resources["RoundedButton"]
    $btnAppSettings.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#607D8B")
    )
    $btnAppSettings.Width = 400
    $btnAppSettings.Height = 55
    $btnAppSettings.FontSize = 15
    $btnAppSettings.Margin = "0,0,0,12"
    $btnAppSettings.HorizontalAlignment = "Center"
    $btnAppSettings.Add_Click({ Switch-View -ViewName "Settings" })
    $stack.Children.Add($btnAppSettings) | Out-Null

    $btnExit = New-Object System.Windows.Controls.Button
    $btnExit.Content = "Выход"
    $btnExit.Style = $window.Resources["RoundedButton"]
    $btnExit.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
    )
    $btnExit.Width = 400
    $btnExit.Height = 55
    $btnExit.FontSize = 15
    $btnExit.HorizontalAlignment = "Center"
    $btnExit.Add_Click({ $window.Close() })
    $stack.Children.Add($btnExit) | Out-Null

    $outerGrid.Children.Add($stack) | Out-Null
    $contentGrid.Children.Add($outerGrid) | Out-Null
    Write-Log -Message "Главное меню" -Level "Info"
}

# ===== ДИАЛОГ "КАК УСТАНОВИТЬ ADB" =====
function Show-AdbHelpDialog {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Установка ADB"
    $dialog.Width = 650
    $dialog.Height = 550
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#F7F7FA"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "20"

    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = "Auto"
    $grid.RowDefinitions.Add($row1)

    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = "*"
    $grid.RowDefinitions.Add($row2)

    $row3 = New-Object System.Windows.Controls.RowDefinition
    $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row3)

    $header = New-ViewHeader -Text "Как установить ADB" -X 0 -Y 0
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $grid.Children.Add($header) | Out-Null

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $stack = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $stack

    # Шаг 1
    $step1 = New-Object System.Windows.Controls.TextBlock
    $step1.Text = "Шаг 1. Скачайте Platform Tools"
    $step1.FontSize = 14
    $step1.FontWeight = "Bold"
    $step1.Margin = "0,0,0,5"
    $stack.Children.Add($step1) | Out-Null

    $step1Text = New-Object System.Windows.Controls.TextBlock
    $step1Text.Text = "Скачайте архив platform-tools для Windows с официального сайта Google. Это официальный пакет с ADB, не требующий установки."
    $step1Text.FontSize = 12
    $step1Text.TextWrapping = "Wrap"
    $step1Text.Foreground = "#2D2D30"
    $step1Text.Margin = "0,0,0,10"
    $stack.Children.Add($step1Text) | Out-Null

    # Кнопка "Скачать"
    $btnDownload = New-Object System.Windows.Controls.Button
    $btnDownload.Content = "Открыть страницу загрузки"
    $btnDownload.Style = $window.Resources["RoundedButton"]
    $btnDownload.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnDownload.Padding = "15,8"
    $btnDownload.HorizontalAlignment = "Left"
    $btnDownload.Margin = "0,0,0,15"
    $btnDownload.Add_Click({
        Start-Process "https://developer.android.com/tools/releases/platform-tools"
    })
    $stack.Children.Add($btnDownload) | Out-Null

    # Шаг 2
    $step2 = New-Object System.Windows.Controls.TextBlock
    $step2.Text = "Шаг 2. Распакуйте архив"
    $step2.FontSize = 14
    $step2.FontWeight = "Bold"
    $step2.Margin = "0,0,0,5"
    $stack.Children.Add($step2) | Out-Null

    $step2Text = New-Object System.Windows.Controls.TextBlock
    $step2Text.Text = "Распакуйте скачанный архив в удобное место. Например, в C:\platform-tools. Главное — запомните путь к папке, внутри которой лежит файл adb.exe."
    $step2Text.FontSize = 12
    $step2Text.TextWrapping = "Wrap"
    $step2Text.Foreground = "#2D2D30"
    $step2Text.Margin = "0,0,0,15"
    $stack.Children.Add($step2Text) | Out-Null

    # Шаг 3
    $step3 = New-Object System.Windows.Controls.TextBlock
    $step3.Text = "Шаг 3. Укажите путь в программе"
    $step3.FontSize = 14
    $step3.FontWeight = "Bold"
    $step3.Margin = "0,0,0,5"
    $stack.Children.Add($step3) | Out-Null

    $step3Text = New-Object System.Windows.Controls.TextBlock
    $step3Text.Text = "Нажмите кнопку ниже — откроется окно выбора папки. Укажите папку, куда вы распаковали platform-tools (там, где лежит adb.exe). Программа автоматически добавит её в PATH."
    $step3Text.FontSize = 12
    $step3Text.TextWrapping = "Wrap"
    $step3Text.Foreground = "#2D2D30"
    $step3Text.Margin = "0,0,0,10"
    $stack.Children.Add($step3Text) | Out-Null

    # Кнопка "Указать папку"
    $btnBrowse = New-Object System.Windows.Controls.Button
    $btnBrowse.Content = "Указать папку с adb.exe"
    $btnBrowse.Style = $window.Resources["RoundedButton"]
    $btnBrowse.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
    )
    $btnBrowse.Padding = "15,8"
    $btnBrowse.HorizontalAlignment = "Left"
    $btnBrowse.Margin = "0,0,0,15"
    $btnBrowse.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Укажите папку, где находится adb.exe"
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $selected = $dlg.SelectedPath
            $adbExe = Join-Path $selected "adb.exe"
            if (-not (Test-Path $adbExe)) {
                [System.Windows.MessageBox]::Show(
                    "В выбранной папке нет adb.exe.",
                    "Ошибка",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
                return
            }
            $ok = Add-AdbToUserPath -AdbFolder $selected
            if ($ok) {
                [System.Windows.MessageBox]::Show(
                    "ADB успешно добавлен в PATH.`n`nПрограмма готова к работе.",
                    "Готово",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null
                $dialog.Close()
                Switch-View -ViewName "Main"
            } else {
                [System.Windows.MessageBox]::Show(
                    "Не удалось добавить ADB в PATH.",
                    "Ошибка",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
            }
        }
    })
    $stack.Children.Add($btnBrowse) | Out-Null

    # Пояснение
    $note = New-Object System.Windows.Controls.TextBlock
    $note.Text = "Примечание: программа добавляет путь в пользовательский PATH. Права администратора не требуются. Изменения вступают в силу для новых процессов (текущая сессия обновляется автоматически)."
    $note.FontSize = 11
    $note.TextWrapping = "Wrap"
    $note.Foreground = "#96969B"
    $note.Margin = "0,10,0,0"
    $stack.Children.Add($note) | Out-Null

    # Кнопка "Закрыть"
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnClose.Padding = "15,8"
    $btnClose.HorizontalAlignment = "Right"
    $btnClose.Margin = "0,15,0,0"
    $btnClose.Add_Click({ $dialog.Close() })
    [System.Windows.Controls.Grid]::SetRow($btnClose, 2)
    $grid.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}