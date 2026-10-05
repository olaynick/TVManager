# ============================================================================
#  ScrcpyHelper — интеграция со scrcpy для трансляции экрана ТВ
#
#  Scrcpy — open-source утилита для трансляции экрана Android на ПК.
#  Использует ADB (уже подключённый), дополнительная настройка не нужна.
#
#  Установка:
#    1. Пользователь скачивает архив с GitHub
#    2. Распаковывает в удобную папку
#    3. Указывает папку в диалоге — программа сама добавляет в PATH
# ============================================================================

$script:ScrcpyExe = $null
$script:ScrcpyProcess = $null

# ============================================================================
#  ПОИСК SCRCPY В PATH
# ============================================================================
function Find-ScrcpyExecutable {
    try {
        $cmd = Get-Command "scrcpy" -CommandType Application -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    } catch { }

    return $null
}

function Test-ScrcpyAvailable {
    param([switch]$Force)

    if ($script:ScrcpyExe -and -not $Force) {
        return $true
    }

    $exe = Find-ScrcpyExecutable
    if ($exe) {
        $script:ScrcpyExe = $exe
        return $true
    }

    $script:ScrcpyExe = $null
    return $false
}

function Get-ScrcpyPath {
    if (Test-ScrcpyAvailable) {
        return $script:ScrcpyExe
    }
    return $null
}

# ============================================================================
#  УСТАНОВКА: ДОБАВЛЕНИЕ ПАПКИ В PATH
# ============================================================================
function Install-ScrcpyFromFolder {
    param([string]$Folder)

    if (-not $Folder -or -not (Test-Path $Folder)) {
        Write-Log -Message "Папка не указана или не существует" -Level "Error"
        return $false
    }

    $exePath = Join-Path $Folder "scrcpy.exe"
    if (-not (Test-Path $exePath)) {
        Write-Log -Message "В папке нет scrcpy.exe: $Folder" -Level "Error"
        [System.Windows.MessageBox]::Show(
            "В выбранной папке нет scrcpy.exe.`n`nУбедитесь, что вы распаковали архив scrcpy в эту папку.`nВнутри должны быть: scrcpy.exe, adb.exe, scrcpy-server и другие файлы.",
            "scrcpy.exe не найден",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return $false
    }

    Write-Log -Message "=== Добавление scrcpy в PATH ===" -Level "Info"

    # Переиспользуем универсальную функцию из AdbHelper
    $ok = Add-FolderToUserPath -Folder $Folder -RequireFile "scrcpy.exe"

    if ($ok) {
        # Обновляем кеш
        $script:ScrcpyExe = $exePath
        Write-Log -Message "scrcpy доступен: $exePath" -Level "Success"
        return $true
    }

    return $false
}

# ============================================================================
#  ЗАПУСК SCRCPY
# ============================================================================
function Start-Scrcpy {
    param(
        [string]$DeviceIp,
        [int]$MaxSize = 0,
        [int]$BitRateMbps = 8,
        [int]$MaxFps = 0,
        [switch]$TurnScreenOff,
        [switch]$StayAwake,
        [switch]$Fullscreen,
        [switch]$NoAudio,
        [switch]$NoControl
    )

    if (-not $DeviceIp) {
        Write-Log -Message "IP устройства не указан" -Level "Error"
        return $false
    }

    if (-not (Test-ScrcpyAvailable)) {
        Write-Log -Message "scrcpy не найден в PATH" -Level "Error"
        return $false
    }

    if ($script:ScrcpyProcess -and -not $script:ScrcpyProcess.HasExited) {
        Write-Log -Message "scrcpy уже запущен (PID $($script:ScrcpyProcess.Id)). Закройте старое окно." -Level "Warning"
        return $false
    }

    $args = @()
    $args += "--serial=$DeviceIp`:5555"
    $args += "--window-title=TV: $DeviceIp"

    if ($MaxSize -gt 0)       { $args += "--max-size=$MaxSize" }
    if ($BitRateMbps -gt 0)   { $args += "--video-bit-rate=$($BitRateMbps * 1000000)" }
    if ($MaxFps -gt 0)        { $args += "--max-fps=$MaxFps" }
    if ($TurnScreenOff)       { $args += "--turn-screen-off" }
    if ($StayAwake)           { $args += "--stay-awake" }
    if ($Fullscreen)          { $args += "--fullscreen" }
    if ($NoAudio)             { $args += "--no-audio" }
    if ($NoControl)           { $args += "--no-control" }

    $exePath = $script:ScrcpyExe
    Write-Log -Message "=== Запуск scrcpy ===" -Level "Info"
    Write-Log -Message "  EXE: $exePath" -Level "Info"
    Write-Log -Message "  Аргументы: $($args -join ' ')" -Level "Info"

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName        = $exePath
        $psi.Arguments       = ($args | ForEach-Object { '"' + ($_ -replace '"','\"') + '"' }) -join ' '
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow  = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $script:ScrcpyProcess = $proc

        Write-Log -Message "scrcpy запущен (PID $($proc.Id))" -Level "Success"
        Write-Log -Message "Окно scrcpy откроется отдельно. Закройте его для остановки трансляции." -Level "Info"

        return $true
    } catch {
        Write-Log -Message "Не удалось запустить scrcpy: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ОСТАНОВКА SCRCPY
# ============================================================================
function Stop-Scrcpy {
    if (-not $script:ScrcpyProcess) {
        Write-Log -Message "scrcpy не запущен" -Level "Warning"
        return $false
    }

    try {
        if (-not $script:ScrcpyProcess.HasExited) {
            $script:ScrcpyProcess.Kill()
            Write-Log -Message "scrcpy остановлен" -Level "Success"
        }
        $script:ScrcpyProcess.Dispose()
        $script:ScrcpyProcess = $null
        return $true
    } catch {
        Write-Log -Message "Ошибка остановки scrcpy: $_" -Level "Error"
        return $false
    }
}

function Test-ScrcpyRunning {
    if (-not $script:ScrcpyProcess) { return $false }
    try {
        return (-not $script:ScrcpyProcess.HasExited)
    } catch {
        return $false
    }
}

# ============================================================================
#  ССЫЛКИ НА СКАЧИВАНИЕ
# ============================================================================
function Open-ScrcpyDownloadWin64 {
    Start-Process "https://github.com/Genymobile/scrcpy/releases/download/v5.0/scrcpy-win64-v5.0.zip"
}

function Open-ScrcpyDownloadWin32 {
    Start-Process "https://github.com/Genymobile/scrcpy/releases/download/v5.0/scrcpy-win32-v5.0.zip"
}

function Open-ScrcpyReleasesPage {
    Start-Process "https://github.com/Genymobile/scrcpy/releases"
}

# ============================================================================
#  ДИАЛОГ УСТАНОВКИ (когда scrcpy не найден)
# ============================================================================
function Show-ScrcpyInstallDialog {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Установка scrcpy"
    $dialog.Width = 640
    $dialog.Height = 560
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#202020")
    )

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

    # --- Заголовок ---
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "Установка scrcpy"
    $title.FontSize = 20
    $title.FontWeight = "Bold"
    $title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $title.Margin = "0,0,0,12"
    [System.Windows.Controls.Grid]::SetRow($title, 0)
    $grid.Children.Add($title) | Out-Null

    # --- Контент ---
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $content = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $content

    # Интро
    $intro = New-Object System.Windows.Controls.TextBlock
    $intro.Text = "scrcpy — бесплатная утилита для трансляции экрана Android-устройства на ПК. Работает через уже подключённый ADB — на ТВ ничего настраивать не нужно."
    $intro.FontSize = 12
    $intro.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $intro.TextWrapping = "Wrap"
    $intro.Margin = "0,0,0,18"
    $content.Children.Add($intro) | Out-Null

    # ---- ШАГ 1: Скачать ----
    $step1Title = New-Object System.Windows.Controls.TextBlock
    $step1Title.Text = "Шаг 1. Скачайте архив"
    $step1Title.FontSize = 14
    $step1Title.FontWeight = "Bold"
    $step1Title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $step1Title.Margin = "0,0,0,8"
    $content.Children.Add($step1Title) | Out-Null

    $step1Text = New-Object System.Windows.Controls.TextBlock
    $step1Text.Text = "Выберите версию под вашу Windows (64-бит — почти всегда):"
    $step1Text.FontSize = 12
    $step1Text.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $step1Text.TextWrapping = "Wrap"
    $step1Text.Margin = "0,0,0,10"
    $content.Children.Add($step1Text) | Out-Null

    $dlPanel = New-Object System.Windows.Controls.StackPanel
    $dlPanel.Orientation = "Horizontal"
    $dlPanel.Margin = "0,0,0,18"

    $btnWin64 = New-Object System.Windows.Controls.Button
    $btnWin64.Content = "Скачать Windows 64-bit"
    $btnWin64.Style = $window.Resources["RoundedButton"]
    $btnWin64.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnWin64.Padding = "14,8"
    $btnWin64.FontSize = 12
    $btnWin64.Margin = "0,0,8,0"
    $btnWin64.Add_Click({ Open-ScrcpyDownloadWin64 })
    $dlPanel.Children.Add($btnWin64) | Out-Null

    $btnWin32 = New-Object System.Windows.Controls.Button
    $btnWin32.Content = "Скачать Windows 32-bit"
    $btnWin32.Style = $window.Resources["RoundedButton"]
    $btnWin32.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnWin32.Padding = "14,8"
    $btnWin32.FontSize = 12
    $btnWin32.Add_Click({ Open-ScrcpyDownloadWin32 })
    $dlPanel.Children.Add($btnWin32) | Out-Null

    $content.Children.Add($dlPanel) | Out-Null

    # ---- ШАГ 2: Распаковать ----
    $step2Title = New-Object System.Windows.Controls.TextBlock
    $step2Title.Text = "Шаг 2. Распакуйте архив"
    $step2Title.FontSize = 14
    $step2Title.FontWeight = "Bold"
    $step2Title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $step2Title.Margin = "0,0,0,8"
    $content.Children.Add($step2Title) | Out-Null

    $step2Text = New-Object System.Windows.Controls.TextBlock
    $step2Text.Text = "Распакуйте содержимое архива в удобную папку, например:`n    C:\Tools\scrcpy\`n`nВнутри должны быть файлы: scrcpy.exe, adb.exe, scrcpy-server и другие."
    $step2Text.FontSize = 12
    $step2Text.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $step2Text.TextWrapping = "Wrap"
    $step2Text.Margin = "0,0,0,18"
    $content.Children.Add($step2Text) | Out-Null

    # ---- ШАГ 3: Указать папку ----
    $step3Title = New-Object System.Windows.Controls.TextBlock
    $step3Title.Text = "Шаг 3. Укажите папку в программе"
    $step3Title.FontSize = 14
    $step3Title.FontWeight = "Bold"
    $step3Title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $step3Title.Margin = "0,0,0,8"
    $content.Children.Add($step3Title) | Out-Null

    $step3Text = New-Object System.Windows.Controls.TextBlock
    $step3Text.Text = "Нажмите кнопку «Указать папку со scrcpy» внизу. Программа сама добавит эту папку в PATH — вручную ничего прописывать не нужно.`n`nПосле этого scrcpy будет доступен для запуска."
    $step3Text.FontSize = 12
    $step3Text.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $step3Text.TextWrapping = "Wrap"
    $step3Text.Margin = "0,0,0,18"
    $content.Children.Add($step3Text) | Out-Null

    # Ссылка на все релизы
    $btnReleases = New-Object System.Windows.Controls.Button
    $btnReleases.Content = "Открыть страницу всех релизов scrcpy"
    $btnReleases.Style = $window.Resources["RoundedButton"]
    $btnReleases.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnReleases.Padding = "14,8"
    $btnReleases.FontSize = 12
    $btnReleases.HorizontalAlignment = "Left"
    $btnReleases.Add_Click({ Open-ScrcpyReleasesPage })
    $content.Children.Add($btnReleases) | Out-Null

    # --- Нижняя панель кнопок ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    $btnPanel.Margin = "0,15,0,0"
    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    # Указать папку
    $btnBrowse = New-Object System.Windows.Controls.Button
    $btnBrowse.Content = "Указать папку со scrcpy"
    $btnBrowse.Style = $window.Resources["RoundedButton"]
    $btnBrowse.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnBrowse.Padding = "15,8"
    $btnBrowse.Margin = "0,0,8,0"
    $btnBrowse.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Выберите папку, где находится scrcpy.exe"
        $dlg.ShowNewFolderButton = $false

        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $folder = $dlg.SelectedPath
            $ok = Install-ScrcpyFromFolder -Folder $folder

            if ($ok) {
                [System.Windows.MessageBox]::Show(
                    "scrcpy добавлен в PATH!`n`nПапка: $folder`n`nТеперь можно открыть диалог запуска.",
                    "Готово",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information) | Out-Null
                $dialog.Close()
                Show-ScrcpyDialog
            }
        }
    })
    $btnPanel.Children.Add($btnBrowse) | Out-Null

    # Проверить снова
    $btnCheck = New-Object System.Windows.Controls.Button
    $btnCheck.Content = "Проверить снова"
    $btnCheck.Style = $window.Resources["RoundedButton"]
    $btnCheck.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnCheck.Padding = "15,8"
    $btnCheck.Margin = "0,0,8,0"
    $btnCheck.Add_Click({
        if (Test-ScrcpyAvailable -Force) {
            [System.Windows.MessageBox]::Show(
                "scrcpy найден!`n`nПуть: $($script:ScrcpyExe)",
                "Готово",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
            $dialog.Close()
            Show-ScrcpyDialog
        } else {
            [System.Windows.MessageBox]::Show(
                "scrcpy не найден в PATH.`n`nЕсли вы уже добавляли папку — перезапустите TVManager, чтобы PATH обновился.",
                "Не найден",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }
    })
    $btnPanel.Children.Add($btnCheck) | Out-Null

    # Закрыть
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnClose.Padding = "15,8"
    $btnClose.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

# ============================================================================
#  ДИАЛОГ ЗАПУСКА (компактная версия)
# ============================================================================
function Show-ScrcpyDialog {
    if (-not $script:connected -or -not $script:deviceIp) {
        [System.Windows.MessageBox]::Show(
            "Сначала подключитесь к телевизору.",
            "Нет подключения",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    if (-not (Test-ScrcpyAvailable)) {
        Show-ScrcpyInstallDialog
        return
    }

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Трансляция экрана (scrcpy)"
    $dialog.Width = 520
    $dialog.Height = 480
    $dialog.MinWidth = 480
    $dialog.MinHeight = 440
    $dialog.SizeToContent = "Height"
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#202020")
    )

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "15"

    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = "Auto"
    $grid.RowDefinitions.Add($row1)

    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = "Auto"
    $grid.RowDefinitions.Add($row2)

    $row3 = New-Object System.Windows.Controls.RowDefinition
    $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row3)

    # ===== ЗАГОЛОВОК =====
    $headerStack = New-Object System.Windows.Controls.StackPanel
    $headerStack.Margin = "0,0,0,12"

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "Трансляция экрана ТВ"
    $title.FontSize = 16
    $title.FontWeight = "Bold"
    $title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $title.Margin = "0,0,0,4"
    $headerStack.Children.Add($title) | Out-Null

    $subtitle = New-Object System.Windows.Controls.TextBlock
    $subtitle.Text = "✓ scrcpy: $($script:ScrcpyExe)"
    $subtitle.FontSize = 10
    $subtitle.TextTrimming = "CharacterEllipsis"
    $subtitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
    )
    $headerStack.Children.Add($subtitle) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($headerStack, 0)
    $grid.Children.Add($headerStack) | Out-Null

    # ===== КОНТЕНТ =====
    $content = New-Object System.Windows.Controls.StackPanel

    # --- Разрешение ---
    $lblSize = New-Object System.Windows.Controls.TextBlock
    $lblSize.Text = "Разрешение:"
    $lblSize.FontSize = 11
    $lblSize.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblSize.Margin = "0,0,0,3"
    $content.Children.Add($lblSize) | Out-Null

    $comboSize = New-Object System.Windows.Controls.ComboBox
    $comboSize.FontSize = 11
    $comboSize.Height = 26
    $comboSize.Margin = "0,0,0,10"
    [void]$comboSize.Items.Add("Без ограничения (родное)")
    [void]$comboSize.Items.Add("1920 (Full HD)")
    [void]$comboSize.Items.Add("1280 (HD)")
    [void]$comboSize.Items.Add("1024 (эконом)")
    $comboSize.SelectedIndex = 1
    $content.Children.Add($comboSize) | Out-Null

    # --- Битрейт + FPS в одной строке ---
    $rowGrid = New-Object System.Windows.Controls.Grid
    $rowGrid.Margin = "0,0,0,10"

    $rc1 = New-Object System.Windows.Controls.ColumnDefinition; $rc1.Width = "*"
    $rc2 = New-Object System.Windows.Controls.ColumnDefinition; $rc2.Width = "10"
    $rc3 = New-Object System.Windows.Controls.ColumnDefinition; $rc3.Width = "*"
    $rowGrid.ColumnDefinitions.Add($rc1)
    $rowGrid.ColumnDefinitions.Add($rc2)
    $rowGrid.ColumnDefinitions.Add($rc3)

    # Битрейт
    $bitStack = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($bitStack, 0)

    $lblBit = New-Object System.Windows.Controls.TextBlock
    $lblBit.Text = "Битрейт (Мбит/с):"
    $lblBit.FontSize = 11
    $lblBit.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblBit.Margin = "0,0,0,3"
    $bitStack.Children.Add($lblBit) | Out-Null

    $comboBit = New-Object System.Windows.Controls.ComboBox
    $comboBit.FontSize = 11
    $comboBit.Height = 26
    [void]$comboBit.Items.Add("2")
    [void]$comboBit.Items.Add("4")
    [void]$comboBit.Items.Add("8 (реком.)")
    [void]$comboBit.Items.Add("12")
    [void]$comboBit.Items.Add("20")
    $comboBit.SelectedIndex = 2
    $bitStack.Children.Add($comboBit) | Out-Null

    $rowGrid.Children.Add($bitStack) | Out-Null

    # FPS
    $fpsStack = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($fpsStack, 2)

    $lblFps = New-Object System.Windows.Controls.TextBlock
    $lblFps.Text = "FPS:"
    $lblFps.FontSize = 11
    $lblFps.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblFps.Margin = "0,0,0,3"
    $fpsStack.Children.Add($lblFps) | Out-Null

    $comboFps = New-Object System.Windows.Controls.ComboBox
    $comboFps.FontSize = 11
    $comboFps.Height = 26
    [void]$comboFps.Items.Add("Без огр.")
    [void]$comboFps.Items.Add("60")
    [void]$comboFps.Items.Add("30")
    [void]$comboFps.Items.Add("15")
    $comboFps.SelectedIndex = 0
    $fpsStack.Children.Add($comboFps) | Out-Null

    $rowGrid.Children.Add($fpsStack) | Out-Null
    $content.Children.Add($rowGrid) | Out-Null

    # --- Опции ---
    $optHeader = New-Object System.Windows.Controls.TextBlock
    $optHeader.Text = "Опции:"
    $optHeader.FontSize = 11
    $optHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $optHeader.Margin = "0,0,0,4"
    $content.Children.Add($optHeader) | Out-Null

    $optGrid = New-Object System.Windows.Controls.Grid
    $optGrid.Margin = "0,0,0,0"

    $oc1 = New-Object System.Windows.Controls.ColumnDefinition; $oc1.Width = "*"
    $oc2 = New-Object System.Windows.Controls.ColumnDefinition; $oc2.Width = "*"
    $optGrid.ColumnDefinitions.Add($oc1)
    $optGrid.ColumnDefinitions.Add($oc2)

    # Колонка 1
    $optCol1 = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($optCol1, 0)

    $chkTurnOff = New-Object System.Windows.Controls.CheckBox
    $chkTurnOff.Style = $window.Resources["MiuiCheckBox"]
    $chkTurnOff.Content = "Погасить экран ТВ"
    $chkTurnOff.FontSize = 11
    $chkTurnOff.Padding = "4,2"
    $chkTurnOff.IsChecked = $true
    $chkTurnOff.Margin = "0,0,0,2"
    $optCol1.Children.Add($chkTurnOff) | Out-Null

    $chkStayAwake = New-Object System.Windows.Controls.CheckBox
    $chkStayAwake.Style = $window.Resources["MiuiCheckBox"]
    $chkStayAwake.Content = "Не давать ТВ уснуть"
    $chkStayAwake.FontSize = 11
    $chkStayAwake.Padding = "4,2"
    $chkStayAwake.IsChecked = $true
    $chkStayAwake.Margin = "0,0,0,2"
    $optCol1.Children.Add($chkStayAwake) | Out-Null

    $chkFullscreen = New-Object System.Windows.Controls.CheckBox
    $chkFullscreen.Style = $window.Resources["MiuiCheckBox"]
    $chkFullscreen.Content = "На весь экран"
    $chkFullscreen.FontSize = 11
    $chkFullscreen.Padding = "4,2"
    $chkFullscreen.IsChecked = $false
    $optCol1.Children.Add($chkFullscreen) | Out-Null

    $optGrid.Children.Add($optCol1) | Out-Null

    # Колонка 2
    $optCol2 = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($optCol2, 1)

    $chkNoAudio = New-Object System.Windows.Controls.CheckBox
    $chkNoAudio.Style = $window.Resources["MiuiCheckBox"]
    $chkNoAudio.Content = "Без звука"
    $chkNoAudio.FontSize = 11
    $chkNoAudio.Padding = "4,2"
    $chkNoAudio.IsChecked = $false
    $chkNoAudio.Margin = "0,0,0,2"
    $optCol2.Children.Add($chkNoAudio) | Out-Null

    $chkNoControl = New-Object System.Windows.Controls.CheckBox
    $chkNoControl.Style = $window.Resources["MiuiCheckBox"]
    $chkNoControl.Content = "Без управления"
    $chkNoControl.FontSize = 11
    $chkNoControl.Padding = "4,2"
    $chkNoControl.IsChecked = $false
    $optCol2.Children.Add($chkNoControl) | Out-Null

    $optGrid.Children.Add($optCol2) | Out-Null

    $content.Children.Add($optGrid) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($content, 1)
    $grid.Children.Add($content) | Out-Null

    # ===== КНОПКИ =====
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    $btnPanel.Margin = "0,15,0,0"

    $btnStart = New-Object System.Windows.Controls.Button
    $btnStart.Content = "Запустить"
    $btnStart.Style = $window.Resources["RoundedButton"]
    $btnStart.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnStart.Padding = "18,6"
    $btnStart.FontSize = 12
    $btnStart.Margin = "0,0,8,0"
    $btnStart.Add_Click({
        $sizeMap = @{ 0 = 0; 1 = 1920; 2 = 1280; 3 = 1024 }
        $bitMap  = @{ 0 = 2; 1 = 4; 2 = 8; 3 = 12; 4 = 20 }
        $fpsMap  = @{ 0 = 0; 1 = 60; 2 = 30; 3 = 15 }

        $maxSize = $sizeMap[$comboSize.SelectedIndex]
        $bit     = $bitMap[$comboBit.SelectedIndex]
        $fps     = $fpsMap[$comboFps.SelectedIndex]

        $ok = Start-Scrcpy -DeviceIp $script:deviceIp `
                           -MaxSize $maxSize `
                           -BitRateMbps $bit `
                           -MaxFps $fps `
                           -TurnScreenOff:$chkTurnOff.IsChecked `
                           -StayAwake:$chkStayAwake.IsChecked `
                           -Fullscreen:$chkFullscreen.IsChecked `
                           -NoAudio:$chkNoAudio.IsChecked `
                           -NoControl:$chkNoControl.IsChecked

        if ($ok) {
            $dialog.Close()
        }
    })
    $btnPanel.Children.Add($btnStart) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Отмена"
    $btnCancel.Style = $window.Resources["RoundedButton"]
    $btnCancel.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnCancel.Padding = "18,6"
    $btnCancel.FontSize = 12
    $btnCancel.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnCancel) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}