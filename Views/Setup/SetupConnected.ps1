function Add-SetupConnectedBlock {
    param([System.Windows.Controls.StackPanel]$Stack)

    # ===== УПРАВЛЕНИЕ =====
    $Stack.Children.Add((New-StepTitle -Text "Управление")) | Out-Null

    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = "*"
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = "*"
    $grid.ColumnDefinitions.Add($c1)
    $grid.ColumnDefinitions.Add($c2)

    $btnPackages = New-ViewButton -Text "Пакеты" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Cleanup"
    }
    $btnPackages.Width = 200
    [System.Windows.Controls.Grid]::SetColumn($btnPackages, 0)
    $grid.Children.Add($btnPackages) | Out-Null

    $btnFiles = New-ViewButton -Text "Файлы" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Files"
    }
    $btnFiles.Width = 200
    [System.Windows.Controls.Grid]::SetColumn($btnFiles, 1)
    $grid.Children.Add($btnFiles) | Out-Null

    $Stack.Children.Add($grid) | Out-Null

    # ===== УСТАНОВКА =====
    $Stack.Children.Add((New-StepTitle -Text "Установка")) | Out-Null

    $btnApk = New-ViewButton -Text "Установить APK" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Apk"
    }
    $Stack.Children.Add($btnApk) | Out-Null

    # ===== ИНСТРУМЕНТЫ (3 колонки, 2 строки) =====
    $Stack.Children.Add((New-StepTitle -Text "Инструменты")) | Out-Null

    $toolsGrid = New-Object System.Windows.Controls.Grid
    for ($i = 0; $i -lt 3; $i++) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = "*"
        $toolsGrid.ColumnDefinitions.Add($col)
    }

    $btnRemote = New-ViewButton -Text "Пульт" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Remote"
    }
    $btnRemote.Width = 130
    [System.Windows.Controls.Grid]::SetColumn($btnRemote, 0)
    $toolsGrid.Children.Add($btnRemote) | Out-Null

    $btnScreenshot = New-ViewButton -Text "Скриншот" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Screenshot"
    }
    $btnScreenshot.Width = 130
    [System.Windows.Controls.Grid]::SetColumn($btnScreenshot, 1)
    $toolsGrid.Children.Add($btnScreenshot) | Out-Null

    $btnInfo = New-ViewButton -Text "Сведения" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Info"
    }
    $btnInfo.Width = 130
    [System.Windows.Controls.Grid]::SetColumn($btnInfo, 2)
    $toolsGrid.Children.Add($btnInfo) | Out-Null

    $Stack.Children.Add($toolsGrid) | Out-Null

    $toolsGrid2 = New-Object System.Windows.Controls.Grid
    $toolsGrid2.Margin = "0,8,0,0"
    for ($i = 0; $i -lt 3; $i++) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = "*"
        $toolsGrid2.ColumnDefinitions.Add($col)
    }

    $btnPower = New-ViewButton -Text "Питание" -ColorType "Danger" -OnClick {
        Switch-View -ViewName "Power"
    }
    $btnPower.Width = 130
    [System.Windows.Controls.Grid]::SetColumn($btnPower, 0)
    $toolsGrid2.Children.Add($btnPower) | Out-Null

    $btnAnim = New-ViewButton -Text "Анимация" -ColorType "Primary" -OnClick {
        Switch-View -ViewName "Animation"
    }
    $btnAnim.Width = 130
    [System.Windows.Controls.Grid]::SetColumn($btnAnim, 1)
    $toolsGrid2.Children.Add($btnAnim) | Out-Null

    $btnDisconnect = New-ViewButton -Text "Отключиться" -ColorType "Neutral" -OnClick {
        Write-Log -Message "Отключаюсь от $($script:deviceIp)..." -Level "Info"
        & $script:adbPath disconnect 2>&1 | Out-Null
        $script:connected = $false
        $script:deviceIp = ""
        Update-StatusBar
        Switch-View -ViewName "Setup"
    }
    $btnDisconnect.Width = 130
    [System.Windows.Controls.Grid]::SetColumn($btnDisconnect, 2)
    $toolsGrid2.Children.Add($btnDisconnect) | Out-Null

    $Stack.Children.Add($toolsGrid2) | Out-Null

    # ===== СИСТЕМА =====
    $Stack.Children.Add((New-StepTitle -Text "Система")) | Out-Null

    $sysGrid = New-Object System.Windows.Controls.Grid
    $sc1 = New-Object System.Windows.Controls.ColumnDefinition
    $sc1.Width = "*"
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition
    $sc2.Width = "*"
    $sysGrid.ColumnDefinitions.Add($sc1)
    $sysGrid.ColumnDefinitions.Add($sc2)

    $otaText = if ($script:OtaDisabled) { "Включить OTA" } else { "Отключить OTA" }
    $btnOta = New-ViewButton -Text $otaText -ColorType "Primary" -OnClick {
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
    $btnOta.Width = 200
    [System.Windows.Controls.Grid]::SetColumn($btnOta, 0)
    $sysGrid.Children.Add($btnOta) | Out-Null

    $btnUnlock = New-ViewButton -Text "Разблокировать APK" -ColorType "Primary" -OnClick {
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
    $btnUnlock.Width = 200
    [System.Windows.Controls.Grid]::SetColumn($btnUnlock, 1)
    $sysGrid.Children.Add($btnUnlock) | Out-Null

    $Stack.Children.Add($sysGrid) | Out-Null
}