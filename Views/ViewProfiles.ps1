function Show-ProfilesView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Профили устройств"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Профиль хранит полное состояние ТВ: все отключённые пакеты, настройки анимации, OTA. При применении состояние синхронизируется." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    $profiles = Get-Profiles
    $profileCount = @($profiles).Count

    # ===== СПИСОК =====
    if ($profileCount -eq 0) {
        $mainStack.Children.Add((New-ViewLabel -Text "Пока нет сохранённых профилей." -Light)) | Out-Null
    } else {
        $script:ProfilesViewListBox = New-Object System.Windows.Controls.ListBox
        $script:ProfilesViewListBox.FontSize = 13
        $script:ProfilesViewListBox.BorderThickness = "1"
        $script:ProfilesViewListBox.BorderBrush = "#3A3A3A"
        $script:ProfilesViewListBox.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#1F1F1F")
        )
        $script:ProfilesViewListBox.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $script:ProfilesViewListBox.MinHeight = 200
        $script:ProfilesViewListBox.Padding = "5"
        $script:ProfilesViewListBox.Margin = "0,0,0,15"

        foreach ($p in $profiles) {
            $disabledCount = 0
            $removedCount = 0
            $enableCount = 0
            $thirdCount = 0
            if ($p.Packages) {
                foreach ($pkg in $p.Packages) {
                    if ($pkg.State -eq "disabled") { $disabledCount++ }
                    elseif ($pkg.State -eq "removed") { $removedCount++ }
                }
            }
            if ($p.PackagesToEnable) { $enableCount = @($p.PackagesToEnable).Count }
            if ($p.ThirdPartyPackages) { $thirdCount = @($p.ThirdPartyPackages).Count }

            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Content = "$($p.Name)  —  $($p.Ip)   [откл: $disabledCount, удал: $removedCount, вкл: $enableCount, стор: $thirdCount]"
            $item.Tag = $p
            $item.Padding = "5"
            [void]$script:ProfilesViewListBox.Items.Add($item)
        }
        if ($script:ProfilesViewListBox.Items.Count -gt 0) { $script:ProfilesViewListBox.SelectedIndex = 0 }

        $mainStack.Children.Add($script:ProfilesViewListBox) | Out-Null
    }

    # ===== ФОРМА =====
    $mainStack.Children.Add((New-StepTitle -Text "Новый / изменить профиль")) | Out-Null

    # Имя
    $nameGrid = New-Object System.Windows.Controls.Grid
    $nc1 = New-Object System.Windows.Controls.ColumnDefinition
    $nc1.Width = "80"
    $nc2 = New-Object System.Windows.Controls.ColumnDefinition
    $nc2.Width = "*"
    $nameGrid.ColumnDefinitions.Add($nc1)
    $nameGrid.ColumnDefinitions.Add($nc2)
    $nameGrid.Margin = "0,0,0,8"

    $lblName = New-Object System.Windows.Controls.TextBlock
    $lblName.Text = "Имя:"
    $lblName.FontSize = 13
    $lblName.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblName.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($lblName, 0)
    $nameGrid.Children.Add($lblName) | Out-Null

    $script:ProfileNameBox = New-Object System.Windows.Controls.TextBox
    $script:ProfileNameBox.Style = $window.Resources["RoundedTextBox"]
    $script:ProfileNameBox.FontSize = 13
    $script:ProfileNameBox.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    [System.Windows.Controls.Grid]::SetColumn($script:ProfileNameBox, 1)
    $nameGrid.Children.Add($script:ProfileNameBox) | Out-Null

    $mainStack.Children.Add($nameGrid) | Out-Null

    # IP
    $ipGrid = New-Object System.Windows.Controls.Grid
    $ic1 = New-Object System.Windows.Controls.ColumnDefinition
    $ic1.Width = "80"
    $ic2 = New-Object System.Windows.Controls.ColumnDefinition
    $ic2.Width = "*"
    $ipGrid.ColumnDefinitions.Add($ic1)
    $ipGrid.ColumnDefinitions.Add($ic2)
    $ipGrid.Margin = "0,0,0,10"

    $lblIp = New-Object System.Windows.Controls.TextBlock
    $lblIp.Text = "IP:"
    $lblIp.FontSize = 13
    $lblIp.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblIp.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($lblIp, 0)
    $ipGrid.Children.Add($lblIp) | Out-Null

    $script:ProfileIpBox = New-Object System.Windows.Controls.TextBox
    $script:ProfileIpBox.Style = $window.Resources["RoundedTextBox"]
    $script:ProfileIpBox.FontSize = 13
    $script:ProfileIpBox.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    if ($script:connected -and $script:deviceIp) {
        $script:ProfileIpBox.Text = $script:deviceIp
    }
    [System.Windows.Controls.Grid]::SetColumn($script:ProfileIpBox, 1)
    $ipGrid.Children.Add($script:ProfileIpBox) | Out-Null

    $mainStack.Children.Add($ipGrid) | Out-Null

    # Кнопка "Сохранить"
    $mainStack.Children.Add((New-ViewButton -Text "Сохранить текущее состояние" -ColorType "Success" -Margin "0,8,0,0" -OnClick {
        $name = $script:ProfileNameBox.Text.Trim()
        $ip = $script:ProfileIpBox.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($ip)) {
            Write-Log -Message "Заполните имя и IP" -Level "Error"
            return
        }

        if (-not $script:connected) {
            Write-Log -Message "Сначала подключитесь к ТВ" -Level "Error"
            return
        }

        Write-Log -Message "Читаю состояние ТВ..." -Level "Info"
        $installed = Get-InstalledPackagesSet
        $disabled = Get-DisabledPackagesSet

        # 1. Отключённые и удалённые
        $packages = @()
        foreach ($pkgName in $disabled.Keys) {
            $packages += [PSCustomObject]@{
                Package = $pkgName
                State   = "disabled"
            }
        }
        foreach ($pkgName in $script:RemovedPackages) {
            $packages += [PSCustomObject]@{
                Package = $pkgName
                State   = "removed"
            }
        }

        # 2. Пакеты, которые должны быть включены
        $packagesToEnable = @()
        $knownPackages = @()
        foreach ($cat in @($script:adwarePackages, $script:tclServicesPackages, $script:googleJunkPackages, $script:systemJunkPackages)) {
            foreach ($pkg in $cat) { $knownPackages += $pkg.Package }
        }
        foreach ($pkgName in $knownPackages) {
            if (-not $disabled.ContainsKey($pkgName) -and -not ($script:RemovedPackages -contains $pkgName)) {
                $packagesToEnable += [PSCustomObject]@{ Package = $pkgName }
            }
        }

        # 3. Сторонние приложения
        $allThirdParty = & $script:adbPath shell pm list packages -3 2>&1
        $thirdPartyPkgs = @()
        foreach ($line in $allThirdParty) {
            if ($line -match '^package:(.+)$') {
                $thirdPartyPkgs += $matches[1].Trim()
            }
        }
        Write-Log -Message "Сторонних приложений: $($thirdPartyPkgs.Count)" -Level "Info"

        # 4. Настройки
        $animValue = (& $script:adbPath shell settings get global window_animation_scale 2>&1).Trim()
        $otaVal = $script:OtaDisabled

        Save-Profile -Name $name -Ip $ip -Packages $packages -PackagesToEnable $packagesToEnable -ThirdPartyPackages $thirdPartyPkgs -AnimationScale $animValue -OtaDisabled $otaVal
        Switch-View -ViewName "Profiles"
    })) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    # "Импорт" — всегда доступен
    $btnImport = New-Object System.Windows.Controls.Button
    $btnImport.Content = "Импорт"
    $btnImport.Style = $window.Resources["RoundedButton"]
    $btnImport.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnImport.Padding = "12,6"
    $btnImport.Margin = "0,0,8,0"
    $btnImport.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $result = [System.Windows.MessageBox]::Show(
                "Заменить все существующие профили?`n`nДа — полная замена.`nНет — добавить / обновить.",
                "Импорт профилей",
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Question)

            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Import-Profiles -FilePath $dlg.FileName -Replace
                Switch-View -ViewName "Profiles"
            } elseif ($result -eq [System.Windows.MessageBoxResult]::No) {
                Import-Profiles -FilePath $dlg.FileName
                Switch-View -ViewName "Profiles"
            }
        }
    })
    $buttons += $btnImport

    if ($profileCount -gt 0) {
        # "Применить профиль"
        $btnApply = New-Object System.Windows.Controls.Button
        $btnApply.Content = "Применить профиль"
        $btnApply.Style = $window.Resources["RoundedButton"]
        $btnApply.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnApply.Padding = "12,6"
        $btnApply.Margin = "0,0,8,0"
        $btnApply.Add_Click({
            if (-not $script:connected) {
                Write-Log -Message "Сначала подключитесь к ТВ" -Level "Error"
                return
            }
            if ($script:ProfilesViewListBox.SelectedItem) {
                $profile = $script:ProfilesViewListBox.SelectedItem.Tag
                $confirm = [System.Windows.MessageBox]::Show(
                    "Применить профиль '$($profile.Name)' к подключённому ТВ?`n`nСостояние пакетов будет синхронизировано.",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                    Apply-Profile -Profile $profile
                }
            }
        })
        $buttons += $btnApply

        # "Просмотр"
        $btnView = New-Object System.Windows.Controls.Button
        $btnView.Content = "Просмотр"
        $btnView.Style = $window.Resources["RoundedButton"]
        $btnView.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnView.Padding = "12,6"
        $btnView.Margin = "0,0,8,0"
        $btnView.Add_Click({
            if ($script:ProfilesViewListBox.SelectedItem) {
                Show-ProfileDetails -Profile $script:ProfilesViewListBox.SelectedItem.Tag
            }
        })
        $buttons += $btnView

        # "Экспорт"
        $btnExport = New-Object System.Windows.Controls.Button
        $btnExport.Content = "Экспорт"
        $btnExport.Style = $window.Resources["RoundedButton"]
        $btnExport.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnExport.Padding = "12,6"
        $btnExport.Margin = "0,0,8,0"
        $btnExport.Add_Click({
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object System.Windows.Forms.SaveFileDialog
            $dlg.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
            $dlg.FileName = "tv_profiles_$(Get-Date -Format 'yyyy-MM-dd').json"
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                Export-Profiles -FilePath $dlg.FileName
            }
        })
        $buttons += $btnExport

        # "Удалить"
        $btnDelete = New-Object System.Windows.Controls.Button
        $btnDelete.Content = "Удалить"
        $btnDelete.Style = $window.Resources["RoundedButton"]
        $btnDelete.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnDelete.Padding = "12,6"
        $btnDelete.Add_Click({
            if ($script:ProfilesViewListBox.SelectedItem) {
                $profile = $script:ProfilesViewListBox.SelectedItem.Tag
                $confirm = [System.Windows.MessageBox]::Show(
                    "Удалить профиль '$($profile.Name)'?",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                    Remove-Profile -Name $profile.Name
                    Switch-View -ViewName "Profiles"
                }
            }
        })
        $buttons += $btnDelete
    }

    if ($buttons.Count -gt 0) {
        Set-BottomButtons -Buttons $buttons
    }

    Write-Log -Message "Экран профилей устройств" -Level "Info"
}

# ===== ДИАЛОГ ПРОСМОТРА ПРОФИЛЯ =====
function Show-ProfileDetails {
    param([PSCustomObject]$Profile)

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Профиль: $($Profile.Name)"
    $dialog.Width = 700
    $dialog.Height = 650
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#202020"

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

    $header = New-ViewHeader -Text "Профиль: $($Profile.Name)" -X 0 -Y 0
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $grid.Children.Add($header) | Out-Null

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $stack = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $stack

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text = "IP: $($Profile.Ip)`nСохранён: $($Profile.SavedAt)`nАнимация: $(if ($Profile.AnimationScale) { $Profile.AnimationScale } else { '—' })`nOTA: $(if ($Profile.OtaDisabled) { 'отключены' } else { 'включены' })"
    $info.FontSize = 13
    $info.Margin = "0,0,0,15"
    $stack.Children.Add($info) | Out-Null

    # Отключённые / удалённые
    $disabledList = @()
    $removedList = @()
    foreach ($p in $Profile.Packages) {
        if ($p.State -eq "disabled") { $disabledList += $p.Package }
        elseif ($p.State -eq "removed") { $removedList += $p.Package }
    }

    $disabledHeader = New-Object System.Windows.Controls.TextBlock
    $disabledHeader.Text = "Отключённые приложения ($($disabledList.Count)):"
    $disabledHeader.FontSize = 14
    $disabledHeader.FontWeight = "Bold"
    $disabledHeader.Foreground = "#C8C8C8"
    $disabledHeader.Margin = "0,10,0,5"
    $stack.Children.Add($disabledHeader) | Out-Null

    if ($disabledList.Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "  (нет)"
        $tb.FontSize = 12
        $tb.Margin = "10,2,0,2"
        $stack.Children.Add($tb) | Out-Null
    } else {
        foreach ($pkg in $disabledList) {
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = "  $pkg"
            $tb.FontFamily = "Consolas"
            $tb.FontSize = 12
            $tb.Margin = "10,2,0,2"
            $stack.Children.Add($tb) | Out-Null
        }
    }

    $removedHeader = New-Object System.Windows.Controls.TextBlock
    $removedHeader.Text = "Удалённые приложения ($($removedList.Count)):"
    $removedHeader.FontSize = 14
    $removedHeader.FontWeight = "Bold"
    $removedHeader.Foreground = "#C8C8C8"
    $removedHeader.Margin = "0,15,0,5"
    $stack.Children.Add($removedHeader) | Out-Null

    if ($removedList.Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "  (нет)"
        $tb.FontSize = 12
        $tb.Margin = "10,2,0,2"
        $stack.Children.Add($tb) | Out-Null
    } else {
        foreach ($pkg in $removedList) {
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = "  $pkg"
            $tb.FontFamily = "Consolas"
            $tb.FontSize = 12
            $tb.Margin = "10,2,0,2"
            $stack.Children.Add($tb) | Out-Null
        }
    }

    # Включённые
    $enableList = @()
    if ($Profile.PackagesToEnable) {
        foreach ($p in $Profile.PackagesToEnable) { $enableList += $p.Package }
    }

    $enableHeader = New-Object System.Windows.Controls.TextBlock
    $enableHeader.Text = "Должны быть включены ($($enableList.Count)):"
    $enableHeader.FontSize = 14
    $enableHeader.FontWeight = "Bold"
    $enableHeader.Foreground = "#C8C8C8"
    $enableHeader.Margin = "0,15,0,5"
    $stack.Children.Add($enableHeader) | Out-Null

    if ($enableList.Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "  (нет)"
        $tb.FontSize = 12
        $tb.Margin = "10,2,0,2"
        $stack.Children.Add($tb) | Out-Null
    } else {
        foreach ($pkg in $enableList) {
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = "  $pkg"
            $tb.FontFamily = "Consolas"
            $tb.FontSize = 12
            $tb.Margin = "10,2,0,2"
            $stack.Children.Add($tb) | Out-Null
        }
    }

    # Сторонние приложения
    $thirdPartyList = @()
    if ($Profile.ThirdPartyPackages) {
        foreach ($pkg in $Profile.ThirdPartyPackages) { $thirdPartyList += $pkg }
    }

    $thirdPartyHeader = New-Object System.Windows.Controls.TextBlock
    $thirdPartyHeader.Text = "Сторонние приложения (устанавливаются вручную) ($($thirdPartyList.Count)):"
    $thirdPartyHeader.FontSize = 14
    $thirdPartyHeader.FontWeight = "Bold"
    $thirdPartyHeader.Foreground = "#C8C8C8"
    $thirdPartyHeader.Margin = "0,15,0,5"
    $stack.Children.Add($thirdPartyHeader) | Out-Null

    if ($thirdPartyList.Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "  (нет)"
        $tb.FontSize = 12
        $tb.Margin = "10,2,0,2"
        $stack.Children.Add($tb) | Out-Null
    } else {
        foreach ($pkg in $thirdPartyList) {
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = "  $pkg"
            $tb.FontFamily = "Consolas"
            $tb.FontSize = 12
            $tb.Margin = "10,2,0,2"
            $stack.Children.Add($tb) | Out-Null
        }
    }

    # Кнопка "Закрыть"
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
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