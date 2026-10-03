# ============================================================================
#  Экран: DPI / Разрешение
# ============================================================================

# ===== БЕЗОПАСНЫЙ ADB =====
function Invoke-DisplayAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== ЧТЕНИЕ ТЕКУЩЕГО СОСТОЯНИЯ =====
function Get-DisplayInfo {
    Write-Log -Message "Читаю текущие значения экрана..." -Level "Info"

    $info = [ordered]@{
        PhysSize      = "—"   # Физическое разрешение панели
        CurrSize      = "—"   # Текущее (что реально используется)
        OverrideSize  = "—"   # Override размер, если задан
        PhysDensity   = "—"   # Физический DPI
        CurrDensity   = "—"   # Текущий DPI
        OverrideDensity = "—" # Override DPI, если задан
        HasSizeOverride    = $false
        HasDensityOverride = $false
    }

    try {
        # ===== wm size =====
        $sizeOut = Invoke-DisplayAdb @("shell", "wm", "size")
        # Пример вывода:
        #   Physical size: 1920x1080
        #   Override size: 1280x720        (если применён)
        foreach ($line in ($sizeOut -split "`r?`n")) {
            if ($line -match 'Physical size:\s*(\d+x\d+)') {
                $info.PhysSize = $matches[1]
            }
            if ($line -match 'Override size:\s*(\d+x\d+)') {
                $info.OverrideSize = $matches[1]
                $info.HasSizeOverride = $true
            }
        }

        # Текущее = override, если есть, иначе physical
        if ($info.HasSizeOverride) {
            $info.CurrSize = $info.OverrideSize
        } else {
            $info.CurrSize = $info.PhysSize
        }

        # ===== wm density =====
        $densOut = Invoke-DisplayAdb @("shell", "wm", "density")
        # Пример вывода:
        #   Physical density: 320
        #   Override density: 240          (если применён)
        foreach ($line in ($densOut -split "`r?`n")) {
            if ($line -match 'Physical density:\s*(\d+)') {
                $info.PhysDensity = $matches[1]
            }
            if ($line -match 'Override density:\s*(\d+)') {
                $info.OverrideDensity = $matches[1]
                $info.HasDensityOverride = $true
            }
        }

        if ($info.HasDensityOverride) {
            $info.CurrDensity = $info.OverrideDensity
        } else {
            $info.CurrDensity = $info.PhysDensity
        }

        Write-Log -Message "Разрешение: $($info.CurrSize) (физическое: $($info.PhysSize))" -Level "Info"
        Write-Log -Message "DPI: $($info.CurrDensity) (физический: $($info.PhysDensity))" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка чтения display: $_" -Level "Error"
    }

    return [PSCustomObject]$info
}

# ===== ПРИМЕНЕНИЕ РАЗРЕШЕНИЯ =====
function Set-DisplaySize {
    param([string]$SizeValue)  # "1920x1080" или "reset"

    Write-Log -Message "Применяю разрешение: $SizeValue" -Level "Info"

    # Сохраняем текущее для отката
    $current = Get-DisplayInfo
    $prevSize = if ($current.HasSizeOverride) { $current.OverrideSize } else { "reset" }

    if ($SizeValue -eq "reset") {
        $out = Invoke-DisplayAdb @("shell", "wm", "size", "reset")
    } else {
        $out = Invoke-DisplayAdb @("shell", "wm", "size", $SizeValue)
    }

    if ($out -match 'error|Error|Exception') {
        Write-Log -Message "Ошибка: $out" -Level "Error"
        return $false
    }

    Write-Log -Message "OK: $SizeValue" -Level "Success"

    # Восстановительная команда
    if ($prevSize -eq "reset") {
        Save-Change -Type "display_size" -Target "wm size" -RestoreCommand "adb shell wm size reset"
    } else {
        Save-Change -Type "display_size" -Target "wm size" -RestoreCommand "adb shell wm size $prevSize"
    }
    Save-AllChanges
    return $true
}

# ===== ПРИМЕНЕНИЕ DPI =====
function Set-DisplayDensity {
    param([string]$DensityValue)  # "320" или "reset"

    Write-Log -Message "Применяю DPI: $DensityValue" -Level "Info"

    $current = Get-DisplayInfo
    $prevDensity = if ($current.HasDensityOverride) { $current.OverrideDensity } else { "reset" }

    if ($DensityValue -eq "reset") {
        $out = Invoke-DisplayAdb @("shell", "wm", "density", "reset")
    } else {
        $out = Invoke-DisplayAdb @("shell", "wm", "density", $DensityValue)
    }

    if ($out -match 'error|Error|Exception') {
        Write-Log -Message "Ошибка: $out" -Level "Error"
        return $false
    }

    Write-Log -Message "OK: $DensityValue" -Level "Success"

    if ($prevDensity -eq "reset") {
        Save-Change -Type "display_density" -Target "wm density" -RestoreCommand "adb shell wm density reset"
    } else {
        Save-Change -Type "display_density" -Target "wm density" -RestoreCommand "adb shell wm density $prevDensity"
    }
    Save-AllChanges
    return $true
}

# ===== ПРИМЕНЕНИЕ ПАРЫ (размер + плотность) =====
function Set-DisplayBoth {
    param(
        [string]$SizeValue,
        [string]$DensityValue
    )

    Write-Log -Message "=== Применяю $SizeValue @ $DensityValue dpi ===" -Level "Info"
    Set-DisplaySize -SizeValue $SizeValue | Out-Null
    Set-DisplayDensity -DensityValue $DensityValue | Out-Null

    # Даём системе применить
    Start-Sleep -Seconds 1
    return $true
}

# ===== ДИАЛОГ КАСТОМНЫХ ЗНАЧЕНИЙ =====
function Show-CustomDisplayDialog {
    param([PSCustomObject]$CurrentInfo)

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Кастомные значения экрана"
    $dialog.Width = 460
    $dialog.Height = 380
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#202020"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "25"

    $header = New-ViewHeader -Text "Кастомные значения" -X 0 -Y 0
    $stack.Children.Add($header) | Out-Null

    # --- Разрешение ---
    $lblSize = New-ViewLabel -Text "Разрешение (формат 1920x1080):"
    $stack.Children.Add($lblSize) | Out-Null

    $txtSize = New-Object System.Windows.Controls.TextBox
    $txtSize.Style = $window.Resources["RoundedTextBox"]
    $txtSize.Text = if ($CurrentInfo.CurrSize -ne "—") { $CurrentInfo.CurrSize } else { "" }
    $txtSize.Margin = "0,0,0,10"
    $stack.Children.Add($txtSize) | Out-Null

    # --- Плотность ---
    $lblDensity = New-ViewLabel -Text "Плотность (dpi, например 320):"
    $stack.Children.Add($lblDensity) | Out-Null

    $txtDensity = New-Object System.Windows.Controls.TextBox
    $txtDensity.Style = $window.Resources["RoundedTextBox"]
    $txtDensity.Text = if ($CurrentInfo.CurrDensity -ne "—") { $CurrentInfo.CurrDensity } else { "" }
    $txtDensity.Margin = "0,0,0,10"
    $stack.Children.Add($txtDensity) | Out-Null

    # --- Предупреждение ---
    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = "Внимание: неверное разрешение может сделать экран ТВ чёрным или нечитаемым. Если это случится — перезагрузите ТВ (кнопка на корпусе), настройки сбросятся."
    $warnText.FontSize = 11
    $warnText.Foreground = "#856404"
    $warnText.TextWrapping = "Wrap"
    $warnText.Margin = "0,0,0,15"
    $stack.Children.Add($warnText) | Out-Null

    # --- Кнопки ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"

    $btnApply = New-ViewButton -Text "Применить" -ColorType "Success" -OnClick {
        $sizeVal    = $txtSize.Text.Trim()
        $densityVal = $txtDensity.Text.Trim()

        # Валидация размера
        if ($sizeVal -and $sizeVal -notmatch '^\d+x\d+$') {
            [System.Windows.MessageBox]::Show("Разрешение должно быть в формате 1920x1080", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        # Валидация плотности
        if ($densityVal -and $densityVal -notmatch '^\d+$') {
            [System.Windows.MessageBox]::Show("Плотность должна быть числом, например 320", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        if (-not $sizeVal -and -not $densityVal) {
            [System.Windows.MessageBox]::Show("Введите хотя бы одно значение", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        $dialog.Close()

        if ($sizeVal -and $densityVal) {
            Set-DisplayBoth -SizeValue $sizeVal -DensityValue $densityVal | Out-Null
        } elseif ($sizeVal) {
            Set-DisplaySize -SizeValue $sizeVal | Out-Null
        } else {
            Set-DisplayDensity -DensityValue $densityVal | Out-Null
        }

        Start-Sleep -Seconds 1
        Switch-View -ViewName "Display"
    }
    $btnPanel.Children.Add($btnApply) | Out-Null

    $btnCancel = New-ViewButton -Text "Отмена" -ColorType "Neutral" -OnClick {
        $dialog.Close()
    }
    $btnPanel.Children.Add($btnCancel) | Out-Null

    $stack.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $stack
    $dialog.ShowDialog() | Out-Null
}

# ===== ОСНОВНОЙ ЭКРАН =====
function Show-DisplayView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Разрешение и DPI"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ТЕКУЩЕЕ СОСТОЯНИЕ =====
    $info = Get-DisplayInfo

    $stateCard = New-Object System.Windows.Controls.Border
    $stateCard.Background = "#2B2B2B"
    $stateCard.BorderBrush = "#3A3A3A"
    $stateCard.BorderThickness = "1"
    $stateCard.CornerRadius = "8"
    $stateCard.Padding = "15"
    $stateCard.Margin = "0,0,0,15"

    $stateStack = New-Object System.Windows.Controls.StackPanel

    $stateTitle = New-Object System.Windows.Controls.TextBlock
    $stateTitle.Text = "Текущее состояние"
    $stateTitle.FontSize = 14
    $stateTitle.FontWeight = "Bold"
    $stateTitle.Foreground = "#C8C8C8"
    $stateTitle.Margin = "0,0,0,10"
    $stateStack.Children.Add($stateTitle) | Out-Null

    # Разрешение
    $sizeLine = New-Object System.Windows.Controls.TextBlock
    $sizeLine.FontSize = 13
    $sizeLine.Foreground = "#FFFFFF"
    $sizeLine.Margin = "0,2,0,2"
    if ($info.HasSizeOverride) {
        $sizeLine.Text = "Разрешение: $($info.CurrSize)   (override; физическое $($info.PhysSize))"
        $sizeLine.Foreground = "#F57C00"
    } else {
        $sizeLine.Text = "Разрешение: $($info.CurrSize)   (физическое)"
        $sizeLine.Foreground = "#2E7D32"
    }
    $stateStack.Children.Add($sizeLine) | Out-Null

    # Плотность
    $densLine = New-Object System.Windows.Controls.TextBlock
    $densLine.FontSize = 13
    $densLine.Margin = "0,2,0,2"
    if ($info.HasDensityOverride) {
        $densLine.Text = "DPI: $($info.CurrDensity)   (override; физический $($info.PhysDensity))"
        $densLine.Foreground = "#F57C00"
    } else {
        $densLine.Text = "DPI: $($info.CurrDensity)   (физический)"
        $densLine.Foreground = "#2E7D32"
    }
    $stateStack.Children.Add($densLine) | Out-Null

    # Кнопка сброса если есть override
    if ($info.HasSizeOverride -or $info.HasDensityOverride) {
        $btnResetAll = New-ViewButton -Text "Сбросить всё к заводскому" -ColorType "Warning" -Margin "0,10,0,0" -OnClick {
            $confirm = [System.Windows.MessageBox]::Show(
                "Сбросить разрешение и DPI к заводским значениям?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            if ($info.HasSizeOverride)    { Set-DisplaySize    -SizeValue "reset"    | Out-Null }
            if ($info.HasDensityOverride) { Set-DisplayDensity -DensityValue "reset" | Out-Null }

            Start-Sleep -Seconds 1
            Switch-View -ViewName "Display"
        }
        $stateStack.Children.Add($btnResetAll) | Out-Null
    }

    $stateCard.Child = $stateStack
    $mainStack.Children.Add($stateCard) | Out-Null

    # ===== ПРЕСЕТЫ РАЗРЕШЕНИЯ =====
    $mainStack.Children.Add((New-StepTitle -Text "Разрешение")) | Out-Null

    $sizePresets = @(
        @{ Name = "1280 × 720 (HD)";    Size = "1280x720";  Density = "240" }
        @{ Name = "1920 × 1080 (FHD)";  Size = "1920x1080"; Density = "320" }
        @{ Name = "2560 × 1440 (QHD)";  Size = "2560x1440"; Density = "320" }
        @{ Name = "3840 × 2160 (4K)";   Size = "3840x2160"; Density = "480" }
    )

    foreach ($preset in $sizePresets) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "#2B2B2B"
        $row.BorderBrush = "#3A3A3A"
        $row.BorderThickness = "1"
        $row.CornerRadius = "6"
        $row.Padding = "10"
        $row.Margin = "0,0,0,6"

        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition
        $c1.Width = "*"
        $c2 = New-Object System.Windows.Controls.ColumnDefinition
        $c2.Width = "Auto"
        $c3 = New-Object System.Windows.Controls.ColumnDefinition
        $c3.Width = "Auto"
        $grid.ColumnDefinitions.Add($c1)
        $grid.ColumnDefinitions.Add($c2)
        $grid.ColumnDefinitions.Add($c3)

        $textStack = New-Object System.Windows.Controls.StackPanel
        [System.Windows.Controls.Grid]::SetColumn($textStack, 0)

        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = $preset.Name
        $nameTb.FontSize = 13
        $nameTb.FontWeight = "Bold"
        $nameTb.Foreground = "#FFFFFF"
        $textStack.Children.Add($nameTb) | Out-Null

        $detailTb = New-Object System.Windows.Controls.TextBlock
        $detailTb.Text = "Разрешение: $($preset.Size)   |   Рекомендуемый DPI: $($preset.Density)"
        $detailTb.FontFamily = "Consolas"
        $detailTb.FontSize = 11
        $detailTb.Foreground = "#A0A0A0"
        $detailTb.Margin = "0,2,0,0"
        $textStack.Children.Add($detailTb) | Out-Null

        $grid.Children.Add($textStack) | Out-Null

        # Кнопка "Только размер"
        $btnSizeOnly = New-Object System.Windows.Controls.Button
        $btnSizeOnly.Content = "Только размер"
        $btnSizeOnly.Style = $window.Resources["RoundedButton"]
        $btnSizeOnly.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnSizeOnly.Padding = "10,5"
        $btnSizeOnly.FontSize = 11
        $btnSizeOnly.Margin = "0,0,6,0"
        $btnSizeOnly.VerticalAlignment = "Center"
        $sizeLocal = $preset.Size
        $btnSizeOnly.Add_Click({
            Set-DisplaySize -SizeValue $sizeLocal | Out-Null
            Start-Sleep -Milliseconds 500
            Switch-View -ViewName "Display"
        }.GetNewClosure())
        [System.Windows.Controls.Grid]::SetColumn($btnSizeOnly, 1)
        $grid.Children.Add($btnSizeOnly) | Out-Null

        # Кнопка "Размер + DPI"
        $btnBoth = New-Object System.Windows.Controls.Button
        $btnBoth.Content = "Размер + DPI"
        $btnBoth.Style = $window.Resources["RoundedButton"]
        $btnBoth.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnBoth.Padding = "10,5"
        $btnBoth.FontSize = 11
        $btnBoth.VerticalAlignment = "Center"
        $sizeLocal2    = $preset.Size
        $densityLocal  = $preset.Density
        $btnBoth.Add_Click({
            Set-DisplayBoth -SizeValue $sizeLocal2 -DensityValue $densityLocal | Out-Null
            Start-Sleep -Milliseconds 500
            Switch-View -ViewName "Display"
        }.GetNewClosure())
        [System.Windows.Controls.Grid]::SetColumn($btnBoth, 2)
        $grid.Children.Add($btnBoth) | Out-Null

        $row.Child = $grid
        $mainStack.Children.Add($row) | Out-Null
    }

    # ===== ПРЕСЕТЫ DPI =====
    $mainStack.Children.Add((New-StepTitle -Text "Плотность (DPI)")) | Out-Null

    $densityPresets = @(
        @{ Name = "160 dpi (LDPI)";  Value = "160" }
        @{ Name = "240 dpi (HDPI)";  Value = "240" }
        @{ Name = "320 dpi (XHDPI)"; Value = "320" }
        @{ Name = "480 dpi (XXHDPI)";Value = "480" }
    )

    $densityWrap = New-Object System.Windows.Controls.WrapPanel
    $densityWrap.Margin = "0,5,0,15"

    foreach ($preset in $densityPresets) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $preset.Name
        $btn.Style = $window.Resources["RoundedButton"]
        $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btn.Padding = "12,6"
        $btn.Margin = "0,0,8,8"
        $btn.FontSize = 12
        $valLocal = $preset.Value
        $btn.Add_Click({
            Set-DisplayDensity -DensityValue $valLocal | Out-Null
            Start-Sleep -Milliseconds 500
            Switch-View -ViewName "Display"
        }.GetNewClosure())
        $densityWrap.Children.Add($btn) | Out-Null
    }

    $mainStack.Children.Add($densityWrap) | Out-Null

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== НИЖНЯЯ ПАНЕЛЬ =====
    $buttons = @()

    $btnCustom = New-Object System.Windows.Controls.Button
    $btnCustom.Content = "Кастомные значения"
    $btnCustom.Style = $window.Resources["RoundedButton"]
    $btnCustom.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnCustom.Padding = "12,6"
    $btnCustom.Margin = "0,0,8,0"
    $btnCustom.Add_Click({
        Show-CustomDisplayDialog -CurrentInfo $info
    })
    $buttons += $btnCustom

    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({
        Switch-View -ViewName "Display"
    })
    $buttons += $btnRefresh

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран разрешения и DPI" -Level "Info"
}