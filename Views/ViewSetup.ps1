function Show-SetupView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Настройка телевизора"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        Add-SetupConnectBlock -Stack $mainStack

        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        Write-Log -Message "Экран настройки (не подключено)" -Level "Info"

        # ===== АВТОЗАПУСК СКАНИРОВАНИЯ =====
        if ($script:NeedAutoScan) {
            $script:NeedAutoScan = $false
            Write-Log -Message "Автозапуск сканирования сети..." -Level "Info"
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMilliseconds(400)
            $timer.Add_Tick({
                $timer.Stop()
                try {
                    if (-not $script:connected) { Start-NetworkScan }
                } catch {
                    Write-Log -Message "Ошибка автозапуска скана: $_" -Level "Warning"
                }
            })
            $timer.Start()
        }

        return
    }

    # ===== ПОДКЛЮЧЕНО — ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,10,0,0"

    # =========================================================================
    #  ВКЛАДКА 1: ПРИЛОЖЕНИЯ И ФАЙЛЫ
    # =========================================================================
    $tabApps = New-Object System.Windows.Controls.TabItem
    $tabApps.Header = "Приложения и файлы"
    $tabApps.Style = $window.Resources["MiuiTabItem"]

    $appsPanel = New-Object System.Windows.Controls.StackPanel
    $appsPanel.Margin = "15"

    $appsPanel.Children.Add((New-ViewLabel -Text "Управление приложениями и файлами на телевизоре." -Light)) | Out-Null

    $appsPanel.Children.Add((New-ViewButton -Text "Управление пакетами" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Cleanup"
    })) | Out-Null

    $appsPanel.Children.Add((New-ViewButton -Text "Установить APK" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Apk"
    })) | Out-Null

    $appsPanel.Children.Add((New-ViewButton -Text "Файловый менеджер" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Files"
    })) | Out-Null

    $appsPanel.Children.Add((New-ViewButton -Text "Отключённые приложения" -ColorType "Warning" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "DisabledApps"
    })) | Out-Null

    $tabApps.Content = $appsPanel
    $tabControl.Items.Add($tabApps) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 2: ИНСТРУМЕНТЫ
    # =========================================================================
    $tabTools = New-Object System.Windows.Controls.TabItem
    $tabTools.Header = "Инструменты"
    $tabTools.Style = $window.Resources["MiuiTabItem"]

    $toolsPanel = New-Object System.Windows.Controls.StackPanel
    $toolsPanel.Margin = "15"

    $toolsPanel.Children.Add((New-ViewLabel -Text "Дополнительные инструменты для работы с телевизором." -Light)) | Out-Null

    $toolsPanel.Children.Add((New-ViewButton -Text "Пульт" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Remote"
    })) | Out-Null

    $toolsPanel.Children.Add((New-ViewButton -Text "Скриншот / запись видео" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Screenshot"
    })) | Out-Null

    $tabTools.Content = $toolsPanel
    $tabControl.Items.Add($tabTools) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 3: СИСТЕМА (кнопки сгруппированы по 2 в ряд)
    # =========================================================================
    $tabSystem = New-Object System.Windows.Controls.TabItem
    $tabSystem.Header = "Система"
    $tabSystem.Style = $window.Resources["MiuiTabItem"]

    $systemPanel = New-Object System.Windows.Controls.StackPanel
    $systemPanel.Margin = "15"

    # ---------- Группа: ДИАГНОСТИКА ----------
    $diagHeader = New-Object System.Windows.Controls.TextBlock
    $diagHeader.Text = "Диагностика"
    $diagHeader.FontSize = 13
    $diagHeader.FontWeight = "Bold"
    $diagHeader.Foreground = "#4A90E2"
    $diagHeader.Margin = "0,0,0,8"
    $systemPanel.Children.Add($diagHeader) | Out-Null

    $gridDiag1 = New-Object System.Windows.Controls.Grid
    $gridDiag1.Margin = "0,0,0,8"
    $dc1 = New-Object System.Windows.Controls.ColumnDefinition; $dc1.Width = "*"
    $dc2 = New-Object System.Windows.Controls.ColumnDefinition; $dc2.Width = "*"
    $gridDiag1.ColumnDefinitions.Add($dc1)
    $gridDiag1.ColumnDefinitions.Add($dc2)

    $btnInfo = New-ViewButton -Text "Сведения об устройстве" -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        Switch-View -ViewName "Info"
    }
    $btnInfo.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnInfo, 0)
    $gridDiag1.Children.Add($btnInfo) | Out-Null

    $btnProcesses = New-ViewButton -Text "Процессы ТВ" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Processes"
    }
    $btnProcesses.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnProcesses, 1)
    $gridDiag1.Children.Add($btnProcesses) | Out-Null

    $systemPanel.Children.Add($gridDiag1) | Out-Null

    $gridDiag2 = New-Object System.Windows.Controls.Grid
    $gridDiag2.Margin = "0,0,0,15"
    $dc3 = New-Object System.Windows.Controls.ColumnDefinition; $dc3.Width = "*"
    $dc4 = New-Object System.Windows.Controls.ColumnDefinition; $dc4.Width = "*"
    $gridDiag2.ColumnDefinitions.Add($dc3)
    $gridDiag2.ColumnDefinitions.Add($dc4)

    $btnExport = New-ViewButton -Text "Экспорт дампа" -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        Show-ExportDeviceDumpDialog
    }
    $btnExport.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnExport, 0)
    $gridDiag2.Children.Add($btnExport) | Out-Null

    $btnIntegrity = New-ViewButton -Text "Проверка целостности" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Integrity"
    }
    $btnIntegrity.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnIntegrity, 1)
    $gridDiag2.Children.Add($btnIntegrity) | Out-Null

    $systemPanel.Children.Add($gridDiag2) | Out-Null

    # ---------- Группа: НАСТРОЙКИ ----------
    $settingsHeader = New-Object System.Windows.Controls.TextBlock
    $settingsHeader.Text = "Настройки"
    $settingsHeader.FontSize = 13
    $settingsHeader.FontWeight = "Bold"
    $settingsHeader.Foreground = "#66BB6A"
    $settingsHeader.Margin = "0,0,0,8"
    $systemPanel.Children.Add($settingsHeader) | Out-Null

    $gridSet1 = New-Object System.Windows.Controls.Grid
    $gridSet1.Margin = "0,0,0,8"
    $sc1 = New-Object System.Windows.Controls.ColumnDefinition; $sc1.Width = "*"
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition; $sc2.Width = "*"
    $gridSet1.ColumnDefinitions.Add($sc1)
    $gridSet1.ColumnDefinitions.Add($sc2)

    $btnDisplay = New-ViewButton -Text "Разрешение и DPI" -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        Switch-View -ViewName "Display"
    }
    $btnDisplay.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnDisplay, 0)
    $gridSet1.Children.Add($btnDisplay) | Out-Null

    $btnPresets = New-ViewButton -Text "Пресеты настроек" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Presets"
    }
    $btnPresets.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnPresets, 1)
    $gridSet1.Children.Add($btnPresets) | Out-Null

    $systemPanel.Children.Add($gridSet1) | Out-Null

    $gridSet2 = New-Object System.Windows.Controls.Grid
    $gridSet2.Margin = "0,0,0,15"
    $sc3 = New-Object System.Windows.Controls.ColumnDefinition; $sc3.Width = "*"
    $sc4 = New-Object System.Windows.Controls.ColumnDefinition; $sc4.Width = "*"
    $gridSet2.ColumnDefinitions.Add($sc3)
    $gridSet2.ColumnDefinitions.Add($sc4)

    $btnAnimation = New-ViewButton -Text "Масштаб анимации" -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        Switch-View -ViewName "Animation"
    }
    $btnAnimation.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnAnimation, 0)
    $gridSet2.Children.Add($btnAnimation) | Out-Null

    $btnWifi = New-ViewButton -Text "Wi-Fi" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Wifi"
    }
    $btnWifi.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnWifi, 1)
    $gridSet2.Children.Add($btnWifi) | Out-Null

    $systemPanel.Children.Add($gridSet2) | Out-Null

    # ---------- Группа: СЕРВИС ----------
    $serviceHeader = New-Object System.Windows.Controls.TextBlock
    $serviceHeader.Text = "Сервис"
    $serviceHeader.FontSize = 13
    $serviceHeader.FontWeight = "Bold"
    $serviceHeader.Foreground = "#9C27B0"
    $serviceHeader.Margin = "0,0,0,8"
    $systemPanel.Children.Add($serviceHeader) | Out-Null

    $gridSrv = New-Object System.Windows.Controls.Grid
    $gridSrv.Margin = "0,0,0,15"
    $vc1 = New-Object System.Windows.Controls.ColumnDefinition; $vc1.Width = "*"
    $vc2 = New-Object System.Windows.Controls.ColumnDefinition; $vc2.Width = "*"
    $gridSrv.ColumnDefinitions.Add($vc1)
    $gridSrv.ColumnDefinitions.Add($vc2)

    $btnService = New-ViewButton -Text "ADB-команды" -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        Switch-View -ViewName "Service"
    }
    $btnService.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnService, 0)
    $gridSrv.Children.Add($btnService) | Out-Null

    $btnLogcat = New-ViewButton -Text "Logcat (логи)" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Logcat"
    }
    $btnLogcat.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnLogcat, 1)
    $gridSrv.Children.Add($btnLogcat) | Out-Null

    $systemPanel.Children.Add($gridSrv) | Out-Null

    # ---------- Группа: ДЕЙСТВИЯ ----------
    $actionsHeader = New-Object System.Windows.Controls.TextBlock
    $actionsHeader.Text = "Действия"
    $actionsHeader.FontSize = 13
    $actionsHeader.FontWeight = "Bold"
    $actionsHeader.Foreground = "#607D8B"
    $actionsHeader.Margin = "0,0,0,8"
    $systemPanel.Children.Add($actionsHeader) | Out-Null

    $gridAct = New-Object System.Windows.Controls.Grid
    $gridAct.Margin = "0,0,0,15"
    $ac1 = New-Object System.Windows.Controls.ColumnDefinition; $ac1.Width = "*"
    $ac2 = New-Object System.Windows.Controls.ColumnDefinition; $ac2.Width = "*"
    $gridAct.ColumnDefinitions.Add($ac1)
    $gridAct.ColumnDefinitions.Add($ac2)

    $btnProfiles = New-ViewButton -Text "Профили устройств" -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        Switch-View -ViewName "Profiles"
    }
    $btnProfiles.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnProfiles, 0)
    $gridAct.Children.Add($btnProfiles) | Out-Null

    $btnBackupApk = New-ViewButton -Text "Резервная копия APK" -ColorType "Primary" -OnClick {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Выберите папку для сохранения APK"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $confirm = [System.Windows.MessageBox]::Show(
                "Скачать все сторонние APK в:`n$($dlg.SelectedPath)?`n`nЭто может занять несколько минут.",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                $result = Backup-AllApks -LocalFolder $dlg.SelectedPath
                [System.Windows.MessageBox]::Show(
                    "Готово!`n`nУспешно: $($result.Success)`nОшибок: $($result.Failed)`n`nПапка: $($dlg.SelectedPath)",
                    "Результат",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information) | Out-Null
            }
        }
    }
    $btnBackupApk.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnBackupApk, 1)
    $gridAct.Children.Add($btnBackupApk) | Out-Null

    $systemPanel.Children.Add($gridAct) | Out-Null

    # ---------- Группа: БЕЗОПАСНОСТЬ И OTA ----------
    $secHeader = New-Object System.Windows.Controls.TextBlock
    $secHeader.Text = "Безопасность и OTA"
    $secHeader.FontSize = 13
    $secHeader.FontWeight = "Bold"
    $secHeader.Foreground = "#E57373"
    $secHeader.Margin = "0,0,0,8"
    $systemPanel.Children.Add($secHeader) | Out-Null

    $gridSec = New-Object System.Windows.Controls.Grid
    $gridSec.Margin = "0,0,0,8"
    $ec1 = New-Object System.Windows.Controls.ColumnDefinition; $ec1.Width = "*"
    $ec2 = New-Object System.Windows.Controls.ColumnDefinition; $ec2.Width = "*"
    $gridSec.ColumnDefinitions.Add($ec1)
    $gridSec.ColumnDefinitions.Add($ec2)

    $otaText = if ($script:OtaDisabled) { "Включить авто-обновления" } else { "Отключить авто-обновления" }
    $btnOta = New-ViewButton -Text $otaText -ColorType "Primary" -Margin "0,0,8,0" -OnClick {
        if (-not $script:OtaDisabled) {
            $confirm = [System.Windows.MessageBox]::Show(
                "Вы действительно хотите отключить автоматические обновления системы?",
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
                "Включить автоматические обновления системы обратно?",
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
    }
    $btnOta.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnOta, 0)
    $gridSec.Children.Add($btnOta) | Out-Null

    $btnUnlock = New-ViewButton -Text "Разблокировать установку APK" -ColorType "Primary" -OnClick {
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
    }
    $btnUnlock.HorizontalAlignment = "Stretch"
    [System.Windows.Controls.Grid]::SetColumn($btnUnlock, 1)
    $gridSec.Children.Add($btnUnlock) | Out-Null

    $systemPanel.Children.Add($gridSec) | Out-Null

    # ---------- Группа: ПИТАНИЕ ----------
    $pwrHeader = New-Object System.Windows.Controls.TextBlock
    $pwrHeader.Text = "Питание"
    $pwrHeader.FontSize = 13
    $pwrHeader.FontWeight = "Bold"
    $pwrHeader.Foreground = "#FFB74D"
    $pwrHeader.Margin = "0,0,0,8"
    $systemPanel.Children.Add($pwrHeader) | Out-Null

    $btnPower = New-ViewButton -Text "Питание и перезагрузка" -ColorType "Danger" -OnClick {
        Switch-View -ViewName "Power"
    }
    $btnPower.HorizontalAlignment = "Stretch"
    $systemPanel.Children.Add($btnPower) | Out-Null

    $tabSystem.Content = $systemPanel
    $tabControl.Items.Add($tabSystem) | Out-Null

    $mainStack.Children.Add($tabControl) | Out-Null

    # ===== BOTTOM BAR: ОТКЛЮЧИТЬСЯ =====
    $script:BottomBarContent.Children.Clear()

    $btnDisconnect = New-Object System.Windows.Controls.Button
    $btnDisconnect.Content = "Отключиться"
    $btnDisconnect.Style = $window.Resources["RoundedButton"]
    $btnDisconnect.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
    )
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