# ============================================================================
#  Экран: Пресеты настроек системы
#  3 вкладки: Экран / Интерфейс / Система.
#  Внутри каждой — подзаголовки по исходным группам.
# ============================================================================

function Invoke-PresetAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== ПРИМЕНЕНИЕ ОДНОЙ SETTINGS-КОМАНДЫ С СОХРАНЕНИЕМ =====
function Apply-SettingPreset {
    param(
        [string]$Namespace,     # global / system / secure
        [string]$Key,
        [string]$Value,
        [string]$DisplayName = ""
    )

    $label = if ($DisplayName) { $DisplayName } else { "$Namespace.$Key = $Value" }
    Write-Log -Message "Применяю: $label" -Level "Info"

    # Считываем предыдущее значение
    $prev = Invoke-PresetAdb @("shell", "settings", "get", $Namespace, $Key)
    $prevClean = ($prev -replace "`r?`n", "").Trim()

    $isNullPrev = ($prevClean -eq "null" -or [string]::IsNullOrWhiteSpace($prevClean))

    # Применяем
    $out = Invoke-PresetAdb @("shell", "settings", "put", $Namespace, $Key, $Value)
    if ($out -match 'error|Error|Exception|Security') {
        Write-Log -Message "  Ошибка: $out" -Level "Error"
        return $false
    }

    Write-Log -Message "  OK (было: $(if ($isNullPrev) { 'не задано' } else { $prevClean }))" -Level "Success"

    # Команда отката
    if ($isNullPrev) {
        $restoreCmd = "adb shell settings delete $Namespace $Key"
    } else {
        $restoreCmd = "adb shell settings put $Namespace $Key $prevClean"
    }

    Save-Change -Type "settings_changed" -Target "$Namespace.$Key" `
                -RestoreCommand $restoreCmd `
                -Namespace $Namespace `
                -PreviousValue $prevClean
    Save-AllChanges
    return $true
}

# ===== ПРИМЕНЕНИЕ НЕСКОЛЬКИХ НАСТРОЕК ПАКЕТОМ =====
function Apply-SettingsBatch {
    param(
        [array]$Settings,
        [string]$DisplayName
    )

    Write-Log -Message "=== Пресет: $DisplayName ===" -Level "Info"
    $ok = 0
    foreach ($s in $Settings) {
        if (Apply-SettingPreset -Namespace $s.Namespace -Key $s.Key -Value $s.Value) {
            $ok++
        }
    }
    Write-Log -Message "Применено: $ok из $($Settings.Count)" -Level "Success"
    return ($ok -eq $Settings.Count)
}

# ===== СПИСОК ПРЕСЕТОВ =====
#  Поле Group — это подзаголовок внутри вкладки.
#  Вкладка определяется по Group в $script:PresetTabMap ниже.
function Get-SettingPresets {
    return @(
        # ===== Тайм-аут экрана =====
        @{ Group = "Тайм-аут экрана"; Name = "5 минут"; Desc = "Экран отключается через 5 минут бездействия"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_off_timeout"; Value = "300000" }) }

        @{ Group = "Тайм-аут экрана"; Name = "15 минут"; Desc = "Экран отключается через 15 минут бездействия"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_off_timeout"; Value = "900000" }) }

        @{ Group = "Тайм-аут экрана"; Name = "30 минут"; Desc = "Экран отключается через 30 минут бездействия"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_off_timeout"; Value = "1800000" }) }

        @{ Group = "Тайм-аут экрана"; Name = "1 час"; Desc = "Экран отключается через 1 час бездействия"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_off_timeout"; Value = "3600000" }) }

        @{ Group = "Тайм-аут экрана"; Name = "2 часа"; Desc = "Экран отключается через 2 часа бездействия"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_off_timeout"; Value = "7200000" }) }

        @{ Group = "Тайм-аут экрана"; Name = "Никогда"; Desc = "Экран не отключается автоматически"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_off_timeout"; Value = "2147483647" }) }

        # ===== Анимации =====
        @{ Group = "Анимации"; Name = "Стандарт (1x)"; Desc = "Обычная плавность, как при первом запуске"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "global"; Key = "window_animation_scale";     Value = "1.0" }
               @{ Namespace = "global"; Key = "transition_animation_scale"; Value = "1.0" }
               @{ Namespace = "global"; Key = "animator_duration_scale";    Value = "1.0" }
           ) }

        @{ Group = "Анимации"; Name = "Быстро (0.5x)"; Desc = "Анимации в 2 раза быстрее. Рекомендуется."; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "global"; Key = "window_animation_scale";     Value = "0.5" }
               @{ Namespace = "global"; Key = "transition_animation_scale"; Value = "0.5" }
               @{ Namespace = "global"; Key = "animator_duration_scale";    Value = "0.5" }
           ) }

        @{ Group = "Анимации"; Name = "Очень быстро (0.25x)"; Desc = "Почти мгновенно, переходы едва заметны"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "global"; Key = "window_animation_scale";     Value = "0.25" }
               @{ Namespace = "global"; Key = "transition_animation_scale"; Value = "0.25" }
               @{ Namespace = "global"; Key = "animator_duration_scale";    Value = "0.25" }
           ) }

        @{ Group = "Анимации"; Name = "Отключить (0x)"; Desc = "Мгновенные переходы. Интерфейс работает максимально быстро."; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "global"; Key = "window_animation_scale";     Value = "0.0" }
               @{ Namespace = "global"; Key = "transition_animation_scale"; Value = "0.0" }
               @{ Namespace = "global"; Key = "animator_duration_scale";    Value = "0.0" }
           ) }

        # ===== Яркость экрана =====
        @{ Group = "Яркость экрана"; Name = "25%"; Desc = "Минимальная комфортная яркость (для тёмных помещений)"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "system"; Key = "screen_brightness";      Value = "64" }
               @{ Namespace = "system"; Key = "screen_brightness_mode"; Value = "0" }
           ) }

        @{ Group = "Яркость экрана"; Name = "50%"; Desc = "Средняя яркость. Подходит для большинства помещений."; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "system"; Key = "screen_brightness";      Value = "127" }
               @{ Namespace = "system"; Key = "screen_brightness_mode"; Value = "0" }
           ) }

        @{ Group = "Яркость экрана"; Name = "75%"; Desc = "Повышенная яркость для светлых помещений"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "system"; Key = "screen_brightness";      Value = "191" }
               @{ Namespace = "system"; Key = "screen_brightness_mode"; Value = "0" }
           ) }

        @{ Group = "Яркость экрана"; Name = "100%"; Desc = "Максимальная яркость"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "system"; Key = "screen_brightness";      Value = "255" }
               @{ Namespace = "system"; Key = "screen_brightness_mode"; Value = "0" }
           ) }

        @{ Group = "Яркость экрана"; Name = "Автоматически"; Desc = "Адаптивная яркость от датчика освещения"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "screen_brightness_mode"; Value = "1" }) }

        # ===== Immersive =====
        @{ Group = "Immersive режим"; Name = "Скрыть всё (полный)"; Desc = "Убирает статус-бар и навигацию. Полноэкранный режим."; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "policy_control"; Value = "immersive.full=*" }) }

        @{ Group = "Immersive режим"; Name = "Скрыть только статус-бар"; Desc = "Убирает верхнюю полосу, оставляет навигацию"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "policy_control"; Value = "immersive.status=*" }) }

        @{ Group = "Immersive режим"; Name = "Показать всё обратно"; Desc = "Возвращает статус-бар и навигацию"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "policy_control"; Value = "null" }) }

        # ===== Разработчик =====
        @{ Group = "Для разработчиков"; Name = "Показывать касания"; Desc = "На экране отображаются точки нажатий (для отладки пультов)"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "system"; Key = "show_touches"; Value = "1" }) }

        @{ Group = "Для разработчиков"; Name = "Границы макета"; Desc = "Показывает границы элементов UI (полезно для разработки лаунчеров)"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "debug_layout"; Value = "1" }) }

        @{ Group = "Для разработчиков"; Name = "GPU-рендеринг"; Desc = "Показывает профилировку GPU (полосы на экране)"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "show_gpu_view"; Value = "1" }) }

        @{ Group = "Для разработчиков"; Name = "Выключить отладку"; Desc = "Убрать все визуальные отладочные оверлеи"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "system"; Key = "show_touches";  Value = "0" }
               @{ Namespace = "global"; Key = "debug_layout";  Value = "0" }
               @{ Namespace = "global"; Key = "show_gpu_view"; Value = "0" }
           ) }

        # ===== Питание и блокировка =====
        @{ Group = "Питание и блокировка"; Name = "Не гасить при зарядке"; Desc = "ТВ не будет уходить в сон, пока подключён к сети"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "stay_on_while_plugged_in"; Value = "7" }) }

        @{ Group = "Питание и блокировка"; Name = "Обычное поведение сна"; Desc = "Разрешить ТВ уходить в сон по тайм-ауту"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "stay_on_while_plugged_in"; Value = "0" }) }

        @{ Group = "Питание и блокировка"; Name = "Отключить блокировку экрана"; Desc = "ТВ не запрашивает PIN после пробуждения"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "secure"; Key = "lockscreen.disabled"; Value = "1" }) }

        @{ Group = "Питание и блокировка"; Name = "Включить блокировку экрана"; Desc = "Вернуть запрос PIN после пробуждения"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "secure"; Key = "lockscreen.disabled"; Value = "0" }) }

        # ===== Звук =====
        @{ Group = "Звук"; Name = "Отключить предупреждение громкости"; Desc = "Убирает всплывающее окно «Безопасный уровень громкости»"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "audio_safe_volume_state"; Value = "2" }) }

        @{ Group = "Звук"; Name = "Включить предупреждение громкости"; Desc = "Вернуть системное предупреждение при высокой громкости"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "global"; Key = "audio_safe_volume_state"; Value = "0" }) }

        # ===== Прочее =====
        @{ Group = "Прочее"; Name = "Оставить ADB включённым"; Desc = "ADB не отключается после перезагрузки"; Color = "#C8C8C8";
           Settings = @(
               @{ Namespace = "global"; Key = "adb_enabled";                   Value = "1" }
               @{ Namespace = "global"; Key = "development_settings_enabled";  Value = "1" }
           ) }

        @{ Group = "Прочее"; Name = "Скрыть значки уведомлений"; Desc = "Убирает иконки приложений из статус-бара"; Color = "#C8C8C8";
           Settings = @(@{ Namespace = "secure"; Key = "icon_blacklist"; Value = "com.android.systemui.statusbar.notification,com.android.systemui.statusbar.phone" }) }
    )
}

# ===== СООТВЕТСТВИЕ: Подзаголовок → Вкладка =====
$script:PresetTabMap = @{
    "Экран" = @("Тайм-аут экрана", "Яркость экрана", "Immersive режим")
    "Интерфейс" = @("Анимации", "Для разработчиков")
    "Система" = @("Питание и блокировка", "Звук", "Прочее")
}

# ===== ОСНОВНОЙ ЭКРАН =====
function Show-PresetsView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Пресеты настроек"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Готовые наборы настроек системы. Каждое изменение сохраняется в историю отката." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # --- Загружаем все пресеты ---
    $allPresets = Get-SettingPresets

    if (-not $allPresets -or $allPresets.Count -eq 0) {
        $mainStack.Children.Add((New-ViewLabel -Text "Не удалось загрузить пресеты.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # --- Строим вкладки ---
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    $tabControl.Margin = "0,10,0,0"

    foreach ($tabName in @("Экран", "Интерфейс", "Система")) {
        $subGroups = $script:PresetTabMap[$tabName]

        # Собираем пресеты этой вкладки
        $tabPresets = @()
        foreach ($subGroup in $subGroups) {
            foreach ($p in $allPresets) {
                if ($p.Group -eq $subGroup) {
                    $tabPresets += $p
                }
            }
        }

        $tab = New-Object System.Windows.Controls.TabItem
        $tab.Header = "$tabName ($($tabPresets.Count))"
        $tab.Style = $window.Resources["MiuiTabItem"]

        $tabPanel = New-Object System.Windows.Controls.StackPanel
        $tabPanel.Margin = "15"

        # --- Группируем по подзаголовку ---
        $lastSubGroup = ""
        foreach ($preset in $tabPresets) {
            # --- Подзаголовок группы ---
            if ($preset.Group -ne $lastSubGroup) {
                $subHeader = New-Object System.Windows.Controls.TextBlock
                $subHeader.Text = $preset.Group
                $subHeader.FontSize = 14
                $subHeader.FontWeight = "Bold"
                $subHeader.Foreground = "#C8C8C8"
                $subHeader.Margin = "0,10,0,8"
                $tabPanel.Children.Add($subHeader) | Out-Null
                $lastSubGroup = $preset.Group
            }

            # --- Карточка пресета ---
            $row = New-Object System.Windows.Controls.Border
            $row.Background = "#2B2B2B"
            $row.BorderBrush = "#3A3A3A"
            $row.BorderThickness = "1"
            $row.CornerRadius = "6"
            $row.Padding = "12"
            $row.Margin = "0,0,0,8"

            $grid = New-Object System.Windows.Controls.Grid
            $c1 = New-Object System.Windows.Controls.ColumnDefinition
            $c1.Width = "*"
            $c2 = New-Object System.Windows.Controls.ColumnDefinition
            $c2.Width = "Auto"
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)

            $textStack = New-Object System.Windows.Controls.StackPanel
            [System.Windows.Controls.Grid]::SetColumn($textStack, 0)

            $nameTb = New-Object System.Windows.Controls.TextBlock
            $nameTb.Text = $preset.Name
            $nameTb.FontSize = 13
            $nameTb.FontWeight = "Bold"
            $nameTb.Foreground = "#FFFFFF"
            $textStack.Children.Add($nameTb) | Out-Null

            $descTb = New-Object System.Windows.Controls.TextBlock
            $descTb.Text = $preset.Desc
            $descTb.FontSize = 11
            $descTb.Foreground = "#A0A0A0"
            $descTb.TextWrapping = "Wrap"
            $descTb.Margin = "0,3,0,0"
            $textStack.Children.Add($descTb) | Out-Null

            # Список команд
            $cmdText = ($preset.Settings | ForEach-Object {
                "$($_.Namespace).$($_.Key)=$($_.Value)"
            }) -join "   |   "

            $cmdTb = New-Object System.Windows.Controls.TextBlock
            $cmdTb.Text = $cmdText
            $cmdTb.FontFamily = "Consolas"
            $cmdTb.FontSize = 10
            $cmdTb.Foreground = "#C8C8C8"
            $cmdTb.TextWrapping = "Wrap"
            $cmdTb.Margin = "0,3,0,0"
            $textStack.Children.Add($cmdTb) | Out-Null

            $grid.Children.Add($textStack) | Out-Null

            # Кнопка "Применить"
            $btnApply = New-Object System.Windows.Controls.Button
            $btnApply.Content = "Применить"
            $btnApply.Style = $window.Resources["RoundedButton"]
            $btnApply.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString($preset.Color)
            )
            $btnApply.Padding = "12,6"
            $btnApply.FontSize = 12
            $btnApply.VerticalAlignment = "Center"
            $btnApply.MinWidth = 100

            $presetLocal = $preset
            $btnApply.Add_Click({
                $confirm = [System.Windows.MessageBox]::Show(
                    "Применить пресет «$($presetLocal.Name)»?`n`n$($presetLocal.Desc)",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

                Apply-SettingsBatch -Settings $presetLocal.Settings -DisplayName $presetLocal.Name | Out-Null

                [System.Windows.MessageBox]::Show(
                    "Пресет применён.",
                    "Готово",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information) | Out-Null
            }.GetNewClosure())

            [System.Windows.Controls.Grid]::SetColumn($btnApply, 1)
            $grid.Children.Add($btnApply) | Out-Null

            $row.Child = $grid
            $tabPanel.Children.Add($row) | Out-Null
        }

        $tab.Content = $tabPanel
        $tabControl.Items.Add($tab) | Out-Null
    }

    $mainStack.Children.Add($tabControl) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран пресетов настроек (3 вкладки: Экран / Интерфейс / Система)" -Level "Info"
}