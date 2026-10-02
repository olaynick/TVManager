# ===== ФУНКЦИЯ ЗАГРУЗКИ ГАЛЕРЕИ =====
function Load-ScreenshotGallery {
    param(
        [System.Windows.Controls.WrapPanel]$Container,
        [string]$Folder
    )

    if (-not $Container) { return }
    $Container.Children.Clear()

    if (-not (Test-Path $Folder)) {
        $empty = New-ViewLabel -Text "Папка не найдена: $Folder" -Light
        $Container.Children.Add($empty) | Out-Null
        return
    }

    $files = Get-ChildItem -Path $Folder -File | Where-Object {
        $_.Extension -in @(".png", ".jpg", ".jpeg", ".mp4")
    } | Sort-Object LastWriteTime -Descending

    if ($files.Count -eq 0) {
        $empty = New-ViewLabel -Text "Пока нет сохранённых файлов." -Light
        $Container.Children.Add($empty) | Out-Null
        return
    }

    foreach ($file in $files) {
        $tile = New-ScreenshotTile -File $file
        $Container.Children.Add($tile) | Out-Null
    }
}

# ===== ФУНКЦИЯ СОЗДАНИЯ ПЛИТКИ =====
function New-ScreenshotTile {
    param([System.IO.FileInfo]$File)

    $isVideo = $File.Extension -eq ".mp4"

    $border = New-Object System.Windows.Controls.Border
    $border.Width = 200
    $border.Height = 180
    $border.Margin = "0,0,12,12"
    $border.Background = "White"
    $border.BorderBrush = "#E1E1E6"
    $border.BorderThickness = "1"
    $border.CornerRadius = "8"
    $border.Cursor = [System.Windows.Input.Cursors]::Hand

    $tileStack = New-Object System.Windows.Controls.StackPanel

    # ===== ПРЕВЬЮ =====
    $preview = New-Object System.Windows.Controls.Grid
    $preview.Height = 110
    $preview.Background = "#2D2D30"

    if ($isVideo) {
        $playBtn = New-Object System.Windows.Controls.TextBlock
        $playBtn.Text = "▶"
        $playBtn.FontSize = 42
        $playBtn.Foreground = "White"
        $playBtn.HorizontalAlignment = "Center"
        $playBtn.VerticalAlignment = "Center"
        $preview.Children.Add($playBtn) | Out-Null

        $videoLabel = New-Object System.Windows.Controls.TextBlock
        $videoLabel.Text = "ВИДЕО"
        $videoLabel.FontSize = 10
        $videoLabel.FontWeight = "Bold"
        $videoLabel.Foreground = "White"
        $videoLabel.Background = "#9C27B0"
        $videoLabel.Padding = "5,2"
        $videoLabel.HorizontalAlignment = "Left"
        $videoLabel.VerticalAlignment = "Top"
        $videoLabel.Margin = "5,5,0,0"
        $preview.Children.Add($videoLabel) | Out-Null
    } else {
        try {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = New-Object System.Uri($File.FullName)
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.DecodePixelWidth = 200
            $bitmap.EndInit()
            $bitmap.Freeze()

            $img = New-Object System.Windows.Controls.Image
            $img.Source = $bitmap
            $img.Stretch = "UniformToFill"
            $preview.Children.Add($img) | Out-Null
        } catch {
            $errLabel = New-Object System.Windows.Controls.TextBlock
            $errLabel.Text = "ФОТО"
            $errLabel.FontSize = 18
            $errLabel.Foreground = "White"
            $errLabel.HorizontalAlignment = "Center"
            $errLabel.VerticalAlignment = "Center"
            $preview.Children.Add($errLabel) | Out-Null
        }
    }

    $previewClip = New-Object System.Windows.Controls.Border
    $previewClip.CornerRadius = "8,8,0,0"
    $previewClip.ClipToBounds = $true
    $previewClip.Child = $preview

    $tileStack.Children.Add($previewClip) | Out-Null

    # ===== ИМЯ ФАЙЛА =====
    $nameLabel = New-Object System.Windows.Controls.TextBlock
    $nameLabel.Text = $File.Name
    $nameLabel.FontSize = 10
    $nameLabel.Foreground = "#2D2D30"
    $nameLabel.TextTrimming = "CharacterEllipsis"
    $nameLabel.Margin = "8,5,8,0"
    $tileStack.Children.Add($nameLabel) | Out-Null

    # ===== ДАТА =====
    $dateLabel = New-Object System.Windows.Controls.TextBlock
    $dateLabel.Text = $File.LastWriteTime.ToString("dd.MM.yyyy HH:mm")
    $dateLabel.FontSize = 10
    $dateLabel.Foreground = "#96969B"
    $dateLabel.Margin = "8,2,8,5"
    $tileStack.Children.Add($dateLabel) | Out-Null

    $border.Child = $tileStack

    # Сохраняем путь в локальную переменную, чтобы замыкание её "поймало"
    $filePath = $File.FullName

    $border.Add_MouseLeftButtonUp({
        if (Test-Path $filePath) {
            Start-Process $filePath
        } else {
            Write-Log -Message "Файл не найден: $filePath" -Level "Warning"
        }
    }.GetNewClosure())

    return $border
}

# ===== ФУНКЦИЯ ОБНОВЛЕНИЯ ГАЛЕРЕИ =====
function Update-ScreenshotGallery {
    $folder = Get-ScreenshotFolder
    if ($script:GalleryContainer) {
        Load-ScreenshotGallery -Container $script:GalleryContainer -Folder $folder
    }
}

# ===== ОСНОВНОЙ ЭКРАН =====
function Show-ScreenshotView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "30,25,30,25"

    $header = New-ViewHeader -Text "Скриншот и запись экрана"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    $folder = Get-ScreenshotFolder
    $desc = New-ViewLabel -Text "Файлы сохраняются в: $folder" -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    # ===== КНОПКА СКРИНШОТА =====
    $script:CaptureBtn = New-Object System.Windows.Controls.Button
    $script:CaptureBtn.Content = "Сделать скриншот"
    $script:CaptureBtn.Style = $window.Resources["RoundedButton"]
    $script:CaptureBtn.Background = "#00BCD4"
    $script:CaptureBtn.Height = 55
    $script:CaptureBtn.FontSize = 15
    $script:CaptureBtn.HorizontalAlignment = "Left"
    $script:CaptureBtn.Padding = "30,10"
    $script:CaptureBtn.Margin = "0,0,0,15"
    $script:CaptureBtn.Add_Click({
        $script:CaptureBtn.IsEnabled = $false
        $script:CaptureBtn.Content = "Снимаю..."

        $path = Take-Screenshot-ToFolder

        $script:CaptureBtn.IsEnabled = $true
        $script:CaptureBtn.Content = "Сделать скриншот"

        if ($path) {
            $script:LastScreenshotPath = $path
            Update-ScreenshotGallery
        }
    })
    $mainStack.Children.Add($script:CaptureBtn) | Out-Null

    # ===== БЛОК ЗАПИСИ ВИДЕО =====
    $mainStack.Children.Add((New-StepTitle -Text "Запись видео")) | Out-Null

    $recInfo = New-ViewLabel -Text "Выберите длительность записи. Запись идёт на телевизоре." -Light
    $recInfo.Margin = "0,0,0,10"
    $mainStack.Children.Add($recInfo) | Out-Null

    $durationPanel = New-Object System.Windows.Controls.WrapPanel
    $durationPanel.Margin = "0,0,0,10"

    $durations = @(15, 30, 60, 120, 300, 600)
    foreach ($sec in $durations) {
        $label = if ($sec -lt 60) { "$sec сек" } else { "$([int]($sec/60)) мин" }

        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $label
        $btn.Style = $window.Resources["RoundedButton"]
        $btn.Background = "#9C27B0"
        $btn.Padding = "15,8"
        $btn.Margin = "0,0,8,8"
        $secLocal = $sec
        $btn.Add_Click({
            Start-VideoRecording -DurationSeconds $secLocal
        }.GetNewClosure())
        $durationPanel.Children.Add($btn) | Out-Null
    }

    $mainStack.Children.Add($durationPanel) | Out-Null

    # ===== КНОПКИ ДЕЙСТВИЙ =====
    $actionsPanel = New-Object System.Windows.Controls.StackPanel
    $actionsPanel.Orientation = "Horizontal"
    $actionsPanel.Margin = "0,10,0,15"

    $btnRefreshGallery = New-Object System.Windows.Controls.Button
    $btnRefreshGallery.Content = "Обновить галерею"
    $btnRefreshGallery.Style = $window.Resources["RoundedButton"]
    $btnRefreshGallery.Background = "#4A90E2"
    $btnRefreshGallery.Padding = "15,8"
    $btnRefreshGallery.Margin = "0,0,10,0"
    $btnRefreshGallery.Add_Click({
        Update-ScreenshotGallery
        Write-Log -Message "Галерея обновлена" -Level "Info"
    })
    $actionsPanel.Children.Add($btnRefreshGallery) | Out-Null

    $btnOpenFolder = New-Object System.Windows.Controls.Button
    $btnOpenFolder.Content = "Открыть папку"
    $btnOpenFolder.Style = $window.Resources["RoundedButton"]
    $btnOpenFolder.Background = "#607D8B"
    $btnOpenFolder.Padding = "15,8"
    $btnOpenFolder.Add_Click({
        Start-Process explorer.exe $folder
    })
    $actionsPanel.Children.Add($btnOpenFolder) | Out-Null

    $mainStack.Children.Add($actionsPanel) | Out-Null

    # ===== ГАЛЕРЕЯ =====
    $mainStack.Children.Add((New-StepTitle -Text "Сохранённые файлы")) | Out-Null

    $script:GalleryContainer = New-Object System.Windows.Controls.WrapPanel
    $script:GalleryContainer.Margin = "0,10,0,0"
    $mainStack.Children.Add($script:GalleryContainer) | Out-Null

    Load-ScreenshotGallery -Container $script:GalleryContainer -Folder $folder

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран скриншота" -Level "Info"
}

# ===== ЗАПИСЬ ВИДЕО В ФОНЕ =====
function Start-VideoRecording {
    param([int]$DurationSeconds = 30)

    Write-Log -Message "=== Запись видео ($DurationSeconds сек) ===" -Level "Info"

    $folder = Get-ScreenshotFolder
    $logBoxRef = $script:LogBox
    $adbPathRef = $script:adbPath

    $script:RecordRunspace = [runspacefactory]::CreateRunspace()
    $script:RecordRunspace.ApartmentState = "STA"
    $script:RecordRunspace.ThreadOptions = "ReuseThread"
    $script:RecordRunspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $script:RecordRunspace

    $ps.AddScript({
        param($dispatcher, $logBox, $adbPath, $folder, $duration)

        function Write-BgLog {
            param($msg, $lvl = "Info")
            if (-not $logBox) { return }
            try {
                $logBox.Dispatcher.Invoke([action]{
                    $time = Get-Date -Format "HH:mm:ss"
                    $prefix = switch ($lvl) {
                        "Error"   { "[ОШИБКА]" }
                        "Warning" { "[!]" }
                        "Success" { "[OK]" }
                        default   { "[i]" }
                    }
                    $line = "$time $prefix $msg"

                    $para = New-Object System.Windows.Documents.Paragraph
                    $para.Margin = New-Object System.Windows.Thickness(0)
                    $run = New-Object System.Windows.Documents.Run
                    $run.Text = "$line`r`n"
                    $color = switch ($lvl) {
                        "Error"   { [System.Windows.Media.Brushes]::LightCoral }
                        "Warning" { [System.Windows.Media.Brushes]::Khaki }
                        "Success" { [System.Windows.Media.Brushes]::LightGreen }
                        default   { [System.Windows.Media.Brushes]::LightGray }
                    }
                    $run.Foreground = $color
                    $para.Inlines.Add($run)
                    $logBox.Document.Blocks.Add($para)
                    $logBox.ScrollToEnd()
                })
            } catch { }
            Start-Sleep -Milliseconds 80
        }

        $remotePath = "/sdcard/tvmanager_record.mp4"
        Write-BgLog "Временный файл на ТВ: $remotePath" "Info"

        Write-BgLog "Запись идёт на телевизоре. Не отключайте ТВ." "Warning"

        $out = & $adbPath shell screenrecord --time-limit $duration $remotePath 2>&1

        Write-BgLog "Запись завершена" "Success"

        # Проверяем, создан ли файл на ТВ
        $checkOut = & $adbPath shell ls -la $remotePath 2>&1
        Write-BgLog "Файл на ТВ: $checkOut" "Info"

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $filename = "TV_record_$timestamp.mp4"
        $localPath = Join-Path $folder $filename

        Write-BgLog "Локальный путь: $localPath" "Info"
        Write-BgLog "Скачиваю видео: $filename" "Info"

        $out = & $adbPath pull $remotePath $localPath 2>&1
        Write-BgLog "Ответ pull: $out" "Info"

        if ($LASTEXITCODE -ne 0) {
            Write-BgLog "Ошибка pull: $out" "Error"
            return $null
        }

        Write-BgLog "Удаляю временный файл с ТВ: $remotePath" "Info"
        $rmOut = & $adbPath shell rm $remotePath 2>&1
        Write-BgLog "Ответ rm: $rmOut" "Info"

        # Проверяем, что файл удалён
        $checkAfter = & $adbPath shell ls $remotePath 2>&1
        if ($checkAfter -match "No such file") {
            Write-BgLog "Временный файл удалён с устройства" "Success"
        } else {
            Write-BgLog "Временный файл мог остаться на ТВ: $checkAfter" "Warning"
        }

        Write-BgLog "Видео сохранено: $localPath" "Success"
        return $localPath
    })

    $ps.AddArgument($window.Dispatcher)
    $ps.AddArgument($logBoxRef)
    $ps.AddArgument($adbPathRef)
    $ps.AddArgument($folder)
    $ps.AddArgument($DurationSeconds)

    $handle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $timer.Stop()
            try {
                $result = $ps.EndInvoke($handle)
                if ($result) {
                    $script:LastScreenshotPath = $result
                    if ($script:GalleryContainer) {
                        Update-ScreenshotGallery
                    }
                }
            } catch {
                Write-Log -Message "Ошибка записи: $_" -Level "Error"
            }
            $ps.Dispose()
        }
    })
    $timer.Start()
}