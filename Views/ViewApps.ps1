# ============================================================================
#  Экран: Приложения и лаунчеры
# ============================================================================
function Show-AppsView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Приложения и лаунчеры"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Запуск приложений на ТВ и назначение лаунчера (главного экрана). Лаунчер — приложение, которое открывается по кнопке «Домой»." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,10"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ВКЛАДКИ =====
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,8,0,0"

    # =========================================================================
    #  ВКЛАДКА 1: ЛАУНЧЕРЫ
    # =========================================================================
    $tabLaunchers = New-Object System.Windows.Controls.TabItem
    $tabLaunchers.Header = "Лаунчеры"
    $tabLaunchers.Style = $window.Resources["MiuiTabItem"]

    $launchersPanel = New-Object System.Windows.Controls.StackPanel
    $launchersPanel.Margin = "12"

    $launchersInfo = New-ViewLabel -Text "Лаунчер — приложение, которое открывается по кнопке «Домой». Выберите, какой использовать по умолчанию." -Light
    $launchersInfo.TextWrapping = "Wrap"
    $launchersInfo.Margin = "0,0,0,10"
    $launchersPanel.Children.Add($launchersInfo) | Out-Null

    $launchers = Get-LauncherPackages

    if ($launchers.Count -eq 0) {
        $launchersPanel.Children.Add((New-ViewLabel -Text "Лаунчеры не найдены." -Light)) | Out-Null
    } else {
        foreach ($l in $launchers) {
            $row = New-Object System.Windows.Controls.Border
            $row.Background = "#2B2B2B"
            $row.BorderBrush = "#3A3A3A"
            $row.BorderThickness = "1"
            $row.CornerRadius = "6"
            $row.Padding = "10"
            $row.Margin = "0,0,0,6"

            $grid = New-Object System.Windows.Controls.Grid
            $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "*"
            $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "Auto"
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)

            # --- Левая часть ---
            $leftStack = New-Object System.Windows.Controls.StackPanel
            [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)

            $nameTb = New-Object System.Windows.Controls.TextBlock
            $nameTb.FontSize = 13
            $nameTb.FontWeight = "Bold"

            $badge = ""
            if ($l.IsCurrent) { $badge += "  [ТЕКУЩИЙ]" }
            if ($l.IsSystem)  { $badge += "  [SYSTEM]" }

            $nameTb.Text = "$(if ($l.Name -and $l.Name -ne $l.Package) { "$($l.Name)  ($($l.Package))" } else { $l.Package })$badge"
            if ($l.IsCurrent) {
                $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
                )
            } elseif ($l.IsSystem) {
                $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
                )
            } else {
                $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
                )
            }
            $leftStack.Children.Add($nameTb) | Out-Null

            $actTb = New-Object System.Windows.Controls.TextBlock
            $actTb.Text = $l.Activity
            $actTb.FontFamily = "Consolas"
            $actTb.FontSize = 10
            $actTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#909090")
            )
            $actTb.Margin = "0,3,0,0"
            $leftStack.Children.Add($actTb) | Out-Null

            $grid.Children.Add($leftStack) | Out-Null

            # --- Кнопки ---
            $btnPanel = New-Object System.Windows.Controls.StackPanel
            $btnPanel.Orientation = "Horizontal"
            $btnPanel.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($btnPanel, 1)

            if (-not $l.IsCurrent) {
                $btnSet = New-Object System.Windows.Controls.Button
                $btnSet.Content = "Сделать лаунчером"
                $btnSet.Style = $window.Resources["RoundedButton"]
                $btnSet.Background = New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
                )
                $btnSet.Height = 30
                $btnSet.FontSize = 11
                $btnSet.Padding = New-Object System.Windows.Thickness(8, 0, 8, 0)
                $btnSet.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
                $btnSet.VerticalAlignment = "Center"

                # --- Tag: самый надёжный способ передать данные ---
                $btnSet.Tag = [PSCustomObject]@{
                    Action   = "set_launcher"
                    Activity = $l.Activity
                    Package  = $l.Package
                    Name     = $l.Name
                }

                $btnSet.Add_Click({
                    param($sender, $e)

                    $data = $sender.Tag
                    $activity = $data.Activity
                    $package  = $data.Package
                    $name     = $data.Name

                    Write-Log -Message "=== Нажата кнопка 'Сделать лаунчером' ===" -Level "Info"
                    Write-Log -Message "  Name:     $name" -Level "Info"
                    Write-Log -Message "  Package:  $package" -Level "Info"
                    Write-Log -Message "  Activity: $activity" -Level "Info"

                    $confirm = [System.Windows.MessageBox]::Show(
                        "Назначить лаунчером:`n`n$name`n$activity`n`nПосле этого кнопка «Домой» будет открывать это приложение.",
                        "Подтверждение",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Question)

                    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
                        Write-Log -Message "Отменено пользователем" -Level "Info"
                        return
                    }

                    Write-Log -Message "Вызываю Set-DefaultLauncher..." -Level "Info"
                    $ok = Set-DefaultLauncher -Activity $activity -Package $package

                    if ($ok) {
                        Write-Log -Message "Готово. Перерисовываю экран." -Level "Success"
                        Switch-View -ViewName "Apps"
                    } else {
                        Write-Log -Message "Не удалось назначить лаунчер" -Level "Error"
                        [System.Windows.MessageBox]::Show(
                            "Не удалось назначить лаунчер.`n`nПодробности в логе.`n`nПопробуйте вручную:`nСервис → Своя команда →`n  shell cmd package set-home-activity $activity",
                            "Ошибка",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    }
                })

                $btnPanel.Children.Add($btnSet) | Out-Null
            }

            $btnLaunch = New-Object System.Windows.Controls.Button
            $btnLaunch.Content = "Запустить"
            $btnLaunch.Style = $window.Resources["RoundedButton"]
            $btnLaunch.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
            )
            $btnLaunch.Height = 30
            $btnLaunch.FontSize = 11
            $btnLaunch.Padding = New-Object System.Windows.Thickness(8, 0, 8, 0)
            $btnLaunch.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
            $btnLaunch.VerticalAlignment = "Center"

            $btnLaunch.Tag = [PSCustomObject]@{
                Action  = "launch"
                Package = $l.Package
                Name    = $l.Name
            }

            $btnLaunch.Add_Click({
                param($sender, $e)
                $data = $sender.Tag
                Write-Log -Message "Запускаю: $($data.Name) ($($data.Package))" -Level "Info"
                Start-RemoteApp -Package $data.Package | Out-Null
            })

            $btnPanel.Children.Add($btnLaunch) | Out-Null

            $grid.Children.Add($btnPanel) | Out-Null

            $row.Child = $grid
            $launchersPanel.Children.Add($row) | Out-Null
        }
    }

    $tabLaunchers.Content = $launchersPanel
    $tabControl.Items.Add($tabLaunchers) | Out-Null

    # =========================================================================
    #  ВКЛАДКА 2: ВСЕ ПРИЛОЖЕНИЯ
    # =========================================================================
    $tabApps = New-Object System.Windows.Controls.TabItem
    $tabApps.Header = "Все приложения"
    $tabApps.Style = $window.Resources["MiuiTabItem"]

    $appsPanel = New-Object System.Windows.Controls.StackPanel
    $appsPanel.Margin = "12"

    # --- Поиск ---
    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Style = $window.Resources["RoundedTextBox"]
    $searchBox.FontSize = 13
    $searchBox.Margin = "0,0,0,10"

    $placeholderText = "Поиск по имени пакета..."
    $searchBox.Text = $placeholderText
    $searchBox.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
    )

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
                [System.Windows.Media.ColorConverter]::ConvertFromString("#707070")
            )
        }
    }.GetNewClosure())

    $appsPanel.Children.Add($searchBox) | Out-Null

    # --- Список приложений ---
    $script:AppsListContainer = New-Object System.Windows.Controls.StackPanel
    $appsPanel.Children.Add($script:AppsListContainer) | Out-Null

    $allApps = Get-AllAppsWithNames
    $allApps = $allApps | Sort-Object Package

    $script:AppsItems = @()

    foreach ($a in $allApps) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "#2B2B2B"
        $row.BorderBrush = "#3A3A3A"
        $row.BorderThickness = "1"
        $row.CornerRadius = "6"
        $row.Padding = "8"
        $row.Margin = "0,0,0,4"

        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "*"
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "Auto"
        $grid.ColumnDefinitions.Add($c1)
        $grid.ColumnDefinitions.Add($c2)

        $pkgTb = New-Object System.Windows.Controls.TextBlock
        $pkgTb.FontSize = 12
        $pkgTb.FontFamily = "Consolas"

        $typeLabel = if ($a.IsSystem) { "[SYS]" } else { "[USR]" }
        $pkgTb.Text = "$typeLabel  $($a.Package)"

        if ($a.IsSystem) {
            $pkgTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
            )
        } else {
            $pkgTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
            )
        }
        $pkgTb.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($pkgTb, 0)
        $grid.Children.Add($pkgTb) | Out-Null

        $btnRun = New-Object System.Windows.Controls.Button
        $btnRun.Content = "Запустить"
        $btnRun.Style = $window.Resources["RoundedButton"]
        $btnRun.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnRun.Height = 26
        $btnRun.FontSize = 11
        $btnRun.Padding = New-Object System.Windows.Thickness(8, 0, 8, 0)

        # Tag — надёжная передача пакета
        $btnRun.Tag = $a.Package
        $btnRun.Add_Click({
            param($sender, $e)
            $pkg = $sender.Tag
            Write-Log -Message "Запускаю: $pkg" -Level "Info"
            Start-RemoteApp -Package $pkg | Out-Null
        })

        [System.Windows.Controls.Grid]::SetColumn($btnRun, 1)
        $grid.Children.Add($btnRun) | Out-Null

        $row.Child = $grid
        $script:AppsListContainer.Children.Add($row) | Out-Null
        $script:AppsItems += @{ Row = $row; Package = $a.Package.ToLower() }
    }

    # --- Фильтр ---
    $script:AppsSearchBox = $searchBox
    $script:AppsPlaceholder = $placeholderText

    $searchBox.Add_TextChanged({
        $query = $script:AppsSearchBox.Text.Trim().ToLower()
        if ($query -eq $script:AppsPlaceholder.ToLower()) { $query = "" }

        foreach ($item in $script:AppsItems) {
            if (-not $query -or $item.Package -like "*$query*") {
                $item.Row.Visibility = "Visible"
            } else {
                $item.Row.Visibility = "Collapsed"
            }
        }
    })

    $tabApps.Content = $appsPanel
    $tabControl.Items.Add($tabApps) | Out-Null

    $mainStack.Children.Add($tabControl) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран приложений" -Level "Info"
}