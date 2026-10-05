# ============================================================================
#  Экран: Автозапуск и фоновая активность
# ============================================================================

function Show-AutostartView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Автозапуск и фон"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Управление фоновой активностью приложений через AppOps. На некоторых прошивках TCL операция BOOT_COMPLETED (автозапуск) не поддерживается — тогда кнопки «Авто» будут недоступны." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,10"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    Write-Log -Message "Читаю список приложений..." -Level "Info"
    $apps = Get-AppsWithAutostart

    if ($apps.Count -eq 0) {
        $mainStack.Children.Add((New-ViewLabel -Text "Не удалось прочитать список приложений.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # Проверяем, поддерживается ли BOOT_COMPLETED
    $bootSupported = ($apps | Where-Object { $_.BootSupported } | Select-Object -First 1) -ne $null
    if (-not $bootSupported) {
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
        $warnCard.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)

        $warnText = New-Object System.Windows.Controls.TextBlock
        $warnText.Text = "На этой прошивке операция BOOT_COMPLETED (автозапуск) не поддерживается. Кнопки «Авто» отключены. Управление фоном (RUN_IN_BACKGROUND) работает."
        $warnText.TextWrapping = "Wrap"
        $warnText.FontSize = 11
        $warnText.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $warnCard.Child = $warnText
        $mainStack.Children.Add($warnCard) | Out-Null
    }

    # ===== ПОИСК =====
    $searchPanel = New-Object System.Windows.Controls.Grid
    $searchPanel.Margin = "0,0,0,12"

    $sc1 = New-Object System.Windows.Controls.ColumnDefinition; $sc1.Width = "*"
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition; $sc2.Width = "Auto"
    $searchPanel.ColumnDefinitions.Add($sc1)
    $searchPanel.ColumnDefinitions.Add($sc2)

    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Style = $window.Resources["RoundedTextBox"]
    $searchBox.FontSize = 13
    $searchBox.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)

    $placeholderText = "Поиск по имени пакета..."

    $searchBox.Add_GotFocus({
        if ($this.Text -eq $placeholderText) {
            $this.Text = ""
            $this.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
            )
        }
    }.GetNewClosure())

    $searchBox.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($this.Text)) {
            $this.Text = $placeholderText
            $this.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
            )
        }
    }.GetNewClosure())

    $searchBox.Text = $placeholderText
    $searchBox.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
    )
    [System.Windows.Controls.Grid]::SetColumn($searchBox, 0)
    $searchPanel.Children.Add($searchBox) | Out-Null

    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnRefresh.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
    $btnRefresh.FontSize = 11
    $btnRefresh.Add_Click({ Switch-View -ViewName "Autostart" })
    [System.Windows.Controls.Grid]::SetColumn($btnRefresh, 1)
    $searchPanel.Children.Add($btnRefresh) | Out-Null

    $mainStack.Children.Add($searchPanel) | Out-Null

    # ===== СПИСОК =====
    $script:AutostartItems = @()

    $listContainer = New-Object System.Windows.Controls.StackPanel
    $listContainer.Margin = New-Object System.Windows.Thickness(0, 5, 0, 15)
    $mainStack.Children.Add($listContainer) | Out-Null

    foreach ($app in $apps) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
        )
        $row.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )
        $row.BorderThickness = "1"
        $row.CornerRadius = "6"
        $row.Padding = New-Object System.Windows.Thickness(10)
        $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

        if ($app.IsDisabled) {
            $row.Opacity = 0.55
        }

        $grid = New-Object System.Windows.Controls.Grid
        $gc1 = New-Object System.Windows.Controls.ColumnDefinition; $gc1.Width = "*"
        $gc2 = New-Object System.Windows.Controls.ColumnDefinition; $gc2.Width = "Auto"
        $grid.ColumnDefinitions.Add($gc1)
        $grid.ColumnDefinitions.Add($gc2)

        # --- Левая колонка: имя + статус ---
        $leftStack = New-Object System.Windows.Controls.StackPanel
        [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)

        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.FontSize = 13
        $nameTb.FontWeight = "Bold"

        $badges = ""
        if ($app.IsSystem)   { $badges += " [SYS]" }
        else                 { $badges += " [USR]" }
        if ($app.IsDisabled) { $badges += " [ОТКЛЮЧЕНО]" }

        $nameTb.Text = "$($app.Package)$badges"

        if ($app.IsDisabled) {
            $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
            )
        } elseif ($app.IsSystem) {
            $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
            )
        } else {
            $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
            )
        }

        $leftStack.Children.Add($nameTb) | Out-Null

        # --- Статусная строка ---
        $statusText = New-Object System.Windows.Controls.TextBlock
        $statusText.FontSize = 11
        $statusText.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)

        $bgText = switch ($app.Background) {
            "allow"   { "Фон: разрешён" }
            "deny"    { "Фон: запрещён" }
            "ignore"  { "Фон: игнорируется" }
            default   { "Фон: по умолчанию" }
        }

        if (-not $app.BootSupported) {
            $bootText = "Автозапуск: не поддерживается"
        } else {
            $bootText = switch ($app.Autostart) {
                "allow"   { "Автозапуск: разрешён" }
                "deny"    { "Автозапуск: запрещён" }
                "ignore"  { "Автозапуск: игнорируется" }
                default   { "Автозапуск: по умолчанию" }
            }
        }

        $statusText.Text = "$bgText   |   $bootText"

        if ($app.IsDisabled) {
            $statusText.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
            )
        } elseif ($app.Background -eq "deny" -and ($app.Autostart -eq "deny" -or -not $app.BootSupported)) {
            $statusText.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
            )
        } elseif ($app.Background -eq "deny" -or $app.Autostart -eq "deny") {
            $statusText.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
            )
        } else {
            $statusText.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#909090")
            )
        }

        $leftStack.Children.Add($statusText) | Out-Null
        $grid.Children.Add($leftStack) | Out-Null

        # --- Правая колонка: кнопки ---
        $btnPanel = New-Object System.Windows.Controls.StackPanel
        $btnPanel.Orientation = "Vertical"
        $btnPanel.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($btnPanel, 1)

        # Строка 1: фон
        $bgRow = New-Object System.Windows.Controls.StackPanel
        $bgRow.Orientation = "Horizontal"
        $bgRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 3)

        $btnAllowBg = New-Object System.Windows.Controls.Button
        $btnAllowBg.Content = "✓ Фон"
        $btnAllowBg.Style = $window.Resources["RoundedButton"]
        $btnAllowBg.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
        $btnAllowBg.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
        $btnAllowBg.FontSize = 10
        $btnAllowBg.Margin = New-Object System.Windows.Thickness(0, 0, 4, 0)
        $btnAllowBg.ToolTip = "Разрешить фоновую активность"
        $btnAllowBg.Tag = $app.Package
        $btnAllowBg.Add_Click({
            param($sender, $e)
            $pkg = $sender.Tag
            $r = Set-AppOpsPermission -Package $pkg -Op "RUN_IN_BACKGROUND" -Mode "allow"
            if ($r.Success) {
                Write-Log -Message "Фон разрешён: $pkg" -Level "Success"
                Switch-View -ViewName "Autostart"
            } else {
                Write-Log -Message "Ошибка: $($r.Message)" -Level "Error"
            }
        })
        if ($app.IsDisabled) { $btnAllowBg.IsEnabled = $false }
        $bgRow.Children.Add($btnAllowBg) | Out-Null

        $btnBlockBg = New-Object System.Windows.Controls.Button
        $btnBlockBg.Content = "✗ Фон"
        $btnBlockBg.Style = $window.Resources["RoundedButton"]
        $btnBlockBg.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
        )
        $btnBlockBg.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
        $btnBlockBg.FontSize = 10
        $btnBlockBg.ToolTip = "Запретить фоновую активность"
        $btnBlockBg.Tag = $app.Package
        $btnBlockBg.Add_Click({
            param($sender, $e)
            $pkg = $sender.Tag
            $r = Set-AppOpsPermission -Package $pkg -Op "RUN_IN_BACKGROUND" -Mode "deny"
            if ($r.Success) {
                & $script:adbPath shell am force-stop $pkg 2>&1 | Out-Null
                Write-Log -Message "Фон запрещён: $pkg" -Level "Success"
                Switch-View -ViewName "Autostart"
            } else {
                Write-Log -Message "Ошибка: $($r.Message)" -Level "Error"
            }
        })
        if ($app.IsDisabled) { $btnBlockBg.IsEnabled = $false }
        $bgRow.Children.Add($btnBlockBg) | Out-Null

        $btnPanel.Children.Add($bgRow) | Out-Null

        # Строка 2: автозапуск (только если поддерживается)
        if ($app.BootSupported) {
            $bootRow = New-Object System.Windows.Controls.StackPanel
            $bootRow.Orientation = "Horizontal"

            $btnAllowBoot = New-Object System.Windows.Controls.Button
            $btnAllowBoot.Content = "✓ Авто"
            $btnAllowBoot.Style = $window.Resources["RoundedButton"]
            $btnAllowBoot.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
            )
            $btnAllowBoot.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
            $btnAllowBoot.FontSize = 10
            $btnAllowBoot.Margin = New-Object System.Windows.Thickness(0, 0, 4, 0)
            $btnAllowBoot.ToolTip = "Разрешить автозапуск"
            $btnAllowBoot.Tag = $app.Package
            $btnAllowBoot.Add_Click({
                param($sender, $e)
                $pkg = $sender.Tag
                $r = Set-AppOpsPermission -Package $pkg -Op "BOOT_COMPLETED" -Mode "allow"
                if ($r.Success) {
                    Write-Log -Message "Автозапуск разрешён: $pkg" -Level "Success"
                    Switch-View -ViewName "Autostart"
                } else {
                    Write-Log -Message "Ошибка: $($r.Message)" -Level "Error"
                }
            })
            if ($app.IsDisabled) { $btnAllowBoot.IsEnabled = $false }
            $bootRow.Children.Add($btnAllowBoot) | Out-Null

            $btnBlockBoot = New-Object System.Windows.Controls.Button
            $btnBlockBoot.Content = "✗ Авто"
            $btnBlockBoot.Style = $window.Resources["RoundedButton"]
            $btnBlockBoot.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
            )
            $btnBlockBoot.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
            $btnBlockBoot.FontSize = 10
            $btnBlockBoot.ToolTip = "Запретить автозапуск"
            $btnBlockBoot.Tag = $app.Package
            $btnBlockBoot.Add_Click({
                param($sender, $e)
                $pkg = $sender.Tag
                $r = Set-AppOpsPermission -Package $pkg -Op "BOOT_COMPLETED" -Mode "deny"
                if ($r.Success) {
                    Write-Log -Message "Автозапуск запрещён: $pkg" -Level "Success"
                    Switch-View -ViewName "Autostart"
                } else {
                    Write-Log -Message "Ошибка: $($r.Message)" -Level "Error"
                }
            })
            if ($app.IsDisabled) { $btnBlockBoot.IsEnabled = $false }
            $bootRow.Children.Add($btnBlockBoot) | Out-Null

            $btnPanel.Children.Add($bootRow) | Out-Null
        } else {
            $noBootTb = New-Object System.Windows.Controls.TextBlock
            $noBootTb.Text = "Автозапуск: не поддерживается"
            $noBootTb.FontSize = 9
            $noBootTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
            )
            $noBootTb.TextAlignment = "Center"
            $btnPanel.Children.Add($noBootTb) | Out-Null
        }

        $grid.Children.Add($btnPanel) | Out-Null

        $row.Child = $grid
        $listContainer.Children.Add($row) | Out-Null

        $script:AutostartItems += @{
            Row        = $row
            SearchText = $app.Package.ToLower()
            Package    = $app.Package
        }
    }

    # ===== ФИЛЬТР =====
    $script:AutostartSearchBox = $searchBox
    $script:AutostartPlaceholder = $placeholderText

    $searchBox.Add_TextChanged({
        $query = $script:AutostartSearchBox.Text.Trim().ToLower()
        if ($query -eq $script:AutostartPlaceholder.ToLower()) { $query = "" }

        foreach ($item in $script:AutostartItems) {
            if (-not $query -or $item.SearchText -like "*$query*") {
                $item.Row.Visibility = "Visible"
            } else {
                $item.Row.Visibility = "Collapsed"
            }
        }
    })

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    # --- Пресет: ограничить всех (только фон) ---
    $btnSystemPreset = New-Object System.Windows.Controls.Button
    $btnSystemPreset.Content = "Запретить фон всем пользовательским"
    $btnSystemPreset.Style = $window.Resources["RoundedButton"]
    $btnSystemPreset.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
    )
    $btnSystemPreset.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
    $btnSystemPreset.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $btnSystemPreset.Add_Click({
        $userPkgs = @($script:AutostartItems | Where-Object {
            $item = $_
            $app = $apps | Where-Object { $_.Package -eq $item.Package } | Select-Object -First 1
            $app -and -not $app.IsSystem -and -not $app.IsDisabled
        } | ForEach-Object { $_.Package })

        if ($userPkgs.Count -eq 0) {
            Write-Log -Message "Нет пользовательских приложений" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Запретить фон для $($userPkgs.Count) пользовательских приложений?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Применяю ограничения для $($userPkgs.Count) приложений..." -Level "Info"
        $r = Set-AppOpsBatch -Packages $userPkgs -Op "RUN_IN_BACKGROUND" -Mode "deny"
        Write-Log -Message "Готово: фон $($r.Ok)" -Level "Success"
        Switch-View -ViewName "Autostart"
    })
    $buttons += $btnSystemPreset

    # --- Сброс ---
    $btnRestoreAll = New-Object System.Windows.Controls.Button
    $btnRestoreAll.Content = "Разрешить всё (сброс)"
    $btnRestoreAll.Style = $window.Resources["RoundedButton"]
    $btnRestoreAll.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnRestoreAll.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
    $btnRestoreAll.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $btnRestoreAll.Add_Click({
        $allPkgs = @($script:AutostartItems | ForEach-Object { $_.Package })

        $confirm = [System.Windows.MessageBox]::Show(
            "Сбросить фон и автозапуск для $($allPkgs.Count) приложений?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Сбрасываю $($allPkgs.Count) приложений..." -Level "Info"
        $r1 = Set-AppOpsBatch -Packages $allPkgs -Op "RUN_IN_BACKGROUND" -Mode "default"
        if ($bootSupported) {
            $r2 = Set-AppOpsBatch -Packages $allPkgs -Op "BOOT_COMPLETED" -Mode "default"
        }
        Write-Log -Message "Готово: фон $($r1.Ok)" -Level "Success"
        Switch-View -ViewName "Autostart"
    })
    $buttons += $btnRestoreAll

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран автозапуска (приложений: $($apps.Count))" -Level "Info"
}