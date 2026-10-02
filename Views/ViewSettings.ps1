function Show-SettingsView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Настройки приложения"
    $mainStack.Children.Add($header) | Out-Null

    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,10,0,0"

    # ===== ВКЛАДКА "ПОДКЛЮЧЕНИЕ" =====
    $tabConn = New-Object System.Windows.Controls.TabItem
    $tabConn.Header = "Подключение"
    $tabConn.Style = $window.Resources["MiuiTabItem"]

    $connPanel = New-Object System.Windows.Controls.StackPanel
    $connPanel.Margin = "15"

    $autoCheck = New-Object System.Windows.Controls.CheckBox
    $autoCheck.Style = $window.Resources["MiuiCheckBox"]
    $autoCheck.Content = "Автоподключаться при запуске к последнему IP"
    $autoCheck.IsChecked = [bool](Get-ConfigValue -Key "AutoConnect")
    $autoCheck.Margin = "0,0,0,10"
    $autoCheck.Add_Click({
        Set-ConfigValue -Key "AutoConnect" -Value $autoCheck.IsChecked
        Write-Log -Message "Автоподключение: $($autoCheck.IsChecked)" -Level "Info"
    })
    $connPanel.Children.Add($autoCheck) | Out-Null

    $lastIp = Get-ConfigValue -Key "LastIp"
    $ipLabel = New-ViewLabel -Text "Последний IP: $(if ($lastIp) { $lastIp } else { 'не сохранён' })" -Light
    $connPanel.Children.Add($ipLabel) | Out-Null

    $tabConn.Content = $connPanel
    $tabControl.Items.Add($tabConn) | Out-Null

    # ===== ВКЛАДКА "ПРОФИЛИ" =====
    $tabProfiles = New-Object System.Windows.Controls.TabItem
    $tabProfiles.Header = "Профили устройств"
    $tabProfiles.Style = $window.Resources["MiuiTabItem"]

    $profilesPanel = New-Object System.Windows.Controls.StackPanel
    $profilesPanel.Margin = "15"

    $profilesInfo = New-ViewLabel -Text "Сохранённые устройства. При подключении можно выбрать профиль вместо ввода IP вручную." -Light
    $profilesPanel.Children.Add($profilesInfo) | Out-Null

    # Список профилей
    $script:ProfilesListBox = New-Object System.Windows.Controls.ListBox
    $script:ProfilesListBox.FontSize = 13
    $script:ProfilesListBox.BorderThickness = "1"
    $script:ProfilesListBox.BorderBrush = "#E1E1E6"
    $script:ProfilesListBox.MinHeight = 200
    $script:ProfilesListBox.Padding = "5"
    $script:ProfilesListBox.Margin = "0,10,0,10"

    # Загружаем профили
    $profiles = Get-ConfigValue -Key "SavedProfiles"
    if (-not $profiles) { $profiles = @() }

    foreach ($p in $profiles) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = "$($p.Name)  —  $($p.Ip)"
        $item.Tag = $p
        $item.Padding = "5"
        [void]$script:ProfilesListBox.Items.Add($item)
    }
    if ($script:ProfilesListBox.Items.Count -gt 0) { $script:ProfilesListBox.SelectedIndex = 0 }

    $profilesPanel.Children.Add($script:ProfilesListBox) | Out-Null

    # Кнопки управления профилями
    $profilesBtnPanel = New-Object System.Windows.Controls.StackPanel
    $profilesBtnPanel.Orientation = "Horizontal"

    $btnAddProfile = New-ViewButton -Text "Добавить профиль" -ColorType "Primary" -OnClick {
        Show-AddProfileDialog
    }
    $profilesBtnPanel.Children.Add($btnAddProfile) | Out-Null

    $btnConnectProfile = New-ViewButton -Text "Подключиться" -ColorType "Primary" -OnClick {
        if ($script:ProfilesListBox.SelectedItem) {
            $profile = $script:ProfilesListBox.SelectedItem.Tag
            Write-Log -Message "Подключение к профилю '$($profile.Name)' ($($profile.Ip))..." -Level "Info"
            $result = Connect-AdbDevice -Ip $profile.Ip
            if ($result.Success) {
                Set-ConfigValue -Key "LastIp" -Value $profile.Ip
                Update-StatusBar
                Check-OtaState
                Switch-View -ViewName "Setup"
            } else {
                Write-Log -Message "Ошибка: $($result.Message)" -Level "Error"
            }
        } else {
            Write-Log -Message "Профиль не выбран" -Level "Warning"
        }
    }
    $profilesBtnPanel.Children.Add($btnConnectProfile) | Out-Null

    $btnDeleteProfile = New-ViewButton -Text "Удалить" -ColorType "Danger" -OnClick {
        if ($script:ProfilesListBox.SelectedItem) {
            $profile = $script:ProfilesListBox.SelectedItem.Tag
            $confirm = [System.Windows.MessageBox]::Show(
                "Удалить профиль '$($profile.Name)'?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                $allProfiles = Get-ConfigValue -Key "SavedProfiles"
                $allProfiles = $allProfiles | Where-Object { $_.Name -ne $profile.Name -or $_.Ip -ne $profile.Ip }
                Set-ConfigValue -Key "SavedProfiles" -Value @($allProfiles)
                Write-Log -Message "Профиль удалён: $($profile.Name)" -Level "Success"
                Switch-View -ViewName "Settings"
            }
        }
    }
    $profilesBtnPanel.Children.Add($btnDeleteProfile) | Out-Null

    $profilesPanel.Children.Add($profilesBtnPanel) | Out-Null

    $tabProfiles.Content = $profilesPanel
    $tabControl.Items.Add($tabProfiles) | Out-Null

    # ===== ВКЛАДКА "КОНФИГ" =====
    $tabConfig = New-Object System.Windows.Controls.TabItem
    $tabConfig.Header = "Конфиг"
    $tabConfig.Style = $window.Resources["MiuiTabItem"]

    $configPanel = New-Object System.Windows.Controls.StackPanel
    $configPanel.Margin = "15"

    $configInfo = New-ViewLabel -Text "Путь к файлу конфигурации:" -Light
    $configPanel.Children.Add($configInfo) | Out-Null

    $configPathLabel = New-Object System.Windows.Controls.TextBlock
    $configPathLabel.Text = $script:ConfigPath
    $configPathLabel.FontFamily = "Consolas"
    $configPathLabel.FontSize = 11
    $configPathLabel.Foreground = "#2D2D30"
    $configPathLabel.TextWrapping = "Wrap"
    $configPathLabel.Margin = "0,5,0,15"
    $configPanel.Children.Add($configPathLabel) | Out-Null

    $configBtnPanel = New-Object System.Windows.Controls.StackPanel
    $configBtnPanel.Orientation = "Horizontal"

    $btnOpenConfig = New-ViewButton -Text "Открыть папку" -ColorType "Primary" -OnClick {
        $folder = Split-Path $script:ConfigPath -Parent
        Start-Process explorer.exe $folder
    }
    $configBtnPanel.Children.Add($btnOpenConfig) | Out-Null

    $btnResetConfig = New-ViewButton -Text "Сбросить настройки" -ColorType "Danger" -OnClick {
        $confirm = [System.Windows.MessageBox]::Show(
            "Сбросить все настройки приложения?`n`nПрофили устройств тоже будут удалены.",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:Config = Get-DefaultConfig
            Save-AppConfig
            Write-Log -Message "Настройки сброшены" -Level "Success"
            Switch-View -ViewName "Settings"
        }
    }
    $configBtnPanel.Children.Add($btnResetConfig) | Out-Null

    $configPanel.Children.Add($configBtnPanel) | Out-Null

    $tabConfig.Content = $configPanel
    $tabControl.Items.Add($tabConfig) | Out-Null

    $mainStack.Children.Add($tabControl) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Main" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран настроек приложения" -Level "Info"
}

# ===== ДИАЛОГ ДОБАВЛЕНИЯ ПРОФИЛЯ =====
function Show-AddProfileDialog {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Добавить профиль"
    $dialog.Width = 450
    $dialog.Height = 300
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#F7F7FA"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "25"

    $header = New-ViewHeader -Text "Новый профиль" -X 0 -Y 0
    $stack.Children.Add($header) | Out-Null

    $lblName = New-ViewLabel -Text "Имя профиля:"
    $stack.Children.Add($lblName) | Out-Null

    $txtName = New-Object System.Windows.Controls.TextBox
    $txtName.Style = $window.Resources["RoundedTextBox"]
    $txtName.Text = "Мой телевизор"
    $txtName.Margin = "0,0,0,10"
    $stack.Children.Add($txtName) | Out-Null

    $lblIp = New-ViewLabel -Text "IP-адрес:"
    $stack.Children.Add($lblIp) | Out-Null

    $txtIp = New-Object System.Windows.Controls.TextBox
    $txtIp.Style = $window.Resources["RoundedTextBox"]
    $txtIp.Text = Get-ConfigValue -Key "LastIp"
    $txtIp.Margin = "0,0,0,15"
    $stack.Children.Add($txtIp) | Out-Null

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"

    $btnSave = New-ViewButton -Text "Сохранить" -ColorType "Primary" -OnClick {
        $name = $txtName.Text.Trim()
        $ip = $txtIp.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($ip)) {
            [System.Windows.MessageBox]::Show("Заполните имя и IP", "Ошибка") | Out-Null
            return
        }

        $profiles = Get-ConfigValue -Key "SavedProfiles"
        if (-not $profiles) { $profiles = @() }
        $profiles += [PSCustomObject]@{ Name = $name; Ip = $ip }
        Set-ConfigValue -Key "SavedProfiles" -Value @($profiles)
        Write-Log -Message "Профиль добавлен: $name ($ip)" -Level "Success"
        $dialog.Close()
        Switch-View -ViewName "Settings"
    }
    $btnPanel.Children.Add($btnSave) | Out-Null

    $btnCancel = New-ViewButton -Text "Отмена" -ColorType "Neutral" -OnClick {
        $dialog.Close()
    }
    $btnPanel.Children.Add($btnCancel) | Out-Null

    $stack.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $stack
    $dialog.ShowDialog() | Out-Null
}