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
        return
    }

    # ===== ПОДКЛЮЧЕНО — ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,10,0,0"

    # ===== ВКЛАДКА 1: ПРИЛОЖЕНИЯ И ФАЙЛЫ =====
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

    # ===== ВКЛАДКА 2: ИНСТРУМЕНТЫ =====
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

    # ===== ВКЛАДКА 3: СИСТЕМА =====
    $tabSystem = New-Object System.Windows.Controls.TabItem
    $tabSystem.Header = "Система"
    $tabSystem.Style = $window.Resources["MiuiTabItem"]

    $systemPanel = New-Object System.Windows.Controls.StackPanel
    $systemPanel.Margin = "15"

    $systemPanel.Children.Add((New-ViewLabel -Text "Системные настройки телевизора." -Light)) | Out-Null

    $systemPanel.Children.Add((New-ViewButton -Text "Профили устройств" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Profiles"
    })) | Out-Null

    $systemPanel.Children.Add((New-ViewButton -Text "Logcat (живые логи)" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Logcat"
    })) | Out-Null

   $systemPanel.Children.Add((New-ViewButton -Text "Сервис (ADB-команды)" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Service"
    })) | Out-Null

        $systemPanel.Children.Add((New-ViewButton -Text "Резервная копия APK" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
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
    })) | Out-Null

    # --- OTA ---
    $otaText = if ($script:OtaDisabled) { "Включить автоматические обновления" } else { "Отключить автоматические обновления" }
    $systemPanel.Children.Add((New-ViewButton -Text $otaText -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
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
    })) | Out-Null

    # --- Анимация ---
    $systemPanel.Children.Add((New-ViewButton -Text "Масштаб анимации" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Animation"
    })) | Out-Null

    # --- Разблокировка APK ---
    $systemPanel.Children.Add((New-ViewButton -Text "Разблокировать установку APK" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
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
    })) | Out-Null

    # --- Сведения об устройстве (перенесено) ---
    $systemPanel.Children.Add((New-ViewButton -Text "Сведения об устройстве" -ColorType "Primary" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Info"
    })) | Out-Null

    # --- Питание (перенесено) ---
    $systemPanel.Children.Add((New-ViewButton -Text "Питание и перезагрузка" -ColorType "Danger" -Margin "0,8,0,0" -OnClick {
        Switch-View -ViewName "Power"
    })) | Out-Null

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