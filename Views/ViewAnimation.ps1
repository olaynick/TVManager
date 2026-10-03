function Show-AnimationView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "40,30,40,30"

    $header = New-ViewHeader -Text "Масштаб анимации"
    $mainStack.Children.Add($header) | Out-Null

    # ===== ЧТО ЭТО ТАКОЕ =====
    $desc = New-ViewLabel -Text "Масштаб анимации определяет скорость проигрывания анимаций интерфейса: открытие окон, переключение меню, запуск приложений. Чем меньше значение — тем быстрее отклик, но тем резче выглядят переходы." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    # ===== ТЕКУЩИЕ ЗНАЧЕНИЯ =====
    $currentHeader = New-StepTitle -Text "Текущие значения"
    $mainStack.Children.Add($currentHeader) | Out-Null

    # Получаем текущие значения с ТВ
    $windowVal = "—"
    $transitionVal = "—"
    $animatorVal = "—"
    if ($script:connected) {
        try {
            $windowVal = (& $script:adbPath shell settings get global window_animation_scale 2>&1).Trim()
            $transitionVal = (& $script:adbPath shell settings get global transition_animation_scale 2>&1).Trim()
            $animatorVal = (& $script:adbPath shell settings get global animator_duration_scale 2>&1).Trim()
        } catch { }
    }

    $valuesBox = New-Object System.Windows.Controls.Border
    $valuesBox.Background = "#FFFFFF"
    $valuesBox.BorderBrush = "#3A3A3A"
    $valuesBox.BorderThickness = "1"
    $valuesBox.CornerRadius = "8"
    $valuesBox.Padding = "15,10"
    $valuesBox.Margin = "0,0,0,20"

    $valuesStack = New-Object System.Windows.Controls.StackPanel

    $l1 = New-Object System.Windows.Controls.TextBlock
    $l1.Text = "Окна:              $windowVal"
    $l1.FontFamily = "Consolas"
    $l1.FontSize = 13
    $l1.Foreground = "#FFFFFF"
    $l1.Margin = "0,2,0,2"
    $valuesStack.Children.Add($l1) | Out-Null

    $l2 = New-Object System.Windows.Controls.TextBlock
    $l2.Text = "Переходы:          $transitionVal"
    $l2.FontFamily = "Consolas"
    $l2.FontSize = 13
    $l2.Foreground = "#FFFFFF"
    $l2.Margin = "0,2,0,2"
    $valuesStack.Children.Add($l2) | Out-Null

    $l3 = New-Object System.Windows.Controls.TextBlock
    $l3.Text = "Аниматор:          $animatorVal"
    $l3.FontFamily = "Consolas"
    $l3.FontSize = 13
    $l3.Foreground = "#FFFFFF"
    $l3.Margin = "0,2,0,2"
    $valuesStack.Children.Add($l3) | Out-Null

    $valuesBox.Child = $valuesStack
    $mainStack.Children.Add($valuesBox) | Out-Null

    # ===== ВАРИАНТЫ =====
    $variantsHeader = New-StepTitle -Text "Выберите масштаб"
    $mainStack.Children.Add($variantsHeader) | Out-Null

    # 1x
    $desc1 = New-ViewLabel -Text "1x — стандартная плавность, но интерфейс ощущается медленнее" -Light
    $mainStack.Children.Add($desc1) | Out-Null
    $mainStack.Children.Add((New-ViewButton -Text "1x  (стандарт)" -Color "#C8C8C8" -Margin "0,0,0,15" -Padding "20,10" -OnClick {
        Set-Animation -Value "1.0"
        Switch-View -ViewName "Animation"
    })) | Out-Null

    # 0.5x
    $desc2 = New-ViewLabel -Text "0.5x — анимации в 2 раза короче, интерфейс заметно шустрее (рекомендуется)" -Light
    $mainStack.Children.Add($desc2) | Out-Null
    $mainStack.Children.Add((New-ViewButton -Text "0.5x  (быстрее, рекомендуется)" -Color "#C8C8C8" -Margin "0,0,0,15" -Padding "20,10" -OnClick {
        Set-Animation -Value "0.5"
        Switch-View -ViewName "Animation"
    })) | Out-Null

    # 0x
    $desc3 = New-ViewLabel -Text "0x — анимации отключены, окна открываются мгновенно, но переходы выглядят резко" -Light
    $mainStack.Children.Add($desc3) | Out-Null
    $mainStack.Children.Add((New-ViewButton -Text "0x  (мгновенно, максимальная скорость)" -Color "#C8C8C8" -Padding "20,10" -OnClick {
        Set-Animation -Value "0.0"
        Switch-View -ViewName "Animation"
    })) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран анимации" -Level "Info"
}

function Set-Animation {
    param([string]$Value)

    Write-Log -Message "Меняю масштаб анимации на $Value..." -Level "Info"

    $prevWindow = (& $script:adbPath shell settings get global window_animation_scale 2>&1).Trim()
    $prevTransition = (& $script:adbPath shell settings get global transition_animation_scale 2>&1).Trim()
    $prevAnimator = (& $script:adbPath shell settings get global animator_duration_scale 2>&1).Trim()

    & $script:adbPath shell settings put global window_animation_scale $Value
    & $script:adbPath shell settings put global transition_animation_scale $Value
    & $script:adbPath shell settings put global animator_duration_scale $Value

    Write-Log -Message "Установлено: $Value" -Level "Success"

    Save-Change -Type "settings_changed" -Target "window_animation_scale" -RestoreCommand "adb shell settings put global window_animation_scale $prevWindow"
    Save-Change -Type "settings_changed" -Target "transition_animation_scale" -RestoreCommand "adb shell settings put global transition_animation_scale $prevTransition"
    Save-Change -Type "settings_changed" -Target "animator_duration_scale" -RestoreCommand "adb shell settings put global animator_duration_scale $prevAnimator"
    Save-AllChanges
    Write-Log -Message "Файл отката обновлён." -Level "Success"
}