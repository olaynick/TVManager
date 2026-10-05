# ============================================================================
#  Экран: HTTP-сервер для управления с телефона
# ============================================================================

function Show-HttpServerView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "HTTP-сервер"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Управление телевизором с телефона через браузер. TVManager поднимает локальный HTTP-сервер на ПК, а вы открываете его с телефона в той же Wi-Fi сети." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    # ===== СТАТУС =====
    $isRunning = $script:HttpServerRunning -eq $true

    $statusCard = New-Object System.Windows.Controls.Border
    if ($isRunning) {
        $statusCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#1F3A1F")
        )
    } else {
        $statusCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
        )
    }
    $statusCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $statusCard.BorderThickness = "1"
    $statusCard.CornerRadius = "8"
    $statusCard.Padding = "15"
    $statusCard.Margin = "0,0,0,15"

    $statusStack = New-Object System.Windows.Controls.StackPanel

    $statusLine = New-Object System.Windows.Controls.TextBlock
    $statusLine.FontSize = 16
    $statusLine.FontWeight = "Bold"
    if ($isRunning) {
        $statusLine.Text = "● Сервер работает"
        $statusLine.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } else {
        $statusLine.Text = "○ Сервер остановлен"
        $statusLine.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
    }
    $statusStack.Children.Add($statusLine) | Out-Null

    $statusCard.Child = $statusStack
    $mainStack.Children.Add($statusCard) | Out-Null

    # =========================================================================
    #  ЕСЛИ ЗАПУЩЕН — URL / ТОКЕН / ПРЕДУПРЕЖДЕНИЕ
    # =========================================================================
    if ($isRunning) {
        $localIp = Get-LocalIpAddress
        $port    = $script:HttpPort
        $token   = $script:HttpToken
        $isLocalOnly = $script:HttpLocalOnly -eq $true

        if ($isLocalOnly) {
            $url = "http://localhost:$Port/?token=$token"

            # ===== Карточка с проблемой и кнопкой =====
            $warnCardLocal = New-Object System.Windows.Controls.Border
            $warnCardLocal.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3D3520")
            )
            $warnCardLocal.BorderBrush = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#5A4A2A")
            )
            $warnCardLocal.BorderThickness = "1"
            $warnCardLocal.CornerRadius = "8"
            $warnCardLocal.Padding = New-Object System.Windows.Thickness(12)
            $warnCardLocal.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)

            $warnStackLocal = New-Object System.Windows.Controls.StackPanel

            $warnHead = New-Object System.Windows.Controls.TextBlock
            $warnHead.Text = "Сервер слушает только localhost"
            $warnHead.FontSize = 13
            $warnHead.FontWeight = "Bold"
            $warnHead.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
            )
            $warnHead.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
            $warnStackLocal.Children.Add($warnHead) | Out-Null

            $warnBody = New-Object System.Windows.Controls.TextBlock
            $warnBody.Text = "С телефона подключиться нельзя. Нужно один раз разрешить сетевой доступ — для этого потребуются права администратора (Windows покажет UAC-запрос)."
            $warnBody.FontSize = 11
            $warnBody.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
            )
            $warnBody.TextWrapping = "Wrap"
            $warnBody.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
            $warnStackLocal.Children.Add($warnBody) | Out-Null

            # ===== КНОПКА "Разрешить доступ по сети" =====
            $btnEnableAccess = New-Object System.Windows.Controls.Button
            $btnEnableAccess.Content = "Разрешить доступ по сети (нужен админ)"
            $btnEnableAccess.Style = $window.Resources["RoundedButton"]
            $btnEnableAccess.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
            )
            $btnEnableAccess.Padding = New-Object System.Windows.Thickness(15, 8, 15, 8)
            $btnEnableAccess.FontSize = 12
            $btnEnableAccess.HorizontalAlignment = "Left"
            $btnEnableAccess.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

            $btnEnableAccess.Add_Click({
                param($sender, $e)

                $btn = $sender
                $btn.IsEnabled = $false
                $btn.Content = "Ожидание UAC..."

                try {
                    Write-Log -Message "=== Запрос сетевого доступа ===" -Level "Info"
                    $ok = Enable-HttpNetworkAccess -Port 8080

                    if ($ok) {
                        Write-Log -Message "Сетевой доступ разрешён" -Level "Success"

                        Write-Log -Message "Перезапускаю HTTP-сервер..." -Level "Info"
                        Stop-HttpServer | Out-Null
                        Start-Sleep -Milliseconds 500
                        $restarted = Start-HttpServer -Port 8080

                        if ($restarted -and -not $script:HttpLocalOnly) {
                            [System.Windows.MessageBox]::Show(
                                "Готово! Сетевой доступ разрешён, сервер перезапущен.`n`nТеперь можно открывать URL с телефона.",
                                "Успешно",
                                [System.Windows.MessageBoxButton]::OK,
                                [System.Windows.MessageBoxImage]::Information) | Out-Null
                            Switch-View -ViewName "HttpServer"
                        } else {
                            [System.Windows.MessageBox]::Show(
                                "Сетевой доступ разрешён, но сервер всё ещё слушает только localhost.`n`nПопробуйте перезапустить TVManager (закройте и откройте заново).",
                                "Частичный успех",
                                [System.Windows.MessageBoxButton]::OK,
                                [System.Windows.MessageBoxImage]::Warning) | Out-Null
                            Switch-View -ViewName "HttpServer"
                        }
                    } else {
                        Write-Log -Message "Сетевой доступ НЕ разрешён" -Level "Warning"
                        $btn.IsEnabled = $true
                        $btn.Content = "Разрешить доступ по сети (нужен админ)"

                        [System.Windows.MessageBox]::Show(
                            "Не удалось разрешить сетевой доступ.`n`nВозможные причины:`n• UAC-запрос был отменён`n• Нет прав администратора`n• Антивирус блокирует netsh`n`nПопробуйте вручную, от имени администратора:`n`n  netsh http add urlacl url=http://+:8080/ user=Everyone`n  netsh advfirewall firewall add rule name=`"TVManager HTTP 8080`" dir=in action=allow protocol=TCP localport=8080",
                            "Не удалось",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    }
                } catch {
                    Write-Log -Message "Ошибка при разрешении доступа: $_" -Level "Error"
                    $btn.IsEnabled = $true
                    $btn.Content = "Разрешить доступ по сети (нужен админ)"
                }
            })

            $warnStackLocal.Children.Add($btnEnableAccess) | Out-Null

            # ===== Секция "ручные команды" =====
            $manualHeader = New-Object System.Windows.Controls.TextBlock
            $manualHeader.Text = "Или выполните вручную от администратора:"
            $manualHeader.FontSize = 11
            $manualHeader.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
            )
            $manualHeader.Margin = New-Object System.Windows.Thickness(0, 6, 0, 6)
            $warnStackLocal.Children.Add($manualHeader) | Out-Null

            # Команда 1
            $cmd1 = "netsh http add urlacl url=http://+:$Port/ user=Everyone"
            $tbCmd1 = New-Object System.Windows.Controls.TextBox
            $tbCmd1.Text = $cmd1
            $tbCmd1.FontFamily = "Consolas"
            $tbCmd1.FontSize = 11
            $tbCmd1.IsReadOnly = $true
            $tbCmd1.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#181818")
            )
            $tbCmd1.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
            )
            $tbCmd1.BorderBrush = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
            )
            $tbCmd1.Padding = New-Object System.Windows.Thickness(6, 4, 6, 4)
            $tbCmd1.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
            $warnStackLocal.Children.Add($tbCmd1) | Out-Null

            # Команда 2
            $cmd2 = "netsh advfirewall firewall add rule name=`"TVManager HTTP $Port`" dir=in action=allow protocol=TCP localport=$Port"
            $tbCmd2 = New-Object System.Windows.Controls.TextBox
            $tbCmd2.Text = $cmd2
            $tbCmd2.FontFamily = "Consolas"
            $tbCmd2.FontSize = 11
            $tbCmd2.IsReadOnly = $true
            $tbCmd2.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#181818")
            )
            $tbCmd2.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
            )
            $tbCmd2.BorderBrush = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
            )
            $tbCmd2.Padding = New-Object System.Windows.Thickness(6, 4, 6, 4)
            $warnStackLocal.Children.Add($tbCmd2) | Out-Null

            # Кнопка "Скопировать обе команды"
            $btnCopyCmds = New-Object System.Windows.Controls.Button
            $btnCopyCmds.Content = "Скопировать обе команды"
            $btnCopyCmds.Style = $window.Resources["RoundedButton"]
            $btnCopyCmds.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
            )
            $btnCopyCmds.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
            $btnCopyCmds.FontSize = 11
            $btnCopyCmds.HorizontalAlignment = "Left"
            $btnCopyCmds.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0)
            $btnCopyCmds.Tag = "$cmd1`r`n$cmd2"
            $btnCopyCmds.Add_Click({
                param($sender, $e)
                try {
                    [System.Windows.Clipboard]::SetText($sender.Tag)
                    Write-Log -Message "Команды скопированы в буфер обмена" -Level "Success"
                } catch {
                    Write-Log -Message "Ошибка копирования: $_" -Level "Error"
                }
            })
            $warnStackLocal.Children.Add($btnCopyCmds) | Out-Null

            $warnCardLocal.Child = $warnStackLocal
            $mainStack.Children.Add($warnCardLocal) | Out-Null
        } else {
            $url = "http://$($localIp):$Port/?token=$token"
        }


        # ===== URL ДЛЯ ТЕЛЕФОНА =====
        $urlLabel = New-ViewLabel -Text "Откройте на телефоне:" -Light
        $urlLabel.Margin = "0,0,0,5"
        $mainStack.Children.Add($urlLabel) | Out-Null

        $urlGrid = New-Object System.Windows.Controls.Grid
        $urlGrid.Margin = "0,0,0,10"

        $ug1 = New-Object System.Windows.Controls.ColumnDefinition
        $ug1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ug2 = New-Object System.Windows.Controls.ColumnDefinition
        $ug2.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Auto)
        $urlGrid.ColumnDefinitions.Add($ug1)
        $urlGrid.ColumnDefinitions.Add($ug2)

        $urlBox = New-Object System.Windows.Controls.TextBox
        $urlBox.Text = $url
        $urlBox.FontFamily = "Consolas"
        $urlBox.FontSize = 12
        $urlBox.IsReadOnly = $true
        $urlBox.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#181818")
        )
        $urlBox.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
        $urlBox.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )
        $urlBox.Padding = New-Object System.Windows.Thickness(6, 4, 6, 4)
        [System.Windows.Controls.Grid]::SetColumn($urlBox, 0)
        $urlGrid.Children.Add($urlBox) | Out-Null

        $btnCopyUrl = New-Object System.Windows.Controls.Button
        $btnCopyUrl.Content = "Копировать"
        $btnCopyUrl.Style = $window.Resources["RoundedButton"]
        $btnCopyUrl.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnCopyUrl.Padding = New-Object System.Windows.Thickness(10, 4, 10, 4)
        $btnCopyUrl.FontSize = 11
        $btnCopyUrl.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
        $btnCopyUrl.Tag = $url
        $btnCopyUrl.Add_Click({
            param($sender, $e)
            try {
                [System.Windows.Clipboard]::SetText($sender.Tag)
                Write-Log -Message "URL скопирован в буфер обмена" -Level "Success"
            } catch {
                Write-Log -Message "Ошибка копирования: $_" -Level "Error"
            }
        })
        [System.Windows.Controls.Grid]::SetColumn($btnCopyUrl, 1)
        $urlGrid.Children.Add($btnCopyUrl) | Out-Null

        $mainStack.Children.Add($urlGrid) | Out-Null

        # ===== ТОКЕН =====
        $tokenLabel = New-ViewLabel -Text "Токен доступа (нужен для API):" -Light
        $tokenLabel.Margin = "0,0,0,5"
        $mainStack.Children.Add($tokenLabel) | Out-Null

        $tokenGrid = New-Object System.Windows.Controls.Grid
        $tokenGrid.Margin = "0,0,0,15"

        $tg1 = New-Object System.Windows.Controls.ColumnDefinition
        $tg1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $tg2 = New-Object System.Windows.Controls.ColumnDefinition
        $tg2.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Auto)
        $tokenGrid.ColumnDefinitions.Add($tg1)
        $tokenGrid.ColumnDefinitions.Add($tg2)

        $tokenBox = New-Object System.Windows.Controls.TextBox
        $tokenBox.Text = $token
        $tokenBox.FontFamily = "Consolas"
        $tokenBox.FontSize = 14
        $tokenBox.FontWeight = "Bold"
        $tokenBox.IsReadOnly = $true
        $tokenBox.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#181818")
        )
        $tokenBox.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $tokenBox.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )
        $tokenBox.Padding = New-Object System.Windows.Thickness(6, 4, 6, 4)
        [System.Windows.Controls.Grid]::SetColumn($tokenBox, 0)
        $tokenGrid.Children.Add($tokenBox) | Out-Null

        $btnCopyToken = New-Object System.Windows.Controls.Button
        $btnCopyToken.Content = "Копировать"
        $btnCopyToken.Style = $window.Resources["RoundedButton"]
        $btnCopyToken.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnCopyToken.Padding = New-Object System.Windows.Thickness(10, 4, 10, 4)
        $btnCopyToken.FontSize = 11
        $btnCopyToken.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
        $btnCopyToken.Tag = $token
        $btnCopyToken.Add_Click({
            param($sender, $e)
            try {
                [System.Windows.Clipboard]::SetText($sender.Tag)
                Write-Log -Message "Токен скопирован в буфер обмена" -Level "Success"
            } catch {
                Write-Log -Message "Ошибка копирования: $_" -Level "Error"
            }
        })
        [System.Windows.Controls.Grid]::SetColumn($btnCopyToken, 1)
        $tokenGrid.Children.Add($btnCopyToken) | Out-Null

        $mainStack.Children.Add($tokenGrid) | Out-Null
    }

    # ===== ИНСТРУКЦИЯ =====
    $stepTitle = New-StepTitle -Text "Как пользоваться"
    $mainStack.Children.Add($stepTitle) | Out-Null

    $steps = @(
        "1. Нажмите «Запустить сервер» внизу экрана.",
        "2. Если появилась жёлтая карточка — нажмите «Разрешить доступ по сети (нужен админ)».",
        "3. Скопируйте URL (кнопка «Копировать»).",
        "4. Отправьте URL себе в мессенджер или введите вручную на телефоне.",
        "5. Откройте URL в браузере телефона — появится веб-пульт.",
        "6. Управляйте ТВ: пульт, приложения, ввод текста, скриншоты, лог."
    )
    foreach ($step in $steps) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $step
        $tb.FontSize = 12
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $tb.TextWrapping = "Wrap"
        $tb.Margin = New-Object System.Windows.Thickness(0, 3, 0, 3)
        $mainStack.Children.Add($tb) | Out-Null
    }

    # ===== ПРЕДУПРЕЖДЕНИЕ О БЕЗОПАСНОСТИ =====
    $warnCard = New-Object System.Windows.Controls.Border
    $warnCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3D3520")
    )
    $warnCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#5A4A2A")
    )
    $warnCard.BorderThickness = "1"
    $warnCard.CornerRadius = "8"
    $warnCard.Padding = New-Object System.Windows.Thickness(12)
    $warnCard.Margin = New-Object System.Windows.Thickness(0, 15, 0, 0)

    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = "Безопасность: сервер доступен всем устройствам в вашей Wi-Fi сети. Токен защищает API от случайного доступа. Не оставляйте сервер запущенным без необходимости — останавливайте после использования."
    $warnText.TextWrapping = "Wrap"
    $warnText.FontSize = 11
    $warnText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $warnCard.Child = $warnText
    $mainStack.Children.Add($warnCard) | Out-Null

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    if (-not $isRunning) {
        # --- Запустить сервер ---
        $btnStart = New-Object System.Windows.Controls.Button
        $btnStart.Content = "Запустить сервер"
        $btnStart.Style = $window.Resources["RoundedButton"]
        $btnStart.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
        $btnStart.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
        $btnStart.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
        $btnStart.Add_Click({
            $ok = Start-HttpServer -Port 8080
            if ($ok) {
                Switch-View -ViewName "HttpServer"
            } else {
                [System.Windows.MessageBox]::Show(
                    "Не удалось запустить HTTP-сервер.`n`nПроверьте лог на наличие ошибок.`n`nЕсли ошибка про права — порт 8080 может быть занят или нужны права администратора.",
                    "Ошибка запуска",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error) | Out-Null
            }
        })
        $buttons += $btnStart
    } else {
        # --- Остановить сервер ---
        $btnStop = New-Object System.Windows.Controls.Button
        $btnStop.Content = "Остановить сервер"
        $btnStop.Style = $window.Resources["RoundedButton"]
        $btnStop.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
        $btnStop.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
        $btnStop.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
        $btnStop.Add_Click({
            Stop-HttpServer | Out-Null
            Switch-View -ViewName "HttpServer"
        })
        $buttons += $btnStop

        # --- Открыть в браузере ПК ---
        $btnOpen = New-Object System.Windows.Controls.Button
        $btnOpen.Content = "Открыть на ПК"
        $btnOpen.Style = $window.Resources["RoundedButton"]
        $btnOpen.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnOpen.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
        $btnOpen.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
        $btnOpen.Add_Click({
            $port  = $script:HttpPort
            $token = $script:HttpToken
            $url   = "http://localhost:$Port/?token=$token"
            try {
                Start-Process $url
                Write-Log -Message "Открываю в браузере: $url" -Level "Info"
            } catch {
                Write-Log -Message "Не удалось открыть браузер: $_" -Level "Error"
            }
        })
        $buttons += $btnOpen
    }

    # --- Обновить ---
    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnRefresh.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
    $btnRefresh.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $btnRefresh.Add_Click({ Switch-View -ViewName "HttpServer" })
    $buttons += $btnRefresh

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран HTTP-сервера (running=$isRunning, localOnly=$($script:HttpLocalOnly))" -Level "Info"
}