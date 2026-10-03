function Show-RemoteView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,15,25,15"

    $header = New-ViewHeader -Text "Пульт управления"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ОБЪЕДИНЁННАЯ ИНФО-КАРТОЧКА (хоткеи + ADBKeyboard) =====
    $hasAdbKb = Test-AdbKeyboardInstalled

    $infoCard = New-Object System.Windows.Controls.Border
    $infoCard.BorderThickness = "1"
    $infoCard.CornerRadius = "6"
    $infoCard.Padding = "8,6"
    $infoCard.Margin = "0,0,0,10"

    $infoStack = New-Object System.Windows.Controls.StackPanel

    # Строка 1: хоткеи
    $hotkeyTb = New-Object System.Windows.Controls.TextBlock
    $hotkeyTb.FontSize = 10
    $hotkeyTb.TextWrapping = "Wrap"
    $hotkeyTb.Text = "Хоткеи: ↑↓←→ стрелки · Enter OK · Backspace Назад · Esc Домой · Space Play/Pause · +/− громкость · M mute · P питание"
    $infoStack.Children.Add($hotkeyTb) | Out-Null

    # Строка 2: статус ADBKeyboard
    $kbTb = New-Object System.Windows.Controls.TextBlock
    $kbTb.FontSize = 10
    $kbTb.TextWrapping = "Wrap"
    $kbTb.Margin = "0,4,0,0"

    if ($hasAdbKb) {
        $kbTb.Text = "✓ ADBKeyboard установлен. Кириллица и эмодзи — через него. Может не работать на некоторых ТВ."
        $kbTb.Foreground = "#2E7D32"
    } else {
        $kbTb.Text = "Для кириллицы/эмодзи нужен ADBKeyboard (кнопка ниже). На некоторых TCL не работает."
        $kbTb.Foreground = "#856404"
    }
    $infoStack.Children.Add($kbTb) | Out-Null

    if ($hasAdbKb) {
        $infoCard.Background = "#1F3A1F"
        $infoCard.BorderBrush = "#C8C8C8"
    } else {
        $infoCard.Background = "#2E2A1A"
        $infoCard.BorderBrush = "#C8C8C8"
    }
    $infoCard.Child = $infoStack
    $mainStack.Children.Add($infoCard) | Out-Null

    # ===== НАВИГАЦИЯ =====
    $navTitle = New-Object System.Windows.Controls.TextBlock
    $navTitle.Text = "Навигация"
    $navTitle.FontSize = 13
    $navTitle.FontWeight = "SemiBold"
    $navTitle.Margin = "0,5,0,5"
    $mainStack.Children.Add($navTitle) | Out-Null

    $topGrid = New-Object System.Windows.Controls.Grid
    $tc1 = New-Object System.Windows.Controls.ColumnDefinition; $tc1.Width = "*"
    $tc2 = New-Object System.Windows.Controls.ColumnDefinition; $tc2.Width = "*"
    $tc3 = New-Object System.Windows.Controls.ColumnDefinition; $tc3.Width = "*"
    $topGrid.ColumnDefinitions.Add($tc1)
    $topGrid.ColumnDefinitions.Add($tc2)
    $topGrid.ColumnDefinitions.Add($tc3)

    $btnBack = New-Object System.Windows.Controls.Button
    $btnBack.Content = "◄  Назад"
    $btnBack.Style = $window.Resources["RoundedButton"]
    $btnBack.Background = "#4A4A4A"
    $btnBack.Height = 48
    $btnBack.FontSize = 14
    $btnBack.Margin = "0,0,8,0"
    $btnBack.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_BACK" -Description "Назад" })
    [System.Windows.Controls.Grid]::SetColumn($btnBack, 0)
    $topGrid.Children.Add($btnBack) | Out-Null

    $btnHome = New-Object System.Windows.Controls.Button
    $btnHome.Content = "⌂  Домой"
    $btnHome.Style = $window.Resources["RoundedButton"]
    $btnHome.Background = "#4A4A4A"
    $btnHome.Height = 48
    $btnHome.FontSize = 14
    $btnHome.Margin = "0,0,8,0"
    $btnHome.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_HOME" -Description "Домой" })
    [System.Windows.Controls.Grid]::SetColumn($btnHome, 1)
    $topGrid.Children.Add($btnHome) | Out-Null

    $btnMenu = New-Object System.Windows.Controls.Button
    $btnMenu.Content = "☰  Меню"
    $btnMenu.Style = $window.Resources["RoundedButton"]
    $btnMenu.Background = "#4A4A4A"
    $btnMenu.Height = 48
    $btnMenu.FontSize = 14
    $btnMenu.Add_Click({ Send-MenuKey })
    [System.Windows.Controls.Grid]::SetColumn($btnMenu, 2)
    $topGrid.Children.Add($btnMenu) | Out-Null

    $mainStack.Children.Add($topGrid) | Out-Null

    # ===== КРЕСТОВИНА =====
    $dpadTitle = New-Object System.Windows.Controls.TextBlock
    $dpadTitle.Text = "Стрелки"
    $dpadTitle.FontSize = 13
    $dpadTitle.FontWeight = "SemiBold"
    $dpadTitle.Margin = "0,10,0,5"
    $mainStack.Children.Add($dpadTitle) | Out-Null

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
    $btnUp.Background = "#4A4A4A"
    $btnUp.FontSize = 18
    $btnUp.Margin = "2"
    $btnUp.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_UP" -Description "Вверх" })
    [System.Windows.Controls.Grid]::SetRow($btnUp, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnUp, 1)
    $dpadGrid.Children.Add($btnUp) | Out-Null

    $btnLeft = New-Object System.Windows.Controls.Button
    $btnLeft.Content = "◄"
    $btnLeft.Style = $window.Resources["RoundedButton"]
    $btnLeft.Background = "#4A4A4A"
    $btnLeft.FontSize = 18
    $btnLeft.Margin = "2"
    $btnLeft.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_LEFT" -Description "Влево" })
    [System.Windows.Controls.Grid]::SetRow($btnLeft, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnLeft, 0)
    $dpadGrid.Children.Add($btnLeft) | Out-Null

    $btnOk = New-Object System.Windows.Controls.Button
    $btnOk.Content = "OK"
    $btnOk.Style = $window.Resources["RoundedButton"]
    $btnOk.Background = "#4A4A4A"
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
    $btnRight.Background = "#4A4A4A"
    $btnRight.FontSize = 18
    $btnRight.Margin = "2"
    $btnRight.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_RIGHT" -Description "Вправо" })
    [System.Windows.Controls.Grid]::SetRow($btnRight, 1)
    [System.Windows.Controls.Grid]::SetColumn($btnRight, 2)
    $dpadGrid.Children.Add($btnRight) | Out-Null

    $btnDown = New-Object System.Windows.Controls.Button
    $btnDown.Content = "▼"
    $btnDown.Style = $window.Resources["RoundedButton"]
    $btnDown.Background = "#4A4A4A"
    $btnDown.FontSize = 18
    $btnDown.Margin = "2"
    $btnDown.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_DPAD_DOWN" -Description "Вниз" })
    [System.Windows.Controls.Grid]::SetRow($btnDown, 2)
    [System.Windows.Controls.Grid]::SetColumn($btnDown, 1)
    $dpadGrid.Children.Add($btnDown) | Out-Null

    $mainStack.Children.Add($dpadGrid) | Out-Null

    # ===== ГРОМКОСТЬ =====
    $volTitle = New-Object System.Windows.Controls.TextBlock
    $volTitle.Text = "Громкость"
    $volTitle.FontSize = 13
    $volTitle.FontWeight = "SemiBold"
    $volTitle.Margin = "0,10,0,5"
    $mainStack.Children.Add($volTitle) | Out-Null

    $volGrid = New-Object System.Windows.Controls.Grid
    $vc1 = New-Object System.Windows.Controls.ColumnDefinition; $vc1.Width = "*"
    $vc2 = New-Object System.Windows.Controls.ColumnDefinition; $vc2.Width = "*"
    $vc3 = New-Object System.Windows.Controls.ColumnDefinition; $vc3.Width = "*"
    $volGrid.ColumnDefinitions.Add($vc1)
    $volGrid.ColumnDefinitions.Add($vc2)
    $volGrid.ColumnDefinitions.Add($vc3)

    $btnVolDown = New-Object System.Windows.Controls.Button
    $btnVolDown.Content = "−  Тише"
    $btnVolDown.Style = $window.Resources["RoundedButton"]
    $btnVolDown.Background = "#4A4A4A"
    $btnVolDown.Height = 46
    $btnVolDown.FontSize = 14
    $btnVolDown.Margin = "0,0,8,0"
    $btnVolDown.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_VOLUME_DOWN" -Description "Тише" })
    [System.Windows.Controls.Grid]::SetColumn($btnVolDown, 0)
    $volGrid.Children.Add($btnVolDown) | Out-Null

    $muteText = if ($script:RemoteMuted) { "🔊  Вкл. звук" } else { "🔇  Mute" }
    $muteColor = if ($script:RemoteMuted) { "#C8C8C8" } else { "#9E9E9E" }

    $script:RemoteMuteBtn = New-Object System.Windows.Controls.Button
    $script:RemoteMuteBtn.Content = $muteText
    $script:RemoteMuteBtn.Style = $window.Resources["RoundedButton"]
    $script:RemoteMuteBtn.Background = $muteColor
    $script:RemoteMuteBtn.Height = 46
    $script:RemoteMuteBtn.FontSize = 14
    $script:RemoteMuteBtn.Margin = "0,0,8,0"
    $script:RemoteMuteBtn.Add_Click({
        Send-KeyEvent -KeyCode "KEYCODE_VOLUME_MUTE" -Description "Без звука"
        $script:RemoteMuted = -not $script:RemoteMuted
        if ($script:RemoteMuted) {
            $script:RemoteMuteBtn.Content = "🔊  Вкл. звук"
            $script:RemoteMuteBtn.Background = "#4A4A4A"
        } else {
            $script:RemoteMuteBtn.Content = "🔇  Mute"
            $script:RemoteMuteBtn.Background = "#9E9E9E"
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($script:RemoteMuteBtn, 1)
    $volGrid.Children.Add($script:RemoteMuteBtn) | Out-Null

    $btnVolUp = New-Object System.Windows.Controls.Button
    $btnVolUp.Content = "+  Громче"
    $btnVolUp.Style = $window.Resources["RoundedButton"]
    $btnVolUp.Background = "#4A4A4A"
    $btnVolUp.Height = 46
    $btnVolUp.FontSize = 14
    $btnVolUp.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_VOLUME_UP" -Description "Громче" })
    [System.Windows.Controls.Grid]::SetColumn($btnVolUp, 2)
    $volGrid.Children.Add($btnVolUp) | Out-Null

    $mainStack.Children.Add($volGrid) | Out-Null

    # ===== МЕДИА =====
    $mediaTitle = New-Object System.Windows.Controls.TextBlock
    $mediaTitle.Text = "Медиа"
    $mediaTitle.FontSize = 13
    $mediaTitle.FontWeight = "SemiBold"
    $mediaTitle.Margin = "0,10,0,5"
    $mainStack.Children.Add($mediaTitle) | Out-Null

    $mediaGrid = New-Object System.Windows.Controls.Grid
    $mc1 = New-Object System.Windows.Controls.ColumnDefinition; $mc1.Width = "*"
    $mc2 = New-Object System.Windows.Controls.ColumnDefinition; $mc2.Width = "*"
    $mc3 = New-Object System.Windows.Controls.ColumnDefinition; $mc3.Width = "*"
    $mediaGrid.ColumnDefinitions.Add($mc1)
    $mediaGrid.ColumnDefinitions.Add($mc2)
    $mediaGrid.ColumnDefinitions.Add($mc3)

    $btnPrev = New-Object System.Windows.Controls.Button
    $btnPrev.Content = "⏮  Назад"
    $btnPrev.Style = $window.Resources["RoundedButton"]
    $btnPrev.Background = "#4A4A4A"
    $btnPrev.Height = 46
    $btnPrev.FontSize = 13
    $btnPrev.Margin = "0,0,8,0"
    $btnPrev.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PREVIOUS" -Description "Предыдущий" })
    [System.Windows.Controls.Grid]::SetColumn($btnPrev, 0)
    $mediaGrid.Children.Add($btnPrev) | Out-Null

    $btnPlay = New-Object System.Windows.Controls.Button
    $btnPlay.Content = "⏯  Пауза"
    $btnPlay.Style = $window.Resources["RoundedButton"]
    $btnPlay.Background = "#4A4A4A"
    $btnPlay.Height = 46
    $btnPlay.FontSize = 13
    $btnPlay.Margin = "0,0,8,0"
    $btnPlay.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_MEDIA_PLAY_PAUSE" -Description "Пауза/Играть" })
    [System.Windows.Controls.Grid]::SetColumn($btnPlay, 1)
    $mediaGrid.Children.Add($btnPlay) | Out-Null

    $btnNext = New-Object System.Windows.Controls.Button
    $btnNext.Content = "⏭  Вперёд"
    $btnNext.Style = $window.Resources["RoundedButton"]
    $btnNext.Background = "#4A4A4A"
    $btnNext.Height = 46
    $btnNext.FontSize = 13
    $btnNext.Add_Click({ Send-KeyEvent -KeyCode "KEYCODE_MEDIA_NEXT" -Description "Следующий" })
    [System.Windows.Controls.Grid]::SetColumn($btnNext, 2)
    $mediaGrid.Children.Add($btnNext) | Out-Null

    $mainStack.Children.Add($mediaGrid) | Out-Null

     # ===== ВВОД ТЕКСТА =====
    $textTitle = New-Object System.Windows.Controls.TextBlock
    $textTitle.Text = "Ввод текста"
    $textTitle.FontSize = 13
    $textTitle.FontWeight = "SemiBold"
    $textTitle.Margin = "0,10,0,5"
    $mainStack.Children.Add($textTitle) | Out-Null

    $textPanel = New-Object System.Windows.Controls.StackPanel
    $textPanel.Orientation = "Horizontal"

    $script:RemoteTxtInput = New-Object System.Windows.Controls.TextBox
    $script:RemoteTxtInput.Style = $window.Resources["RoundedTextBox"]
    $script:RemoteTxtInput.Width = 380
    $script:RemoteTxtInput.FontSize = 13
    $script:RemoteTxtInput.MinHeight = 34
    $script:RemoteTxtInput.VerticalContentAlignment = "Center"

    # Клик по TextBox — снимаем фокус с кнопок и переводим в поле
    $script:RemoteTxtInput.Add_GotFocus({
        $script:RemoteHotkeysEnabled = $false
    })
    $script:RemoteTxtInput.Add_LostFocus({
        $script:RemoteHotkeysEnabled = $true
    })

    $textPanel.Children.Add($script:RemoteTxtInput) | Out-Null

    $btnSendText = New-Object System.Windows.Controls.Button
    $btnSendText.Content = "Отправить"
    $btnSendText.Style = $window.Resources["RoundedButton"]
    $btnSendText.Background = "#4A4A4A"
    $btnSendText.Height = 34
    $btnSendText.Margin = "8,0,0,0"
    $btnSendText.Padding = "14,4"
    $btnSendText.FontSize = 13
    $btnSendText.Add_Click({
        $text = $script:RemoteTxtInput.Text
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $script:RemoteTxtInput.Text = ""
            Send-Text -Text $text
        }
    })
    $textPanel.Children.Add($btnSendText) | Out-Null

    # Кнопка ADBKeyboard в той же строке
    if ($hasAdbKb) {
        $btnKb = New-Object System.Windows.Controls.Button
        $btnKb.Content = "ADB KB"
        $btnKb.Style = $window.Resources["RoundedButton"]
        $btnKb.Background = "#4A4A4A"
        $btnKb.Height = 34
        $btnKb.Margin = "8,0,0,0"
        $btnKb.Padding = "12,4"
        $btnKb.FontSize = 12
        $btnKb.Add_Click({
            Show-AdbKeyboardDialog
            Switch-View -ViewName "Remote"
        })
        $textPanel.Children.Add($btnKb) | Out-Null
    } else {
        $btnKb = New-Object System.Windows.Controls.Button
        $btnKb.Content = "Открыть APK ADB Keyboard"
        $btnKb.Style = $window.Resources["RoundedButton"]
        $btnKb.Background = "#4A4A4A"
        $btnKb.Height = 34
        $btnKb.Margin = "8,0,0,0"
        $btnKb.Padding = "12,4"
        $btnKb.FontSize = 12
        $btnKb.Add_Click({
            Show-AdbKeyboardDialog
            Switch-View -ViewName "Remote"
        })
        $textPanel.Children.Add($btnKb) | Out-Null
    }

    $mainStack.Children.Add($textPanel) | Out-Null

        # ========================================================================
    #  РЕГИСТРАЦИЯ ХОТКЕЕВ
    # ========================================================================
    $script:RemoteHotkeysEnabled = $true

    $script:RemoteKeyHandler = {
        param($sender, $e)

        if (-not $script:RemoteHotkeysEnabled) { return }
        if (-not $script:connected) { return }

        # ВАЖНО: если фокус в TextBox — не перехватываем клавиши!
        $focused = [System.Windows.Input.Keyboard]::FocusedElement
        if ($focused -is [System.Windows.Controls.TextBox]) {
            # Enter — отправляем текст
            if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
                $text = $focused.Text
                if (-not [string]::IsNullOrWhiteSpace($text)) {
                    $focused.Text = ""
                    Send-Text -Text $text
                }
                $e.Handled = $true
            }
            # Остальные клавиши — пусть обрабатывает TextBox
            return
        }

        $key = $e.Key
        $handled = $true

        switch ($key) {
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

    # ========================================================================
    #  ROOT
    # ========================================================================
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