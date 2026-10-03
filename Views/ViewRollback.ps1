function Show-RollbackView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "История действий и откат"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Здесь отображаются все изменения, которые программа внесла в ТВ. Отметьте нужные и нажмите «Откатить выбранные»." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    # ===== ЗАГРУЗКА ИСТОРИИ =====
    $backupFile = Get-ChangesFilePath

    if (-not (Test-Path $backupFile)) {
        $mainStack.Children.Add((New-ViewLabel -Text "История пуста. Файл не найден.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    try {
        $backup = Get-Content $backupFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        $mainStack.Children.Add((New-ViewLabel -Text "Ошибка чтения истории.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    if (-not $backup.Changes -or @($backup.Changes).Count -eq 0) {
        $mainStack.Children.Add((New-ViewLabel -Text "История пуста. Действий не было.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # Загружаем историю в script-скоуп, чтобы Remove-Change работал
    $script:allChanges = @($backup.Changes)

    $changes = @($backup.Changes | Sort-Object Timestamp -Descending)

    Write-Log -Message "Загружено действий: $($changes.Count)" -Level "Info"

    # Информация о файле
    $infoLabel = New-Object System.Windows.Controls.TextBlock
    $infoLabel.Text = "Устройство: $($backup.DeviceIP)   |   Сохранено: $($backup.SavedAt)"
    $infoLabel.FontSize = 11
    $infoLabel.Foreground = "#A0A0A0"
    $infoLabel.Margin = "0,0,0,10"
    $mainStack.Children.Add($infoLabel) | Out-Null

    # ===== СПИСОК ДЕЙСТВИЙ =====
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    $scroll.MaxHeight = 400
    $mainStack.Children.Add($scroll) | Out-Null

    $listStack = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $listStack

    $script:RollbackCheckboxes = @()

    foreach ($change in $changes) {
        # Карточка действия
        $card = New-Object System.Windows.Controls.Border
        $card.Background = "#2B2B2B"
        $card.BorderBrush = "#3A3A3A"
        $card.BorderThickness = "1"
        $card.CornerRadius = "6"
        $card.Padding = "10"
        $card.Margin = "0,0,0,6"

        $cardGrid = New-Object System.Windows.Controls.Grid
        $cc1 = New-Object System.Windows.Controls.ColumnDefinition
        $cc1.Width = "Auto"
        $cc2 = New-Object System.Windows.Controls.ColumnDefinition
        $cc2.Width = "*"
        $cardGrid.ColumnDefinitions.Add($cc1)
        $cardGrid.ColumnDefinitions.Add($cc2)

        # Чекбокс
        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]
        $chk.VerticalAlignment = "Top"
        $chk.Margin = "0,0,10,0"
        $chk.Tag = $change
        [System.Windows.Controls.Grid]::SetColumn($chk, 0)
        $cardGrid.Children.Add($chk) | Out-Null
        $script:RollbackCheckboxes += $chk

        # Текст
        $textStack = New-Object System.Windows.Controls.StackPanel
        [System.Windows.Controls.Grid]::SetColumn($textStack, 1)

        # Тип действия + цель
        $typeLabel = switch ($change.Type) {
            "package_removed"   { "Удалён пакет" }
            "package_disabled"  { "Отключён пакет" }
            "settings_changed"  { "Изменена настройка" }
            "ota_disabled"      { "Отключён OTA" }
            "apk_unlock"        { "Разблокировка APK" }
            "launcher_changed"  { "Изменён лаунчер" }
            default             { $change.Type }
        }

        $titleLabel = New-Object System.Windows.Controls.TextBlock
        $titleLabel.Text = "${typeLabel}: $($change.Target)"
        $titleLabel.FontSize = 13
        $titleLabel.FontWeight = "Bold"
        $titleLabel.Foreground = "#FFFFFF"
        $titleLabel.TextWrapping = "Wrap"
        $textStack.Children.Add($titleLabel) | Out-Null

        # Команда отката
        $cmdLabel = New-Object System.Windows.Controls.TextBlock
        $cmdLabel.Text = $change.RestoreCommand
        $cmdLabel.FontFamily = "Consolas"
        $cmdLabel.FontSize = 11
        $cmdLabel.Foreground = "#C8C8C8"
        $cmdLabel.TextWrapping = "Wrap"
        $cmdLabel.Margin = "0,3,0,3"
        $textStack.Children.Add($cmdLabel) | Out-Null

        # Время
        $timeLabel = New-Object System.Windows.Controls.TextBlock
        $timeLabel.Text = $change.Timestamp
        $timeLabel.FontSize = 11
        $timeLabel.Foreground = "#A0A0A0"
        $textStack.Children.Add($timeLabel) | Out-Null

        $cardGrid.Children.Add($textStack) | Out-Null

        $card.Child = $cardGrid
        $listStack.Children.Add($card) | Out-Null
    }

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    # "Выбрать всё"
    $btnSelectAll = New-Object System.Windows.Controls.Button
    $btnSelectAll.Content = "Выбрать всё"
    $btnSelectAll.Style = $window.Resources["RoundedButton"]
    $btnSelectAll.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnSelectAll.Padding = "12,6"
    $btnSelectAll.Margin = "0,0,8,0"
    $btnSelectAll.Add_Click({
        foreach ($chk in $script:RollbackCheckboxes) { $chk.IsChecked = $true }
    })
    $buttons += $btnSelectAll

    # "Снять всё"
    $btnDeselect = New-Object System.Windows.Controls.Button
    $btnDeselect.Content = "Снять всё"
    $btnDeselect.Style = $window.Resources["RoundedButton"]
    $btnDeselect.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnDeselect.Padding = "12,6"
    $btnDeselect.Margin = "0,0,8,0"
    $btnDeselect.Add_Click({
        foreach ($chk in $script:RollbackCheckboxes) { $chk.IsChecked = $false }
    })
    $buttons += $btnDeselect

    # "Откатить выбранные"
    $btnRollback = New-Object System.Windows.Controls.Button
    $btnRollback.Content = "Откатить выбранные"
    $btnRollback.Style = $window.Resources["RoundedButton"]
    $btnRollback.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnRollback.Padding = "12,6"
    $btnRollback.Margin = "0,0,8,0"
    $btnRollback.Add_Click({
        $selected = @()
        foreach ($chk in $script:RollbackCheckboxes) {
            if ($chk.IsChecked -eq $true) {
                $selected += $chk.Tag
            }
        }
        if ($selected.Count -eq 0) {
            Write-Log -Message "Ничего не выбрано" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Откатить $($selected.Count) изменений?`n`nБудут выполнены команды восстановления.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        # ===== ПРОВЕРКА ПОДКЛЮЧЕНИЯ =====
        Write-Log -Message "Проверяю подключение к ТВ..." -Level "Info"
        $isConnected = Test-TvConnected
        Write-Log -Message "Результат проверки: $isConnected" -Level "Info"

        if (-not $isConnected) {
            Write-Log -Message "ТВ не подключён. Откат отменён." -Level "Error"
            [System.Windows.MessageBox]::Show(
                "Телевизор не подключён.`n`nСначала подключитесь к ТВ в разделе «Настройка», затем повторите откат.",
                "Нет подключения",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        Write-Log -Message "=== Откат $($selected.Count) изменений ===" -Level "Info"
        $success = 0
        foreach ($change in $selected) {
            Write-Log -Message "Откат: $($change.Type) — $($change.Target)" -Level "Info"

            # Убираем "adb " в начале
            $cmd = $change.RestoreCommand -replace '^adb\s+', ''

            # Собираем полную команду и выполняем через cmd /c
            $fullCmd = '"' + $script:adbPath + '" ' + $cmd
            Write-Log -Message "  Выполняю: $fullCmd" -Level "Info"

            $out = cmd /c $fullCmd 2>&1
            $outText = ($out | Out-String).Trim()
            $exitCode = $LASTEXITCODE

            # Проверяем результат — по коду возврата + по выводу
            $isOk = $false

            # 1. Код возврата 0 — команда выполнена
            if ($exitCode -eq 0) {
                $isOk = $true
            }

            # 2. Явные признаки успеха в выводе
            if ($outText -match "Success|new state|installed|enabled") {
                $isOk = $true
            }

            # 3. Явные признаки ошибки в выводе
            if ($outText -match "Failure|Error|Exception|Unknown|not found") {
                $isOk = $false
            }

            # 4. Если вывод пустой И код НЕ 0 — вероятно, ТВ не отвечает
            if (-not $outText -and $exitCode -ne 0) {
                $isOk = $false
                Write-Log -Message "  Пустой вывод и код $exitCode — вероятно, ТВ не отвечает" -Level "Warning"
            }

            if ($isOk) {
                Write-Log -Message "  OK" -Level "Success"
                $success++

                # Удаляем это изменение из истории
                Remove-Change -Type $change.Type -Target $change.Target -Timestamp $change.Timestamp
            } else {
                Write-Log -Message "  FAIL (код $exitCode): $outText" -Level "Error"
            }
        }
        Write-Log -Message "=== Откат завершён: $success из $($selected.Count) ===" -Level "Success"
        Switch-View -ViewName "Rollback"
    })
    $buttons += $btnRollback

    # "Обновить"
    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({
        Switch-View -ViewName "Rollback"
    })
    $buttons += $btnRefresh

    # "Очистить историю"
    $btnClear = New-Object System.Windows.Controls.Button
    $btnClear.Content = "Очистить историю"
    $btnClear.Style = $window.Resources["RoundedButton"]
    $btnClear.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnClear.Padding = "12,6"
    $btnClear.Add_Click({
        $confirm = [System.Windows.MessageBox]::Show(
            "Удалить всю историю действий?`n`nВосстановить её будет невозможно.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            if (Test-Path $backupFile) {
                Remove-Item $backupFile -Force
            }
            $script:allChanges = @()
            Write-Log -Message "История очищена" -Level "Success"
            Switch-View -ViewName "Rollback"
        }
    })
    $buttons += $btnClear

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран истории действий" -Level "Info"
}