function Show-SetupView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "20,12,20,12"

    $header = New-ViewHeader -Text "Настройка телевизора"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        Add-SetupConnectBlock -Stack $mainStack

        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        Write-Log -Message "Экран настройки (не подключено)" -Level "Info"

        if ($script:NeedAutoScan) {
            $script:NeedAutoScan = $false
            Write-Log -Message "Автозапуск сканирования сети..." -Level "Info"
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMilliseconds(400)
            $timer.Add_Tick({
                $timer.Stop()
                try {
                    if (-not $script:connected) { Start-NetworkScan }
                } catch { }
            })
            $timer.Start()
        }

        return
    }

    # =========================================================================
    #  ПОДКЛЮЧЕНО — ВКЛАДКИ
    # =========================================================================
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,8,0,0"

    # =========================================================================
    #  ВКЛАДКА 1: ПРИЛОЖЕНИЯ И ФАЙЛЫ
    # =========================================================================
    $tabApps = New-Object System.Windows.Controls.TabItem
    $tabApps.Header = "Приложения и файлы"
    $tabApps.Style = $window.Resources["MiuiTabItem"]

    $appsPanel = New-Object System.Windows.Controls.StackPanel
    $appsPanel.Margin = "12"

    $appsPanel.Children.Add((New-ViewLabel -Text "Управление приложениями и файлами на телевизоре." -Light)) | Out-Null

    $btn = New-ViewButton -Text "Управление пакетами" -ColorType "Primary" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Cleanup"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $appsPanel.Children.Add($btn) | Out-Null

    $btn = New-ViewButton -Text "Установить APK" -ColorType "Primary" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Apk"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $appsPanel.Children.Add($btn) | Out-Null

    $btn = New-ViewButton -Text "Файловый менеджер" -ColorType "Primary" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Files"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $appsPanel.Children.Add($btn) | Out-Null

    $btn = New-ViewButton -Text "Отключённые приложения" -ColorType "Warning" -Compact -Stretch -OnClick {
        Switch-View -ViewName "DisabledApps"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 0)
    $appsPanel.Children.Add($btn) | Out-Null

    $tabApps.Content = $appsPanel
    $tabControl.Items.Add($tabApps) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 2: ИНСТРУМЕНТЫ
    # =========================================================================
    $tabTools = New-Object System.Windows.Controls.TabItem
    $tabTools.Header = "Инструменты"
    $tabTools.Style = $window.Resources["MiuiTabItem"]

    $toolsPanel = New-Object System.Windows.Controls.StackPanel
    $toolsPanel.Margin = "12"

    $toolsPanel.Children.Add((New-ViewLabel -Text "Дополнительные инструменты." -Light)) | Out-Null

    $btn = New-ViewButton -Text "Пульт" -ColorType "Primary" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Remote"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $toolsPanel.Children.Add($btn) | Out-Null

    $btn = New-ViewButton -Text "Скриншот / запись видео" -ColorType "Primary" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Screenshot"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 0)
    $toolsPanel.Children.Add($btn) | Out-Null

    $tabTools.Content = $toolsPanel
    $tabControl.Items.Add($tabTools) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 3: СИСТЕМА
    # =========================================================================
    $tabSystem = New-Object System.Windows.Controls.TabItem
    $tabSystem.Header = "Система"
    $tabSystem.Style = $window.Resources["MiuiTabItem"]

    $systemPanel = New-Object System.Windows.Controls.StackPanel
    $systemPanel.Margin = "12"

    # ========================================================================
    #  Вспомогательная функция: строка из N кнопок в Grid
    # ========================================================================
    function New-ButtonRow {
        param(
            [array]$Buttons,
            [string]$Margin = "0,0,0,6"
        )

        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = $Margin

        $count = $Buttons.Count

        for ($i = 0; $i -lt $count; $i++) {
            $c = New-Object System.Windows.Controls.ColumnDefinition
            $c.Width = "*"
            $grid.ColumnDefinitions.Add($c)

            if ($i -lt $count - 1) {
                $cGap = New-Object System.Windows.Controls.ColumnDefinition
                $cGap.Width = "6"
                $grid.ColumnDefinitions.Add($cGap)
            }
        }

        $gridCol = 0
        foreach ($b in $Buttons) {
            $btn = New-ViewButton -Text $b.Text -ColorType $b.ColorType -Compact -Stretch -OnClick $b.OnClick
            [System.Windows.Controls.Grid]::SetColumn($btn, $gridCol)
            $grid.Children.Add($btn) | Out-Null

            $gridCol += 2
        }

        return $grid
    }

    # ---------- МОНИТОРИНГ ----------
    $diagHeader = New-Object System.Windows.Controls.TextBlock
    $diagHeader.Text = "Мониторинг"
    $diagHeader.FontSize = 12
    $diagHeader.FontWeight = "Bold"
    $diagHeader.Foreground = "#C8C8C8"
    $diagHeader.Margin = "0,0,0,6"
    $systemPanel.Children.Add($diagHeader) | Out-Null

    $btn = New-ViewButton -Text "Мониторинг ТВ" -ColorType "Primary" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Monitoring"
    }
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $systemPanel.Children.Add($btn) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "Сведения об устройстве"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Info" } }
    ) -Margin "0,0,0,10")) | Out-Null

    # ---------- НАСТРОЙКИ ----------
    $settingsHeader = New-Object System.Windows.Controls.TextBlock
    $settingsHeader.Text = "Настройки"
    $settingsHeader.FontSize = 12
    $settingsHeader.FontWeight = "Bold"
    $settingsHeader.Foreground = "#C8C8C8"
    $settingsHeader.Margin = "0,0,0,6"
    $systemPanel.Children.Add($settingsHeader) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "Разрешение и DPI"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Display" } }
        @{ Text = "Пресеты"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Presets" } }
        @{ Text = "Анимация"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Animation" } }
    ))) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "Wi-Fi"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Wifi" } }
        @{ Text = "Bluetooth"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Bluetooth" } }
    ) -Margin "0,0,0,10")) | Out-Null

    # ---------- СЕРВИС ----------
    $serviceHeader = New-Object System.Windows.Controls.TextBlock
    $serviceHeader.Text = "Сервис"
    $serviceHeader.FontSize = 12
    $serviceHeader.FontWeight = "Bold"
    $serviceHeader.Foreground = "#C8C8C8"
    $serviceHeader.Margin = "0,0,0,6"
    $systemPanel.Children.Add($serviceHeader) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "ADB-команды"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Service" } }
        @{ Text = "Logcat"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Logcat" } }
        @{ Text = "HTTP-сервер"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "HttpServer" } }
    ) -Margin "0,0,0,10")) | Out-Null

    # ---------- ДЕЙСТВИЯ ----------
    $actionsHeader = New-Object System.Windows.Controls.TextBlock
    $actionsHeader.Text = "Действия"
    $actionsHeader.FontSize = 12
    $actionsHeader.FontWeight = "Bold"
    $actionsHeader.Foreground = "#C8C8C8"
    $actionsHeader.Margin = "0,0,0,6"
    $systemPanel.Children.Add($actionsHeader) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "Сценарии"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Scenarios" } }
        @{ Text = "Автозапуск"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Autostart" } }
        @{ Text = "Разрешения"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Permissions" } }
    ))) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "Приложения и лаунчеры"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Apps" } }
    ) -Margin "0,0,0,10")) | Out-Null

    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = "Резервные копии ТВ"; ColorType = "Primary"; OnClick = { Switch-View -ViewName "Snapshots" } }
        @{ Text = "Резервная копия APK"; ColorType = "Primary"; OnClick = {
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = "Выберите папку для сохранения APK"
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $confirm = [System.Windows.MessageBox]::Show(
                    "Скачать все сторонние APK в:`n$($dlg.SelectedPath)?",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                    $result = Backup-AllApks -LocalFolder $dlg.SelectedPath
                    [System.Windows.MessageBox]::Show(
                        "Готово!`n`nУспешно: $($result.Success)`nОшибок: $($result.Failed)",
                        "Результат",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information) | Out-Null
                }
            }
        } }
    ) -Margin "0,0,0,10")) | Out-Null

    # ---------- БЕЗОПАСНОСТЬ И OTA ----------
    $secHeader = New-Object System.Windows.Controls.TextBlock
    $secHeader.Text = "Безопасность и OTA"
    $secHeader.FontSize = 12
    $secHeader.FontWeight = "Bold"
    $secHeader.Foreground = "#C8C8C8"
    $secHeader.Margin = "0,0,0,6"
    $systemPanel.Children.Add($secHeader) | Out-Null

    $otaText = if ($script:OtaDisabled) { "Включить авто-обновления" } else { "Отключить авто-обновления" }
    $systemPanel.Children.Add((New-ButtonRow -Buttons @(
        @{ Text = $otaText; ColorType = "Primary"; OnClick = {
            if (-not $script:OtaDisabled) {
                $confirm = [System.Windows.MessageBox]::Show(
                    "Отключить автоматические обновления системы?",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

                Write-Log -Message "=== Отключение OTA ===" -Level "Info"
                $anyDisabled = $false
                foreach ($item in $script:otaPackages) {
                    if (Disable-Package -Package $item.Package) {
                        $anyDisabled = $true
                        Save-Change -Type "ota_disabled" -Target $item.Package -RestoreCommand "adb shell pm enable $($item.Package)"
                    }
                }
                Save-AllChanges
                if ($anyDisabled) {
                    $script:OtaDisabled = $true
                    Write-Log -Message "OTA отключены." -Level "Success"
                    Switch-View -ViewName "Setup"
                }
            } else {
                $confirm = [System.Windows.MessageBox]::Show(
                    "Включить автоматические обновления системы?",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

                Write-Log -Message "=== Включение OTA ===" -Level "Info"
                $anyEnabled = $false
                foreach ($item in $script:otaPackages) {
                    if (Enable-Package -Package $item.Package) { $anyEnabled = $true }
                }
                if ($anyEnabled) {
                    $script:OtaDisabled = $false
                    Write-Log -Message "OTA включены." -Level "Success"
                    Switch-View -ViewName "Setup"
                }
            }
        } }
        @{ Text = "Разблокировать APK"; ColorType = "Primary"; OnClick = {
            Write-Log -Message "=== Проверка блокировки APK ===" -Level "Info"
            $status = & $script:adbPath shell content query --uri content://com.tcl.providers.config/InstallConfig --projection config_content 2>&1
            if ($status -match '"enable"\s*:\s*"false"') {
                Write-Log -Message "Заблокировано. Применяю разблокировку..." -Level "Warning"
                & $script:adbPath shell setprop persist.TCL.debug.installapk 1 2>&1 | Out-Null
                & $script:adbPath shell setprop persist.tcl.installapk.enable 1 2>&1 | Out-Null
                Write-Log -Message "Разблокировано." -Level "Success"
                Save-Change -Type "apk_unlock" -Target "persist.TCL.debug.installapk" -RestoreCommand "adb shell setprop persist.TCL.debug.installapk 0"
                Save-AllChanges
            } else {
                Write-Log -Message "Не заблокировано." -Level "Success"
            }
        } }
    ) -Margin "0,0,0,10")) | Out-Null

    # ---------- ПИТАНИЕ ----------
    $pwrHeader = New-Object System.Windows.Controls.TextBlock
    $pwrHeader.Text = "Питание"
    $pwrHeader.FontSize = 12
    $pwrHeader.FontWeight = "Bold"
    $pwrHeader.Foreground = "#C8C8C8"
    $pwrHeader.Margin = "0,0,0,6"
    $systemPanel.Children.Add($pwrHeader) | Out-Null

    $btn = New-ViewButton -Text "Питание и перезагрузка" -ColorType "Danger" -Compact -Stretch -OnClick {
        Switch-View -ViewName "Power"
    }
    $systemPanel.Children.Add($btn) | Out-Null

    $tabSystem.Content = $systemPanel
    $tabControl.Items.Add($tabSystem) | Out-Null

    # =========================================================================
    #  ВОССТАНОВЛЕНИЕ АКТИВНОЙ ВКЛАДКИ
    # =========================================================================

    $savedTab = $script:SetupLastTab
    Write-Log -Message "Setup: сохранённое = $savedTab" -Level "Info"

    if ($savedTab -eq $null -or $savedTab -lt 0 -or $savedTab -ge $tabControl.Items.Count) {
        $savedTab = 0
    }

    $tabControl.SelectedIndex = $savedTab
    $script:SetupLastTab = $savedTab

    $mainStack.Children.Add($tabControl) | Out-Null

    $tabControl.Add_SelectionChanged({
        param($sender, $e)
        $idx = $sender.SelectedIndex
        $script:SetupLastTab = $idx
        Write-Log -Message "Setup: переключение на вкладку $idx" -Level "Info"
    })

    # ===== BOTTOM BAR: ОТКЛЮЧИТЬСЯ =====
    $script:BottomBarContent.Children.Clear()

    $btnDisconnect = New-Object System.Windows.Controls.Button
    $btnDisconnect.Content = "Отключиться"
    $btnDisconnect.Style = $window.Resources["BackButton"]
    $btnDisconnect.Padding = "20,8"
    $btnDisconnect.FontSize = 13
    $btnDisconnect.Add_Click({
        Write-Log -Message "Отключаюсь от $($script:deviceIp)..." -Level "Info"
        & $script:adbPath disconnect 2>&1 | Out-Null
        $script:connected = $false
        $script:deviceIp = ""
        Update-StatusBar
        Switch-View -ViewName "Setup"
    })
    $script:BottomBarContent.Children.Add($btnDisconnect) | Out-Null

    $script:BottomBar.Visibility = "Visible"

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран настройки (вкладки)" -Level "Info"
}