function Show-RemoteView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "30,25,30,25"

    $header = New-ViewHeader -Text "Пульт управления"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== НАВИГАЦИЯ =====
    $mainStack.Children.Add((New-StepTitle -Text "Навигация")) | Out-Null

    $topGrid = New-Object System.Windows.Controls.Grid
    $tc1 = New-Object System.Windows.Controls.ColumnDefinition
    $tc1.Width = "*"
    $tc2 = New-Object System.Windows.Controls.ColumnDefinition
    $tc2.Width = "*"
    $tc3 = New-Object System.Windows.Controls.ColumnDefinition
    $tc3.Width = "*"
    $topGrid.ColumnDefinitions.Add($tc1)
    $topGrid.ColumnDefinitions.Add($tc2)
    $topGrid.ColumnDefinitions.Add($tc3)

    $btnBack = New-Object System.Windows.Controls.Button
    $btnBack.Content = "◄  Назад"
    $btnBack.Style = $window.Resources["RoundedButton"]
    $btnBack.Background = "#4A90E2"
    $btnBack.Height = 60
    $btnBack.FontSize = 16
    $btnBack.Margin = "0,0,10,0"
    $btnBack.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_BACK" -Description "Назад" })
    [System.Windows.Controls.Grid]::SetColumn($btnBack, 0)
    $topGrid.Children.Add($btnBack) | Out-Null

    $btnHome = New-Object System.Windows.Controls.Button
    $btnHome.Content = "⌂  Домой"
    $btnHome.Style = $window.Resources["RoundedButton"]
    $btnHome.Background = "#66BB6A"
    $btnHome.Height = 60
    $btnHome.FontSize = 16
    $btnHome.Margin = "0,0,10,0"
    $btnHome.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_HOME" -Description "Домой" })
    [System.Windows.Controls.Grid]::SetColumn($btnHome, 1)
    $topGrid.Children.Add($btnHome) | Out-Null

    $btnMenu = New-Object System.Windows.Controls.Button
    $btnMenu.Content = "☰  Меню"
    $btnMenu.Style = $window.Resources["RoundedButton"]
    $btnMenu.Background = "#FFB74D"
    $btnMenu.Height = 60
    $btnMenu.FontSize = 16
    $btnMenu.Add_Click({ Send-MenuKey })
    [System.Windows.Controls.Grid]::SetColumn($btnMenu, 2)
    $topGrid.Children.Add($btnMenu) | Out-Null

    $mainStack.Children.Add($topGrid) | Out-Null

    # ===== КРЕСТОВИНА =====
    $mainStack.Children.Add((New-StepTitle -Text "Стрелки")) | Out-Null

    $dpadGrid = New-Object System.Windows.Controls.Grid
    $dpadGrid.HorizontalAlignment = "Center"
    $dpadGrid.Width = 300

    for ($r = 0; $r -lt 3; $r++) {
        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = "70"
        $dpadGrid.RowDefinitions.Add($row)
    }
    for ($c = 0; $c -lt 3; $c++) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = "100"
        $dpadGrid.ColumnDefinitions.Add($col)
    }

    $btnUp = New-Object System.Windows.Controls.Button
    $btnUp.Content = "▲"
    $btnUp.Style = $window.Resources["RoundedButton"]
    $btnUp.Background = "#4A90E2"
    $btnUp.FontSize = 22
    $btnUp.Margin = "3"
    $btnUp.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_UP" -Description "Вверх" })
    [System.Windows.Controls.Grid]::SetRow($btnUp, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnUp, 1)
    $dpadGrid.Children.Add($btnUp) | Out-Null

    $btnLeft = New-Object System.Windows.Controls.Button
    $btnLeft.Content = "◄"
    $btnLeft.Style = $window.Resources["RoundedButton"]
    $btnLeft.Background = "#4A90E2"
    $btnLeft.FontSize = 22
    $btnLeft.Margin = "3"
    $btnLeft.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_LEFT" -Description "Влево" })
    [System.Windows.Controls.Grid]::SetRow($btnLeft, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnLeft, 0)
    $dpadGrid.Children.Add($btnLeft) | Out-Null

    $btnOk = New-Object System.Windows.Controls.Button
    $btnOk.Content = "OK"
    $btnOk.Style = $window.Resources["RoundedButton"]
    $btnOk.Background = "#66BB6A"
    $btnOk.FontSize = 18
    $btnOk.FontWeight = "Bold"
    $btnOk.Margin = "3"
    $btnOk.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_CENTER" -Description "ОК" })
    [System.Windows.Controls.Grid]::SetRow($btnOk, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnOk, 1)
    $dpadGrid.Children.Add($btnOk) | Out-Null

    $btnRight = New-Object System.Windows.Controls.Button
    $btnRight.Content = "►"
    $btnRight.Style = $window.Resources["RoundedButton"]
    $btnRight.Background = "#4A90E2"
    $btnRight.FontSize = 22
    $btnRight.Margin = "3"
    $btnRight.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_RIGHT" -Description "Вправо" })
    [System.Windows.Controls.Grid]::SetRow($btnRight, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnRight, 2)
    $dpadGrid.Children.Add($btnRight) | Out-Null

    $btnDown = New-Object System.Windows.Controls.Button
    $btnDown.Content = "▼"
    $btnDown.Style = $window.Resources["RoundedButton"]
    $btnDown.Background = "#4A90E2"
    $btnDown.FontSize = 22
    $btnDown.Margin = "3"
    $btnDown.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_DOWN" -Description "Вниз" })
    [System.Windows.Controls.Grid]::SetRow($btnDown, 2)
    [System.Windows.Controls.Grid]::SetColumn($btnDown, 1)
    $dpadGrid.Children.Add($btnDown) | Out-Null

    $mainStack.Children.Add($dpadGrid) | Out-Null

    # ===== ГРОМКОСТЬ =====
    $mainStack.Children.Add((New-StepTitle -Text "Громкость")) | Out-Null

    $volGrid = New-Object System.Windows.Controls.Grid
    $vc1 = New-Object System.Windows.Controls.ColumnDefinition
    $vc1.Width = "*"
    $vc2 = New-Object System.Windows.Controls.ColumnDefinition
    $vc2.Width = "*"
    $vc3 = New-Object System.Windows.Controls.ColumnDefinition
    $vc3.Width = "*"
    $volGrid.ColumnDefinitions.Add($vc1)
    $volGrid.ColumnDefinitions.Add($vc2)
    $volGrid.ColumnDefinitions.Add($vc3)

    $btnVolDown = New-Object System.Windows.Controls.Button
    $btnVolDown.Content = "−  Тише"
    $btnVolDown.Style = $window.Resources["RoundedButton"]
    $btnVolDown.Background = "#FFB74D"
    $btnVolDown.Height = 55
    $btnVolDown.FontSize = 16
    $btnVolDown.Margin = "0,0,10,0"
    $btnVolDown.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_VOLUME_DOWN" -Description "Тише" })
    [System.Windows.Controls.Grid]::SetColumn($btnVolDown, 0)
    $volGrid.Children.Add($btnVolDown) | Out-Null

    # Mute — toggle
    $muteText = if ($script:RemoteMuted) { "🔊  Включить звук" } else { "🔇  Без звука" }
    $muteColor = if ($script:RemoteMuted) { "#66BB6A" } else { "#9E9E9E" }

    $script:RemoteMuteBtn = New-Object System.Windows.Controls.Button
    $script:RemoteMuteBtn.Content = $muteText
    $script:RemoteMuteBtn.Style = $window.Resources["RoundedButton"]
    $script:RemoteMuteBtn.Background = $muteColor
    $script:RemoteMuteBtn.Height = 55
    $script:RemoteMuteBtn.FontSize = 16
    $script:RemoteMuteBtn.Margin = "0,0,10,0"
    $script:RemoteMuteBtn.Add_Click({
        Send-KeyEvent -KeyCode "KEYCODE_VOLUME_MUTE" -Description "Без звука"
        $script:RemoteMuted = -not $script:RemoteMuted
        if ($script:RemoteMuted) {
            $script:RemoteMuteBtn.Content = "🔊  Включить звук"
            $script:RemoteMuteBtn.Background = "#66BB6A"
        } else {
            $script:RemoteMuteBtn.Content = "🔇  Без звука"
            $script:RemoteMuteBtn.Background = "#9E9E9E"
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($script:RemoteMuteBtn, 1)
    $volGrid.Children.Add($script:RemoteMuteBtn) | Out-Null

    $btnVolUp = New-Object System.Windows.Controls.Button
    $btnVolUp.Content = "+  Громче"
    $btnVolUp.Style = $window.Resources["RoundedButton"]
    $btnVolUp.Background = "#FFB74D"
    $btnVolUp.Height = 55
    $btnVolUp.FontSize = 16
    $btnVolUp.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_VOLUME_UP" -Description "Громче" })
    [System.Windows.Controls.Grid]::SetColumn($btnVolUp, 2)
    $volGrid.Children.Add($btnVolUp) | Out-Null

    $mainStack.Children.Add($volGrid) | Out-Null

    # ===== МЕДИА =====
    $mainStack.Children.Add((New-StepTitle -Text "Медиа")) | Out-Null

    $mediaGrid = New-Object System.Windows.Controls.Grid
    $mc1 = New-Object System.Windows.Controls.ColumnDefinition
    $mc1.Width = "*"
    $mc2 = New-Object System.Windows.Controls.ColumnDefinition
    $mc2.Width = "*"
    $mc3 = New-Object System.Windows.Controls.ColumnDefinition
    $mc3.Width = "*"
    $mediaGrid.ColumnDefinitions.Add($mc1)
    $mediaGrid.ColumnDefinitions.Add($mc2)
    $mediaGrid.ColumnDefinitions.Add($mc3)

    $btnPrev = New-Object System.Windows.Controls.Button
    $btnPrev.Content = "⏮  Предыдущий"
    $btnPrev.Style = $window.Resources["RoundedButton"]
    $btnPrev.Background = "#9C27B0"
    $btnPrev.Height = 55
    $btnPrev.FontSize = 14
    $btnPrev.Margin = "0,0,10,0"
    $btnPrev.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PREVIOUS" -Description "Предыдущий" })
    [System.Windows.Controls.Grid]::SetColumn($btnPrev, 0)
    $mediaGrid.Children.Add($btnPrev) | Out-Null

    $btnPlay = New-Object System.Windows.Controls.Button
    $btnPlay.Content = "⏯  Пауза/Играть"
    $btnPlay.Style = $window.Resources["RoundedButton"]
    $btnPlay.Background = "#9C27B0"
    $btnPlay.Height = 55
    $btnPlay.FontSize = 14
    $btnPlay.Margin = "0,0,10,0"
    $btnPlay.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PLAY_PAUSE" -Description "Пауза/Играть" })
    [System.Windows.Controls.Grid]::SetColumn($btnPlay, 1)
    $mediaGrid.Children.Add($btnPlay) | Out-Null

    $btnNext = New-Object System.Windows.Controls.Button
    $btnNext.Content = "⏭  Следующий"
    $btnNext.Style = $window.Resources["RoundedButton"]
    $btnNext.Background = "#9C27B0"
    $btnNext.Height = 55
    $btnNext.FontSize = 14
    $btnNext.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_MEDIA_NEXT" -Description "Следующий" })
    [System.Windows.Controls.Grid]::SetColumn($btnNext, 2)
    $mediaGrid.Children.Add($btnNext) | Out-Null

    $mainStack.Children.Add($mediaGrid) | Out-Null

    # ===== ВВОД ТЕКСТА =====
    $mainStack.Children.Add((New-StepTitle -Text "Ввод текста")) | Out-Null

    $textHint = New-ViewLabel -Text "Внимание: команда 'input text' не поддерживает кириллицу. Используйте латиницу." -Light
    $textHint.TextWrapping = "Wrap"
    $textHint.Margin = "0,0,0,8"
    $mainStack.Children.Add($textHint) | Out-Null

    $textPanel = New-Object System.Windows.Controls.StackPanel
    $textPanel.Orientation = "Horizontal"

    $script:RemoteTxtInput = New-Object System.Windows.Controls.TextBox
    $script:RemoteTxtInput.Style = $window.Resources["RoundedTextBox"]
    $script:RemoteTxtInput.Width = 400
    $script:RemoteTxtInput.FontSize = 14
    $textPanel.Children.Add($script:RemoteTxtInput) | Out-Null

    $btnSendText = New-Object System.Windows.Controls.Button
    $btnSendText.Content = "Отправить"
    $btnSendText.Style = $window.Resources["RoundedButton"]
    $btnSendText.Background = "#66BB6A"
    $btnSendText.Margin = "10,0,0,0"
    $btnSendText.Padding = "15,8"
    $btnSendText.Add_Click({
        $text = $script:RemoteTxtInput.Text
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            Send-Text -Text $text
            $script:RemoteTxtInput.Text = ""
        }
    })
    $textPanel.Children.Add($btnSendText) | Out-Null

    $mainStack.Children.Add($textPanel) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран пульта" -Level "Info"
}