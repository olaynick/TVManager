function Add-SetupConnectBlock {
    param([System.Windows.Controls.StackPanel]$Stack)

    $Stack.Children.Add((New-StepTitle -Text "Шаг 1. Подключение")) | Out-Null

    $ipPanel = New-Object System.Windows.Controls.StackPanel
    $ipPanel.Orientation = "Horizontal"
    $ipPanel.Margin = "0,0,0,8"

    $script:SetupTxtIp = New-Object System.Windows.Controls.TextBox
    $script:SetupTxtIp.Style = $window.Resources["RoundedTextBox"]
    $script:SetupTxtIp.Width = 260
    $script:SetupTxtIp.FontSize = 14

    $lastIp = Get-ConfigValue -Key "LastIp"
    if ($lastIp -and $lastIp -ne "") {
        $script:SetupTxtIp.Text = $lastIp
        $script:SetupTxtIp.Foreground = [System.Windows.Media.Brushes]::Black
    } else {
        $script:SetupTxtIp.Text = "Введите IP вручную"
        $script:SetupTxtIp.Foreground = [System.Windows.Media.Brushes]::Gray
    }

    $script:SetupTxtIp.Add_GotFocus({
        if ($script:SetupTxtIp.Text -eq "Введите IP вручную") {
            $script:SetupTxtIp.Text = ""
            $script:SetupTxtIp.Foreground = [System.Windows.Media.Brushes]::Black
        }
    })
    $script:SetupTxtIp.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($script:SetupTxtIp.Text)) {
            $script:SetupTxtIp.Text = "Введите IP вручную"
            $script:SetupTxtIp.Foreground = [System.Windows.Media.Brushes]::Gray
        }
    })

    $ipPanel.Children.Add($script:SetupTxtIp) | Out-Null

    $btnConnectManual = New-ViewButton -Text "Подключиться" -Color "#3e5f6e" -Margin "10,0,0,0" -OnClick {
        $ip = $script:SetupTxtIp.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($ip) -or $ip -eq "Введите IP вручную") {
            Write-Log -Message "IP не введён" -Level "Error"
            return
        }
        $result = Connect-AdbDevice -Ip $ip
        if ($result.Success) {
            Set-ConfigValue -Key "LastIp" -Value $ip
            Update-StatusBar
            Check-OtaState
            Switch-View -ViewName "Setup"
        } else {
            Write-Log -Message "Ошибка: $($result.Message)" -Level "Error"
        }
    }
    $ipPanel.Children.Add($btnConnectManual) | Out-Null

    $script:SetupBtnScan = New-ViewButton -Text "Сканировать" -Color "#3e5f6e" -Margin "10,0,0,0" -OnClick {
        Start-NetworkScan
    }
    $ipPanel.Children.Add($script:SetupBtnScan) | Out-Null

    $Stack.Children.Add($ipPanel) | Out-Null
    $Stack.Children.Add((New-ViewLabel -Text "Сканирование — поиск устройств в вашей локальной сети (Wi-Fi)." -Light)) | Out-Null
    $Stack.Children.Add((New-ViewLabel -Text "Важно: ПК и ТВ должны быть в одной Wi-Fi сети. Если ПК подключён по кабелю (Ethernet), подключение может не работать." -Light)) | Out-Null

    $script:DeviceListContainer = New-Object System.Windows.Controls.StackPanel
    $script:DeviceListContainer.Margin = "0,5,0,15"
    $Stack.Children.Add($script:DeviceListContainer) | Out-Null

    if ($script:FoundDevices.Count -gt 0) {
        Show-DeviceListInline -Devices $script:FoundDevices
    }
}