# ============================================================================
#  ЭКРАН УПРАВЛЕНИЯ ПАКЕТАМИ
# ============================================================================

# ============================================================================
#  ФИЛЬТРАЦИЯ ПАКЕТОВ (глобальная функция)
# ============================================================================
function Update-CleanupFilter {
    if (-not $script:CleanupSearchBox)  { return }
    if (-not $script:CleanupSearchInfo) { return }
    if (-not $script:CleanupClearBtn)   { return }

    $query = $script:CleanupSearchBox.Text.Trim().ToLower()
    if ($query -eq $script:CleanupPlaceholder.ToLower()) { $query = "" }

    if ($query) {
        $script:CleanupClearBtn.Visibility = "Visible"
    } else {
        $script:CleanupClearBtn.Visibility = "Collapsed"
    }

    if (-not $script:CleanupTabCheckboxes) { return }

    # ===== АКТИВНЫЙ ПОИСК: скрываем вкладки, показываем панель результатов =====
    if ($query) {
        $script:CleanupTabControl.Visibility = "Collapsed"
        $script:CleanupResultsPanel.Visibility = "Visible"
        $script:CleanupResultsPanel.Children.Clear()

        $totalVisible = 0

        foreach ($catName in $script:CleanupTabCheckboxes.Keys) {
            $checkboxes = $script:CleanupTabCheckboxes[$catName]
            $catHasResults = $false

            # Заголовок категории (если есть совпадения)
            $catHeader = New-Object System.Windows.Controls.TextBlock
            $catHeader.Text = "📁 $catName"
            $catHeader.FontSize = 12
            $catHeader.FontWeight = "Bold"
            $catHeader.Foreground = "#C8C8C8"
            $catHeader.Margin = "0,10,0,5"

            $catContainer = New-Object System.Windows.Controls.StackPanel

            foreach ($chk in $checkboxes) {
                $searchText = ""
                if ($chk.PSObject.Properties["SearchText"]) {
                    $searchText = $chk.SearchText
                }

                if ($searchText -like "*$query*") {
                    # Создаём КОПИЮ чекбокса, привязанную к оригиналу
                    $copy = New-Object System.Windows.Controls.CheckBox
                    $copy.Style = $window.Resources["MiuiCheckBox"]
                    $copy.Content = $chk.Content
                    $copy.Foreground = $chk.Foreground
                    $copy.IsEnabled = $chk.IsEnabled
                    $copy.IsChecked = $chk.IsChecked
                    $copy.Tag = $chk.Tag
                    $copy.ToolTip = $chk.ToolTip
                    $copy | Add-Member -MemberType NoteProperty -Name "SearchText" -Value $searchText -Force

                    # Синхронизация: при клике по копии — меняется оригинал
                    $original = $chk
                    $copy.Add_Click({
                        $original.IsChecked = $this.IsChecked
                    }.GetNewClosure())

                    $catContainer.Children.Add($copy) | Out-Null
                    $catHasResults = $true
                    $totalVisible++
                }
            }

            if ($catHasResults) {
                $script:CleanupResultsPanel.Children.Add($catHeader) | Out-Null
                $script:CleanupResultsPanel.Children.Add($catContainer) | Out-Null
            }
        }

        if ($totalVisible -eq 0) {
            $empty = New-Object System.Windows.Controls.TextBlock
            $empty.Text = "Ничего не найдено по запросу: $query"
            $empty.FontSize = 13
            $empty.Foreground = "#A0A0A0"
            $empty.Margin = "20"
            $script:CleanupResultsPanel.Children.Add($empty) | Out-Null
        }

        $script:CleanupSearchInfo.Text = "Найдено: $totalVisible"
    }
    # ===== ПУСТОЙ ПОИСК: возвращаем вкладки, скрываем результаты =====
    else {
        $script:CleanupTabControl.Visibility = "Visible"
        $script:CleanupResultsPanel.Visibility = "Collapsed"
        $script:CleanupResultsPanel.Children.Clear()
        $script:CleanupSearchInfo.Text = ""
    }
}

# ============================================================================
#  ОСНОВНОЙ ЭКРАН
# ============================================================================
function Show-CleanupView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Управление пакетами"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "«Отключить» — пакет остаётся в системе. «Удалить» — данные стираются. «Очистить данные» — сброс кэша и настроек. Цвет метки: зелёный — безопасно, оранжевый — осторожно, красный — может сломать ТВ." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,10"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    Write-Log -Message "Читаю списки пакетов..." -Level "Info"
    $script:InstalledPackagesSet = Get-InstalledPackagesSet
    $script:DisabledPackagesSet  = Get-DisabledPackagesSet
    Write-Log -Message "Установлено: $($script:InstalledPackagesSet.Count), отключено: $($script:DisabledPackagesSet.Count)" -Level "Info"

    # ===== СТРОКА ПОИСКА =====
    $searchPanel = New-Object System.Windows.Controls.Grid
    $searchPanel.Margin = "0,0,0,12"

    $sc1 = New-Object System.Windows.Controls.ColumnDefinition; $sc1.Width = "*"
    $sc2 = New-Object System.Windows.Controls.ColumnDefinition; $sc2.Width = "Auto"
    $sc3 = New-Object System.Windows.Controls.ColumnDefinition; $sc3.Width = "Auto"
    $searchPanel.ColumnDefinitions.Add($sc1)
    $searchPanel.ColumnDefinitions.Add($sc2)
    $searchPanel.ColumnDefinitions.Add($sc3)

    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Style = $window.Resources["RoundedTextBox"]
    $searchBox.FontSize = 13
    $searchBox.Height = 34
    $searchBox.Margin = "0,0,8,0"

    $placeholderText = "Поиск по всем вкладкам — по имени пакета или описанию..."

    $searchBox.Add_GotFocus({
        if ($this.Text -eq $placeholderText) {
            $this.Text = ""
            $this.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0"))
        }
    }.GetNewClosure())

    $searchBox.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($this.Text)) {
            $this.Text = $placeholderText
            $this.Foreground = [System.Windows.Media.Brushes]::Gray
        }
    }.GetNewClosure())

    $searchBox.Text = $placeholderText
    $searchBox.Foreground = [System.Windows.Media.Brushes]::Gray

    [System.Windows.Controls.Grid]::SetColumn($searchBox, 0)
    $searchPanel.Children.Add($searchBox) | Out-Null

    $searchInfo = New-Object System.Windows.Controls.TextBlock
    $searchInfo.FontSize = 11
    $searchInfo.Foreground = "#A0A0A0"
    $searchInfo.VerticalAlignment = "Center"
    $searchInfo.Margin = "0,0,8,0"
    [System.Windows.Controls.Grid]::SetColumn($searchInfo, 1)
    $searchPanel.Children.Add($searchInfo) | Out-Null

    $btnClearSearch = New-Object System.Windows.Controls.Button
    $btnClearSearch.Content = "Очистить"
    $btnClearSearch.Style = $window.Resources["RoundedButton"]
    $btnClearSearch.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnClearSearch.Padding = "12,6"
    $btnClearSearch.FontSize = 11
    $btnClearSearch.Visibility = "Collapsed"
    $btnClearSearch.Add_Click({
        $script:CleanupSearchBox.Text = ""
        $script:CleanupSearchBox.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0"))
        Update-CleanupFilter
    })
    [System.Windows.Controls.Grid]::SetColumn($btnClearSearch, 2)
    $searchPanel.Children.Add($btnClearSearch) | Out-Null

    $mainStack.Children.Add($searchPanel) | Out-Null

    # ===== КАТЕГОРИИ =====
    $allCategories = @(
        @{ Name = "Реклама и слежка"; Packages = $script:adwarePackages }
        @{ Name = "Стриминг и медиа"; Packages = $script:streamingPackages }
        @{ Name = "Лаунчеры";         Packages = $script:launcherPackages }
        @{ Name = "TCL-сервисы";      Packages = $script:tclServicesPackages }
        @{ Name = "Google-мусор";     Packages = $script:googleJunkPackages }
        @{ Name = "Системные";        Packages = $script:systemJunkPackages }
    )

    # ===== ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,10,0,0"

    $script:CleanupTabCheckboxes = @{}
    $script:CleanupTabHeaders    = @{}

    foreach ($cat in $allCategories) {
        $tab = New-Object System.Windows.Controls.TabItem
        $tab.Header = "$($cat.Name) ($($cat.Packages.Count))"
        $tab.Style = $window.Resources["MiuiTabItem"]

        $tabPanel = New-Object System.Windows.Controls.StackPanel
        $tabPanel.Margin = "15"

        # ===== ПРЕДУПРЕЖДЕНИЕ ДЛЯ ВКЛАДКИ "ЛАУНЧЕРЫ" =====
        if ($cat.Name -eq "Лаунчеры") {
            $warnCard = New-Object System.Windows.Controls.Border
            $warnCard.Background = "#3D3520"
            $warnCard.BorderBrush = "#C8C8C8"
            $warnCard.BorderThickness = "1"
            $warnCard.CornerRadius = "6"
            $warnCard.Padding = "12"
            $warnCard.Margin = "0,0,0,15"

            $warnStack = New-Object System.Windows.Controls.StackPanel

            $warnTitle = New-Object System.Windows.Controls.TextBlock
            $warnTitle.Text = "⚠️ ВНИМАНИЕ: отключение лаунчера"
            $warnTitle.FontSize = 13
            $warnTitle.FontWeight = "Bold"
            $warnTitle.Foreground = "#856404"
            $warnTitle.Margin = "0,0,0,8"
            $warnStack.Children.Add($warnTitle) | Out-Null

            $warnText = New-Object System.Windows.Controls.TextBlock
            $warnText.FontSize = 12
            $warnText.Foreground = "#856404"
            $warnText.TextWrapping = "Wrap"
            $warnText.Text = "Отключайте стандартный лаунчер ТОЛЬКО если:`n`n  1. Вы уже установили сторонний лаунчер (Projectivy, FLauncher, ATV Launcher и т.п.)`n  2. Сторонний лаунчер работает и открывается`n  3. Кнопка «Домой» на пульте ТВ открывает именно его`n  4. Вы проверили, что после нажатия Home возврат на главный экран работает`n`n❌ Если сторонний лаунчер не работает — отключение стандартного оставит вас БЕЗ ГЛАВНОГО ЭКРАНА."
            $warnStack.Children.Add($warnText) | Out-Null

            # ===== КНОПКА ВОССТАНОВЛЕНИЯ =====
            $restorePanel = New-Object System.Windows.Controls.StackPanel
            $restorePanel.Orientation = "Horizontal"
            $restorePanel.Margin = "0,12,0,0"

            $btnRestoreGoogle = New-Object System.Windows.Controls.Button
            $btnRestoreGoogle.Content = "Восстановить Google Launcher"
            $btnRestoreGoogle.Style = $window.Resources["RoundedButton"]
            $btnRestoreGoogle.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
            $btnRestoreGoogle.Padding = "12,6"
            $btnRestoreGoogle.FontSize = 11
            $btnRestoreGoogle.Margin = "0,0,8,0"
            $btnRestoreGoogle.Add_Click({
                $pkg = "com.google.android.apps.tv.launcherx"
                Write-Log -Message "Восстанавливаю стандартный Google Launcher..." -Level "Info"
                $out = & $script:adbPath shell pm enable $pkg 2>&1
                $outText = ($out | Out-String).Trim()
                if ($outText -match 'new state: enabled' -or $outText -match 'already enabled') {
                    Write-Log -Message "OK: Google Launcher включён" -Level "Success"
                    [System.Windows.MessageBox]::Show(
                        "Google Launcher восстановлен.`n`nТеперь нажмите кнопку «Домой» на пульте ТВ — должен открыться Google TV Launcher.",
                        "Готово",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information) | Out-Null
                } else {
                    Write-Log -Message "Не удалось включить: $outText" -Level "Warning"
                    [System.Windows.MessageBox]::Show(
                        "Не удалось включить Google Launcher:`n`n$outText",
                        "Ошибка",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Error) | Out-Null
                }
                Switch-View -ViewName "Cleanup"
            })
            $restorePanel.Children.Add($btnRestoreGoogle) | Out-Null

            $btnRestoreTcl = New-Object System.Windows.Controls.Button
            $btnRestoreTcl.Content = "Восстановить TCL Launcher"
            $btnRestoreTcl.Style = $window.Resources["RoundedButton"]
            $btnRestoreTcl.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6c547e")
        )
            $btnRestoreTcl.Padding = "12,6"
            $btnRestoreTcl.FontSize = 11
            $btnRestoreTcl.Add_Click({
                $pkg = "com.tcl.tv"
                Write-Log -Message "Восстанавливаю TCL Launcher..." -Level "Info"
                $out = & $script:adbPath shell pm enable $pkg 2>&1
                $outText = ($out | Out-String).Trim()
                if ($outText -match 'new state: enabled' -or $outText -match 'already enabled') {
                    Write-Log -Message "OK: TCL Launcher включён" -Level "Success"
                    [System.Windows.MessageBox]::Show(
                        "TCL Launcher восстановлен.`n`nТеперь нажмите кнопку «Домой» на пульте ТВ.",
                        "Готово",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information) | Out-Null
                } else {
                    Write-Log -Message "Не удалось включить: $outText" -Level "Warning"
                    [System.Windows.MessageBox]::Show(
                        "Не удалось включить TCL Launcher:`n`n$outText",
                        "Ошибка",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Error) | Out-Null
                }
                Switch-View -ViewName "Cleanup"
            })
            $restorePanel.Children.Add($btnRestoreTcl) | Out-Null

            $warnStack.Children.Add($restorePanel) | Out-Null

            # ===== ПОДСКАЗКА ПРО ADB =====
            $adbHint = New-Object System.Windows.Controls.TextBlock
            $adbHint.FontSize = 11
            $adbHint.Foreground = "#856404"
            $adbHint.TextWrapping = "Wrap"
            $adbHint.Margin = "0,10,0,0"
            $adbHint.Text = "Если кнопки не помогают — восстановить вручную через Сервис → Своя команда:`n    shell pm enable com.google.android.apps.tv.launcherx`n    shell pm enable com.tcl.tv"
            $warnStack.Children.Add($adbHint) | Out-Null

            $warnCard.Child = $warnStack
            $tabPanel.Children.Add($warnCard) | Out-Null
        }

        $itemsStack = New-Object System.Windows.Controls.StackPanel
        $tabPanel.Children.Add($itemsStack) | Out-Null

        $tabCheckboxes = @()

        foreach ($pkg in $cat.Packages) {
            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.Style = $window.Resources["MiuiCheckBox"]

            $isInstalled = $script:InstalledPackagesSet.ContainsKey($pkg.Package)
            $isRemoved = $script:RemovedPackages -contains $pkg.Package
            $isDisabled = $script:DisabledPackagesSet.ContainsKey($pkg.Package)

            $risk = if ($pkg.ContainsKey("Risk")) { $pkg.Risk } else { "low" }
            $riskIcon = switch ($risk) {
                "low"    { "[OK]" }
                "medium" { "[!]"  }
                "high"   { "[X]"  }
                default  { ""     }
            }
            $riskColor = switch ($risk) {
                "low"    { "#2E7D32" }
                "medium" { "#F57C00" }
                "high"   { "#C62828" }
                default  { "#FFFFFF" }
            }

            $baseText = "$riskIcon $($pkg.Desc)  ($($pkg.Package))"
            $searchData = "$($pkg.Package) $($pkg.Desc)".ToLower()

            if ($isRemoved) {
                $chk.Content = "$baseText  — Удалено"
                $chk.Foreground = [System.Windows.Media.Brushes]::Gray
                $chk.IsEnabled = $false
            } elseif ($isDisabled) {
                $chk.Content = "$baseText  — Отключено"
                $chk.Foreground = [System.Windows.Media.Brushes]::Gray
                $chk.IsEnabled = $false
            } elseif (-not $isInstalled) {
                $chk.Content = "$baseText  — Не установлено"
                $chk.Foreground = [System.Windows.Media.Brushes]::Gray
                $chk.IsEnabled = $false
            } else {
                $chk.Content = $baseText
                $chk.Tag = $pkg
                $chk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString($riskColor)
                )

                $riskText = switch ($risk) {
                    "low"    { "низкий — безопасно отключать" }
                    "medium" { "средний — отключайте с осторожностью" }
                    "high"   { "высокий — может нарушить работу ТВ" }
                }
                $chk.ToolTip = "Пакет: $($pkg.Package)`n`n$($pkg.Desc)`n`nУровень риска: $riskText"
            }

            $chk | Add-Member -MemberType NoteProperty -Name "SearchText" -Value $searchData -Force

            $itemsStack.Children.Add($chk) | Out-Null
            $tabCheckboxes += $chk
        }

        $tab.Content = $tabPanel
        $tabControl.Items.Add($tab) | Out-Null
        $script:CleanupTabCheckboxes[$cat.Name] = $tabCheckboxes
        $script:CleanupTabHeaders[$cat.Name]    = $tab
    }

    # ===== ВКЛАДКА "ДОПОЛНИТЕЛЬНО" =====
    $extraTab = New-Object System.Windows.Controls.TabItem
    $extraTab.Header = "Дополнительно"
    $extraTab.Style = $window.Resources["MiuiTabItem"]

    $extraPanel = New-Object System.Windows.Controls.StackPanel
    $extraPanel.Margin = "15"

    $knownPackages = @()
    foreach ($cat in $allCategories) {
        foreach ($pkg in $cat.Packages) {
            $knownPackages += $pkg.Package
        }
    }

    $allThirdParty = & $script:adbPath shell pm list packages -3 2>&1
    $thirdPartyPkgs = @()
    foreach ($line in $allThirdParty) {
        if ($line -match '^package:(.+)$') {
            $pkgName = $matches[1].Trim()
            if ($pkgName -notin $knownPackages) { $thirdPartyPkgs += $pkgName }
        }
    }

    $allSystem = & $script:adbPath shell pm list packages -s 2>&1
    $systemPkgs = @()
    foreach ($line in $allSystem) {
        if ($line -match '^package:(.+)$') {
            $pkgName = $matches[1].Trim()
            if ($pkgName -notin $knownPackages) { $systemPkgs += $pkgName }
        }
    }

    $extraInfo = New-ViewLabel -Text "Пакеты, не описанные в категориях." -Light
    $extraInfo.TextWrapping = "Wrap"
    $extraInfo.Margin = "0,0,0,10"
    $extraPanel.Children.Add($extraInfo) | Out-Null

    $extraSubTabs = New-Object System.Windows.Controls.TabControl
    $extraSubTabs.Style = $window.Resources["MiuiTabControlTemplate"]

    # --- Сторонние ---
    $tpTab = New-Object System.Windows.Controls.TabItem
    $tpTab.Header = "Сторонние ($($thirdPartyPkgs.Count))"
    $tpTab.Style = $window.Resources["MiuiTabItem"]

    $tpPanel = New-Object System.Windows.Controls.StackPanel
    $tpPanel.Margin = "10"

    $tpCheckboxes = @()
    foreach ($pkgName in $thirdPartyPkgs) {
        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]
        $chk.Content = $pkgName

        $isRemoved = $script:RemovedPackages -contains $pkgName
        $isDisabled = $script:DisabledPackagesSet.ContainsKey($pkgName)

        if ($isRemoved) {
            $chk.Content = "$pkgName  — Удалено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
        } elseif ($isDisabled) {
            $chk.Content = "$pkgName  — Отключено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
        } else {
            $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(сторонний)"; Risk = "low" }
        }

        $chk | Add-Member -MemberType NoteProperty -Name "SearchText" -Value "$pkgName (сторонний)".ToLower() -Force

        $tpPanel.Children.Add($chk) | Out-Null
        $tpCheckboxes += $chk
    }
    $tpTab.Content = $tpPanel
    $extraSubTabs.Items.Add($tpTab) | Out-Null
    $script:CleanupTabCheckboxes["Сторонние"] = $tpCheckboxes
    $script:CleanupTabHeaders["Сторонние"]    = $tpTab

    # --- Системные ---
    $sysTab = New-Object System.Windows.Controls.TabItem
    $sysTab.Header = "Системные ($($systemPkgs.Count))"
    $sysTab.Style = $window.Resources["MiuiTabItem"]

    $sysPanel = New-Object System.Windows.Controls.StackPanel
    $sysPanel.Margin = "10"

    $sysWarn = New-ViewLabel -Text "Внимание: изменение системных пакетов может нарушить работу ТВ." -Light
    $sysWarn.TextWrapping = "Wrap"
    $sysWarn.Margin = "0,0,0,10"
    $sysPanel.Children.Add($sysWarn) | Out-Null

    $sysCheckboxes = @()
    foreach ($pkgName in $systemPkgs) {
        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]
        $chk.Content = $pkgName

        $isRemoved = $script:RemovedPackages -contains $pkgName
        $isDisabled = $script:DisabledPackagesSet.ContainsKey($pkgName)

        if ($isRemoved) {
            $chk.Content = "$pkgName  — Удалено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
        } elseif ($isDisabled) {
            $chk.Content = "$pkgName  — Отключено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
        } else {
            $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(системный)"; Risk = "high" }
            $chk.Foreground = [System.Windows.Media.Brushes]::DarkRed
        }

        $chk | Add-Member -MemberType NoteProperty -Name "SearchText" -Value "$pkgName (системный)".ToLower() -Force

        $sysPanel.Children.Add($chk) | Out-Null
        $sysCheckboxes += $chk
    }
    $sysTab.Content = $sysPanel
    $extraSubTabs.Items.Add($sysTab) | Out-Null
    $script:CleanupTabCheckboxes["Системные (доп)"] = $sysCheckboxes
    $script:CleanupTabHeaders["Системные (доп)"]    = $sysTab

    $extraPanel.Children.Add($extraSubTabs) | Out-Null
    $extraTab.Content = $extraPanel
    $tabControl.Items.Add($extraTab) | Out-Null

    # ===== ПАНЕЛЬ РЕЗУЛЬТАТОВ СКВОЗНОГО ПОИСКА =====
    $script:CleanupResultsPanel = New-Object System.Windows.Controls.StackPanel
    $script:CleanupResultsPanel.Margin = "0,10,0,0"
    $script:CleanupResultsPanel.Visibility = "Collapsed"

    $tabControl = $tabControl   # сохраняем ссылку

    $mainStack.Children.Add($tabControl) | Out-Null
    $mainStack.Children.Add($script:CleanupResultsPanel) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ========================================================================
    #  СОХРАНЯЕМ ССЫЛКИ
    # ========================================================================
    $script:CleanupSearchBox      = $searchBox
    $script:CleanupSearchInfo     = $searchInfo
    $script:CleanupPlaceholder    = $placeholderText
    $script:CleanupClearBtn       = $btnClearSearch
    $script:CleanupTabControl     = $tabControl

    $searchBox.Add_TextChanged({
        Update-CleanupFilter
    })

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()
    $script:CleanupAllCheckboxes = @()
    foreach ($key in $script:CleanupTabCheckboxes.Keys) {
        $script:CleanupAllCheckboxes += $script:CleanupTabCheckboxes[$key]
    }

    # "Выбрать всё"
    $btnSelectAll = New-Object System.Windows.Controls.Button
    $btnSelectAll.Content = "Выбрать всё"
    $btnSelectAll.Style = $window.Resources["RoundedButton"]
    $btnSelectAll.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#4e7891")
        )
    $btnSelectAll.Padding = "12,6"
    $btnSelectAll.Margin = "0,0,8,0"
    $btnSelectAll.Add_Click({
        foreach ($chk in $script:CleanupAllCheckboxes) {
            if ($chk.IsEnabled -eq $true -and $chk.Visibility -eq "Visible") {
                $chk.IsChecked = $true
            }
        }
    })
    $buttons += $btnSelectAll

    # "Снять всё"
    $btnDeselect = New-Object System.Windows.Controls.Button
    $btnDeselect.Content = "Снять всё"
    $btnDeselect.Style = $window.Resources["RoundedButton"]
    $btnDeselect.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
        )
    $btnDeselect.Padding = "12,6"
    $btnDeselect.Margin = "0,0,8,0"
    $btnDeselect.Add_Click({
        foreach ($chk in $script:CleanupAllCheckboxes) { $chk.IsChecked = $false }
    })
    $buttons += $btnDeselect

    # "Отключить"
    $btnDisable = New-Object System.Windows.Controls.Button
    $btnDisable.Content = "Отключить"
    $btnDisable.Style = $window.Resources["RoundedButton"]
    $btnDisable.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
        )
    $btnDisable.Padding = "12,6"
    $btnDisable.Margin = "0,0,8,0"
    $btnDisable.Add_Click({
        $selected = @()
        foreach ($chk in $script:CleanupAllCheckboxes) {
            if ($chk.IsChecked -eq $true -and $chk.IsEnabled -eq $true) {
                $selected += $chk.Tag
            }
        }
        if ($selected.Count -eq 0) {
            Write-Log -Message "Ничего не выбрано" -Level "Warning"
            return
        }

        $highRisk = @($selected | Where-Object { $_.Risk -eq "high" })
        if ($highRisk.Count -gt 0) {
            $names = ($highRisk | ForEach-Object { $_.Package }) -join "`n"
            $confirm = [System.Windows.MessageBox]::Show(
                "ВНИМАНИЕ: среди выбранных пакетов есть с высоким риском:`n`n$names`n`nОтключение этих пакетов может нарушить работу ТВ. Продолжить?",
                "Высокий риск",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Отключить $($selected.Count) пакетов?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Отключаю $($selected.Count) пакетов..." -Level "Info"
        $success = 0
        foreach ($pkg in $selected) {
            if (Disable-Package -Package $pkg.Package) {
                $success++
                Save-Change -Type "package_disabled" -Target $pkg.Package -RestoreCommand "adb shell pm enable $($pkg.Package)"
            }
        }
        Save-AllChanges
        Write-Log -Message "Отключено: $success из $($selected.Count)" -Level "Success"
        Switch-View -ViewName "Cleanup"
    })
    $buttons += $btnDisable

    # "Удалить"
    $btnDelete = New-Object System.Windows.Controls.Button
    $btnDelete.Content = "Удалить"
    $btnDelete.Style = $window.Resources["RoundedButton"]
    $btnDelete.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
    $btnDelete.Padding = "12,6"
    $btnDelete.Margin = "0,0,8,0"
    $btnDelete.Add_Click({
        $selected = @()
        foreach ($chk in $script:CleanupAllCheckboxes) {
            if ($chk.IsChecked -eq $true -and $chk.IsEnabled -eq $true) {
                $selected += $chk.Tag
            }
        }
        if ($selected.Count -eq 0) {
            Write-Log -Message "Ничего не выбрано" -Level "Warning"
            return
        }

        $highRisk = @($selected | Where-Object { $_.Risk -eq "high" -or $_.Risk -eq "medium" })
        if ($highRisk.Count -gt 0) {
            $names = ($highRisk | ForEach-Object { $_.Package }) -join "`n"
            $confirm = [System.Windows.MessageBox]::Show(
                "ВНИМАНИЕ: среди выбранных пакетов есть рискованные:`n`n$names`n`nУдаление этих пакетов может нарушить работу ТВ. Продолжить?",
                "Высокий риск",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }

        # --- ДИАЛОГ ВЫБОРА МЕТОДА УДАЛЕНИЯ ---
        $choiceDialog = New-Object System.Windows.Window
        $choiceDialog.Title = "Как удалить?"
        $choiceDialog.Width = 520
        $choiceDialog.Height = 340
        $choiceDialog.WindowStartupLocation = "CenterOwner"
        $choiceDialog.Owner = $window
        $choiceDialog.Background = "#202020"

        $cStack = New-Object System.Windows.Controls.StackPanel
        $cStack.Margin = "25"

        $cHeader = New-Object System.Windows.Controls.TextBlock
        $cHeader.Text = "Выбрано пакетов: $($selected.Count)"
        $cHeader.FontSize = 16
        $cHeader.FontWeight = "Bold"
        $cHeader.Margin = "0,0,0,10"
        $cStack.Children.Add($cHeader) | Out-Null

        $cInfo = New-Object System.Windows.Controls.TextBlock
        $cInfo.Text = "Выберите метод удаления. Если не уверены — оставьте «Автоматически»."
        $cInfo.FontSize = 12
        $cInfo.Foreground = "#A0A0A0"
        $cInfo.TextWrapping = "Wrap"
        $cInfo.Margin = "0,0,0,15"
        $cStack.Children.Add($cInfo) | Out-Null

        $script:DeleteChoice = "auto"

        $radioAuto = New-Object System.Windows.Controls.RadioButton
        $radioAuto.Content = "Автоматически (рекомендуется)"
        $radioAuto.GroupName = "DeleteMode"
        $radioAuto.IsChecked = $true
        $radioAuto.FontSize = 13
        $radioAuto.Margin = "0,0,0,8"
        $radioAuto.Add_Click({ $script:DeleteChoice = "auto" })
        $cStack.Children.Add($radioAuto) | Out-Null

        $radioUser0 = New-Object System.Windows.Controls.RadioButton
        $radioUser0.Content = "Только для текущего пользователя (user 0)"
        $radioUser0.GroupName = "DeleteMode"
        $radioUser0.FontSize = 13
        $radioUser0.Margin = "0,0,0,8"
        $radioUser0.Add_Click({ $script:DeleteChoice = "user0" })
        $cStack.Children.Add($radioUser0) | Out-Null

        $radioAll = New-Object System.Windows.Controls.RadioButton
        $radioAll.Content = "Для всех пользователей"
        $radioAll.GroupName = "DeleteMode"
        $radioAll.FontSize = 13
        $radioAll.Margin = "0,0,0,8"
        $radioAll.Add_Click({ $script:DeleteChoice = "all" })
        $cStack.Children.Add($radioAll) | Out-Null

        $radioDisable = New-Object System.Windows.Controls.RadioButton
        $radioDisable.Content = "Не удалять, а отключить (для системных)"
        $radioDisable.GroupName = "DeleteMode"
        $radioDisable.FontSize = 13
        $radioDisable.Margin = "0,0,0,15"
        $radioDisable.Add_Click({ $script:DeleteChoice = "disable" })
        $cStack.Children.Add($radioDisable) | Out-Null

        $cBtnPanel = New-Object System.Windows.Controls.StackPanel
        $cBtnPanel.Orientation = "Horizontal"
        $cBtnPanel.HorizontalAlignment = "Right"

        $btnOk = New-Object System.Windows.Controls.Button
        $btnOk.Content = "Продолжить"
        $btnOk.Style = $window.Resources["RoundedButton"]
        $btnOk.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
        $btnOk.Padding = "15,8"
        $btnOk.Margin = "0,0,8,0"
        $btnOk.Add_Click({
            $mode = $script:DeleteChoice
            $choiceDialog.Close()

            Write-Log -Message "Обрабатываю $($selected.Count) пакетов (режим: $mode)..." -Level "Info"
            $success = 0
            $failed = 0
            foreach ($pkg in $selected) {
                $result = Remove-Package -Package $pkg.Package -Mode $mode
                if ($result.Success) {
                    $success++
                    if ($script:RemovedPackages -notcontains $pkg.Package) {
                        $script:RemovedPackages += $pkg.Package
                    }

                    $restoreCmd = switch ($result.Method) {
                        "user0"   { "adb shell cmd package install-existing $($pkg.Package)" }
                        "all"     { "adb shell cmd package install-existing $($pkg.Package)" }
                        "disable" { "adb shell pm enable $($pkg.Package)" }
                        default   { "adb shell cmd package install-existing $($pkg.Package)" }
                    }
                    Save-Change -Type "package_removed" -Target $pkg.Package -RestoreCommand $restoreCmd
                } else {
                    $failed++
                }
            }
            Save-AllChanges
            Write-Log -Message "Готово: успешно $success, не удалось $failed из $($selected.Count)" -Level "Success"
            Switch-View -ViewName "Cleanup"
        })
        $cBtnPanel.Children.Add($btnOk) | Out-Null

        $btnCancel = New-Object System.Windows.Controls.Button
        $btnCancel.Content = "Отмена"
        $btnCancel.Style = $window.Resources["RoundedButton"]
        $btnCancel.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
        )
        $btnCancel.Padding = "15,8"
        $btnCancel.Add_Click({ $choiceDialog.Close() })
        $cBtnPanel.Children.Add($btnCancel) | Out-Null

        $cStack.Children.Add($cBtnPanel) | Out-Null

        $choiceDialog.Content = $cStack
        $choiceDialog.ShowDialog() | Out-Null
    })
    $buttons += $btnDelete

    # "Очистить данные"
    $btnClearData = New-Object System.Windows.Controls.Button
    $btnClearData.Content = "Очистить данные"
    $btnClearData.Style = $window.Resources["RoundedButton"]
    $btnClearData.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6c547e")
        )
    $btnClearData.Padding = "12,6"
    $btnClearData.Add_Click({
        $selected = @()
        foreach ($chk in $script:CleanupAllCheckboxes) {
            if ($chk.IsChecked -eq $true -and $chk.IsEnabled -eq $true) {
                $selected += $chk.Tag
            }
        }
        if ($selected.Count -eq 0) {
            Write-Log -Message "Ничего не выбрано" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Очистить данные (кэш, настройки, аккаунты) для $($selected.Count) приложений?`n`nВНИМАНИЕ: это может привести к:`n  • потере настроек приложений`n  • выходу из аккаунтов (YouTube, Кинопоиск и т.д.)`n  • необходимости повторной настройки`n`nПродолжить?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Очищаю данные $($selected.Count) приложений..." -Level "Info"
        $success = 0
        foreach ($pkg in $selected) {
            if (Clear-AppCache -Package $pkg.Package) { $success++ }
        }
        Write-Log -Message "Очищено: $success из $($selected.Count)" -Level "Success"
        Switch-View -ViewName "Cleanup"
    })
    $buttons += $btnClearData

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран управления пакетами (5 вкладок, сквозной поиск)" -Level "Info"
}

# ============================================================================
#  ЭКРАН "ОТКЛЮЧЁННЫЕ ПРИЛОЖЕНИЯ"
# ============================================================================
function Show-DisabledAppsView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Отключённые приложения"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Пакеты, которые сейчас отключены. Отметьте нужные и нажмите «Включить»." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    Write-Log -Message "Читаю отключённые пакеты..." -Level "Info"
    $script:DisabledPackagesSet = Get-DisabledPackagesSet
    Write-Log -Message "Отключено: $($script:DisabledPackagesSet.Count)" -Level "Info"

    $disabledList = @()
    foreach ($pkgName in $script:DisabledPackagesSet.Keys) {
        $disabledList += $pkgName
    }

    if ($disabledList.Count -eq 0) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет отключённых приложений.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    $script:DisabledAppsCheckboxes = @()
    foreach ($pkgName in $disabledList) {
        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]
        $chk.Content = "$pkgName  — Отключено"
        $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(отключён)"; Risk = "low" }
        $mainStack.Children.Add($chk) | Out-Null
        $script:DisabledAppsCheckboxes += $chk
    }

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ =====
    $buttons = @()

    $btnSelectAll = New-Object System.Windows.Controls.Button
    $btnSelectAll.Content = "Выбрать всё"
    $btnSelectAll.Style = $window.Resources["RoundedButton"]
    $btnSelectAll.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#4e7891")
        )
    $btnSelectAll.Padding = "12,6"
    $btnSelectAll.Margin = "0,0,8,0"
    $btnSelectAll.Add_Click({
        foreach ($chk in $script:DisabledAppsCheckboxes) { $chk.IsChecked = $true }
    })
    $buttons += $btnSelectAll

    $btnDeselect = New-Object System.Windows.Controls.Button
    $btnDeselect.Content = "Снять всё"
    $btnDeselect.Style = $window.Resources["RoundedButton"]
    $btnDeselect.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
        )
    $btnDeselect.Padding = "12,6"
    $btnDeselect.Margin = "0,0,8,0"
    $btnDeselect.Add_Click({
        foreach ($chk in $script:DisabledAppsCheckboxes) { $chk.IsChecked = $false }
    })
    $buttons += $btnDeselect

    $btnEnable = New-Object System.Windows.Controls.Button
    $btnEnable.Content = "Включить"
    $btnEnable.Style = $window.Resources["RoundedButton"]
    $btnEnable.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
        )
    $btnEnable.Padding = "12,6"
    $btnEnable.Add_Click({
        $selected = @()
        foreach ($chk in $script:DisabledAppsCheckboxes) {
            if ($chk.IsChecked -eq $true) { $selected += $chk.Tag }
        }
        if ($selected.Count -eq 0) {
            Write-Log -Message "Ничего не выбрано" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Включить $($selected.Count) пакетов обратно?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Включаю $($selected.Count) пакетов..." -Level "Info"
        $success = 0
        foreach ($pkg in $selected) {
            if (Enable-Package -Package $pkg.Package) { $success++ }
        }
        Write-Log -Message "Включено: $success из $($selected.Count)" -Level "Success"
        Switch-View -ViewName "DisabledApps"
    })
    $buttons += $btnEnable

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран отключённых приложений" -Level "Info"
}