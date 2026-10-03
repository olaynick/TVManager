# ============================================================================
#  Экран: Проверка целостности
#  Сравнивает текущее состояние ТВ с сохранённым JSON-дампом.
# ============================================================================

function Invoke-IntegrityAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== ЗАГРУЗКА ЭТАЛОННОГО ДАМПА =====
function Select-ReferenceDump {
    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "JSON dump (*.json)|*.json|All files (*.*)|*.*"
    $dlg.Title = "Выберите эталонный дамп"

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    try {
        $json = Get-Content $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Log -Message "Эталон загружен: $($dlg.FileName)" -Level "Success"
        return @{
            Path = $dlg.FileName
            Data = $json
        }
    } catch {
        Write-Log -Message "Ошибка чтения дампа: $_" -Level "Error"
        return $null
    }
}

# ===== СРАВНЕНИЕ С ЭТАЛОНОМ =====
function Compare-WithReference {
    param([PSCustomObject]$RefData)

    Write-Log -Message "=== Сравнение с эталоном ===" -Level "Info"

    $result = [ordered]@{
        Added         = @()   # Установлены после дампа
        Removed       = @()   # Были в дампе, теперь удалены
        DisabledNow   = @()   # Были включены, сейчас отключены
        EnabledNow    = @()   # Были отключены, сейчас включены
        RefTimestamp  = ""
        RefDeviceIP   = ""
        IsSame        = $true
        Error         = ""
    }

    try {
        $result.RefTimestamp = $RefData.ExportedAt
        $result.RefDeviceIP  = $RefData.DeviceIP

        # --- Текущее состояние ---
        Write-Log -Message "Читаю текущее состояние ТВ..." -Level "Info"

        $nowAllRaw = Invoke-IntegrityAdb @("shell", "pm", "list", "packages")
        $nowAll = @()
        foreach ($line in ($nowAllRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') { $nowAll += $matches[1].Trim() }
        }

        $nowDisabledRaw = Invoke-IntegrityAdb @("shell", "pm", "list", "packages", "-d")
        $nowDisabled = @()
        foreach ($line in ($nowDisabledRaw -split "`r?`n")) {
            if ($line -match '^package:(.+)$') { $nowDisabled += $matches[1].Trim() }
        }

        # --- Эталонное состояние из дампа ---
        $refAll = @()
        $refDisabled = @()

        if ($RefData.Packages) {
            if ($RefData.Packages.All)      { $refAll = @($RefData.Packages.All) }
            if ($RefData.Packages.Disabled) { $refDisabled = @($RefData.Packages.Disabled) }
        }

        Write-Log -Message "Сейчас: $($nowAll.Count) пакетов, отключено: $($nowDisabled.Count)" -Level "Info"
        Write-Log -Message "В эталоне: $($refAll.Count) пакетов, отключено: $($refDisabled.Count)" -Level "Info"

        # --- Установленные после дампа (есть сейчас, не было в дампе) ---
        foreach ($pkg in $nowAll) {
            if ($pkg -notin $refAll) {
                $result.Added += $pkg
            }
        }

        # --- Удалённые (были в дампе, нет сейчас) ---
        foreach ($pkg in $refAll) {
            if ($pkg -notin $nowAll) {
                $result.Removed += $pkg
            }
        }

        # --- Отключённые (в дампе включены, сейчас отключены) ---
        foreach ($pkg in $nowDisabled) {
            if ($pkg -notin $refDisabled) {
                $result.DisabledNow += $pkg
            }
        }

        # --- Включённые обратно (в дампе отключены, сейчас включены) ---
        foreach ($pkg in $refDisabled) {
            if ($pkg -notin $nowDisabled -and $pkg -in $nowAll) {
                $result.EnabledNow += $pkg
            }
        }

        $result.IsSame = ($result.Added.Count -eq 0 -and
                          $result.Removed.Count -eq 0 -and
                          $result.DisabledNow.Count -eq 0 -and
                          $result.EnabledNow.Count -eq 0)

        Write-Log -Message "Различия: +$($result.Added.Count) -$($result.Removed.Count) / откл: $($result.DisabledNow.Count) / вкл: $($result.EnabledNow.Count)" -Level "Info"
    } catch {
        $result.Error = "$_"
        Write-Log -Message "Ошибка сравнения: $_" -Level "Error"
    }

    return [PSCustomObject]$result
}

# ===== ПОСТРОЕНИЕ КАРТОЧКИ ДЛЯ ГРУППЫ =====
function New-DiffSection {
    param(
        [string]$Title,
        [array]$Items,
        [string]$Color
    )

    $section = New-Object System.Windows.Controls.Border
    $section.Background = "White"
    $section.BorderBrush = "#E1E1E6"
    $section.BorderThickness = "1"
    $section.CornerRadius = "6"
    $section.Padding = "12"
    $section.Margin = "0,0,0,10"

    $stack = New-Object System.Windows.Controls.StackPanel

    $headerStack = New-Object System.Windows.Controls.StackPanel
    $headerStack.Orientation = "Horizontal"

    $titleTb = New-Object System.Windows.Controls.TextBlock
    $titleTb.Text = $Title
    $titleTb.FontSize = 14
    $titleTb.FontWeight = "Bold"
    $titleTb.Foreground = $Color
    $titleTb.VerticalAlignment = "Center"
    $headerStack.Children.Add($titleTb) | Out-Null

    $countTb = New-Object System.Windows.Controls.TextBlock
    $countTb.Text = "   ($($Items.Count))"
    $countTb.FontSize = 13
    $countTb.Foreground = "#96969B"
    $countTb.VerticalAlignment = "Center"
    $headerStack.Children.Add($countTb) | Out-Null

    $stack.Children.Add($headerStack) | Out-Null

    if ($Items.Count -eq 0) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "  (нет)"
        $empty.FontSize = 12
        $empty.Foreground = "#96969B"
        $empty.Margin = "10,6,0,0"
        $stack.Children.Add($empty) | Out-Null
    } else {
        $listStack = New-Object System.Windows.Controls.StackPanel
        $listStack.Margin = "10,8,0,0"

        $maxShow = 50
        $shown = 0
        foreach ($item in $Items) {
            if ($shown -ge $maxShow) {
                $moreTb = New-Object System.Windows.Controls.TextBlock
                $moreTb.Text = "  ... и ещё $($Items.Count - $maxShow)"
                $moreTb.FontSize = 11
                $moreTb.Foreground = "#96969B"
                $moreTb.Margin = "0,2,0,0"
                $listStack.Children.Add($moreTb) | Out-Null
                break
            }

            $itemTb = New-Object System.Windows.Controls.TextBlock
            $itemTb.Text = "  $item"
            $itemTb.FontFamily = "Consolas"
            $itemTb.FontSize = 12
            $itemTb.Foreground = "#2D2D30"
            $itemTb.Margin = "0,2,0,0"
            $listStack.Children.Add($itemTb) | Out-Null
            $shown++
        }

        $stack.Children.Add($listStack) | Out-Null
    }

    $section.Child = $stack
    return $section
}

# ===== ПОКАЗАТЬ ОКНО РЕЗУЛЬТАТА =====
function Show-IntegrityResultDialog {
    param(
        [PSCustomObject]$Diff,
        [string]$RefPath
    )

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Результат проверки целостности"
    $dialog.Width = 800
    $dialog.Height = 700
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#F7F7FA"

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
    $headerPanel = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = if ($Diff.IsSame) { "✓ Изменений не обнаружено" } else { "Обнаружены различия" }
    $title.FontSize = 20
    $title.FontWeight = "Bold"
    $title.Foreground = if ($Diff.IsSame) { "#2E7D32" } else { "#F57C00" }
    $title.Margin = "0,0,0,10"
    $headerPanel.Children.Add($title) | Out-Null

    $infoTb = New-Object System.Windows.Controls.TextBlock
    $infoTb.FontSize = 11
    $infoTb.Foreground = "#96969B"
    $infoTb.TextWrapping = "Wrap"
    $infoTb.Text = "Эталон: $RefPath`nУстройство: $($Diff.RefDeviceIP)   |   Дамп от: $($Diff.RefTimestamp)"
    $infoTb.Margin = "0,0,0,15"
    $headerPanel.Children.Add($infoTb) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($headerPanel, 0)
    $grid.Children.Add($headerPanel) | Out-Null

    # --- Скролл с содержимым ---
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $contentStack = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $contentStack

    if ($Diff.IsSame) {
        $okCard = New-Object System.Windows.Controls.Border
        $okCard.Background = "#E8F5E9"
        $okCard.BorderBrush = "#66BB6A"
        $okCard.BorderThickness = "1"
        $okCard.CornerRadius = "8"
        $okCard.Padding = "20"

        $okText = New-Object System.Windows.Controls.TextBlock
        $okText.Text = "Состояние пакетов полностью совпадает с эталонным дампом.`nНичего не установлено, не удалено, не отключено и не включено с момента снятия дампа."
        $okText.FontSize = 13
        $okText.Foreground = "#2E7D32"
        $okText.TextWrapping = "Wrap"
        $okCard.Child = $okText
        $contentStack.Children.Add($okCard) | Out-Null
    } else {
        # Установленные
        $contentStack.Children.Add((New-DiffSection -Title "Установленные после дампа" -Items $Diff.Added -Color "#66BB6A")) | Out-Null

        # Удалённые
        $contentStack.Children.Add((New-DiffSection -Title "Удалённые с момента дампа" -Items $Diff.Removed -Color "#E57373")) | Out-Null

        # Отключённые
        $contentStack.Children.Add((New-DiffSection -Title "Отключённые с момента дампа" -Items $Diff.DisabledNow -Color "#FFB74D")) | Out-Null

        # Включённые
        $contentStack.Children.Add((New-DiffSection -Title "Включённые обратно" -Items $Diff.EnabledNow -Color "#4A90E2")) | Out-Null
    }

    # --- Кнопки ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    # Кнопка "Сохранить отчёт"
    $btnSaveReport = New-Object System.Windows.Controls.Button
    $btnSaveReport.Content = "Сохранить отчёт"
    $btnSaveReport.Style = $window.Resources["RoundedButton"]
    $btnSaveReport.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#607D8B")
    )
    $btnSaveReport.Padding = "15,8"
    $btnSaveReport.Margin = "0,0,10,0"
    $btnSaveReport.Add_Click({
        Save-IntegrityReport -Diff $Diff -RefPath $RefPath
    }.GetNewClosure())
    $btnPanel.Children.Add($btnSaveReport) | Out-Null

    # Кнопка "Закрыть"
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnClose.Padding = "15,8"
    $btnClose.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

# ===== СОХРАНЕНИЕ ОТЧЁТА =====
function Save-IntegrityReport {
    param(
        [PSCustomObject]$Diff,
        [string]$RefPath
    )

    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $dlg.FileName = "integrity_report_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    try {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("Проверка целостности TVManagerTCL")
        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("Отчёт создан: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("Эталон: $RefPath")
        [void]$sb.AppendLine("Устройство: $($Diff.RefDeviceIP)")
        [void]$sb.AppendLine("Дамп от: $($Diff.RefTimestamp)")
        [void]$sb.AppendLine()

        if ($Diff.IsSame) {
            [void]$sb.AppendLine("РЕЗУЛЬТАТ: изменений не обнаружено")
        } else {
            [void]$sb.AppendLine("РЕЗУЛЬТАТ: обнаружены различия")
            [void]$sb.AppendLine()

            [void]$sb.AppendLine("### Установленные после дампа ($($Diff.Added.Count)) ###")
            foreach ($p in $Diff.Added) { [void]$sb.AppendLine("  + $p") }
            [void]$sb.AppendLine()

            [void]$sb.AppendLine("### Удалённые с момента дампа ($($Diff.Removed.Count)) ###")
            foreach ($p in $Diff.Removed) { [void]$sb.AppendLine("  - $p") }
            [void]$sb.AppendLine()

            [void]$sb.AppendLine("### Отключённые с момента дампа ($($Diff.DisabledNow.Count)) ###")
            foreach ($p in $Diff.DisabledNow) { [void]$sb.AppendLine("  off: $p") }
            [void]$sb.AppendLine()

            [void]$sb.AppendLine("### Включённые обратно ($($Diff.EnabledNow.Count)) ###")
            foreach ($p in $Diff.EnabledNow) { [void]$sb.AppendLine("  on:  $p") }
            [void]$sb.AppendLine()
        }

        [void]$sb.AppendLine("=" * 80)
        [System.IO.File]::WriteAllText($dlg.FileName, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

        Write-Log -Message "Отчёт сохранён: $($dlg.FileName)" -Level "Success"
        [System.Windows.MessageBox]::Show(
            "Отчёт сохранён:`n$($dlg.FileName)",
            "Готово",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    } catch {
        Write-Log -Message "Ошибка сохранения отчёта: $_" -Level "Error"
    }
}

# ===== ОСНОВНОЙ ЭКРАН =====
function Show-IntegrityView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Проверка целостности"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Сравнивает текущее состояние пакетов на ТВ с сохранённым ранее дампом устройства. Показывает, что было установлено, удалено, отключено или включено после снятия дампа." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== КАРТОЧКА С ТЕКУЩИМ СОСТОЯНИЕМ =====
    $currentCard = New-Object System.Windows.Controls.Border
    $currentCard.Background = "White"
    $currentCard.BorderBrush = "#E1E1E6"
    $currentCard.BorderThickness = "1"
    $currentCard.CornerRadius = "8"
    $currentCard.Padding = "15"
    $currentCard.Margin = "0,0,0,15"

    $currentStack = New-Object System.Windows.Controls.StackPanel

    $currentTitle = New-Object System.Windows.Controls.TextBlock
    $currentTitle.Text = "Текущее состояние ТВ"
    $currentTitle.FontSize = 14
    $currentTitle.FontWeight = "Bold"
    $currentTitle.Foreground = "#4A90E2"
    $currentTitle.Margin = "0,0,0,10"
    $currentStack.Children.Add($currentTitle) | Out-Null

    Write-Log -Message "Читаю текущее состояние ТВ для проверки..." -Level "Info"

    $nowAllRaw = Invoke-IntegrityAdb @("shell", "pm", "list", "packages")
    $nowAllCount = 0
    foreach ($line in ($nowAllRaw -split "`r?`n")) {
        if ($line -match '^package:') { $nowAllCount++ }
    }

    $nowThirdRaw = Invoke-IntegrityAdb @("shell", "pm", "list", "packages", "-3")
    $nowThirdCount = 0
    foreach ($line in ($nowThirdRaw -split "`r?`n")) {
        if ($line -match '^package:') { $nowThirdCount++ }
    }

    $nowDisabledRaw = Invoke-IntegrityAdb @("shell", "pm", "list", "packages", "-d")
    $nowDisabledCount = 0
    foreach ($line in ($nowDisabledRaw -split "`r?`n")) {
        if ($line -match '^package:') { $nowDisabledCount++ }
    }

    $statLine = New-Object System.Windows.Controls.TextBlock
    $statLine.FontSize = 13
    $statLine.Foreground = "#2D2D30"
    $statLine.Text = "Всего пакетов: $nowAllCount   |   Сторонних: $nowThirdCount   |   Отключённых: $nowDisabledCount"
    $currentStack.Children.Add($statLine) | Out-Null

    $currentCard.Child = $currentStack
    $mainStack.Children.Add($currentCard) | Out-Null

    # ===== ЭТАЛОН =====
    $mainStack.Children.Add((New-StepTitle -Text "Эталон для сравнения")) | Out-Null

    if ($script:IntegrityReference) {
        # Уже загружен эталон
        $refCard = New-Object System.Windows.Controls.Border
        $refCard.Background = "#E8F5E9"
        $refCard.BorderBrush = "#66BB6A"
        $refCard.BorderThickness = "1"
        $refCard.CornerRadius = "6"
        $refCard.Padding = "12"
        $refCard.Margin = "0,0,0,10"

        $refStack = New-Object System.Windows.Controls.StackPanel

        $refTitle = New-Object System.Windows.Controls.TextBlock
        $refTitle.Text = "Эталон загружен"
        $refTitle.FontSize = 13
        $refTitle.FontWeight = "Bold"
        $refTitle.Foreground = "#2E7D32"
        $refStack.Children.Add($refTitle) | Out-Null

        $refPathTb = New-Object System.Windows.Controls.TextBlock
        $refPathTb.Text = $script:IntegrityReference.Path
        $refPathTb.FontFamily = "Consolas"
        $refPathTb.FontSize = 11
        $refPathTb.Foreground = "#2D2D30"
        $refPathTb.TextWrapping = "Wrap"
        $refPathTb.Margin = "0,5,0,0"
        $refStack.Children.Add($refPathTb) | Out-Null

        $refInfoTb = New-Object System.Windows.Controls.TextBlock
        $refInfoTb.FontSize = 11
        $refInfoTb.Foreground = "#96969B"
        $refInfoTb.Margin = "0,3,0,0"
        $refInfoTb.Text = "Дамп создан: $($script:IntegrityReference.Data.ExportedAt)   |   IP: $($script:IntegrityReference.Data.DeviceIP)"
        $refStack.Children.Add($refInfoTb) | Out-Null

        $refCard.Child = $refStack
        $mainStack.Children.Add($refCard) | Out-Null
    } else {
        $noRef = New-ViewLabel -Text "Эталон не загружен. Нажмите «Выбрать дамп» внизу." -Light
        $noRef.Margin = "0,0,0,10"
        $mainStack.Children.Add($noRef) | Out-Null
    }

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== НИЖНЯЯ ПАНЕЛЬ =====
    $buttons = @()

    $btnSelect = New-Object System.Windows.Controls.Button
    $btnSelect.Content = "Выбрать дамп"
    $btnSelect.Style = $window.Resources["RoundedButton"]
    $btnSelect.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#607D8B")
    )
    $btnSelect.Padding = "12,6"
    $btnSelect.Margin = "0,0,8,0"
    $btnSelect.Add_Click({
        $ref = Select-ReferenceDump
        if ($ref) {
            $script:IntegrityReference = $ref
            Switch-View -ViewName "Integrity"
        }
    })
    $buttons += $btnSelect

    if ($script:IntegrityReference) {
        $btnCompare = New-Object System.Windows.Controls.Button
        $btnCompare.Content = "Сравнить"
        $btnCompare.Style = $window.Resources["RoundedButton"]
        $btnCompare.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
        )
        $btnCompare.Padding = "12,6"
        $btnCompare.Margin = "0,0,8,0"
        $btnCompare.Add_Click({
            $diff = Compare-WithReference -RefData $script:IntegrityReference.Data
            Show-IntegrityResultDialog -Diff $diff -RefPath $script:IntegrityReference.Path
        })
        $buttons += $btnCompare

        $btnClear = New-Object System.Windows.Controls.Button
        $btnClear.Content = "Сбросить эталон"
        $btnClear.Style = $window.Resources["RoundedButton"]
        $btnClear.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
        )
        $btnClear.Padding = "12,6"
        $btnClear.Margin = "0,0,8,0"
        $btnClear.Add_Click({
            $script:IntegrityReference = $null
            Write-Log -Message "Эталон сброшен" -Level "Info"
            Switch-View -ViewName "Integrity"
        })
        $buttons += $btnClear
    }

    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({
        Switch-View -ViewName "Integrity"
    })
    $buttons += $btnRefresh

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран проверки целостности" -Level "Info"
}