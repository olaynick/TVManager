function Show-RemoteView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,55,25,15"

    $header = New-ViewHeader -Text "Пульт управления"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ИНФО-КАРТОЧКА =====
    $hasAdbKb = Test-AdbKeyboardInstalled

    $infoCard = New-Object System.Windows.Controls.Border
    $infoCard.BorderThickness = "1"
    $infoCard.CornerRadius = "6"
    $infoCard.Padding = "8,6"
    $infoCard.Margin = "0,0,0,10"

    $infoStack = New-Object System.Windows.Controls.StackPanel

    $hotkeyTb = New-Object System.Windows.Controls.TextBlock
    $hotkeyTb.FontSize = 10
    $hotkeyTb.TextWrapping = "Wrap"
    $hotkeyTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $hotkeyTb.Text = "Хоткеи: ↑↓←→ стрелки · Enter OK · Backspace Назад · Esc Домой · Space Play/Pause · +/− громкость · M mute · P питание"
    $infoStack.Children.Add($hotkeyTb) | Out-Null

    $kbTb = New-Object System.Windows.Controls.TextBlock
    $kbTb.FontSize = 10
    $kbTb.TextWrapping = "Wrap"
    $kbTb.Margin = "0,4,0,0"

    if ($hasAdbKb) {
        $kbTb.Text = "✓ ADBKeyboard установлен. Кириллица и эмодзи — через него. Может не работать на некоторых ТВ."
        $kbTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } else {
        $kbTb.Text = "Для кириллицы/эмодзи нужен ADBKeyboard (кнопка ниже). На некоторых TCL не работает."
        $kbTb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
    }
    $infoStack.Children.Add($kbTb) | Out-Null

    if ($hasAdbKb) {
        $infoCard.Background = "#1F3A1F"
        $infoCard.BorderBrush = "#3A5A3A"
    } else {
        $infoCard.Background = "#2E2A1A"
        $infoCard.BorderBrush = "#5A4A2A"
    }
    $infoCard.Child = $infoStack
    $mainStack.Children.Add($infoCard) | Out-Null

    # ===== ХЕЛПЕР: ЗАГОЛОВОК СЕКЦИИ =====
    function New-RemoteSectionTitle {
        param([string]$Text)
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $Text
        $tb.FontSize = 13
        $tb.FontWeight = "SemiBold"
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $tb.Margin = "0,10,0,5"
        return $tb
    }

    # ===== НАВИГАЦИЯ =====
    $mainStack.Children.Add((New-RemoteSectionTitle -Text "Навигация")) | Out-Null

    $topGrid = New-Object System.Windows.Controls.Grid
    $tc1 = New-Object System.Windows.Controls.ColumnDefinition; $tc1.Width = "*"
    $tc2 = New-Object System.Windows.Controls.ColumnDefinition; $tc2.Width = "*"
    $tc3 = New-Object System.Windows.Controls.ColumnDefinition; $tc3.Width = "*"
    $topGrid.ColumnDefinitions.Add($tc1)
    $topGrid.ColumnDefinitions.Add($tc2)
    $topGrid.ColumnDefinitions.Add($tc3)

    $btnBack = New-ViewButton -Text "◄  Назад" -ColorType "Primary" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_BACK" -Description "Назад"
    }
    $btnBack.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnBack, 0)
    $topGrid.Children.Add($btnBack) | Out-Null

    $btnHome = New-ViewButton -Text "⌂  Домой" -ColorType "Success" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_HOME" -Description "Домой"
    }
    $btnHome.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnHome, 1)
    $topGrid.Children.Add($btnHome) | Out-Null

    $btnMenu = New-ViewButton -Text "☰  Меню" -ColorType "Warning" -Compact -Stretch -OnClick {
        Send-MenuKey
    }
    [System.Windows.Controls.Grid]::SetColumn($btnMenu, 2)
    $topGrid.Children.Add($btnMenu) | Out-Null

    $mainStack.Children.Add($topGrid) | Out-Null

    # ===== КРЕСТОВИНА =====
    $mainStack.Children.Add((New-RemoteSectionTitle -Text "Стрелки")) | Out-Null

    $dpadGrid = New-Object System.Windows.Controls.Grid
    $dpadGrid.HorizontalAlignment = "Center"
    $dpadGrid.Width = 240

    for ($r = 0; $r -lt 3; $r++) {
        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = "54"
        $dpadGrid.RowDefinitions.Add($row)
    }
    for ($c = 0; $c -lt 3; $c++) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = "80"
        $dpadGrid.ColumnDefinitions.Add($col)
    }

    $btnUp = New-Object System.Windows.Controls.Button
    $btnUp.Content = "▲"
    $btnUp.Style = $window.Resources["RoundedButton"]
    $btnUp.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnUp.FontSize = 18
    $btnUp.Margin = "2"
    $btnUp.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_UP" -Description "Вверх" })
    [System.Windows.Controls.Grid]::SetRow($btnUp, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnUp, 1)
    $dpadGrid.Children.Add($btnUp) | Out-Null

    $btnLeft = New-Object System.Windows.Controls.Button
    $btnLeft.Content = "◄"
    $btnLeft.Style = $window.Resources["RoundedButton"]
    $btnLeft.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnLeft.FontSize = 18
    $btnLeft.Margin = "2"
    $btnLeft.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_LEFT" -Description "Влево" })
    [System.Windows.Controls.Grid]::SetRow($btnLeft, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnLeft, 0)
    $dpadGrid.Children.Add($btnLeft) | Out-Null

    $btnOk = New-Object System.Windows.Controls.Button
    $btnOk.Content = "OK"
    $btnOk.Style = $window.Resources["RoundedButton"]
    $btnOk.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnOk.FontSize = 15
    $btnOk.FontWeight = "Bold"
    $btnOk.Margin = "2"
    $btnOk.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_CENTER" -Description "ОК" })
    [System.Windows.Controls.Grid]::SetRow($btnOk, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnOk, 1)
    $dpadGrid.Children.Add($btnOk) | Out-Null

    $btnRight = New-Object System.Windows.Controls.Button
    $btnRight.Content = "►"
    $btnRight.Style = $window.Resources["RoundedButton"]
    $btnRight.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnRight.FontSize = 18
    $btnRight.Margin = "2"
    $btnRight.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_RIGHT" -Description "Вправо" })
    [System.Windows.Controls.Grid]::SetRow($btnRight, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnRight, 2)
    $dpadGrid.Children.Add($btnRight) | Out-Null

    $btnDown = New-Object System.Windows.Controls.Button
    $btnDown.Content = "▼"
    $btnDown.Style = $window.Resources["RoundedButton"]
    $btnDown.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnDown.FontSize = 18
    $btnDown.Margin = "2"
    $btnDown.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_DOWN" -Description "Вниз" })
    [System.Windows.Controls.Grid]::SetRow($btnDown, 2)
    [System.Windows.Controls.Grid]::SetColumn($btnDown, 1)
    $dpadGrid.Children.Add($btnDown) | Out-Null

    $mainStack.Children.Add($dpadGrid) | Out-Null

    # ===== ГРОМКОСТЬ =====
    $mainStack.Children.Add((New-RemoteSectionTitle -Text "Громкость")) | Out-Null

    $volGrid = New-Object System.Windows.Controls.Grid
    $vc1 = New-Object System.Windows.Controls.ColumnDefinition; $vc1.Width = "*"
    $vc2 = New-Object System.Windows.Controls.ColumnDefinition; $vc2.Width = "6"
    $vc3 = New-Object System.Windows.Controls.ColumnDefinition; $vc3.Width = "*"
    $vc4 = New-Object System.Windows.Controls.ColumnDefinition; $vc4.Width = "6"
    $vc5 = New-Object System.Windows.Controls.ColumnDefinition; $vc5.Width = "*"
    $volGrid.ColumnDefinitions.Add($vc1)
    $volGrid.ColumnDefinitions.Add($vc2)
    $volGrid.ColumnDefinitions.Add($vc3)
    $volGrid.ColumnDefinitions.Add($vc4)
    $volGrid.ColumnDefinitions.Add($vc5)

    $btnVolDown = New-ViewButton -Text "−  Тише" -ColorType "Warning" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_VOLUME_DOWN" -Description "Тише"
    }
    [System.Windows.Controls.Grid]::SetColumn($btnVolDown, 0)
    $volGrid.Children.Add($btnVolDown) | Out-Null

    $muteText = if ($script:RemoteMuted) { "🔊  Вкл. звук" } else { "🔇  Mute" }
    $muteColor = if ($script:RemoteMuted) { "#588653" } else { "#4A4A4A" }

    $script:RemoteMuteBtn = New-Object System.Windows.Controls.Button
    $script:RemoteMuteBtn.Content = $muteText
    $script:RemoteMuteBtn.Style = $window.Resources["RoundedButton"]
    $script:RemoteMuteBtn.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($muteColor)
    )
    $script:RemoteMuteBtn.Height = 30
    $script:RemoteMuteBtn.FontSize = 11
    $script:RemoteMuteBtn.Padding = "8,4"
    $script:RemoteMuteBtn.Add_Click({
        Send-KeyEvent -KeyCode "KEYCODE_VOLUME_MUTE" -Description "Без звука"
        $script:RemoteMuted = -not $script:RemoteMuted
        if ($script:RemoteMuted) {
            $script:RemoteMuteBtn.Content = "🔊  Вкл. звук"
            $script:RemoteMuteBtn.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
            )
        } else {
            $script:RemoteMuteBtn.Content = "🔇  Mute"
            $script:RemoteMuteBtn.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
            )
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($script:RemoteMuteBtn, 2)
    $volGrid.Children.Add($script:RemoteMuteBtn) | Out-Null

    $btnVolUp = New-ViewButton -Text "+  Громче" -ColorType "Warning" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_VOLUME_UP" -Description "Громче"
    }
    [System.Windows.Controls.Grid]::SetColumn($btnVolUp, 4)
    $volGrid.Children.Add($btnVolUp) | Out-Null

    $mainStack.Children.Add($volGrid) | Out-Null

    # ===== МЕДИА =====
    $mainStack.Children.Add((New-RemoteSectionTitle -Text "Медиа")) | Out-Null

    $mediaGrid = New-Object System.Windows.Controls.Grid
    $mc1 = New-Object System.Windows.Controls.ColumnDefinition; $mc1.Width = "*"
    $mc2 = New-Object System.Windows.Controls.ColumnDefinition; $mc2.Width = "6"
    $mc3 = New-Object System.Windows.Controls.ColumnDefinition; $mc3.Width = "*"
    $mc4 = New-Object System.Windows.Controls.ColumnDefinition; $mc4.Width = "6"
    $mc5 = New-Object System.Windows.Controls.ColumnDefinition; $mc5.Width = "*"
    $mediaGrid.ColumnDefinitions.Add($mc1)
    $mediaGrid.ColumnDefinitions.Add($mc2)
    $mediaGrid.ColumnDefinitions.Add($mc3)
    $mediaGrid.ColumnDefinitions.Add($mc4)
    $mediaGrid.ColumnDefinitions.Add($mc5)

    $btnPrev = New-ViewButton -Text "⏮  Назад" -ColorType "Purple" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PREVIOUS" -Description "Предыдущий"
    }
    [System.Windows.Controls.Grid]::SetColumn($btnPrev, 0)
    $mediaGrid.Children.Add($btnPrev) | Out-Null

    $btnPlay = New-ViewButton -Text "⏯  Пауза" -ColorType "Purple" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PLAY_PAUSE" -Description "Пауза/Играть"
    }
    [System.Windows.Controls.Grid]::SetColumn($btnPlay, 2)
    $mediaGrid.Children.Add($btnPlay) | Out-Null

    $btnNext = New-ViewButton -Text "⏭  Вперёд" -ColorType "Purple" -Compact -Stretch -OnClick {
        Send-KeyEvent -KeyCode "KEYCODE_MEDIA_NEXT" -Description "Следующий"
    }
    [System.Windows.Controls.Grid]::SetColumn($btnNext, 4)
    $mediaGrid.Children.Add($btnNext) | Out-Null

    $mainStack.Children.Add($mediaGrid) | Out-Null

    # ===== ВВОД ТЕКСТА =====
    $mainStack.Children.Add((New-RemoteSectionTitle -Text "Ввод текста")) | Out-Null

    $textPanel = New-Object System.Windows.Controls.StackPanel
    $textPanel.Orientation = "Horizontal"

    $script:RemoteTxtInput = New-Object System.Windows.Controls.TextBox
    $script:RemoteTxtInput.Style = $window.Resources["RoundedTextBox"]
    $script:RemoteTxtInput.Width = 350
    $script:RemoteTxtInput.FontSize = 13
    $script:RemoteTxtInput.MinHeight = 34
    $script:RemoteTxtInput.VerticalContentAlignment = "Center"

    $script:RemoteTxtInput.Add_GotFocus({ $script:RemoteHotkeysEnabled = $false })
    $script:RemoteTxtInput.Add_LostFocus({ $script:RemoteHotkeysEnabled = $true })

    $textPanel.Children.Add($script:RemoteTxtInput) | Out-Null

    $btnSendText = New-ViewButton -Text "Отправить" -ColorType "Success" -Compact -OnClick {
        $text = $script:RemoteTxtInput.Text
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $script:RemoteTxtInput.Text = ""
            Send-Text -Text $text
        }
    }
    $btnSendText.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
    $btnSendText.Height = 30
    $textPanel.Children.Add($btnSendText) | Out-Null

    if ($hasAdbKb) {
        $btnKb = New-ViewButton -Text "ADB KB" -ColorType "Gray" -Compact -OnClick {
            Show-AdbKeyboardDialog
            Switch-View -ViewName "Remote"
        }
        $btnKb.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
        $btnKb.Height = 30
        $textPanel.Children.Add($btnKb) | Out-Null
    } else {
        $btnKb = New-ViewButton -Text "Открыть APK ADB Keyboard" -ColorType "Purple" -Compact -OnClick {
            Show-AdbKeyboardDialog
            Switch-View -ViewName "Remote"
        }
        $btnKb.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
        $btnKb.Height = 30
        $textPanel.Children.Add($btnKb) | Out-Null
    }

    $mainStack.Children.Add($textPanel) | Out-Null

    # ===== РЕГИСТРАЦИЯ ХОТКЕЕВ =====
    $script:RemoteHotkeysEnabled = $true

    $script:RemoteKeyHandler = {
        param($sender, $e)

        if (-not $script:RemoteHotkeysEnabled) { return }
        if (-not $script:connected) { return }

        $focused = [System.Windows.Input.Keyboard]::FocusedElement
        if ($focused -is [System.Windows.Controls.TextBox]) {
            if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
                $text = $focused.Text
                if (-not [string]::IsNullOrWhiteSpace($text)) {
                    $focused.Text = ""
                    Send-Text -Text $text
                }
                $e.Handled = $true
            }
            return
        }

        $handled = $true
        switch ($e.Key) {
            "Up"        { Send-KeyEvent -KeyCode "KEYCODE_DPAD_UP" -Description "Вверх (хоткей)" }
            "Down"      { Send-KeyEvent -KeyCode "KEYCODE_DPAD_DOWN" -Description "Вниз (хоткей)" }
            "Left"      { Send-KeyEvent -KeyCode "KEYCODE_DPAD_LEFT" -Description "Влево (хоткей)" }
            "Right"     { Send-KeyEvent -KeyCode "KEYCODE_DPAD_RIGHT" -Description "Вправо (хоткей)" }
            "Enter"     { Send-KeyEvent -KeyCode "KEYCODE_DPAD_CENTER" -Description "OK (хоткей)" }
            "Back"      { Send-KeyEvent -KeyCode "KEYCODE_BACK" -Description "Назад (хоткей)" }
            "Escape"    { Send-KeyEvent -KeyCode "KEYCODE_HOME" -Description "Домой (хоткей)" }
            "Space"     { Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PLAY_PAUSE" -Description "Плей/Пауза (хоткей)" }
            "Add"       { Send-KeyEvent -KeyCode "KEYCODE_VOLUME_UP" -Description "Громче (хоткей)" }
            "Subtract"  { Send-KeyEvent -KeyCode "KEYCODE_VOLUME_DOWN" -Description "Тише (хоткей)" }
            "OemPlus"   { Send-KeyEvent -KeyCode "KEYCODE_VOLUME_UP" -Description "Громче (хоткей)" }
            "OemMinus"  { Send-KeyEvent -KeyCode "KEYCODE_VOLUME_DOWN" -Description "Тише (хоткей)" }
            "M"         { Send-KeyEvent -KeyCode "KEYCODE_VOLUME_MUTE" -Description "Mute (хоткей)" }
            "P"         { Send-KeyEvent -KeyCode "KEYCODE_POWER" -Description "Питание (хоткей)" }
            "Delete"    { Send-KeyEvent -KeyCode "KEYCODE_DEL" -Description "Delete (хоткей)" }
            default     { $handled = $false }
        }

        if ($handled) { $e.Handled = $true }
    }

    $window.Add_KeyDown($script:RemoteKeyHandler)

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack {
        if ($script:RemoteKeyHandler) {
            try { $window.Remove_KeyDown($script:RemoteKeyHandler) } catch { }
            $script:RemoteKeyHandler = $null
        }
        Switch-View -ViewName "Setup"
    }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран пульта (хоткеи активны)" -Level "Info"
}