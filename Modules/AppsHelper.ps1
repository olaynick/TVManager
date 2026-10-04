# ============================================================================
#  Apps Helper — список приложений, лаунчеры, запуск
#
#  БЕЗОПАСНАЯ ЛОГИКА СМЕНЫ ЛАУНЧЕРА:
#  - Штатный launcher и setupwraith НИКОГДА не отключаются автоматически.
#  - Используется ТОЛЬКО set-home-activity (безопасная команда).
#  - Если система не переключилась — показывается КАСТОМНЫЙ диалог
#    с возможностью скопировать команды ADB в один клик.
#  - Рекомендуется встроенный Accessibility-режим лаунчера.
# ============================================================================

function Invoke-AppsAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ============================================================================
#  ВСЕ ПРИЛОЖЕНИЯ С НАЗВАНИЯМИ
# ============================================================================
function Get-AllAppsWithNames {
    Write-Log -Message "Читаю список приложений..." -Level "Info"

    $apps = @()

    try {
        $allRaw   = Invoke-AppsAdb @("shell", "pm", "list", "packages")
        $thirdRaw = Invoke-AppsAdb @("shell", "pm", "list", "packages", "-3")

        $thirdSet = @{}
        foreach ($line in ($thirdRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') { $thirdSet[$matches[1].Trim()] = $true }
        }

        foreach ($line in ($allRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') {
                $pkg = $matches[1].Trim()
                $apps += [PSCustomObject]@{
                    Package    = $pkg
                    IsSystem   = (-not $thirdSet.ContainsKey($pkg))
                    IsLauncher = $false
                }
            }
        }

        Write-Log -Message "Пакетов: $($apps.Count)" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка: $_" -Level "Error"
    }

    return ,$apps
}

# ============================================================================
#  ИЗВЕСТНЫЕ ЛАУНЧЕРЫ
# ============================================================================
function Get-KnownLaunchers {
    return @(
        @{ Package = "ca.dstudio.atvlauncher.pro";           Name = "ATV Launcher Pro" }
        @{ Package = "ca.dstudio.atvlauncher";               Name = "ATV Launcher" }
        @{ Package = "com.smart.tv.launcher";                Name = "Smart TV Launcher" }
        @{ Package = "com.nexfy.launcher";                   Name = "Nexfy Launcher" }
        @{ Package = "com.tek.apphub.launcher";              Name = "Primal TV Launcher" }
        @{ Package = "com.spocky.projengmenu";               Name = "Projectivy Launcher" }
        @{ Package = "com.deepnight.launcher";               Name = "Deep Night Launcher" }
        @{ Package = "com.klevico.monet";                    Name = "Monet — Android TV Launcher" }
        @{ Package = "com.atv4k.launcher";                   Name = "AT4K Launcher" }
        @{ Package = "com.atv4k.launcher.premium";           Name = "AT4K Launcher Premium" }
        @{ Package = "me.efesser.flauncher";                 Name = "FLauncher" }
        @{ Package = "com.supersmart.launcher";              Name = "Super Smart Launcher" }
        @{ Package = "com.google.android.apps.tv.launcherx"; Name = "Google TV Launcher (системный)" }
        @{ Package = "com.tcl.tv";                           Name = "TCL Launcher (системный)" }
        @{ Package = "com.android.tv.launcher";              Name = "AOSP TV Launcher" }
        @{ Package = "com.google.android.tvlauncher";        Name = "Google TV Launcher (старый)" }
        @{ Package = "com.android.tv.settings";              Name = "TV Settings (системный)" }
    )
}

# ============================================================================
#  СПИСОК ЛАУНЧЕРОВ
# ============================================================================
function Get-LauncherPackages {
    Write-Log -Message "Ищу лаунчеры..." -Level "Info"

    $launchers = @()

    $allRaw = Invoke-AppsAdb @("shell", "pm", "list", "packages")
    $installed = @{}
    foreach ($line in ($allRaw -split "`r?`n")) {
        if ($line -match '^package:(.+)$') { $installed[$matches[1].Trim()] = $true }
    }

    $sysRaw = Invoke-AppsAdb @("shell", "pm", "list", "packages", "-s")
    $systemSet = @{}
    foreach ($line in ($sysRaw -split "`r?`n")) {
        if ($line -match '^package:(.+)$') { $systemSet[$matches[1].Trim()] = $true }
    }

    # Текущий лаунчер
    $currentLauncher = ""
    try {
        $curOut = Invoke-AppsAdb @("shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.HOME")
        foreach ($line in ($curOut -split "`r?`n")) {
            $line = $line.Trim()
            if ($line -match '^([a-z][a-z0-9_\.]+)/([A-Za-z0-9_\.]+)$') {
                $currentLauncher = $matches[1]
                break
            }
        }
    } catch { }
    Write-Log -Message "Текущий лаунчер: $(if ($currentLauncher) { $currentLauncher } else { 'НЕ ОПРЕДЕЛЁН' })" -Level "Info"

    $knownLaunchers = Get-KnownLaunchers
    foreach ($known in $knownLaunchers) {
        if (-not $installed.ContainsKey($known.Package)) { continue }

        $realActivity = ""

        # Способ 1: resolve-activity -p
        try {
            $resOut = Invoke-AppsAdb @("shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.HOME", "-p", $known.Package)
            foreach ($line in ($resOut -split "`r?`n")) {
                $line = $line.Trim()
                if ($line -match '^([a-z][a-z0-9_\.]+)/([A-Za-z0-9_\.]+)$') {
                    $realActivity = "$($matches[1])/$($matches[2])"
                    break
                }
            }
        } catch { }

        # Способ 2: dumpsys package
        if (-not $realActivity) {
            try {
                $dumpOut = Invoke-AppsAdb @("shell", "dumpsys", "package", $known.Package)
                $inHomeBlock = $false
                foreach ($line in ($dumpOut -split "`r?`n")) {
                    if ($line -match 'android\.intent\.category\.HOME') {
                        $inHomeBlock = $true
                        continue
                    }
                    if ($inHomeBlock) {
                        if ($line -match '([a-z][a-z0-9\.]+)/([A-Za-z0-9_\.]+)') {
                            $realActivity = "$($matches[1])/$($matches[2])"
                            break
                        }
                    }
                    if ($line -match '^\s*$') { $inHomeBlock = $false }
                }
            } catch { }
        }

        # Fallback
        if (-not $realActivity) {
            $realActivity = "$($known.Package)/.MainActivity"
        }

        $launchers += [PSCustomObject]@{
            Package   = $known.Package
            Name      = $known.Name
            Activity  = $realActivity
            IsSystem  = $systemSet.ContainsKey($known.Package)
            IsCurrent = ($currentLauncher -eq $known.Package)
        }
    }

    Write-Log -Message "Лаунчеров найдено: $($launchers.Count)" -Level "Info"
    return ,$launchers
}

# ============================================================================
#  ЗАПУСК ПРИЛОЖЕНИЯ
# ============================================================================
function Start-RemoteApp {
    param([string]$Package)

    Write-Log -Message "Запускаю приложение: $Package" -Level "Info"

    $out = Invoke-AppsAdb @("shell", "monkey", "-p", $Package, "-c", "android.intent.category.LAUNCHER", "1")
    if ($out -match 'Events injected: 1') {
        Write-Log -Message "OK: $Package запущен" -Level "Success"
        return $true
    }

    $out2 = Invoke-AppsAdb @("shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", $Package)
    if ($out2 -match 'priority=') {
        $lines = $out2 -split "`r?`n"
        if ($lines.Count -ge 2) {
            $activity = $lines[1].Trim()
            if ($activity) {
                $out3 = Invoke-AppsAdb @("shell", "am", "start", "-n", $activity)
                if ($out3 -match 'Starting' -or $out3 -notmatch 'Error') {
                    Write-Log -Message "OK: $Package запущен через am start" -Level "Success"
                    return $true
                }
            }
        }
    }

    $out4 = Invoke-AppsAdb @("shell", "am", "start", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", "-p", $Package)
    if ($out4 -match 'Starting' -or $out4 -notmatch 'Error') {
        Write-Log -Message "OK: $Package запущен через am start -a MAIN" -Level "Success"
        return $true
    }

    Write-Log -Message "Не удалось запустить: $Package — $out4" -Level "Error"
    return $false
}

# ============================================================================
#  ХЕЛПЕР: КОПИРОВАНИЕ В БУФЕР ОБМЕНА С УВЕДОМЛЕНИЕМ
# ============================================================================
function Copy-ToClipboard {
    param(
        [string]$Text,
        [string]$Label = "Команда"
    )
    try {
        [System.Windows.Clipboard]::SetText($Text)
        Write-Log -Message "$Label скопирована в буфер обмена: $Text" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка копирования: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ДИАЛОГ: КАК ВКЛЮЧИТЬ НОВЫЙ ЛАУНЧЕР
#  Кастомное WPF-окно с командами ADB и кнопками копирования.
# ============================================================================
function Show-LauncherHelpDialog {
    param(
        [string]$Package,
        [string]$BlockingLauncher
    )

    # Команды для копирования
    $cmdDisable  = "adb shell pm disable-user --user 0 $BlockingLauncher"
    $cmdEnable   = "adb shell pm enable $BlockingLauncher"
    $cmdOpenA11y = "adb shell am start -a android.settings.ACCESSIBILITY_SETTINGS"

    # --- Окно ---
    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Как включить новый лаунчер — инструкция"
    $dialog.Width = 780
    $dialog.Height = 680
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

    # ===== Заголовок =====
    $headerPanel = New-Object System.Windows.Controls.StackPanel
    $headerPanel.Margin = "0,0,0,15"

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "Как включить новый лаунчер"
    $title.FontSize = 20
    $title.FontWeight = "Bold"
    $title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $headerPanel.Children.Add($title) | Out-Null

    $subtitle = New-Object System.Windows.Controls.TextBlock
    $subtitle.Text = "Команда set-home-activity выполнена, но Google TV пока не переключил лаунчер. Выберите способ ниже."
    $subtitle.FontSize = 12
    $subtitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $subtitle.TextWrapping = "Wrap"
    $subtitle.Margin = "0,6,0,0"
    $headerPanel.Children.Add($subtitle) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($headerPanel, 0)
    $grid.Children.Add($headerPanel) | Out-Null

    # ===== Скролл с содержимым =====
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $content = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $content

    # ---------- СПОСОБ 1 ----------
    $card1 = New-Object System.Windows.Controls.Border
    $card1.Background = "#1F3A1F"
    $card1.BorderBrush = "#3A5A3A"
    $card1.BorderThickness = "1"
    $card1.CornerRadius = "8"
    $card1.Padding = "14"
    $card1.Margin = "0,0,0,12"

    $stack1 = New-Object System.Windows.Controls.StackPanel

    $h1 = New-Object System.Windows.Controls.TextBlock
    $h1.Text = "СПОСОБ 1 — РЕКОМЕНДУЕМЫЙ (безопасный)"
    $h1.FontSize = 14
    $h1.FontWeight = "Bold"
    $h1.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    $stack1.Children.Add($h1) | Out-Null

    $h1b = New-Object System.Windows.Controls.TextBlock
    $h1b.Text = "Переназначение Home через Accessibility Service"
    $h1b.FontSize = 12
    $h1b.FontWeight = "SemiBold"
    $h1b.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $h1b.Margin = "0,2,0,10"
    $stack1.Children.Add($h1b) | Out-Null

    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = "Многие сторонние лаунчеры (ATV Launcher Pro, Projectivy и некоторые другие) поддерживают встроенный режим Accessibility Service. Он перехватывает кнопку Home, не требуя отключения штатного лаунчера."
    $t1.FontSize = 12
    $t1.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $t1.TextWrapping = "Wrap"
    $t1.Margin = "0,0,0,10"
    $stack1.Children.Add($t1) | Out-Null

    $steps1 = @(
        "1. Откройте установленный лаунчер на телевизоре",
        "2. В его настройках найдите: Accessibility Service / Home Button Redirect / Перенаправление Home",
        "3. Включите и подтвердите разрешение в системном диалоге",
        "4. Готово — Home будет открывать выбранный лаунчер"
    )
    foreach ($s in $steps1) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $s
        $tb.FontSize = 11
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $tb.TextWrapping = "Wrap"
        $tb.Margin = "0,2,0,2"
        $stack1.Children.Add($tb) | Out-Null
    }

    $t1b = New-Object System.Windows.Controls.TextBlock
    $t1b.Text = "Если у вашего лаунчера такой функции нет — используйте приложение Button Mapper (Google Play) для переназначения Home."
    $t1b.FontSize = 11
    $t1b.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $t1b.TextWrapping = "Wrap"
    $t1b.Margin = "0,8,0,10"
    $stack1.Children.Add($t1b) | Out-Null

    # Кнопка "Открыть Accessibility на ТВ"
    $btnA11y = New-Object System.Windows.Controls.Button
    $btnA11y.Content = "Открыть Accessibility на ТВ"
    $btnA11y.Style = $window.Resources["RoundedButton"]
    $btnA11y.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnA11y.Padding = "12,6"
    $btnA11y.FontSize = 11
    $btnA11y.HorizontalAlignment = "Left"
    $btnA11y.Margin = "0,0,0,8"
    $btnA11y.Add_Click({
        Write-Log -Message "Открываю настройки Accessibility на ТВ..." -Level "Info"
        try {
            & $script:adbPath shell am start -a android.settings.ACCESSIBILITY_SETTINGS 2>&1 | Out-Null
            Write-Log -Message "OK" -Level "Success"
        } catch {
            Write-Log -Message "Ошибка: $_" -Level "Error"
        }
    })
    $stack1.Children.Add($btnA11y) | Out-Null

    # Команда для копирования (на случай ручного запуска)
    $a11yCmdPanel = New-Object System.Windows.Controls.Grid
    $a11yCmdPanel.Margin = "0,4,0,0"

    $ac1 = New-Object System.Windows.Controls.ColumnDefinition; $ac1.Width = "*"
    $ac2 = New-Object System.Windows.Controls.ColumnDefinition; $ac2.Width = "Auto"
    $a11yCmdPanel.ColumnDefinitions.Add($ac1)
    $a11yCmdPanel.ColumnDefinitions.Add($ac2)

    $a11yCmdBox = New-Object System.Windows.Controls.TextBox
    $a11yCmdBox.Text = $cmdOpenA11y
    $a11yCmdBox.FontFamily = "Consolas"
    $a11yCmdBox.FontSize = 11
    $a11yCmdBox.IsReadOnly = $true
    $a11yCmdBox.Background = "#181818"
    $a11yCmdBox.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $a11yCmdBox.BorderBrush = "#3A3A3A"
    $a11yCmdBox.Padding = "6,4"
    [System.Windows.Controls.Grid]::SetColumn($a11yCmdBox, 0)
    $a11yCmdPanel.Children.Add($a11yCmdBox) | Out-Null

    $btnCopyA11y = New-Object System.Windows.Controls.Button
    $btnCopyA11y.Content = "Копировать"
    $btnCopyA11y.Style = $window.Resources["RoundedButton"]
    $btnCopyA11y.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnCopyA11y.Padding = "10,4"
    $btnCopyA11y.FontSize = 11
    $btnCopyA11y.Margin = "6,0,0,0"
    $btnCopyA11y.Tag = $cmdOpenA11y
    $btnCopyA11y.Add_Click({
        param($sender, $e)
        Copy-ToClipboard -Text $sender.Tag -Label "Команда Accessibility" | Out-Null
    })
    [System.Windows.Controls.Grid]::SetColumn($btnCopyA11y, 1)
    $a11yCmdPanel.Children.Add($btnCopyA11y) | Out-Null

    $stack1.Children.Add($a11yCmdPanel) | Out-Null

    $card1.Child = $stack1
    $content.Children.Add($card1) | Out-Null

    # ---------- СПОСОБ 2 ----------
    $card2 = New-Object System.Windows.Controls.Border
    $card2.Background = "#3D3520"
    $card2.BorderBrush = "#5A4A2A"
    $card2.BorderThickness = "1"
    $card2.CornerRadius = "8"
    $card2.Padding = "14"
    $card2.Margin = "0,0,0,12"

    $stack2 = New-Object System.Windows.Controls.StackPanel

    $h2 = New-Object System.Windows.Controls.TextBlock
    $h2.Text = "СПОСОБ 2 — ТРЕБУЕТ ОСТОРОЖНОСТИ"
    $h2.FontSize = 14
    $h2.FontWeight = "Bold"
    $h2.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $stack2.Children.Add($h2) | Out-Null

    $h2b = New-Object System.Windows.Controls.TextBlock
    $h2b.Text = "Отключение штатного лаунчера через ADB"
    $h2b.FontSize = 12
    $h2b.FontWeight = "SemiBold"
    $h2b.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $h2b.Margin = "0,2,0,10"
    $stack2.Children.Add($h2b) | Out-Null

    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = "Этот способ надёжно переключает Home на новый лаунчер, но при неудаче можно потерять часть настроек ТВ (в т.ч. Wi-Fi)."
    $t2.FontSize = 12
    $t2.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $t2.TextWrapping = "Wrap"
    $t2.Margin = "0,0,0,10"
    $stack2.Children.Add($t2) | Out-Null

    # --- Команда 1: отключить ---
    $lblCmd1 = New-Object System.Windows.Controls.TextBlock
    $lblCmd1.Text = "Шаг 1. Отключить ТОЛЬКО штатный launcher:"
    $lblCmd1.FontSize = 12
    $lblCmd1.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $lblCmd1.Margin = "0,0,0,4"
    $stack2.Children.Add($lblCmd1) | Out-Null

    $cmd1Panel = New-Object System.Windows.Controls.Grid
    $c1a = New-Object System.Windows.Controls.ColumnDefinition; $c1a.Width = "*"
    $c1b = New-Object System.Windows.Controls.ColumnDefinition; $c1b.Width = "Auto"
    $cmd1Panel.ColumnDefinitions.Add($c1a)
    $cmd1Panel.ColumnDefinitions.Add($c1b)

    $cmd1Box = New-Object System.Windows.Controls.TextBox
    $cmd1Box.Text = $cmdDisable
    $cmd1Box.FontFamily = "Consolas"
    $cmd1Box.FontSize = 11
    $cmd1Box.IsReadOnly = $true
    $cmd1Box.Background = "#181818"
    $cmd1Box.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $cmd1Box.BorderBrush = "#3A3A3A"
    $cmd1Box.Padding = "6,4"
    [System.Windows.Controls.Grid]::SetColumn($cmd1Box, 0)
    $cmd1Panel.Children.Add($cmd1Box) | Out-Null

    $btnCopy1 = New-Object System.Windows.Controls.Button
    $btnCopy1.Content = "Копировать"
    $btnCopy1.Style = $window.Resources["RoundedButton"]
    $btnCopy1.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnCopy1.Padding = "10,4"
    $btnCopy1.FontSize = 11
    $btnCopy1.Margin = "6,0,0,0"
    $btnCopy1.Tag = $cmdDisable
    $btnCopy1.Add_Click({
        param($sender, $e)
        Copy-ToClipboard -Text $sender.Tag -Label "Команда отключения" | Out-Null
    })
    [System.Windows.Controls.Grid]::SetColumn($btnCopy1, 1)
    $cmd1Panel.Children.Add($btnCopy1) | Out-Null

    $stack2.Children.Add($cmd1Panel) | Out-Null

    $t2b = New-Object System.Windows.Controls.TextBlock
    $t2b.Text = "Шаг 2. Сразу нажать Home на пульте ТВ."
    $t2b.FontSize = 12
    $t2b.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $t2b.Margin = "0,10,0,4"
    $stack2.Children.Add($t2b) | Out-Null

    # --- Команда 2: вернуть ---
    $lblCmd2 = New-Object System.Windows.Controls.TextBlock
    $lblCmd2.Text = "Шаг 3. Если через 30 секунд экран чёрный — СРАЗУ вернуть:"
    $lblCmd2.FontSize = 12
    $lblCmd2.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $lblCmd2.Margin = "0,0,0,4"
    $stack2.Children.Add($lblCmd2) | Out-Null

    $cmd2Panel = New-Object System.Windows.Controls.Grid
    $c2a = New-Object System.Windows.Controls.ColumnDefinition; $c2a.Width = "*"
    $c2b = New-Object System.Windows.Controls.ColumnDefinition; $c2b.Width = "Auto"
    $cmd2Panel.ColumnDefinitions.Add($c2a)
    $cmd2Panel.ColumnDefinitions.Add($c2b)

    $cmd2Box = New-Object System.Windows.Controls.TextBox
    $cmd2Box.Text = $cmdEnable
    $cmd2Box.FontFamily = "Consolas"
    $cmd2Box.FontSize = 11
    $cmd2Box.IsReadOnly = $true
    $cmd2Box.Background = "#181818"
    $cmd2Box.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    $cmd2Box.BorderBrush = "#3A3A3A"
    $cmd2Box.Padding = "6,4"
    [System.Windows.Controls.Grid]::SetColumn($cmd2Box, 0)
    $cmd2Panel.Children.Add($cmd2Box) | Out-Null

    $btnCopy2 = New-Object System.Windows.Controls.Button
    $btnCopy2.Content = "Копировать"
    $btnCopy2.Style = $window.Resources["RoundedButton"]
    $btnCopy2.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnCopy2.Padding = "10,4"
    $btnCopy2.FontSize = 11
    $btnCopy2.Margin = "6,0,0,0"
    $btnCopy2.Tag = $cmdEnable
    $btnCopy2.Add_Click({
        param($sender, $e)
        Copy-ToClipboard -Text $sender.Tag -Label "Команда восстановления" | Out-Null
    })
    [System.Windows.Controls.Grid]::SetColumn($btnCopy2, 1)
    $cmd2Panel.Children.Add($btnCopy2) | Out-Null

    $stack2.Children.Add($cmd2Panel) | Out-Null

    # --- Предупреждения ---
    $warnHeader = New-Object System.Windows.Controls.TextBlock
    $warnHeader.Text = "ВАЖНО:"
    $warnHeader.FontSize = 12
    $warnHeader.FontWeight = "Bold"
    $warnHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $warnHeader.Margin = "0,12,0,4"
    $stack2.Children.Add($warnHeader) | Out-Null

    $warns = @(
        "• НЕ отключайте одновременно com.google.android.tungsten.setupwraith — его отключение может привести к сбросу настроек (в т.ч. Wi-Fi).",
        "• Отключайте по одному шагу, с паузами.",
        "• Держите под рукой телефон/ПК, чтобы при необходимости вернуть launcher через ADB или сбросить ТВ кнопкой на корпусе."
    )
    foreach ($w in $warns) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $w
        $tb.FontSize = 11
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
        $tb.TextWrapping = "Wrap"
        $tb.Margin = "0,2,0,2"
        $stack2.Children.Add($tb) | Out-Null
    }

    $card2.Child = $stack2
    $content.Children.Add($card2) | Out-Null

    # ---------- Кнопка "Скопировать всё" ----------
    $allText = @"
=== СПОСОБ 1: Accessibility Service ===
$cmdOpenA11y

=== СПОСОБ 2: отключение штатного launcher ===
Шаг 1. Отключить штатный launcher:
$cmdDisable

Шаг 2. Сразу нажать Home на пульте ТВ.

Шаг 3. Если через 30 секунд экран чёрный — СРАЗУ вернуть:
$cmdEnable

ВАЖНО: НЕ отключайте com.google.android.tungsten.setupwraith.
"@

    $btnCopyAll = New-Object System.Windows.Controls.Button
    $btnCopyAll.Content = "Скопировать всю инструкцию"
    $btnCopyAll.Style = $window.Resources["RoundedButton"]
    $btnCopyAll.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnCopyAll.Padding = "12,6"
    $btnCopyAll.FontSize = 11
    $btnCopyAll.HorizontalAlignment = "Left"
    $btnCopyAll.Margin = "0,0,0,12"
    $btnCopyAll.Tag = $allText
    $btnCopyAll.Add_Click({
        param($sender, $e)
        Copy-ToClipboard -Text $sender.Tag -Label "Вся инструкция" | Out-Null
    })
    $content.Children.Add($btnCopyAll) | Out-Null

    # ---------- Нижняя панель кнопок ----------
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    $btnPanel.Margin = "0,15,0,0"
    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    # --- Кнопка "Выполнить Способ 2 автоматически" ---
    $btnAutoDisable = New-Object System.Windows.Controls.Button
    $btnAutoDisable.Content = "Отключить штатный launcher сейчас"
    $btnAutoDisable.Style = $window.Resources["RoundedButton"]
    $btnAutoDisable.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
    )
    $btnAutoDisable.Padding = "12,6"
    $btnAutoDisable.FontSize = 11
    $btnAutoDisable.Margin = "0,0,8,0"

    $btnAutoDisable.Tag = [PSCustomObject]@{
        Blocking   = $BlockingLauncher
        NewPackage = $Package
        Dialog     = $dialog
    }

    $btnAutoDisable.Add_Click({
        param($sender, $e)

        $data      = $sender.Tag
        $blocking  = $data.Blocking
        $newPkg    = $data.NewPackage
        $dlg       = $data.Dialog

        Write-Log -Message "=== Автоматическое отключение штатного launcher ===" -Level "Warning"

        $conf = [System.Windows.MessageBox]::Show(
            "Отключить штатный launcher ($blocking)?`n`nСРАЗУ после этого нажмите Home на пульте ТВ.`n`nЕсли через 30 секунд экран чёрный — верните его через «Откат изменений» или командой:`n  adb shell pm enable $blocking",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)

        if ($conf -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-Log -Message "Отменено пользователем" -Level "Info"
            return
        }

        $disOut = Invoke-AppsAdb @("shell", "pm", "disable-user", "--user", "0", $blocking)
        Write-Log -Message "Ответ: '$disOut'" -Level "Info"

        Save-Change -Type "package_disabled" `
                    -Target $blocking `
                    -RestoreCommand "adb shell pm enable $blocking"
        Save-AllChanges

        $dlg.Close()

        [System.Windows.MessageBox]::Show(
            "Штатный launcher отключён.`n`nСЕЙЧАС нажмите Home на пульте ТВ.`n`nЕсли через 30 секунд экран чёрный — верните:`n  adb shell pm enable $blocking",
            "Нажмите Home на пульте",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information) | Out-Null
    })
    $btnPanel.Children.Add($btnAutoDisable) | Out-Null

    # --- Кнопка "Закрыть" ---
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnClose.Padding = "15,6"
    $btnClose.FontSize = 11
    $btnClose.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

# ============================================================================
#  СМЕНА ЛАУНЧЕРА — БЕЗОПАСНАЯ ВЕРСИЯ
# ============================================================================
function Set-DefaultLauncher {
    param([string]$Activity, [string]$Package = "")

    Write-Log -Message "=== Set-DefaultLauncher (безопасный режим) ===" -Level "Info"
    Write-Log -Message "  Activity: $Activity" -Level "Info"
    Write-Log -Message "  Package:  $Package" -Level "Info"

    if ([string]::IsNullOrWhiteSpace($Activity)) {
        Write-Log -Message "Activity не указан — отмена" -Level "Error"
        return $false
    }

    $pkgFromActivity = $Activity.Split('/')[0]
    if ([string]::IsNullOrWhiteSpace($Package)) {
        $Package = $pkgFromActivity
    }

    # ===== Шаг 1: set-home-activity =====
    Write-Log -Message "  [1] cmd package set-home-activity $Activity" -Level "Info"
    $out1 = Invoke-AppsAdb @("shell", "cmd", "package", "set-home-activity", $Activity)
    Write-Log -Message "      Ответ: '$out1'" -Level "Info"

    $success = ([string]::IsNullOrWhiteSpace($out1) -or $out1 -match 'Success|success')

    if (-not $success) {
        Write-Log -Message "  [2] pm set-home-activity $Activity" -Level "Info"
        $out2 = Invoke-AppsAdb @("shell", "pm", "set-home-activity", $Activity)
        Write-Log -Message "      Ответ: '$out2'" -Level "Info"
        $success = ([string]::IsNullOrWhiteSpace($out2) -or $out2 -notmatch 'Error|Unknown|Exception|not found')
    }

    if (-not $success) {
        Write-Log -Message "Не удалось выполнить set-home-activity" -Level "Error"
        [System.Windows.MessageBox]::Show(
            "Не удалось выполнить команду назначения лаунчера.`n`nПодробности в логе.",
            "Ошибка",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error) | Out-Null
        return $false
    }

    Write-Log -Message "  set-home-activity выполнен" -Level "Success"

    # ===== Шаг 2: проверка =====
    Start-Sleep -Milliseconds 1200
    $verify = Invoke-AppsAdb @("shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.HOME")
    Write-Log -Message "  Текущий лаунчер (resolve): $verify" -Level "Info"

    $isNowOurLauncher = ($verify -match [regex]::Escape($Package))

    if ($isNowOurLauncher) {
        Write-Log -Message "OK: лаунчер назначен и подтверждён" -Level "Success"

        Save-Change -Type "launcher_changed" `
                    -Target $Activity `
                    -RestoreCommand "adb shell cmd package set-home-activity com.google.android.apps.tv.launcherx/com.google.android.apps.tv.launcherx.home.HomeActivity"
        Save-AllChanges

        [System.Windows.MessageBox]::Show(
            "Готово! Лаунчер назначен:`n`n$Activity`n`nНажмите кнопку Home на пульте ТВ — откроется новый лаунчер.",
            "Лаунчер назначен",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information) | Out-Null

        return $true
    }

    # ===== Шаг 3: не переключилось =====
    Write-Log -Message "  Система не переключила лаунчер сразу." -Level "Warning"
    Write-Log -Message "  НИЧЕГО не отключаем автоматически — показываем диалог." -Level "Info"

    $blockingLauncher = ""
    if ($verify -match '([a-z][a-z0-9_\.]+)/[A-Za-z0-9_\.]+') {
        $blockingLauncher = $matches[1]
    }
    if (-not $blockingLauncher) {
        $blockingLauncher = "com.google.android.apps.tv.launcherx"
    }

    # Показываем кастомный диалог с копируемыми командами
    Show-LauncherHelpDialog -Package $Package -BlockingLauncher $blockingLauncher

    Save-Change -Type "launcher_changed" `
                -Target $Activity `
                -RestoreCommand "adb shell cmd package set-home-activity com.google.android.apps.tv.launcherx/com.google.android.apps.tv.launcherx.home.HomeActivity"
    Save-AllChanges

    return $true
}