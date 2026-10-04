function Show-PowerView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Питание и перезагрузка"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # --- Предупреждение ---
    $warn = New-Object System.Windows.Controls.Border
    $warn.Background = "#2E2A1A"
    $warn.BorderBrush = "#9c8e6a"
    $warn.BorderThickness = "1"
    $warn.CornerRadius = "8"
    $warn.Padding = "12"
    $warn.Margin = "0,0,0,15"

    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = "Внимание: действия на этом экране прерывают работу телевизора. После перезагрузки или выключения соединение по ADB будет разорвано, и его потребуется установить заново."
    $warnText.TextWrapping = "Wrap"
    $warnText.FontSize = 12
    $warnText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $warn.Child = $warnText
    $mainStack.Children.Add($warn) | Out-Null

    # ===== СОН / ПРОБУЖДЕНИЕ =====
    $mainStack.Children.Add((New-StepTitle -Text "Сон")) | Out-Null

    $sleepGrid = New-Object System.Windows.Controls.Grid
    $sg1 = New-Object System.Windows.Controls.ColumnDefinition; $sg1.Width = "*"
    $sg2 = New-Object System.Windows.Controls.ColumnDefinition; $sg2.Width = "8"
    $sg3 = New-Object System.Windows.Controls.ColumnDefinition; $sg3.Width = "*"
    $sleepGrid.ColumnDefinitions.Add($sg1)
    $sleepGrid.ColumnDefinitions.Add($sg2)
    $sleepGrid.ColumnDefinitions.Add($sg3)

    $btnSleep = New-ViewButton -Text "Спящий режим" -ColorType "Neutral" -Compact -Stretch -OnClick {
        Invoke-Sleep
    }
    [System.Windows.Controls.Grid]::SetColumn($btnSleep, 0)
    $sleepGrid.Children.Add($btnSleep) | Out-Null

    $btnWake = New-ViewButton -Text "Пробуждение" -ColorType "Success" -Compact -Stretch -OnClick {
        Invoke-WakeUp
    }
    [System.Windows.Controls.Grid]::SetColumn($btnWake, 2)
    $sleepGrid.Children.Add($btnWake) | Out-Null

    $sleepGrid.Margin = "0,0,0,10"
    $mainStack.Children.Add($sleepGrid) | Out-Null

    # ===== ПЕРЕЗАГРУЗКА =====
    $mainStack.Children.Add((New-StepTitle -Text "Перезагрузка")) | Out-Null

    $btnReboot = New-ViewButton -Text "Перезагрузить телевизор" -ColorType "Warning" -Compact -Stretch -OnClick {
        $confirm = [System.Windows.MessageBox]::Show(
            "Перезагрузить телевизор?`n`nСоединение по ADB будет разорвано. После включения потребуется подключиться заново.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            Invoke-Reboot
            Update-StatusBar
            Switch-View -ViewName "Setup"
        }
    }
    $btnReboot.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $mainStack.Children.Add($btnReboot) | Out-Null

    # ===== ВЫКЛЮЧЕНИЕ =====
    $mainStack.Children.Add((New-StepTitle -Text "Выключение")) | Out-Null

    $btnShutdown = New-ViewButton -Text "Выключить телевизор" -ColorType "Danger" -Compact -Stretch -OnClick {
        $confirm = [System.Windows.MessageBox]::Show(
            "Выключить телевизор?`n`nСоединение по ADB будет разорвано. Включить телевизор можно будет только с пульта или кнопкой на корпусе.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            Invoke-Shutdown
            Update-StatusBar
            Switch-View -ViewName "Setup"
        }
    }
    $btnShutdown.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $mainStack.Children.Add($btnShutdown) | Out-Null

    # ===== РАСШИРЕННОЕ =====
    $mainStack.Children.Add((New-StepTitle -Text "Расширенное")) | Out-Null

    $advGrid = New-Object System.Windows.Controls.Grid
    $ag1 = New-Object System.Windows.Controls.ColumnDefinition; $ag1.Width = "*"
    $ag2 = New-Object System.Windows.Controls.ColumnDefinition; $ag2.Width = "8"
    $ag3 = New-Object System.Windows.Controls.ColumnDefinition; $ag3.Width = "*"
    $advGrid.ColumnDefinitions.Add($ag1)
    $advGrid.ColumnDefinitions.Add($ag2)
    $advGrid.ColumnDefinitions.Add($ag3)

    $btnRecovery = New-ViewButton -Text "Recovery" -ColorType "Neutral" -Compact -Stretch -OnClick {
        $confirm = [System.Windows.MessageBox]::Show(
            "Перезагрузить в режим Recovery?`n`nЭто режим восстановления. Обычное использование ТВ будет недоступно.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            Invoke-RebootRecovery
            Update-StatusBar
            Switch-View -ViewName "Setup"
        }
    }
    [System.Windows.Controls.Grid]::SetColumn($btnRecovery, 0)
    $advGrid.Children.Add($btnRecovery) | Out-Null

    $btnBootloader = New-ViewButton -Text "Bootloader" -ColorType "Neutral" -Compact -Stretch -OnClick {
        $confirm = [System.Windows.MessageBox]::Show(
            "Перезагрузить в Bootloader?`n`nЭто низкоуровневый режим. Используйте, только если знаете, что делаете.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            Invoke-RebootBootloader
            Update-StatusBar
            Switch-View -ViewName "Setup"
        }
    }
    [System.Windows.Controls.Grid]::SetColumn($btnBootloader, 2)
    $advGrid.Children.Add($btnBootloader) | Out-Null

    $mainStack.Children.Add($advGrid) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран питания" -Level "Info"
}