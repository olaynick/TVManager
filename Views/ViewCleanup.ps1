function Show-CleanupView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Управление пакетами"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "«Отключить» — пакет остаётся в системе. «Удалить» — данные стираются. «Очистить данные» — сброс кэша и настроек приложения." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    Write-Log -Message "Читаю списки пакетов..." -Level "Info"
    $script:InstalledPackagesSet = Get-InstalledPackagesSet
    $script:DisabledPackagesSet = Get-DisabledPackagesSet
    Write-Log -Message "Установлено: $($script:InstalledPackagesSet.Count), отключено: $($script:DisabledPackagesSet.Count)" -Level "Info"

    $allCategories = @(
        @{ Name = "Реклама и слежка"; Packages = $script:adwarePackages },
        @{ Name = "TCL-сервисы"; Packages = $script:tclServicesPackages },
        @{ Name = "Google-мусор"; Packages = $script:googleJunkPackages },
        @{ Name = "Системные"; Packages = $script:systemJunkPackages }
    )

    # ===== ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,10,0,0"

    $script:CleanupTabCheckboxes = @{}

    foreach ($cat in $allCategories) {
        $tab = New-Object System.Windows.Controls.TabItem
        $tab.Header = "$($cat.Name) ($($cat.Packages.Count))"
        $tab.Style = $window.Resources["MiuiTabItem"]

        $tabPanel = New-Object System.Windows.Controls.StackPanel
        $tabPanel.Margin = "15"

        $itemsStack = New-Object System.Windows.Controls.StackPanel
        $tabPanel.Children.Add($itemsStack) | Out-Null

        $tabCheckboxes = @()

        foreach ($pkg in $cat.Packages) {
            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.Style = $window.Resources["MiuiCheckBox"]

            $isInstalled = $script:InstalledPackagesSet.ContainsKey($pkg.Package)
            $isRemoved = $script:RemovedPackages -contains $pkg.Package
            $isDisabled = $script:DisabledPackagesSet.ContainsKey($pkg.Package)

            if ($isRemoved) {
                $chk.Content = "$($pkg.Desc)  ($($pkg.Package))  — Удалено"
                $chk.Foreground = [System.Windows.Media.Brushes]::Gray
                $chk.IsEnabled = $false
            } elseif ($isDisabled) {
                $chk.Content = "$($pkg.Desc)  ($($pkg.Package))  — Отключено"
                $chk.Foreground = [System.Windows.Media.Brushes]::Gray
                $chk.IsEnabled = $false
            } elseif (-not $isInstalled) {
                $chk.Content = "$($pkg.Desc)  ($($pkg.Package))  — Не установлено"
                $chk.Foreground = [System.Windows.Media.Brushes]::Gray
                $chk.IsEnabled = $false
            } else {
                $chk.Content = "$($pkg.Desc)  ($($pkg.Package))"
                $chk.Tag = $pkg
            }

            $itemsStack.Children.Add($chk) | Out-Null
            $tabCheckboxes += $chk
        }

        $tab.Content = $tabPanel
        $tabControl.Items.Add($tab) | Out-Null
        $script:CleanupTabCheckboxes[$cat.Name] = $tabCheckboxes
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

    # Сторонние
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
            $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(сторонний)" }
        }

        $tpPanel.Children.Add($chk) | Out-Null
        $tpCheckboxes += $chk
    }
    $tpTab.Content = $tpPanel
    $extraSubTabs.Items.Add($tpTab) | Out-Null
    $script:CleanupTabCheckboxes["Сторонние"] = $tpCheckboxes

    # Системные
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
            $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(системный)" }
        }

        $sysPanel.Children.Add($chk) | Out-Null
        $sysCheckboxes += $chk
    }
    $sysTab.Content = $sysPanel
    $extraSubTabs.Items.Add($sysTab) | Out-Null
    $script:CleanupTabCheckboxes["Системные (доп)"] = $sysCheckboxes

    $extraPanel.Children.Add($extraSubTabs) | Out-Null
    $extraTab.Content = $extraPanel
    $tabControl.Items.Add($extraTab) | Out-Null

    $mainStack.Children.Add($tabControl) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ =====
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#64B5F6")
    )
    $btnSelectAll.Padding = "12,6"
    $btnSelectAll.Margin = "0,0,8,0"
    $btnSelectAll.Add_Click({
        foreach ($chk in $script:CleanupAllCheckboxes) {
            if ($chk.IsEnabled -eq $true) { $chk.IsChecked = $true }
        }
    })
    $buttons += $btnSelectAll

    # "Снять всё"
    $btnDeselect = New-Object System.Windows.Controls.Button
    $btnDeselect.Content = "Снять всё"
    $btnDeselect.Style = $window.Resources["RoundedButton"]
    $btnDeselect.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
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

        $confirm = [System.Windows.MessageBox]::Show(
            "Удалить $($selected.Count) пакетов?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Write-Log -Message "Удаляю $($selected.Count) пакетов..." -Level "Info"
        $success = 0
        foreach ($pkg in $selected) {
            if (Remove-Package -Package $pkg.Package) {
                $success++
                if ($script:RemovedPackages -notcontains $pkg.Package) {
                    $script:RemovedPackages += $pkg.Package
                }
                Save-Change -Type "package_removed" -Target $pkg.Package -RestoreCommand "adb shell cmd package install-existing $($pkg.Package)"
            }
        }
        Save-AllChanges
        Write-Log -Message "Удалено: $success из $($selected.Count)" -Level "Success"
        Switch-View -ViewName "Cleanup"
    })
    $buttons += $btnDelete

    # "Очистить данные"
    $btnClearData = New-Object System.Windows.Controls.Button
    $btnClearData.Content = "Очистить данные"
    $btnClearData.Style = $window.Resources["RoundedButton"]
    $btnClearData.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9C27B0")
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

    Write-Log -Message "Экран управления пакетами" -Level "Info"
}
# ===== ЭКРАН "ОТКЛЮЧЁННЫЕ ПРИЛОЖЕНИЯ" =====
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
        $chk.Tag = [PSCustomObject]@{ Package = $pkgName; Desc = "(отключён)" }
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#64B5F6")
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
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