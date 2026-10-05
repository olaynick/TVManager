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

    if ($query) {
        $script:CleanupTabControl.Visibility = "Collapsed"
        $script:CleanupResultsPanel.Visibility = "Visible"
        $script:CleanupResultsPanel.Children.Clear()

        $totalVisible = 0

        foreach ($catName in $script:CleanupTabCheckboxes.Keys) {
            $checkboxes = $script:CleanupTabCheckboxes[$catName]

            $catHeader = New-Object System.Windows.Controls.TextBlock
            $catHeader.Text = "📁 $catName"
            $catHeader.FontSize = 12
            $catHeader.FontWeight = "Bold"
            $catHeader.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
            )
            $catHeader.Margin = "0,10,0,5"

            $catMatches = @()

            foreach ($chk in $checkboxes) {
                $searchText = ""
                if ($chk.PSObject.Properties["SearchText"]) {
                    $searchText = $chk.SearchText
                }

                if ($searchText -like "*$query*") {
                    $copy = New-Object System.Windows.Controls.CheckBox
                    $copy.Style = $window.Resources["MiuiCheckBox"]
                    $copy.Content = $chk.Content
                    $copy.Foreground = $chk.Foreground
                    $copy.IsEnabled = $chk.IsEnabled
                    $copy.IsChecked = $chk.IsChecked
                    $copy.Tag = $chk.Tag
                    $copy.ToolTip = $chk.ToolTip
                    $copy | Add-Member -MemberType NoteProperty -Name "SearchText" -Value $searchText -Force

                    $original = $chk
                    $copy.Add_Click({
                        $original.IsChecked = $this.IsChecked
                    }.GetNewClosure())

                    $catMatches += $copy
                    $totalVisible++
                }
            }

            if ($catMatches.Count -gt 0) {
                $script:CleanupResultsPanel.Children.Add($catHeader) | Out-Null
                $catList = New-VirtualizedCheckboxList -Checkboxes $catMatches -MaxHeight 400
                $script:CleanupResultsPanel.Children.Add($catList) | Out-Null
            }
        }

        if ($totalVisible -eq 0) {
            $empty = New-Object System.Windows.Controls.TextBlock
            $empty.Text = "Ничего не найдено по запросу: $query"
            $empty.FontSize = 13
            $empty.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
            )
            $empty.Margin = "20"
            $script:CleanupResultsPanel.Children.Add($empty) | Out-Null
        }

        $script:CleanupSearchInfo.Text = "Найдено: $totalVisible"
    }
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

    $desc = New-ViewLabel -Text "«Отключить» — пакет остаётся в системе. «Удалить» — данные стираются. «Очистить данные» — сброс кэша и настроек. Обозначения: 🛡 — защищён (нельзя изменить), ⚠️ — требует подтверждения, [OK] — безопасно, [!] — осторожно, [X] — может сломать ТВ." -Light
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

            $isCritical = $false
            $critReason = ""
            $critRisk = ""
            if (Get-Command Test-CriticalPackage -ErrorAction SilentlyContinue) {
                $critCheck = Test-CriticalPackage -Package $pkg.Package
                if ($critCheck.IsCritical) {
                    $isCritical = $true
                    $critReason = $critCheck.Reason
                    $critRisk = $critCheck.Risk
                }
            }

            $baseText = "$riskIcon $($pkg.Desc)  ($($pkg.Package))"
            if ($isCritical) {
                if ($critRisk -eq "block") {
                    $baseText = "🛡 $baseText"
                } else {
                    $baseText = "⚠️ $baseText"
                }
            }
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
                if ($isCritical -and $critRisk -eq "block") {
                    $chk.Foreground = [System.Windows.Media.SolidColorBrush](
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#9C27B0")
                    )
                } elseif ($isCritical -and $critRisk -eq "warn") {
                    $chk.Foreground = [System.Windows.Media.SolidColorBrush](
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#F57C00")
                    )
                } else {
                    $chk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                        [System.Windows.Media.ColorConverter]::ConvertFromString($riskColor)
                    )
                }

                $riskText = switch ($risk) {
                    "low"    { "низкий — безопасно отключать" }
                    "medium" { "средний — отключайте с осторожностью" }
                    "high"   { "высокий — может нарушить работу ТВ" }
                }

                $critText = ""
                if ($isCritical) {
                    if ($critRisk -eq "block") {
                        $critText = "`n`n🛡 ЗАЩИЩЁН: $critReason`n(изменение запрещено полностью)"
                    } else {
                        $critText = "`n`n⚠️ ТРЕБУЕТ ПОДТВЕРЖДЕНИЯ: $critReason`n(можно изменить, но с подтверждением)"
                    }
                }

                $chk.ToolTip = "Пакет: $($pkg.Package)`n`n$($pkg.Desc)`n`nУровень риска: $riskText$critText"
            }

            $chk | Add-Member -MemberType NoteProperty -Name "SearchText" -Value $searchData -Force

            $tabCheckboxes += $chk
        }

        if ($tabCheckboxes.Count -gt 0) {
            $itemsList = New-VirtualizedCheckboxList -Checkboxes $tabCheckboxes -MaxHeight 500
            $tabPanel.Children.Add($itemsList) | Out-Null
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

        $tpCheckboxes += $chk
    }

    if ($tpCheckboxes.Count -gt 0) {
        $tpList = New-VirtualizedCheckboxList -Checkboxes $tpCheckboxes -MaxHeight 500
        $tpPanel.Children.Add($tpList) | Out-Null
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

    $sysWarn = New-ViewLabel -Text "Внимание: изменение системных пакетов может нарушить работу ТВ. Обозначения: 🛡 — защищён, ⚠️ — требует подтверждения." -Light
    $sysWarn.TextWrapping = "Wrap"
    $sysWarn.Margin = "0,0,0,10"
    $sysPanel.Children.Add($sysWarn) | Out-Null

    $sysCheckboxes = @()
    foreach ($pkgName in $systemPkgs) {
        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]

        $isRemoved = $script:RemovedPackages -contains $pkgName
        $isDisabled = $script:DisabledPackagesSet.ContainsKey($pkgName)

        $isCritical = $false
        $critReason = ""
        $critRisk = ""
        if (Get-Command Test-CriticalPackage -ErrorAction SilentlyContinue) {
            $critCheck = Test-CriticalPackage -Package $pkgName
            if ($critCheck.IsCritical) {
                $isCritical = $true
                $critReason = $critCheck.Reason
                $critRisk = $critCheck.Risk
            }
        }

        $prefix = ""
        if ($isCritical) {
            if ($critRisk -eq "block") {
                $prefix = "🛡 "
            } else {
                $prefix = "⚠️ "
            }
        }

        if ($isRemoved) {
            $chk.Content = "$prefix$pkgName  — Удалено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
        } elseif ($isDisabled) {
            $chk.Content = "$prefix$pkgName  — Отключено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
        } else {
            $chk.Content = "$prefix$pkgName"
            $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(системный)"; Risk = "high" }
            if ($isCritical -and $critRisk -eq "block") {
                $chk.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#9C27B0")
                )
                $chk.ToolTip = "🛡 ЗАЩИЩЁН: $critReason`n(изменение запрещено полностью)"
            } elseif ($isCritical -and $critRisk -eq "warn") {
                $chk.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#F57C00")
                )
                $chk.ToolTip = "⚠️ ТРЕБУЕТ ПОДТВЕРЖДЕНИЯ: $critReason`n(можно изменить с подтверждением)"
            } else {
                $chk.Foreground = [System.Windows.Media.Brushes]::DarkRed
            }
        }

        $chk | Add-Member -MemberType NoteProperty -Name "SearchText" -Value "$pkgName (системный)".ToLower() -Force

        $sysCheckboxes += $chk
    }

    if ($sysCheckboxes.Count -gt 0) {
        $sysList = New-VirtualizedCheckboxList -Checkboxes $sysCheckboxes -MaxHeight 500
        $sysPanel.Children.Add($sysList) | Out-Null
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

    # ========================================================================
    #  КНОПКИ BOTTOM BAR
    # ========================================================================
    $buttons = @()
    $script:CleanupAllCheckboxes = @()
    foreach ($key in $script:CleanupTabCheckboxes.Keys) {
        $script:CleanupAllCheckboxes += $script:CleanupTabCheckboxes[$key]
    }

    # ========================================================================
    #  "ВЫБРАТЬ ВСЁ"
    # ========================================================================
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

    # ========================================================================
    #  "СНЯТЬ ВСЁ"
    # ========================================================================
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

    # ========================================================================
    #  "ОТКЛЮЧИТЬ"
    # ========================================================================
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

        $blocked = @()
        $warned  = @()
        $allowed = @()

        foreach ($pkg in $selected) {
            $check = Test-PackageOperation -Package $pkg.Package -Operation "disable"
            if (-not $check.Allowed) {
                $blocked += @{ Pkg = $pkg.Package; Reason = $check.Reason }
            } elseif ($check.NeedConfirm) {
                $warned += $pkg
            } else {
                $allowed += $pkg
            }
        }

        if ($blocked.Count -gt 0) {
            $blockedText = ($blocked | ForEach-Object { "• $($_.Pkg)`n  $($_.Reason)" }) -join "`n`n"
            [System.Windows.MessageBox]::Show(
                "Следующие пакеты ЗАЩИЩЕНЫ (🛡) и не будут изменены:`n`n$blockedText",
                "Заблокировано",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }

        $finalList = @($allowed)
        if ($warned.Count -gt 0) {
            $warnedText = ($warned | ForEach-Object { "• $($_.Package) — $($_.Desc)" }) -join "`n"
            $confirm = [System.Windows.MessageBox]::Show(
                "ВНИМАНИЕ (⚠️)! Отключение следующих пакетов может нарушить работу ТВ:`n`n$warnedText`n`nПродолжить?",
                "Требуется подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                $finalList = @($allowed) + @($warned)
            }
        }

        if ($finalList.Count -eq 0) {
            Write-Log -Message "Нечего отключать — все выбранные пакеты защищены" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Отключить $($finalList.Count) пакетов?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Отключаю $($finalList.Count) пакетов..." -Level "Info"
        $success = 0
        $connectionLost = $false
        $processedCount = 0

        for ($i = 0; $i -lt $finalList.Count; $i++) {
            $pkg = $finalList[$i]

            # ===== ПРОВЕРКА СВЯЗИ ПЕРЕД КАЖДОЙ ОПЕРАЦИЕЙ =====
            if (-not (Test-ConnectionQuick)) {
                Write-Log -Message "СВЯЗЬ С ТВ ПОТЕРЯНА на пакете $($i+1) из $($finalList.Count)" -Level "Error"
                Write-Log -Message "  Обработано успешно: $success" -Level "Info"
                Write-Log -Message "  Не обработано: $($finalList.Count - $processedCount)" -Level "Info"
                $connectionLost = $true
                break
            }

            if (Disable-Package -Package $pkg.Package) {
                $success++
                Save-Change -Type "package_disabled" -Target $pkg.Package -RestoreCommand "adb shell pm enable $($pkg.Package)"
            }
            $processedCount++
        }

        Save-AllChanges

        if ($connectionLost) {
            Write-Log -Message "=== Операция прервана: успешно $success из $($finalList.Count) ===" -Level "Warning"
            [System.Windows.MessageBox]::Show(
                "Связь с телевизором потеряна.`n`nОбработано: $success из $($finalList.Count) пакетов.`nНе обработано: $($finalList.Count - $processedCount).`n`nПодключитесь к ТВ заново и повторите операцию для оставшихся пакетов.",
                "Потеря связи",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
        } else {
            Write-Log -Message "Отключено: $success из $($finalList.Count)" -Level "Success"
        }
        Switch-View -ViewName "Cleanup"
    })
    $buttons += $btnDisable

    # ========================================================================
    #  "УДАЛИТЬ"
    # ========================================================================
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

        $blocked = @()
        $warned  = @()
        $allowed = @()

        foreach ($pkg in $selected) {
            $check = Test-PackageOperation -Package $pkg.Package -Operation "remove"
            if (-not $check.Allowed) {
                $blocked += @{ Pkg = $pkg.Package; Reason = $check.Reason }
            } elseif ($check.NeedConfirm) {
                $warned += $pkg
            } else {
                $allowed += $pkg
            }
        }

        if ($blocked.Count -gt 0) {
            $blockedText = ($blocked | ForEach-Object { "• $($_.Pkg)`n  $($_.Reason)" }) -join "`n`n"
            [System.Windows.MessageBox]::Show(
                "Следующие пакеты ЗАЩИЩЕНЫ (🛡) и не будут удалены:`n`n$blockedText",
                "Заблокировано",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }

        $finalList = @($allowed)
        if ($warned.Count -gt 0) {
            $warnedText = ($warned | ForEach-Object { "• $($_.Package) — $($_.Desc)" }) -join "`n"
            $confirm = [System.Windows.MessageBox]::Show(
                "ВНИМАНИЕ (⚠️)! Удаление следующих пакетов может нарушить работу ТВ:`n`n$warnedText`n`nПродолжить?",
                "Требуется подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                $finalList = @($allowed) + @($warned)
            }
        }

        if ($finalList.Count -eq 0) {
            Write-Log -Message "Нечего удалять — все выбранные пакеты защищены" -Level "Warning"
            return
        }

        $highRisk = @($finalList | Where-Object { $_.Risk -eq "high" -or $_.Risk -eq "medium" })
        if ($highRisk.Count -gt 0) {
            $names = ($highRisk | ForEach-Object { $_.Package }) -join "`n"
            $confirm = [System.Windows.MessageBox]::Show(
                "Дополнительно: среди выбранных есть рискованные:`n`n$names`n`nПродолжить?",
                "Высокий риск",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
        }

        # ===== Диалог выбора метода =====
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
        $cHeader.Text = "Выбрано пакетов: $($finalList.Count)"
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
        $btnOk.Tag = @{ FinalList = $finalList }
        $btnOk.Add_Click({
            param($sender, $e)
            $mode = $script:DeleteChoice
            $list = $sender.Tag.FinalList
            $choiceDialog.Close()

            Write-Log -Message "Обрабатываю $($list.Count) пакетов (режим: $mode)..." -Level "Info"
            $success = 0
            $failed = 0
            $connectionLost = $false
            $processedCount = 0

            for ($i = 0; $i -lt $list.Count; $i++) {
                $pkg = $list[$i]

                # ===== ПРОВЕРКА СВЯЗИ =====
                if (-not (Test-ConnectionQuick)) {
                    Write-Log -Message "СВЯЗЬ С ТВ ПОТЕРЯНА на пакете $($i+1) из $($list.Count)" -Level "Error"
                    $connectionLost = $true
                    break
                }

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
                $processedCount++
            }
            Save-AllChanges

            if ($connectionLost) {
                Write-Log -Message "=== Операция прервана: успешно $success, ошибок $failed из $($list.Count) ===" -Level "Warning"
                [System.Windows.MessageBox]::Show(
                    "Связь с телевизором потеряна.`n`nОбработано: $($success + $failed) из $($list.Count) пакетов.`nУспешно: $success, ошибок: $failed.`n`nПодключитесь к ТВ заново и повторите для оставшихся.",
                    "Потеря связи",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
            } else {
                Write-Log -Message "Готово: успешно $success, не удалось $failed из $($list.Count)" -Level "Success"
            }
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

    # ========================================================================
    #  "ОЧИСТИТЬ ДАННЫЕ"
    # ========================================================================
    $btnClearData = New-Object System.Windows.Controls.Button
    $btnClearData.Content = "Очистить данные"
    $btnClearData.Style = $window.Resources["RoundedButton"]
    $btnClearData.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6c547e")
    )
    $btnClearData.Padding = "12,6"
    $btnClearData.Margin = "0,0,8,0"
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

        $blocked = @()
        $finalList = @()
        foreach ($pkg in $selected) {
            $check = Test-PackageOperation -Package $pkg.Package -Operation "clear"
            if (-not $check.Allowed) {
                $blocked += @{ Pkg = $pkg.Package; Reason = $check.Reason }
            } else {
                $finalList += $pkg
            }
        }

        if ($blocked.Count -gt 0) {
            $blockedText = ($blocked | ForEach-Object { "• $($_.Pkg)`n  $($_.Reason)" }) -join "`n`n"
            [System.Windows.MessageBox]::Show(
                "Следующие пакеты ЗАЩИЩЕНЫ (🛡) и не будут очищены:`n`n$blockedText",
                "Заблокировано",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }

        if ($finalList.Count -eq 0) {
            Write-Log -Message "Нечего очищать" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Очистить данные (кэш, настройки, аккаунты) для $($finalList.Count) приложений?`n`nВНИМАНИЕ: это может привести к:`n  • потере настроек приложений`n  • выходу из аккаунтов (YouTube, Кинопоиск и т.д.)`n  • необходимости повторной настройки`n`nПродолжить?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Очищаю данные $($finalList.Count) приложений..." -Level "Info"
        $success = 0
        foreach ($pkg in $finalList) {
            if (Clear-AppCache -Package $pkg.Package) { $success++ }
        }
        Write-Log -Message "Очищено: $success из $($finalList.Count)" -Level "Success"
        Switch-View -ViewName "Cleanup"
    })
    $buttons += $btnClearData

    # ========================================================================
    #  "СКАЧАТЬ APK" (в фоне)
    # ========================================================================
    $btnDownloadApk = New-Object System.Windows.Controls.Button
    $btnDownloadApk.Content = "Скачать APK"
    $btnDownloadApk.Style = $window.Resources["RoundedButton"]
    $btnDownloadApk.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4e7891")
    )
    $btnDownloadApk.Padding = "12,6"
    $btnDownloadApk.Margin = "0,0,8,0"
    $btnDownloadApk.Add_Click({
        param($sender, $e)

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

        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Выберите папку для сохранения APK"
        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $folder = $dlg.SelectedPath

        $sender.IsEnabled = $false
        $sender.Content = "Скачиваю..."

        $pkgs = @()
        foreach ($pkg in $selected) {
            $name = $pkg.Package
            if ($script:InstalledPackagesSet.ContainsKey($name)) {
                $pkgs += $name
            } else {
                Write-Log -Message "Пропущен (не установлен): $name" -Level "Warning"
            }
        }

        if ($pkgs.Count -eq 0) {
            $sender.IsEnabled = $true
            $sender.Content = "Скачать APK"
            Write-Log -Message "Нечего скачивать" -Level "Warning"
            return
        }

        Write-Log -Message "=== Скачивание $($pkgs.Count) APK в $folder ===" -Level "Info"

        $logBoxRef  = $script:LogBox
        $adbPathRef = $script:adbPath
        $btnRef = $sender

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()

        $ps = [powershell]::Create()
        $ps.Runspace = $runspace

        $ps.AddScript({
            param($logBox, $adbPath, $pkgs, $folder)

            function Write-BgLog {
                param($msg, $lvl = "Info")
                if (-not $logBox) { return }
                try {
                    $logBox.Dispatcher.Invoke([action]{
                        $time = Get-Date -Format "HH:mm:ss"
                        $prefix = switch ($lvl) {
                            "Error"   { "[ОШИБКА]" }
                            "Warning" { "[!]" }
                            "Success" { "[OK]" }
                            default   { "[i]" }
                        }
                        $line = "$time $prefix $msg"

                        $para = New-Object System.Windows.Documents.Paragraph
                        $para.Margin = New-Object System.Windows.Thickness(0)
                        $run = New-Object System.Windows.Documents.Run
                        $run.Text = "$line`r`n"
                        $color = switch ($lvl) {
                            "Error"   { [System.Windows.Media.Brushes]::LightCoral }
                            "Warning" { [System.Windows.Media.Brushes]::Khaki }
                            "Success" { [System.Windows.Media.Brushes]::LightGreen }
                            default   { [System.Windows.Media.Brushes]::LightGray }
                        }
                        $run.Foreground = $color
                        $para.Inlines.Add($run)
                        $logBox.Document.Blocks.Add($para)
                        $logBox.ScrollToEnd()
                    })
                } catch { }
                Start-Sleep -Milliseconds 60
            }

            $ok = 0
            $fail = 0

            for ($i = 0; $i -lt $pkgs.Count; $i++) {
                $pkg = $pkgs[$i]
                $num = $i + 1
                Write-BgLog "[$num/$($pkgs.Count)] Скачиваю: $pkg" "Info"

                try {
                    $out = & $adbPath shell pm path $pkg 2>&1
                    $apkPath = ""
                    foreach ($line in $out) {
                        if ($line -match '^package:(.+)$') {
                            $apkPath = $matches[1].Trim()
                            break
                        }
                    }

                    if (-not $apkPath) {
                        Write-BgLog "  APK не найден для $pkg" "Warning"
                        $fail++
                        continue
                    }

                    $fileName = "$pkg.apk"
                    $localPath = Join-Path $folder $fileName

                    $pullOut = & $adbPath pull $apkPath $localPath 2>&1
                    if (Test-Path $localPath) {
                        $sizeMb = [math]::Round((Get-Item $localPath).Length / 1MB, 2)
                        Write-BgLog "  OK: $fileName ($sizeMb МБ)" "Success"
                        $ok++
                    } else {
                        Write-BgLog "  FAIL: $($pullOut | Out-String)" "Error"
                        $fail++
                    }
                } catch {
                    Write-BgLog "  Ошибка: $_" "Error"
                    $fail++
                }
            }

            Write-BgLog "=== Готово: скачано $ok, ошибок $fail из $($pkgs.Count) ===" "Success"

            return @{ Ok = $ok; Fail = $fail; Total = $pkgs.Count; Folder = $folder }
        }) | Out-Null

        $ps.AddArgument($logBoxRef)
        $ps.AddArgument($adbPathRef)
        $ps.AddArgument($pkgs)
        $ps.AddArgument($folder)

        $handle = $ps.BeginInvoke()

        # ===== РЕГИСТРАЦИЯ RUNSPACE =====
        Register-ScreenRunspace -Name "cleanup_download_apk" -PS $ps -RS $runspace -Handle $handle

        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $timer.Add_Tick({
            if ($handle.IsCompleted) {
                $timer.Stop()

                try {
                    $result = $ps.EndInvoke($handle)
                    if ($result -and $result.Count -gt 0) {
                        $r = $result[0]
                        [System.Windows.MessageBox]::Show(
                            "Скачивание завершено.`n`nУспешно: $($r.Ok)`nОшибок: $($r.Fail)`nВсего: $($r.Total)`n`nПапка: $($r.Folder)",
                            "Готово",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Information) | Out-Null
                    }
                } catch {
                    Write-Log -Message "Ошибка завершения скачивания: $_" -Level "Error"
                }

                $ps.Dispose()

                # ===== СНЯТИЕ С РЕГИСТРАЦИИ =====
                Unregister-ScreenRunspace -Name "cleanup_download_apk"

                $btnRef.IsEnabled = $true
                $btnRef.Content = "Скачать APK"
            }
        })
        $timer.Start()
    })
    $buttons += $btnDownloadApk

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран управления пакетами" -Level "Info"
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
        $script:DisabledAppsCheckboxes += $chk
    }

    $disabledListBox = New-VirtualizedCheckboxList -Checkboxes $script:DisabledAppsCheckboxes -MaxHeight 500
    $mainStack.Children.Add($disabledListBox) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

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