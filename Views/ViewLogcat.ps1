# ============================================================================
#  Экран: Logcat
# ============================================================================
function Show-LogcatView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Logcat — живые логи ТВ"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Логи Android в реальном времени. Можно фильтровать по тегу и уровню." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ФИЛЬТРЫ =====
    $filterGrid = New-Object System.Windows.Controls.Grid
    $fc1 = New-Object System.Windows.Controls.ColumnDefinition
    $fc1.Width = "80"
    $fc2 = New-Object System.Windows.Controls.ColumnDefinition
    $fc2.Width = "*"
    $fc3 = New-Object System.Windows.Controls.ColumnDefinition
    $fc3.Width = "120"
    $fc4 = New-Object System.Windows.Controls.ColumnDefinition
    $fc4.Width = "Auto"
    $fc5 = New-Object System.Windows.Controls.ColumnDefinition
    $fc5.Width = "Auto"
    $filterGrid.ColumnDefinitions.Add($fc1)
    $filterGrid.ColumnDefinitions.Add($fc2)
    $filterGrid.ColumnDefinitions.Add($fc3)
    $filterGrid.ColumnDefinitions.Add($fc4)
    $filterGrid.ColumnDefinitions.Add($fc5)
    $filterGrid.Margin = "0,0,0,10"

    # --- Подпись "Фильтр" (светло-серая) ---
    $lblFilter = New-Object System.Windows.Controls.TextBlock
    $lblFilter.Text = "Фильтр:"
    $lblFilter.FontSize = 13
    $lblFilter.VerticalAlignment = "Center"
    $lblFilter.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    [System.Windows.Controls.Grid]::SetColumn($lblFilter, 0)
    $filterGrid.Children.Add($lblFilter) | Out-Null

    # --- Поле фильтра ---
    $script:LogcatFilterBox = New-Object System.Windows.Controls.TextBox
    $script:LogcatFilterBox.Style = $window.Resources["RoundedTextBox"]
    $script:LogcatFilterBox.FontSize = 13
    $script:LogcatFilterBox.Margin = "0,0,8,0"
    [System.Windows.Controls.Grid]::SetColumn($script:LogcatFilterBox, 1)
    $filterGrid.Children.Add($script:LogcatFilterBox) | Out-Null

    # --- ComboBox уровня ---
    $script:LogcatLevelBox = New-Object System.Windows.Controls.ComboBox
    $script:LogcatLevelBox.FontSize = 13
    $script:LogcatLevelBox.Margin = "0,0,8,0"
    [void]$script:LogcatLevelBox.Items.Add("Все")
    [void]$script:LogcatLevelBox.Items.Add("Debug")
    [void]$script:LogcatLevelBox.Items.Add("Info")
    [void]$script:LogcatLevelBox.Items.Add("Warning")
    [void]$script:LogcatLevelBox.Items.Add("Error")
    $script:LogcatLevelBox.SelectedIndex = 0
    [System.Windows.Controls.Grid]::SetColumn($script:LogcatLevelBox, 2)
    $filterGrid.Children.Add($script:LogcatLevelBox) | Out-Null

    # --- Кнопка Запустить / Остановить (Success) ---
    $script:LogcatToggleBtn = New-Object System.Windows.Controls.Button
    $script:LogcatToggleBtn.Content = "Запустить"
    $script:LogcatToggleBtn.Style = $window.Resources["RoundedButton"]
    $script:LogcatToggleBtn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $script:LogcatToggleBtn.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $script:LogcatToggleBtn.Padding = "15,6"
    $script:LogcatToggleBtn.Margin = "0,0,8,0"
    [System.Windows.Controls.Grid]::SetColumn($script:LogcatToggleBtn, 3)
    $filterGrid.Children.Add($script:LogcatToggleBtn) | Out-Null

    # --- Кнопка Очистить (Warning) ---
    $btnClear = New-Object System.Windows.Controls.Button
    $btnClear.Content = "Очистить"
    $btnClear.Style = $window.Resources["RoundedButton"]
    $btnClear.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
    )
    $btnClear.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $btnClear.Padding = "15,6"
    [System.Windows.Controls.Grid]::SetColumn($btnClear, 4)
    $filterGrid.Children.Add($btnClear) | Out-Null

    $mainStack.Children.Add($filterGrid) | Out-Null

    # ===== ОБЛАСТЬ ЛОГА =====
    $logPanel = New-Object System.Windows.Controls.Border
    $logPanel.Background = "#181818"
    $logPanel.CornerRadius = "8"
    $logPanel.Padding = "10"
    $logPanel.Height = 400
    $mainStack.Children.Add($logPanel) | Out-Null

    $script:LogcatBox = New-Object System.Windows.Controls.RichTextBox
    $script:LogcatBox.Background = "#181818"
    $script:LogcatBox.Foreground = "#D0D0D0"
    $script:LogcatBox.FontFamily = "Consolas"
    $script:LogcatBox.FontSize = 11
    $script:LogcatBox.IsReadOnly = $true
    $script:LogcatBox.BorderThickness = "0"
    $script:LogcatBox.VerticalScrollBarVisibility = "Auto"
    $logPanel.Child = $script:LogcatBox

    # ===== СТАТУС =====
    $script:LogcatStatus = New-Object System.Windows.Controls.TextBlock
    $script:LogcatStatus.Text = "Logcat остановлен"
    $script:LogcatStatus.FontSize = 12
    $script:LogcatStatus.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $script:LogcatStatus.Margin = "0,10,0,0"
    $mainStack.Children.Add($script:LogcatStatus) | Out-Null

    # ===== ЛОГИКА КНОПКИ TOGGLE =====
    $script:LogcatToggleBtn.Add_Click({
        $btn = $script:LogcatToggleBtn
        $status = $script:LogcatStatus
        $filterBox = $script:LogcatFilterBox
        $levelBox = $script:LogcatLevelBox
        $logBox = $script:LogcatBox

        if ($script:LogcatProcess -and $script:LogcatProcess.PowerShell) {
            # ===== ОСТАНОВИТЬ =====
            $procToStop = $script:LogcatProcess
            $script:LogcatProcess = $null

            # Меняем UI сразу
            $btn.Content = "Запустить"
            $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
            )
            $status.Text = "Logcat остановлен"
            $status.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
            )

            # Останавливаем в фоне — UI не блокируется
            Stop-Logcat -Proc $procToStop
        } else {
            # ===== ЗАПУСТИТЬ =====
            $filter = $filterBox.Text.Trim()
            $levelText = $levelBox.SelectedItem.ToString()

            $level = ""
            switch ($levelText) {
                "Debug"   { $level = "D" }
                "Info"    { $level = "I" }
                "Warning" { $level = "W" }
                "Error"   { $level = "E" }
            }

            Write-Log -Message "=== Запуск logcat ===" -Level "Info"

            $logBox.Document.Blocks.Clear()

            try {
                $proc = Start-Logcat -LogBox $logBox -Filter $filter -Level $level
                if ($proc) {
                    $script:LogcatProcess = $proc
                    $btn.Content = "Остановить"
                    $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
                    )
                    $status.Text = "Logcat работает..."
                    $status.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
                    )
                } else {
                    $status.Text = "Не удалось запустить logcat"
                }
            } catch {
                Write-Log -Message "Ошибка запуска logcat: $_" -Level "Error"
                $status.Text = "Ошибка: $_"
            }
        }
    })

    # --- Кнопка Очистить ---
    $btnClear.Add_Click({
        $script:LogcatBox.Document.Blocks.Clear()
        Write-Log -Message "Лог очищен" -Level "Info"
    })

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack {
        # Останавливаем logcat перед уходом с экрана
        if ($script:LogcatProcess -and $script:LogcatProcess.PowerShell) {
            $procToStop = $script:LogcatProcess
            $script:LogcatProcess = $null
            Stop-Logcat -Proc $procToStop
        }
        Switch-View -ViewName "Setup"
    }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== BOTTOM BAR =====
    $buttons = @()

    # --- Сохранить в файл (Success) ---
    $btnSave = New-Object System.Windows.Controls.Button
    $btnSave.Content = "Сохранить в файл"
    $btnSave.Style = $window.Resources["RoundedButton"]
    $btnSave.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnSave.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $btnSave.Padding = "12,6"
    $btnSave.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $dlg.FileName = "logcat_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $text = New-Object System.Windows.Documents.TextRange(
                $script:LogcatBox.Document.ContentStart,
                $script:LogcatBox.Document.ContentEnd
            )
            $text.Text | Out-File -FilePath $dlg.FileName -Encoding UTF8
            Write-Log -Message "Лог сохранён: $($dlg.FileName)" -Level "Success"
        }
    })
    $buttons += $btnSave

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран logcat" -Level "Info"
}