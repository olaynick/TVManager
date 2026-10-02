function Show-PowerView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "30,25,30,25"

    $header = New-ViewHeader -Text "Питание и перезагрузка"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # Предупреждение
    $warn = New-Object System.Windows.Controls.Border
    $warn.Background = "#FFF3CD"
    $warn.BorderBrush = "#FFB74D"
    $warn.BorderThickness = "1"
    $warn.CornerRadius = "8"
    $warn.Padding = "12"
    $warn.Margin = "0,0,0,20"

    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = "Внимание: действия на этом экране прерывают работу телевизора. После перезагрузки или выключения соединение по ADB будет разорвано, и его потребуется установить заново."
    $warnText.TextWrapping = "Wrap"
    $warnText.FontSize = 12
    $warnText.Foreground = "#856404"
    $warn.Child = $warnText
    $mainStack.Children.Add($warn) | Out-Null

    # ===== СОН / ПРОБУЖДЕНИЕ =====
    $mainStack.Children.Add((New-StepTitle -Text "Сон")) | Out-Null

    $sleepGrid = New-Object System.Windows.Controls.Grid
    $sg1 = New-Object System.Windows.Controls.ColumnDefinition
    $sg1.Width = "*"
    $sg2 = New-Object System.Windows.Controls.ColumnDefinition
    $sg2.Width = "*"
    $sleepGrid.ColumnDefinitions.Add($sg1)
    $sleepGrid.ColumnDefinitions.Add($sg2)

    $btnSleep = New-Object System.Windows.Controls.Button
    $btnSleep.Content = "Спящий режим"
    $btnSleep.Style = $window.Resources["RoundedButton"]
    $btnSleep.Background = "#607D8B"
    $btnSleep.Height = 50
    $btnSleep.Margin = "0,0,10,0"
    $btnSleep.Add_Click({
        Invoke-Sleep
    })
    [System.Windows.Controls.Grid]::SetColumn($btnSleep, 0)
    $sleepGrid.Children.Add($btnSleep) | Out-Null

    $btnWake = New-Object System.Windows.Controls.Button
    $btnWake.Content = "Пробуждение"
    $btnWake.Style = $window.Resources["RoundedButton"]
    $btnWake.Background = "#66BB6A"
    $btnWake.Height = 50
    $btnWake.Margin = "10,0,0,0"
    $btnWake.Add_Click({
        Invoke-WakeUp
    })
    [System.Windows.Controls.Grid]::SetColumn($btnWake, 1)
    $sleepGrid.Children.Add($btnWake) | Out-Null

    $mainStack.Children.Add($sleepGrid) | Out-Null

    # ===== ПЕРЕЗАГРУЗКА =====
    $mainStack.Children.Add((New-StepTitle -Text "Перезагрузка")) | Out-Null

    $btnReboot = New-Object System.Windows.Controls.Button
    $btnReboot.Content = "Перезагрузить телевизор"
    $btnReboot.Style = $window.Resources["RoundedButton"]
    $btnReboot.Background = "#FFB74D"
    $btnReboot.Height = 50
    $btnReboot.FontSize = 15
    $btnReboot.HorizontalAlignment = "Left"
    $btnReboot.Padding = "20,10"
    $btnReboot.Margin = "0,0,0,10"
    $btnReboot.Add_Click({
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
    })
    $mainStack.Children.Add($btnReboot) | Out-Null

    # ===== ВЫКЛЮЧЕНИЕ =====
    $mainStack.Children.Add((New-StepTitle -Text "Выключение")) | Out-Null

    $btnShutdown = New-Object System.Windows.Controls.Button
    $btnShutdown.Content = "Выключить телевизор"
    $btnShutdown.Style = $window.Resources["RoundedButton"]
    $btnShutdown.Background = "#E57373"
    $btnShutdown.Height = 50
    $btnShutdown.FontSize = 15
    $btnShutdown.HorizontalAlignment = "Left"
    $btnShutdown.Padding = "20,10"
    $btnShutdown.Margin = "0,0,0,10"
    $btnShutdown.Add_Click({
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
    })
    $mainStack.Children.Add($btnShutdown) | Out-Null

    # ===== РАСШИРЕННОЕ =====
    $mainStack.Children.Add((New-StepTitle -Text "Расширенное")) | Out-Null

    $advPanel = New-Object System.Windows.Controls.StackPanel
    $advPanel.Orientation = "Horizontal"

    $btnRecovery = New-Object System.Windows.Controls.Button
    $btnRecovery.Content = "Recovery"
    $btnRecovery.Style = $window.Resources["RoundedButton"]
    $btnRecovery.Background = "#9E9E9E"
    $btnRecovery.Padding = "15,8"
    $btnRecovery.Margin = "0,0,10,0"
    $btnRecovery.Add_Click({
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
    })
    $advPanel.Children.Add($btnRecovery) | Out-Null

    $btnBootloader = New-Object System.Windows.Controls.Button
    $btnBootloader.Content = "Bootloader"
    $btnBootloader.Style = $window.Resources["RoundedButton"]
    $btnBootloader.Background = "#9E9E9E"
    $btnBootloader.Padding = "15,8"
    $btnBootloader.Add_Click({
        $confirm = [System.Windows.MessageBox]::Show(
            "Перезагрузить в Bootloader?`n`nЭто низкоуровневый режим. Используйте, только если знаете, что делаете.`n`nВНИМАНИЕ: выход из Bootloader может потребовать переподключения по USB.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            Invoke-RebootBootloader
            Update-StatusBar
            Switch-View -ViewName "Setup"
        }
    })
    $advPanel.Children.Add($btnBootloader) | Out-Null

    $mainStack.Children.Add($advPanel) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран питания" -Level "Info"
}