# ============================================================================
#  Экран: Процессы ТВ
# ============================================================================

function Invoke-ProcAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== ПОЛУЧЕНИЕ СПИСКА ПРОЦЕССОВ =====
function Get-RemoteProcesses {
    param([int]$TopN = 30, [string]$SortBy = "cpu")

    Write-Log -Message "Читаю процессы (сортировка по $SortBy)..." -Level "Info"

    $processes = @()

    try {
        # Выбираем формат через -o (работает на этой прошивке TCL)
        if ($SortBy -eq "ram") {
            $out = Invoke-ProcAdb @("shell", "top", "-n", "1", "-b", "-o", "%MEM,RES,CMDLINE")
        } else {
            $out = Invoke-ProcAdb @("shell", "top", "-n", "1", "-b", "-o", "%CPU,RES,CMDLINE")
        }

        if (-not $out) {
            Write-Log -Message "Не удалось получить вывод top" -Level "Warning"
            return ,$processes
        }

        $lines = $out -split "`r?`n"

        # Ищем строку заголовка — она содержит "RES" и "CMDLINE"
        $startLine = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'RES\s*\[?CMDLINE') {
                $startLine = $i + 1
                break
            }
        }

        # Парсим данные — формат: " 12.3  45M com.example.app"
        for ($i = $startLine; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            # Ожидаем: [пробелы] число [пробелы] размер [пробелы] имя
            # Пример: "31.4 3.5M top -n 1 -b"
            #          " 0.0  14M zygote"
            if ($line -match '^\s*([\d\.]+)\s+(\d+)([KMG])\s+(.+)$') {
                $cpu    = [double]$matches[1]
                $memVal = [int]$matches[2]
                $memUnit = $matches[3]
                $name   = $matches[4].Trim()

                $memKb = $memVal
                switch ($memUnit) {
                    "M" { $memKb = $memVal * 1024 }
                    "G" { $memKb = $memVal * 1024 * 1024 }
                }

                # Пропускаем сам top
                if ($name -match '^top\s' -or $name -eq "top") { continue }

                $processes += [PSCustomObject]@{
                    PID    = "—"    # В формате -o PID отсутствует
                    CPU    = [math]::Round($cpu, 1)
                    MemPct = 0
                    MemKb  = $memKb
                    Name   = $name
                }
            }
        }

        # Сортируем ещё раз (top не всегда сортирует)
        if ($SortBy -eq "ram") {
            $processes = $processes | Sort-Object -Property MemKb -Descending
        } else {
            $processes = $processes | Sort-Object -Property CPU -Descending
        }

        $processes = @($processes | Select-Object -First $TopN)
        Write-Log -Message "Найдено процессов: $($processes.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения процессов: $_" -Level "Error"
    }

    return ,$processes
}

# ===== УБИЙСТВО ПРОЦЕССА =====
function Stop-RemoteProcess {
    param([string]$Package, [string]$Pid = "")

    if ($Package -and $Package -match '^[a-z][a-z0-9_\.]+$') {
        Write-Log -Message "Останавливаю приложение: $Package" -Level "Info"
        $out = Invoke-ProcAdb @("shell", "am", "force-stop", $Package)
        if ($out -match 'error|Error|Exception') {
            Write-Log -Message "Ошибка: $out" -Level "Error"
            return $false
        }
        Write-Log -Message "OK: $Package остановлен" -Level "Success"
        return $true
    }
    elseif ($Pid -and $Pid -match '^\d+$') {
        Write-Log -Message "Убиваю PID $Pid" -Level "Warning"
        $out = Invoke-ProcAdb @("shell", "kill", "-9", $Pid)
        Write-Log -Message "OK: PID $Pid убит" -Level "Success"
        return $true
    }
    else {
        Write-Log -Message "Не указан ни пакет, ни PID" -Level "Error"
        return $false
    }
}

# ===== ИНФОРМАЦИЯ О ПАМЯТИ =====
function Get-MemorySummary {
    $out = Invoke-ProcAdb @("shell", "cat", "/proc/meminfo")
    $summary = [ordered]@{
        Total     = "—"
        Free      = "—"
        Available = "—"
        UsedPct   = 0
    }

    $total = 0; $avail = 0
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match 'MemTotal:\s+(\d+)\s+kB')     { $total = [int]$matches[1] }
        if ($line -match 'MemAvailable:\s+(\d+)\s+kB') { $avail = [int]$matches[1] }
        if ($line -match 'MemFree:\s+(\d+)\s+kB')      { $summary.Free = "$([math]::Round([int]$matches[1]/1024, 0)) МБ" }
    }

    if ($total -gt 0) {
        $summary.Total = "$([math]::Round($total/1024/1024, 2)) ГБ"
        if ($avail -gt 0) {
            $summary.Available = "$([math]::Round($avail/1024/1024, 2)) ГБ"
            $summary.UsedPct = [math]::Round(100 - ($avail / $total * 100))
        }
    }

    return [PSCustomObject]$summary
}

# ===== ОСНОВНОЙ ЭКРАН =====
function Show-ProcessesView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,25"

    $header = New-ViewHeader -Text "Процессы ТВ"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ПАМЯТЬ =====
    $mem = Get-MemorySummary

    $memCard = New-Object System.Windows.Controls.Border
    $memCard.Background = "White"
    $memCard.BorderBrush = "#E1E1E6"
    $memCard.BorderThickness = "1"
    $memCard.CornerRadius = "8"
    $memCard.Padding = "12,10"
    $memCard.Margin = "0,0,0,15"

    $memStack = New-Object System.Windows.Controls.StackPanel

    $memTitle = New-Object System.Windows.Controls.TextBlock
    $memTitle.Text = "Оперативная память"
    $memTitle.FontSize = 13
    $memTitle.FontWeight = "Bold"
    $memTitle.Foreground = "#4A90E2"
    $memTitle.Margin = "0,0,0,8"
    $memStack.Children.Add($memTitle) | Out-Null

    $memLine = New-Object System.Windows.Controls.TextBlock
    $memLine.FontSize = 13
    $memLine.Foreground = "#2D2D30"
    $memLine.Text = "Всего: $($mem.Total)   |   Свободно: $($mem.Available)   |   Использовано: $($mem.UsedPct)%"
    $memStack.Children.Add($memLine) | Out-Null

    # Прогрессбар
    if ($mem.UsedPct -gt 0) {
        $bar = New-Object System.Windows.Controls.ProgressBar
        $bar.Value = $mem.UsedPct
        $bar.Maximum = 100
        $bar.Height = 6
        $bar.Margin = "0,8,0,0"
        $bar.Foreground = if ($mem.UsedPct -gt 85) { "#E57373" } elseif ($mem.UsedPct -gt 65) { "#FFB74D" } else { "#66BB6A" }
        $bar.Background = "#F0F0F5"
        $memStack.Children.Add($bar) | Out-Null
    }

    $memCard.Child = $memStack
    $mainStack.Children.Add($memCard) | Out-Null

    # ===== СОРТИРОВКА =====
    $mainStack.Children.Add((New-StepTitle -Text "Топ процессов")) | Out-Null

    $sortPanel = New-Object System.Windows.Controls.StackPanel
    $sortPanel.Orientation = "Horizontal"
    $sortPanel.Margin = "0,0,0,10"

    $btnSortCpu = New-ViewButton -Text "По CPU" -ColorType "Primary" -OnClick {
        $script:ProcessesSortBy = "cpu"
        Switch-View -ViewName "Processes"
    }
    if ($script:ProcessesSortBy -eq "cpu") { $btnSortCpu.FontWeight = "Bold" }
    $sortPanel.Children.Add($btnSortCpu) | Out-Null

    $btnSortRam = New-ViewButton -Text "По памяти" -ColorType "Primary" -OnClick {
        $script:ProcessesSortBy = "ram"
        Switch-View -ViewName "Processes"
    }
    if ($script:ProcessesSortBy -eq "ram") { $btnSortRam.FontWeight = "Bold" }
    $sortPanel.Children.Add($btnSortRam) | Out-Null

    $btnRefresh = New-ViewButton -Text "Обновить" -ColorType "Neutral" -OnClick {
        Switch-View -ViewName "Processes"
    }
    $sortPanel.Children.Add($btnRefresh) | Out-Null

    $mainStack.Children.Add($sortPanel) | Out-Null

    # ===== ТАБЛИЦА ПРОЦЕССОВ =====
    $procs = Get-RemoteProcesses -TopN 30 -SortBy $script:ProcessesSortBy

    if ($procs.Count -eq 0) {
        $mainStack.Children.Add((New-ViewLabel -Text "Не удалось получить список процессов.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # Заголовок таблицы
    $headerRow = New-Object System.Windows.Controls.Grid
    $headerRow.Margin = "8,0,8,5"

    $hc1 = New-Object System.Windows.Controls.ColumnDefinition; $hc1.Width = "60"
    $hc2 = New-Object System.Windows.Controls.ColumnDefinition; $hc2.Width = "80"
    $hc3 = New-Object System.Windows.Controls.ColumnDefinition; $hc3.Width = "*"
    $hc4 = New-Object System.Windows.Controls.ColumnDefinition; $hc4.Width = "80"
    $headerRow.ColumnDefinitions.Add($hc1)
    $headerRow.ColumnDefinitions.Add($hc2)
    $headerRow.ColumnDefinitions.Add($hc3)
    $headerRow.ColumnDefinitions.Add($hc4)

    $headers = @("CPU%", "Память", "Процесс", "")
    for ($i = 0; $i -lt 5; $i++) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $headers[$i]
        $tb.FontSize = 11
        $tb.FontWeight = "Bold"
        $tb.Foreground = "#96969B"
        [System.Windows.Controls.Grid]::SetColumn($tb, $i)
        $headerRow.Children.Add($tb) | Out-Null
    }
    $mainStack.Children.Add($headerRow) | Out-Null

    # Строки
    foreach ($p in $procs) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "White"
        $row.BorderBrush = "#E1E1E6"
        $row.BorderThickness = "1,1,1,0"
        $row.Padding = "8,6"

        $g = New-Object System.Windows.Controls.Grid
        $gc1 = New-Object System.Windows.Controls.ColumnDefinition; $gc1.Width = "60"
        $gc2 = New-Object System.Windows.Controls.ColumnDefinition; $gc2.Width = "60"
        $gc3 = New-Object System.Windows.Controls.ColumnDefinition; $gc3.Width = "80"
        $gc4 = New-Object System.Windows.Controls.ColumnDefinition; $gc4.Width = "*"
        $gc5 = New-Object System.Windows.Controls.ColumnDefinition; $gc5.Width = "80"
        $g.ColumnDefinitions.Add($gc1)
        $g.ColumnDefinitions.Add($gc2)
        $g.ColumnDefinitions.Add($gc3)
        $g.ColumnDefinitions.Add($gc4)
        $g.ColumnDefinitions.Add($gc5)

        # PID
        $tbPid = New-Object System.Windows.Controls.TextBlock
        $tbPid.Text = $p.PID
        $tbPid.FontFamily = "Consolas"
        $tbPid.FontSize = 11
        $tbPid.Foreground = "#96969B"
        $tbPid.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($tbPid, 0)
        $g.Children.Add($tbPid) | Out-Null

        # CPU
        $tbCpu = New-Object System.Windows.Controls.TextBlock
        $tbCpu.Text = "$($p.CPU)%"
        $tbCpu.FontFamily = "Consolas"
        $tbCpu.FontSize = 11
        $tbCpu.VerticalAlignment = "Center"
        $tbCpu.Foreground = if ($p.CPU -gt 20) { "#E57373" } elseif ($p.CPU -gt 5) { "#FFB74D" } else { "#2D2D30" }
        [System.Windows.Controls.Grid]::SetColumn($tbCpu, 1)
        $g.Children.Add($tbCpu) | Out-Null

        # RAM
        $tbMem = New-Object System.Windows.Controls.TextBlock
        $tbMem.Text = "$([math]::Round($p.MemKb / 1024, 1)) МБ"
        $tbMem.FontFamily = "Consolas"
        $tbMem.FontSize = 11
        $tbMem.VerticalAlignment = "Center"
        $tbMem.Foreground = "#2D2D30"
        [System.Windows.Controls.Grid]::SetColumn($tbMem, 2)
        $g.Children.Add($tbMem) | Out-Null

        # Имя
        $tbName = New-Object System.Windows.Controls.TextBlock
        $tbName.Text = $p.Name
        $tbName.FontFamily = "Consolas"
        $tbName.FontSize = 11
        $tbName.Foreground = "#2D2D30"
        $tbName.TextTrimming = "CharacterEllipsis"
        $tbName.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($tbName, 3)
        $g.Children.Add($tbName) | Out-Null

        # Кнопка kill (только для пакетов типа com.xxx)
        if ($p.Name -match '^[a-z][a-z0-9_\.]+$') {
            $btnKill = New-Object System.Windows.Controls.Button
            $btnKill.Content = "Стоп"
            $btnKill.Style = $window.Resources["RoundedButton"]
            $btnKill.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
            )
            $btnKill.Padding = "8,3"
            $btnKill.FontSize = 10
            $btnKill.VerticalAlignment = "Center"
            $pkgLocal = $p.Name
            $btnKill.Add_Click({
                $confirm = [System.Windows.MessageBox]::Show(
                    "Остановить процесс `"$pkgLocal`"?`n`nПриложение будет принудительно закрыто.",
                    "Подтверждение",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)
                if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                    Stop-RemoteProcess -Package $pkgLocal | Out-Null
                    Start-Sleep -Milliseconds 500
                    Switch-View -ViewName "Processes"
                }
            }.GetNewClosure())
            [System.Windows.Controls.Grid]::SetColumn($btnKill, 4)
            $g.Children.Add($btnKill) | Out-Null
        }

        $row.Child = $g
        $mainStack.Children.Add($row) | Out-Null
    }

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран процессов (топ $($procs.Count), сортировка: $script:ProcessesSortBy)" -Level "Info"
}