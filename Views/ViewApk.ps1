function Show-ApkView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "40,30,40,30"

    $header = New-ViewHeader -Text "Установка APK"
    $mainStack.Children.Add($header) | Out-Null

    $mainStack.Children.Add((New-ViewLabel -Text "Выберите папку с APK-файлами:")) | Out-Null

    $folderPanel = New-Object System.Windows.Controls.StackPanel
    $folderPanel.Orientation = "Horizontal"
    $folderPanel.Margin = "0,0,0,15"

    $script:ApkFolderLabel = New-Object System.Windows.Controls.TextBlock
    $script:ApkFolderLabel.Text = if ($script:ApkFolderPath) { $script:ApkFolderPath } else { "Папка не выбрана" }
    $script:ApkFolderLabel.FontSize = 12
    $script:ApkFolderLabel.Foreground = "#96969B"
    $script:ApkFolderLabel.VerticalAlignment = "Center"
    $script:ApkFolderLabel.Margin = "0,0,15,0"
    $folderPanel.Children.Add($script:ApkFolderLabel) | Out-Null

    $folderPanel.Children.Add((New-ViewButton -Text "Выбрать папку" -Color "#4A90E2" -OnClick {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Выберите папку с APK"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:ApkFolderPath = $dlg.SelectedPath
            $script:ApkFolderLabel.Text = $script:ApkFolderPath
            Load-ApkFiles -Folder $script:ApkFolderPath
        }
    })) | Out-Null

    $mainStack.Children.Add($folderPanel) | Out-Null

    $script:ApkListContainer = New-Object System.Windows.Controls.StackPanel
    $script:ApkListContainer.Margin = "0,10,0,15"
    $mainStack.Children.Add($script:ApkListContainer) | Out-Null

    if ($script:ApkFolderPath -and (Test-Path $script:ApkFolderPath)) {
        Load-ApkFiles -Folder $script:ApkFolderPath -RestoreSelection
    }

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.Margin = "0,15,0,0"

    $btnPanel.Children.Add((New-ViewButton -Text "Выбрать всё" -Color "#64B5F6" -OnClick {
        if ($script:ApkCheckboxes) {
            foreach ($chk in $script:ApkCheckboxes) {
                if ($chk.IsEnabled -eq $true) {
                    $chk.IsChecked = $true
                }
            }
        }
    })) | Out-Null

    $btnPanel.Children.Add((New-ViewButton -Text "Снять всё" -Color "#FFB74D" -OnClick {
        if ($script:ApkCheckboxes) {
            foreach ($chk in $script:ApkCheckboxes) { $chk.IsChecked = $false }
        }
    })) | Out-Null

    $btnText = if ($script:ApkInstallInProgress) { "Установка..." } else { "Установить выбранные" }
    $script:ApkBtnInstall = New-ViewButton -Text $btnText -Color "#66BB6A" -OnClick {
        $selected = @()
        if ($script:ApkCheckboxes) {
            foreach ($chk in $script:ApkCheckboxes) {
                if ($chk.IsChecked -eq $true -and $chk.IsEnabled -eq $true) {
                    $selected += $chk.Tag
                }
            }
        }

        if ($selected.Count -eq 0) {
            Write-Log -Message "Ничего не выбрано" -Level "Warning"
            return
        }

        $confirm = [System.Windows.MessageBox]::Show(
            "Установить $($selected.Count) APK?",
            "Подтверждение",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)

        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

        Start-BackgroundApkInstall -Files $selected
    }

    if ($script:ApkInstallInProgress) {
        $script:ApkBtnInstall.IsEnabled = $false
    }

    $btnPanel.Children.Add($script:ApkBtnInstall) | Out-Null

    $mainStack.Children.Add($btnPanel) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null
    Write-Log -Message "Экран установки APK" -Level "Info"
}

function Load-ApkFiles {
    param(
        [string]$Folder,
        [switch]$RestoreSelection
    )

    $script:ApkListContainer.Children.Clear()
    $script:ApkCheckboxes = @()

    $apkFiles = Get-ChildItem -Path $Folder -Filter *.apk -File | Sort-Object Name
    if ($apkFiles.Count -eq 0) {
        $script:ApkListContainer.Children.Add((New-ViewLabel -Text "В папке нет APK-файлов.")) | Out-Null
        return
    }

    if (-not $RestoreSelection) {
        Write-Log -Message "Найдено APK: $($apkFiles.Count)" -Level "Info"
    }

    foreach ($f in $apkFiles) {
        $sizeMB = [math]::Round($f.Length / 1MB, 2)
        $isInstalled = $script:ApkInstalledFiles -contains $f.FullName

        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]

        if ($isInstalled) {
            $chk.Content = "$($f.Name)  ($sizeMB МБ)  — Установлено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
            $chk.IsChecked = $false
        } else {
            $chk.Content = "$($f.Name)  ($sizeMB МБ)"
            $chk.Tag = $f

            if ($RestoreSelection -and $script:ApkSelectedFiles -contains $f.FullName) {
                $chk.IsChecked = $true
            }

            $chk.Add_Click({
                $file = $this.Tag.FullName
                if ($this.IsChecked -eq $true) {
                    if ($script:ApkSelectedFiles -notcontains $file) {
                        $script:ApkSelectedFiles += $file
                    }
                } else {
                    $script:ApkSelectedFiles = $script:ApkSelectedFiles | Where-Object { $_ -ne $file }
                }
            })
        }

        $script:ApkListContainer.Children.Add($chk) | Out-Null
        $script:ApkCheckboxes += $chk
    }
}

# ===== ФОНОВАЯ УСТАНОВКА APK =====
function Start-BackgroundApkInstall {
    param([array]$Files)

    Write-Log -Message "=== Запуск установки $($Files.Count) APK ===" -Level "Info"

    $script:ApkInstallInProgress = $true

    $logBoxRef = $script:LogBox
    $adbPathRef = $script:adbPath

    if ($script:ApkBtnInstall) {
        $script:ApkBtnInstall.IsEnabled = $false
        $script:ApkBtnInstall.Content = "Установка..."
    }

    $script:ApkRunspace = [runspacefactory]::CreateRunspace()
    $script:ApkRunspace.ApartmentState = "STA"
    $script:ApkRunspace.ThreadOptions = "ReuseThread"
    $script:ApkRunspace.Open()

    $script:ApkPS = [powershell]::Create()
    $script:ApkPS.Runspace = $script:ApkRunspace

    $script:ApkPS.AddScript({
        param($dispatcher, $logBox, $adbPath, $files)

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

        $success = 0
        $failed = 0
        $installedPaths = @()
        $i = 1
        $total = $files.Count

        foreach ($f in $files) {
            Write-BgLog "[$i/$total] Установка: $($f.Name)" "Info"

            $out = & $adbPath install -r -g $f.FullName 2>&1

            if ($out -match "Success") {
                Write-BgLog "  OK: $($f.Name)" "Success"
                $success++
                $installedPaths += $f.FullName
            } else {
                Write-BgLog "  FAIL: $($f.Name) — $out" "Error"
                $failed++
            }
            $i++
            Start-Sleep -Milliseconds 200
        }

        Write-BgLog "=== Установка завершена: успешно $success, ошибок $failed из $total ===" "Success"
        return @{ Success = $success; Failed = $failed; Total = $total; InstalledPaths = $installedPaths }
    })

    $script:ApkPS.AddArgument($window.Dispatcher)
    $script:ApkPS.AddArgument($logBoxRef)
    $script:ApkPS.AddArgument($adbPathRef)
    $script:ApkPS.AddArgument($Files)

    $script:ApkHandle = $script:ApkPS.BeginInvoke()

    $script:ApkTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ApkTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $script:ApkTimer.Add_Tick({
        if ($script:ApkHandle.IsCompleted) {
            $script:ApkTimer.Stop()

            try {
                $result = $script:ApkPS.EndInvoke($script:ApkHandle)
                # Запоминаем установленные файлы ДО перерисовки
                if ($result -and $result.InstalledPaths) {
                    foreach ($p in $result.InstalledPaths) {
                        if ($script:ApkInstalledFiles -notcontains $p) {
                            $script:ApkInstalledFiles += $p
                        }
                        # Убираем из выбранных
                        $script:ApkSelectedFiles = $script:ApkSelectedFiles | Where-Object { $_ -ne $p }
                    }
                }
            } catch {
                Write-Log -Message "Ошибка установки: $_" -Level "Error"
            }

            $script:ApkPS.Dispose()

            # Снимаем флаг
            $script:ApkInstallInProgress = $false

            # Перерисовываем экран
            Switch-View -ViewName "Apk"
        }
    })
    $script:ApkTimer.Start()
}

# ===== ПОЛУЧЕНИЕ СПИСКА УСТАНОВЛЕННЫХ ПАКЕТОВ =====
function Get-InstalledPackagesSet {
    $out = & $script:adbPath shell pm list packages 2>&1
    $set = @{}
    foreach ($line in $out) {
        if ($line -match '^package:(.+)$') {
            $set[$matches[1].Trim()] = $true
        }
    }
    return $set
}

# ===== ПОЛУЧЕНИЕ СПИСКА ОТКЛЮЧЁННЫХ ПАКЕТОВ =====
function Get-DisabledPackagesSet {
    $out = & $script:adbPath shell pm list packages -d 2>&1
    $set = @{}
    foreach ($line in $out) {
        if ($line -match '^package:(.+)$') {
            $set[$matches[1].Trim()] = $true
        }
    }
    return $set
}