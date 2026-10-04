function Show-AnimationView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Масштаб анимации"
    $mainStack.Children.Add($header) | Out-Null

    # ===== ЧТО ЭТО ТАКОЕ =====
    $desc = New-ViewLabel -Text "Масштаб анимации определяет скорость проигрывания анимаций интерфейса: открытие окон, переключение меню, запуск приложений. Чем меньше значение — тем быстрее отклик, но тем резче выглядят переходы." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    # ===== ТЕКУЩИЕ ЗНАЧЕНИЯ =====
    $mainStack.Children.Add((New-StepTitle -Text "Текущие значения")) | Out-Null

    $windowVal = "—"
    $transitionVal = "—"
    $animatorVal = "—"
    if ($script:connected) {
        try {
            $windowVal = (& $script:adbPath shell settings get global window_animation_scale 2>&1 | Out-String).Trim()
            $transitionVal = (& $script:adbPath shell settings get global transition_animation_scale 2>&1 | Out-String).Trim()
            $animatorVal = (& $script:adbPath shell settings get global animator_duration_scale 2>&1 | Out-String).Trim()
        } catch { }
    }

    $valuesBox = New-Object System.Windows.Controls.Border
    $valuesBox.Background = "#2B2B2B"
    $valuesBox.BorderBrush = "#3A3A3A"
    $valuesBox.BorderThickness = "1"
    $valuesBox.CornerRadius = "8"
    $valuesBox.Padding = "15,10"
    $valuesBox.Margin = "0,0,0,20"

    $valuesStack = New-Object System.Windows.Controls.StackPanel

    $valuesList = @(
        @{ Label = "Окна";        Value = $windowVal }
        @{ Label = "Переходы";    Value = $transitionVal }
        @{ Label = "Аниматор";    Value = $animatorVal }
    )

    foreach ($row in $valuesList) {
        $line = New-Object System.Windows.Controls.TextBlock
        $line.Text = "$($row.Label):  $($row.Value)"
        $line.FontFamily = "Consolas"
        $line.FontSize = 13
        $line.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $line.Margin = "0,2,0,2"
        $valuesStack.Children.Add($line) | Out-Null
    }

    $valuesBox.Child = $valuesStack
    $mainStack.Children.Add($valuesBox) | Out-Null

    # ===== ВАРИАНТЫ =====
    $mainStack.Children.Add((New-StepTitle -Text "Выберите масштаб")) | Out-Null

    # --- 1x ---
    $desc1 = New-ViewLabel -Text "1x — стандартная плавность, но интерфейс ощущается медленнее" -Light
    $mainStack.Children.Add($desc1) | Out-Null
    $btn1x = New-ViewButton -Text "1x  (стандарт)" -ColorType "Primary" -Margin "0,0,0,15" -Stretch -OnClick {
        Set-Animation -Value "1.0"
        Switch-View -ViewName "Animation"
    }
    $mainStack.Children.Add($btn1x) | Out-Null

    # --- 0.5x ---
    $desc2 = New-ViewLabel -Text "0.5x — анимации в 2 раза короче, интерфейс заметно шустрее (рекомендуется)" -Light
    $mainStack.Children.Add($desc2) | Out-Null
    $btn05x = New-ViewButton -Text "0.5x  (быстрее, рекомендуется)" -ColorType "Success" -Margin "0,0,0,15" -Stretch -OnClick {
        Set-Animation -Value "0.5"
        Switch-View -ViewName "Animation"
    }
    $mainStack.Children.Add($btn05x) | Out-Null

    # --- 0x ---
    $desc3 = New-ViewLabel -Text "0x — анимации отключены, окна открываются мгновенно, но переходы выглядят резко" -Light
    $mainStack.Children.Add($desc3) | Out-Null
    $btn0x = New-ViewButton -Text "0x  (мгновенно, максимальная скорость)" -ColorType "Warning" -Stretch -OnClick {
        Set-Animation -Value "0.0"
        Switch-View -ViewName "Animation"
    }
    $mainStack.Children.Add($btn0x) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран анимации" -Level "Info"
}

function Set-Animation {
    param([string]$Value)

    Write-Log -Message "Меняю масштаб анимации на $Value..." -Level "Info"

    $prevWindow = (& $script:adbPath shell settings get global window_animation_scale 2>&1 | Out-String).Trim()
    $prevTransition = (& $script:adbPath shell settings get global transition_animation_scale 2>&1 | Out-String).Trim()
    $prevAnimator = (& $script:adbPath shell settings get global animator_duration_scale 2>&1 | Out-String).Trim()

    & $script:adbPath shell settings put global window_animation_scale $Value | Out-Null
    & $script:adbPath shell settings put global transition_animation_scale $Value | Out-Null
    & $script:adbPath shell settings put global animator_duration_scale $Value | Out-Null

    Write-Log -Message "Установлено: $Value" -Level "Success"

    Save-Change -Type "settings_changed" -Target "window_animation_scale" -RestoreCommand "adb shell settings put global window_animation_scale $prevWindow"
    Save-Change -Type "settings_changed" -Target "transition_animation_scale" -RestoreCommand "adb shell settings put global transition_animation_scale $prevTransition"
    Save-Change -Type "settings_changed" -Target "animator_duration_scale" -RestoreCommand "adb shell settings put global animator_duration_scale $prevAnimator"
    Save-AllChanges
    Write-Log -Message "Файл отката обновлён." -Level "Success"
}