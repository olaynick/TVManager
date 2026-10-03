# ============================================================================
#  ADBKeyboard — вспомогательная клавиатура для передачи текста
#  с ПК на ТВ (включая кириллицу).
#  Пакет: com.android.adbkeyboard
# ============================================================================

$script:AdbKeyboardPackage   = "com.android.adbkeyboard"
$script:AdbKeyboardIme       = "com.android.adbkeyboard/.AdbIME"
$script:AdbKeyboardAvailable = $null  # $null = не проверяли, $true/$false = знаем

# ===== ПРОВЕРКА УСТАНОВКИ =====
function Test-AdbKeyboardInstalled {
    param([switch]$Force)

    if ($null -ne $script:AdbKeyboardAvailable -and -not $Force) {
        return $script:AdbKeyboardAvailable
    }

    if (-not $script:connected) {
        return $false
    }

    try {
        $pkgList = & $script:adbPath shell pm list packages 2>&1
        $installed = ($pkgList | Out-String) -match [regex]::Escape($script:AdbKeyboardPackage)
        $script:AdbKeyboardAvailable = $installed
        if ($installed) {
            Write-Log -Message "ADBKeyboard установлен" -Level "Info"
        } else {
            Write-Log -Message "ADBKeyboard не установлен" -Level "Info"
        }
        return $installed
    } catch {
        Write-Log -Message "Ошибка проверки ADBKeyboard: $_" -Level "Warning"
        return $false
    }
}

# ===== ПРОВЕРКА АКТИВНОСТИ КАК IME =====
function Test-AdbKeyboardEnabled {
    if (-not $script:connected) { return $false }

    try {
        $imeList = & $script:adbPath shell ime list -s 2>&1
        return (($imeList | Out-String) -match [regex]::Escape($script:AdbKeyboardIme))
    } catch {
        return $false
    }
}

# ===== ВКЛЮЧЕНИЕ IME (если установлен, но не включён) =====
function Enable-AdbKeyboard {
    if (-not $script:connected) { return $false }

    Write-Log -Message "Включаю ADBKeyboard в списке IME..." -Level "Info"
    try {
        $out = & $script:adbPath shell ime enable $script:AdbKeyboardIme 2>&1
        $outText = ($out | Out-String).Trim()
        if ($outText -match 'error|Error|Exception') {
            Write-Log -Message "Ошибка включения: $outText" -Level "Error"
            return $false
        }
        Write-Log -Message "ADBKeyboard включён в списке IME" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка: $_" -Level "Error"
        return $false
    }
}

# ===== УСТАНОВКА APK =====
function Install-AdbKeyboard {
    param([string]$ApkPath)

    if (-not (Test-Path $ApkPath)) {
        Write-Log -Message "APK не найден: $ApkPath" -Level "Error"
        return $false
    }

    Write-Log -Message "Устанавливаю ADBKeyboard: $ApkPath" -Level "Info"
    try {
        $out = & $script:adbPath install -r $ApkPath 2>&1
        $outText = ($out | Out-String).Trim()

        if ($outText -match "Success") {
            Write-Log -Message "ADBKeyboard установлен" -Level "Success"
            $script:AdbKeyboardAvailable = $true
            # Включаем как IME сразу
            Start-Sleep -Seconds 1
            Enable-AdbKeyboard | Out-Null
            return $true
        } else {
            Write-Log -Message "Ошибка установки: $outText" -Level "Error"
            return $false
        }
    } catch {
        Write-Log -Message "Ошибка установки: $_" -Level "Error"
        return $false
    }
}

# ===== ДИАЛОГ: ОТКРЫТЬ APK ADBKEYBOARD =====
function Show-AdbKeyboardDialog {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = "ADBKeyboard — ввод кириллицы"
    $dialog.Width = 620
    $dialog.Height = 500
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#F7F7FA"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "20"

    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = "Auto"
    $grid.RowDefinitions.Add($row1)

    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = "*"
    $grid.RowDefinitions.Add($row2)

    $row3 = New-Object System.Windows.Controls.RowDefinition
    $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row3)

    # --- Заголовок ---
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "ADBKeyboard для ввода кириллицы"
    $title.FontSize = 20
    $title.FontWeight = "Bold"
    $title.Foreground = "#2D2D30"
    $title.Margin = "0,0,0,15"
    [System.Windows.Controls.Grid]::SetRow($title, 0)
    $grid.Children.Add($title) | Out-Null

    # --- Контент ---
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $content = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $content

    # Что это
    $aboutHeader = New-Object System.Windows.Controls.TextBlock
    $aboutHeader.Text = "Что это такое?"
    $aboutHeader.FontSize = 14
    $aboutHeader.FontWeight = "Bold"
    $aboutHeader.Foreground = "#4A90E2"
    $aboutHeader.Margin = "0,0,0,8"
    $content.Children.Add($aboutHeader) | Out-Null

    $aboutText = New-Object System.Windows.Controls.TextBlock
    $aboutText.Text = "ADBKeyboard — вспомогательная клавиатура для передачи текста с ПК на ТВ (включая кириллицу и эмодзи). Она не заменяет вашу обычную клавиатуру — работает в фоне.`n`nВАЖНО: на некоторых прошивках TCL (и некоторых других Android TV) система блокирует ввод через ADBKeyboard. В этом случае текст не будет появляться в поле, даже если установка прошла успешно. Это ограничение прошивки, а не приложения.`n`nЕсли после установки текст не вводится — используйте латиницу или пульт ТВ."
    $aboutText.FontSize = 12
    $aboutText.Foreground = "#2D2D30"
    $aboutText.TextWrapping = "Wrap"
    $aboutText.Margin = "0,0,0,15"
    $content.Children.Add($aboutText) | Out-Null

    # Как установить
    $howHeader = New-Object System.Windows.Controls.TextBlock
    $howHeader.Text = "Как установить"
    $howHeader.FontSize = 14
    $howHeader.FontWeight = "Bold"
    $howHeader.Foreground = "#66BB6A"
    $howHeader.Margin = "0,0,0,8"
    $content.Children.Add($howHeader) | Out-Null

    $steps = @(
        "1. Скачайте ADBKeyboard.apk со страницы релизов на GitHub",
        "2. В этом окне нажмите «Установить APK» — выберите скачанный файл",
        "3. Приложение установит клавиатуру и автоматически включит её в списке IME",
        "4. Вернитесь на экран Пульт — теперь кириллица будет работать"
    )
    foreach ($step in $steps) {
        $stepTb = New-Object System.Windows.Controls.TextBlock
        $stepTb.Text = $step
        $stepTb.FontSize = 12
        $stepTb.Foreground = "#2D2D30"
        $stepTb.TextWrapping = "Wrap"
        $stepTb.Margin = "0,4,0,4"
        $content.Children.Add($stepTb) | Out-Null
    }

    $content.Children.Add((New-ViewLabel -Text "Открыть страницу загрузки:" -Light)) | Out-Null

    # --- Кнопка "Открыть страницу GitHub" ---
    $btnGithub = New-Object System.Windows.Controls.Button
    $btnGithub.Content = "Открыть страницу ADBKeyboard на GitHub"
    $btnGithub.Style = $window.Resources["RoundedButton"]
    $btnGithub.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnGithub.Padding = "15,8"
    $btnGithub.HorizontalAlignment = "Left"
    $btnGithub.Margin = "0,0,0,15"
    $btnGithub.Add_Click({
        Start-Process "https://github.com/senzhk/ADBKeyBoard"
    })
    $content.Children.Add($btnGithub) | Out-Null

    # --- Статус (установлен / не установлен) ---
    $isInstalled = Test-AdbKeyboardInstalled -Force
    $isEnabled = $false
    if ($isInstalled) {
        $isEnabled = Test-AdbKeyboardEnabled
    }

    $statusHeader = New-Object System.Windows.Controls.TextBlock
    $statusHeader.Text = "Текущий статус"
    $statusHeader.FontSize = 14
    $statusHeader.FontWeight = "Bold"
    $statusHeader.Foreground = "#9C27B0"
    $statusHeader.Margin = "0,0,0,8"
    $content.Children.Add($statusHeader) | Out-Null

    if ($isInstalled -and $isEnabled) {
        $statusTb = New-Object System.Windows.Controls.TextBlock
        $statusTb.Text = "✓ ADBKeyboard установлен и активен. Кириллица поддерживается."
        $statusTb.FontSize = 12
        $statusTb.Foreground = "#2E7D32"
        $statusTb.Margin = "0,0,0,15"
        $content.Children.Add($statusTb) | Out-Null
    }
    elseif ($isInstalled -and -not $isEnabled) {
        $statusTb = New-Object System.Windows.Controls.TextBlock
        $statusTb.Text = "! ADBKeyboard установлен, но не активен. Нажмите «Включить клавиатуру»."
        $statusTb.FontSize = 12
        $statusTb.Foreground = "#F57C00"
        $statusTb.Margin = "0,0,0,15"
        $content.Children.Add($statusTb) | Out-Null
    }
    else {
        $statusTb = New-Object System.Windows.Controls.TextBlock
        $statusTb.Text = "ADBKeyboard не установлен. Кириллица в поле ввода работать не будет."
        $statusTb.FontSize = 12
        $statusTb.Foreground = "#C62828"
        $statusTb.Margin = "0,0,0,15"
        $content.Children.Add($statusTb) | Out-Null
    }

    # --- Кнопки действий ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Left"

    # Установить APK
    $btnInstall = New-Object System.Windows.Controls.Button
    $btnInstall.Content = "Установить APK"
    $btnInstall.Style = $window.Resources["RoundedButton"]
    $btnInstall.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
    )
    $btnInstall.Padding = "15,8"
    $btnInstall.Margin = "0,0,10,0"
    $btnInstall.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "APK files (*.apk)|*.apk|All files (*.*)|*.*"
        $dlg.Title = "Выберите ADBKeyboard.apk"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ok = Install-AdbKeyboard -ApkPath $dlg.FileName
            if ($ok) {
                [System.Windows.MessageBox]::Show(
                    "ADBKeyboard успешно установлен и включён!`n`nТеперь можно вводить кириллицу.",
                    "Готово",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information) | Out-Null
                $dialog.Close()
            } else {
                [System.Windows.MessageBox]::Show(
                    "Не удалось установить. Подробности в логе.",
                    "Ошибка",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error) | Out-Null
            }
        }
    })
    $btnPanel.Children.Add($btnInstall) | Out-Null

    # Включить IME (если установлен, но не активен)
    if ($isInstalled -and -not $isEnabled) {
        $btnEnable = New-Object System.Windows.Controls.Button
        $btnEnable.Content = "Включить клавиатуру"
        $btnEnable.Style = $window.Resources["RoundedButton"]
        $btnEnable.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
        )
        $btnEnable.Padding = "15,8"
        $btnEnable.Margin = "0,0,10,0"
        $btnEnable.Add_Click({
            $ok = Enable-AdbKeyboard
            if ($ok) {
                [System.Windows.MessageBox]::Show("ADBKeyboard включён.", "Готово") | Out-Null
                $dialog.Close()
            }
        })
        $btnPanel.Children.Add($btnEnable) | Out-Null
    }

    # Удалить (если установлен)
    if ($isInstalled) {
        $btnRemove = New-Object System.Windows.Controls.Button
        $btnRemove.Content = "Удалить"
        $btnRemove.Style = $window.Resources["RoundedButton"]
        $btnRemove.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
        )
        $btnRemove.Padding = "15,8"
        $btnRemove.Margin = "0,0,10,0"
        $btnRemove.Add_Click({
            $confirm = [System.Windows.MessageBox]::Show(
                "Удалить ADBKeyboard с ТВ?`n`nПосле этого ввод кириллицы перестанет работать.",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            Write-Log -Message "Удаляю ADBKeyboard..." -Level "Info"
            & $script:adbPath shell ime disable $script:AdbKeyboardIme 2>&1 | Out-Null
            $out = & $script:adbPath uninstall $script:AdbKeyboardPackage 2>&1
            $outText = ($out | Out-String).Trim()
            if ($outText -match "Success") {
                Write-Log -Message "ADBKeyboard удалён" -Level "Success"
                $script:AdbKeyboardAvailable = $false
                $dialog.Close()
            } else {
                Write-Log -Message "Не удалось удалить: $outText" -Level "Error"
            }
        })
        $btnPanel.Children.Add($btnRemove) | Out-Null
    }

    $content.Children.Add($btnPanel) | Out-Null

    # --- Кнопка "Закрыть" ---
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnClose.Padding = "15,8"
    $btnClose.HorizontalAlignment = "Right"
    $btnClose.Margin = "0,15,0,0"
    $btnClose.Add_Click({ $dialog.Close() })
    [System.Windows.Controls.Grid]::SetRow($btnClose, 2)
    $grid.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

# ===== ВРЕМЕННОЕ ПЕРЕКЛЮЧЕНИЕ IME =====
function Switch-AdbKeyboardTemp {
    param([scriptblock]$Action)

    $adbkIme = "com.android.adbkeyboard/.AdbIME"
    $prevIme = ""

    try {
        $prevIme = (& $script:adbPath shell settings get secure default_input_method 2>&1 | Out-String).Trim()
    } catch {
        Write-Log -Message "Не удалось прочитать текущую IME" -Level "Warning"
    }

    $isAdbKbActive = ($prevIme -match [regex]::Escape($adbkIme))

    if (-not $isAdbKbActive) {
        & $script:adbPath shell ime set $adbkIme 2>&1 | Out-Null
        Start-Sleep -Milliseconds 400
    }

    try {
        if ($Action) { & $Action }
    } finally {
        if (-not $isAdbKbActive -and $prevIme) {
            Start-Sleep -Milliseconds 300
            & $script:adbPath shell ime set $prevIme 2>&1 | Out-Null
        }
    }
}