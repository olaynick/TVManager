# ============================================================================
#  Экран: Автозапуск и фоновая активность
# ============================================================================

function Show-AutostartView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Автозапуск и фон"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Управление тем, какие приложения могут запускаться автоматически и работать в фоне. Отключение фоновой активности экономит память, но может нарушить работу уведомлений и синхронизации." -Light
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
    $searchBox.Margin = "0,0,8,0"

    $placeholderText = "Поиск по имени пакета..."

    $searchBox.Add_GotFocus({
        if ($this.Text -eq $placeholderText) {
            $this.Text = ""
            $this.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#000000")
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.FontSize = 11
    $btnRefresh.Add_Click({
        Switch-View -ViewName "Autostart"
    })
    [System.Windows.Controls.Grid]::SetColumn($btnRefresh, 1)
    $searchPanel.Children.Add($btnRefresh) | Out-Null

    $mainStack.Children.Add($searchPanel) | Out-Null

    # ===== СПИСОК ПРИЛОЖЕНИЙ =====
    $script:AutostartItems = @()

    $listContainer = New-Object System.Windows.Controls.StackPanel
    $listContainer.Margin = "0,5,0,15"
    $mainStack.Children.Add($listContainer) | Out-Null

    foreach ($app in $apps) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "White"
        $row.BorderBrush = "#E1E1E6"
        $row.BorderThickness = "1"
        $row.CornerRadius = "6"
        $row.Padding = "10"
        $row.Margin = "0,0,0,5"

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

        $typeLabel = if ($app.IsSystem) { "[SYSTEM]" } else { "[USER]" }
        $nameTb.Text = "$typeLabel  $($app.Package)"

        if ($app.IsSystem) {
            $nameTb.Foreground = [System.Windows.Media.Brushes]::DarkBlue
        } else {
            $nameTb.Foreground = [System.Windows.Media.Brushes]::DarkGreen
        }

        $leftStack.Children.Add($nameTb) | Out-Null

        $statusText = New-Object System.Windows.Controls.TextBlock
        $statusText.FontSize = 11
        $statusText.Margin = "30,3,0,0"

        $bgText = switch ($app.Background) {
            "allow"   { "Фон: разрешён" }
            "deny"    { "Фон: запрещён" }
            "ignore"  { "Фон: игнорируется" }
            default   { "Фон: по умолчанию" }
        }

        $bootText = switch ($app.Autostart) {
            "allow"   { "Автозапуск: разрешён" }
            "deny"    { "Автозапуск: запрещён" }
            "ignore"  { "Автозапуск: игнорируется" }
            default   { "Автозапуск: по умолчанию" }
        }

        $statusText.Text = "$bgText   |   $bootText"

        if ($app.Background -eq "deny" -and $app.Autostart -eq "deny") {
            $statusText.Foreground = [System.Windows.Media.Brushes]::DarkGreen
        } elseif ($app.Background -eq "deny" -or $app.Autostart -eq "deny") {
            $statusText.Foreground = [System.Windows.Media.Brushes]::DarkOrange
        } else {
            $statusText.Foreground = [System.Windows.Media.Brushes]::Gray
        }

        $leftStack.Children.Add($statusText) | Out-Null

        $grid.Children.Add($leftStack) | Out-Null

        # --- Правая колонка: 4 кнопки (2 строки) ---
        $btnPanel = New-Object System.Windows.Controls.StackPanel
        $btnPanel.Orientation = "Vertical"
        $btnPanel.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($btnPanel, 1)

        # Строка 1: фон
        $bgRow = New-Object System.Windows.Controls.StackPanel
        $bgRow.Orientation = "Horizontal"
        $bgRow.Margin = "0,0,0,3"

        $btnAllowBg = New-Object System.Windows.Controls.Button
        $btnAllowBg.Content = "✓ Фон"
        $btnAllowBg.Style = $window.Resources["RoundedButton"]
        $btnAllowBg.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
        )
        $btnAllowBg.Padding = "8,4"
        $btnAllowBg.FontSize = 10
        $btnAllowBg.Margin = "0,0,4,0"
        $btnAllowBg.ToolTip = "Разрешить фоновую активность"
        $pkgAllowBg = $app.Package
        $btnAllowBg.Add_Click({
            if (Set-AppOpsPermission -Package $pkgAllowBg -Op "RUN_IN_BACKGROUND" -Mode "allow") {
                Write-Log -Message "Фон разрешён: $pkgAllowBg" -Level "Success"
                Switch-View -ViewName "Autostart"
            }
        }.GetNewClosure())
        $bgRow.Children.Add($btnAllowBg) | Out-Null

        $btnBlockBg = New-Object System.Windows.Controls.Button
        $btnBlockBg.Content = "✗ Фон"
        $btnBlockBg.Style = $window.Resources["RoundedButton"]
        $btnBlockBg.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
        )
        $btnBlockBg.Padding = "8,4"
        $btnBlockBg.FontSize = 10
        $btnBlockBg.ToolTip = "Запретить фоновую активность"
        $pkgBlockBg = $app.Package
        $btnBlockBg.Add_Click({
            if (Set-AppOpsPermission -Package $pkgBlockBg -Op "RUN_IN_BACKGROUND" -Mode "deny") {
                & $script:adbPath shell am force-stop $pkgBlockBg 2>&1 | Out-Null
                Write-Log -Message "Фон запрещён: $pkgBlockBg" -Level "Success"
                Switch-View -ViewName "Autostart"
            }
        }.GetNewClosure())
        $bgRow.Children.Add($btnBlockBg) | Out-Null

        $btnPanel.Children.Add($bgRow) | Out-Null

        # Строка 2: автозапуск
        $bootRow = New-Object System.Windows.Controls.StackPanel
        $bootRow.Orientation = "Horizontal"

        $btnAllowBoot = New-Object System.Windows.Controls.Button
        $btnAllowBoot.Content = "✓ Авто"
        $btnAllowBoot.Style = $window.Resources["RoundedButton"]
        $btnAllowBoot.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
        )
        $btnAllowBoot.Padding = "8,4"
        $btnAllowBoot.FontSize = 10
        $btnAllowBoot.Margin = "0,0,4,0"
        $btnAllowBoot.ToolTip = "Разрешить автозапуск"
        $pkgAllowBoot = $app.Package
        $btnAllowBoot.Add_Click({
            if (Set-AppOpsPermission -Package $pkgAllowBoot -Op "BOOT_COMPLETED" -Mode "allow") {
                Write-Log -Message "Автозапуск разрешён: $pkgAllowBoot" -Level "Success"
                Switch-View -ViewName "Autostart"
            }
        }.GetNewClosure())
        $bootRow.Children.Add($btnAllowBoot) | Out-Null

        $btnBlockBoot = New-Object System.Windows.Controls.Button
        $btnBlockBoot.Content = "✗ Авто"
        $btnBlockBoot.Style = $window.Resources["RoundedButton"]
        $btnBlockBoot.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
        )
        $btnBlockBoot.Padding = "8,4"
        $btnBlockBoot.FontSize = 10
        $btnBlockBoot.ToolTip = "Запретить автозапуск"
        $pkgBlockBoot = $app.Package
        $btnBlockBoot.Add_Click({
            if (Set-AppOpsPermission -Package $pkgBlockBoot -Op "BOOT_COMPLETED" -Mode "deny") {
                Write-Log -Message "Автозапуск запрещён: $pkgBlockBoot" -Level "Success"
                Switch-View -ViewName "Autostart"
            }
        }.GetNewClosure())
        $bootRow.Children.Add($btnBlockBoot) | Out-Null

        $btnPanel.Children.Add($bootRow) | Out-Null

        $grid.Children.Add($btnPanel) | Out-Null

        $row.Child = $grid
        $listContainer.Children.Add($row) | Out-Null

        # Сохраняем для фильтрации
        $script:AutostartItems += @{
            Row         = $row
            SearchText  = $app.Package.ToLower()
            IsSystem    = $app.IsSystem
            Package     = $app.Package
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

    # --- Пресет: ограничить всех ---
    $btnSystemPreset = New-Object System.Windows.Controls.Button
    $btnSystemPreset.Content = "Ограничить все пользовательские"
    $btnSystemPreset.Style = $window.Resources["RoundedButton"]
    $btnSystemPreset.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
    )
    $btnSystemPreset.Padding = "12,6"
    $btnSystemPreset.Margin = "0,0,8,0"
    $btnSystemPreset.Add_Click({
        $userPkgs = @($script:AutostartItems | Where-Object { -not $_.IsSystem } | ForEach-Object { $_.Package })

        if ($userPkgs.Count -eq 0) {
            Write-Log -Message "Нет пользовательских приложений" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Запретить фон и автозапуск для $($userPkgs.Count) пользовательских приложений?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Применяю ограничения для $($userPkgs.Count) приложений..." -Level "Info"
        $ok1 = Set-AppOpsBatch -Packages $userPkgs -Op "RUN_IN_BACKGROUND" -Mode "deny"
        $ok2 = Set-AppOpsBatch -Packages $userPkgs -Op "BOOT_COMPLETED" -Mode "deny"
        Write-Log -Message "Готово: фон $ok1, автозапуск $ok2" -Level "Success"
        Switch-View -ViewName "Autostart"
    })
    $buttons += $btnSystemPreset

    # --- Сброс всех ---
    $btnRestoreAll = New-Object System.Windows.Controls.Button
    $btnRestoreAll.Content = "Разрешить всё (сброс)"
    $btnRestoreAll.Style = $window.Resources["RoundedButton"]
    $btnRestoreAll.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
    )
    $btnRestoreAll.Padding = "12,6"
    $btnRestoreAll.Margin = "0,0,8,0"
    $btnRestoreAll.Add_Click({
        $allPkgs = @($script:AutostartItems | ForEach-Object { $_.Package })

        $confirm = [System.Windows.MessageBox]::Show(
            "Сбросить настройки фона и автозапуска для $($allPkgs.Count) приложений?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Сбрасываю $($allPkgs.Count) приложений..." -Level "Info"
        $ok1 = Set-AppOpsBatch -Packages $allPkgs -Op "RUN_IN_BACKGROUND" -Mode "default"
        $ok2 = Set-AppOpsBatch -Packages $allPkgs -Op "BOOT_COMPLETED" -Mode "default"
        Write-Log -Message "Готово: фон $ok1, автозапуск $ok2" -Level "Success"
        Switch-View -ViewName "Autostart"
    })
    $buttons += $btnRestoreAll

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран автозапуска (приложений: $($apps.Count))" -Level "Info"
}