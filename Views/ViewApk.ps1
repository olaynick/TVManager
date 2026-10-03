# ============================================================================
#  Экран: Установка APK и Bundle (.apks / .xapk / .apkm)
# ============================================================================

function Show-ApkView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "40,30,40,30"

    $header = New-ViewHeader -Text "Установка приложений"
    $mainStack.Children.Add($header) | Out-Null

    $mainStack.Children.Add((New-ViewLabel -Text "Выберите папку с файлами .apk, .apks, .xapk или .apkm:")) | Out-Null

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
        $dlg.Description = "Выберите папку с APK или bundle-файлами"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:ApkFolderPath = $dlg.SelectedPath
            Set-ConfigValue -Key "LastApkFolder" -Value $script:ApkFolderPath
            $script:ApkFolderLabel.Text = $script:ApkFolderPath
            Load-ApkFiles -Folder $script:ApkFolderPath
        }
    })) | Out-Null

    $folderPanel.Children.Add((New-ViewButton -Text "Добавить файл" -Color "#9C27B0" -Margin "10,0,0,0" -OnClick {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "APK files (*.apk)|*.apk|Bundle files (*.apks;*.xapk;*.apkm)|*.apks;*.xapk;*.apkm|All supported (*.apk;*.apks;*.xapk;*.apkm)|*.apk;*.apks;*.xapk;*.apkm|All files (*.*)|*.*"
        $dlg.Title = "Выберите APK или bundle-файл"
        $dlg.Multiselect = $true
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $files = $dlg.FileNames
            if (-not $script:ApkExtraFiles) { $script:ApkExtraFiles = @() }
            foreach ($f in $files) {
                if ($script:ApkExtraFiles -notcontains $f) {
                    $script:ApkExtraFiles += $f
                }
            }
            Write-Log -Message "Добавлено файлов: $($files.Count)" -Level "Info"
            Switch-View -ViewName "Apk"
        }
    })) | Out-Null

    $mainStack.Children.Add($folderPanel) | Out-Null

    $script:ApkListContainer = New-Object System.Windows.Controls.StackPanel
    $script:ApkListContainer.Margin = "0,10,0,15"
    $mainStack.Children.Add($script:ApkListContainer) | Out-Null

    Load-ApkFiles -Folder $script:ApkFolderPath -RestoreSelection

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
            "Установить $($selected.Count) файлов?",
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
    Write-Log -Message "Экран установки приложений" -Level "Info"
}

function Load-ApkFiles {
    param(
        [string]$Folder,
        [switch]$RestoreSelection
    )

    $script:ApkListContainer.Children.Clear()
    $script:ApkCheckboxes = @()

    $allFiles = @()

    # --- Файлы из папки ---
    if ($Folder -and (Test-Path $Folder)) {
        $allFiles += Get-ChildItem -Path $Folder -File | Where-Object {
            $_.Extension.ToLower() -in @(".apk", ".apks", ".xapk", ".apkm")
        }
    }

    # --- Файлы, добавленные через "Добавить файл" ---
    if ($script:ApkExtraFiles -and $script:ApkExtraFiles.Count -gt 0) {
        foreach ($f in $script:ApkExtraFiles) {
            if (Test-Path $f) {
                $allFiles += Get-Item $f
            }
        }
    }

    # --- Уникальные + сортировка ---
    $allFiles = $allFiles | Sort-Object FullName -Unique | Sort-Object Name

    if ($allFiles.Count -eq 0) {
        $script:ApkListContainer.Children.Add((New-ViewLabel -Text "Не найдено файлов .apk / .apks / .xapk / .apkm.")) | Out-Null
        return
    }

    if (-not $RestoreSelection) {
        Write-Log -Message "Найдено файлов: $($allFiles.Count)" -Level "Info"
    }

    foreach ($f in $allFiles) {
        $sizeMB = [math]::Round($f.Length / 1MB, 2)
        $isInstalled = $script:ApkInstalledFiles -contains $f.FullName
        $isBundle = Test-IsApkBundle -Path $f.FullName

        # Тип для отображения
        $typeLabel = ""
        $typeColor = "#2D2D30"
        if ($f.Extension.ToLower() -eq ".apk") {
            $typeLabel = "[APK]"
        } else {
            $typeLabel = "[BUNDLE]"
            $typeColor = "#9C27B0"
        }

        $chk = New-Object System.Windows.Controls.CheckBox
        $chk.Style = $window.Resources["MiuiCheckBox"]

        if ($isInstalled) {
            $chk.Content = "$typeLabel  $($f.Name)  ($sizeMB МБ)  — Установлено"
            $chk.Foreground = [System.Windows.Media.Brushes]::Gray
            $chk.IsEnabled = $false
            $chk.IsChecked = $false
        } else {
            $chk.Content = "$typeLabel  $($f.Name)  ($sizeMB МБ)"
            $chk.Tag = $f

            if ($isBundle) {
                $chk.Foreground = New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString($typeColor)
                )
                $chk.ToolTip = "Bundle-файл: содержит базовый APK + split'ы. Устанавливается через adb install-multiple."
            }

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

# ===== ПРЕОБРАЗОВАНИЕ ОШИБКИ =====
function Convert-InstallError {
    param([string]$RawOutput)

    if (-not $RawOutput) { return "неизвестная ошибка (пустой вывод adb)" }

    $clean = $RawOutput -replace "`r?`n", " "
    $clean = $clean -replace '#<\s*CLIXML.*?</\s*CLIXML>', ''
    $clean = $clean -replace 'System\.Management\.Automation\.RemoteException', ''
    $clean = ($clean -replace '\s+', ' ').Trim()

    $installCode = $null
    if ($clean -match 'INSTALL_[A-Z_]+') {
        $installCode = $matches[0]
    }

    if ($installCode) {
        switch ($installCode) {
            "INSTALL_FAILED_VERSION_DOWNGRADE"             { return "версия ниже установленной. Смотрите подсказку ниже." }
            "INSTALL_FAILED_UPDATE_INCOMPATIBLE"           { return "подпись не совпадает с установленной. Смотрите подсказку ниже." }
            "INSTALL_FAILED_ALREADY_EXISTS"                { return "приложение уже установлено" }
            "INSTALL_FAILED_INSUFFICIENT_STORAGE"          { return "недостаточно места на ТВ" }
            "INSTALL_FAILED_INVALID_APK"                   { return "повреждённый или невалидный APK" }
            "INSTALL_FAILED_INVALID_URI"                   { return "неверный путь к файлу" }
            "INSTALL_FAILED_CONFLICTING_PROVIDER"          { return "конфликт с другим приложением" }
            "INSTALL_FAILED_DUPLICATE_PACKAGE"             { return "пакет уже установлен под другим именем" }
            "INSTALL_FAILED_NO_MATCHING_ABIS"              { return "APK не подходит под архитектуру ТВ" }
            "INSTALL_FAILED_OLDER_SDK"                     { return "APK требует более старую версию Android" }
            "INSTALL_FAILED_NEWER_SDK"                     { return "APK требует более новую версию Android" }
            "INSTALL_FAILED_MISSING_SHARED_LIBRARY"        { return "APK требует отсутствующую библиотеку" }
            "INSTALL_FAILED_USER_RESTRICTED"               { return "установка запрещена политикой устройства" }
            "INSTALL_PARSE_FAILED_NO_CERTIFICATES"         { return "APK не подписан" }
            "INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES" { return "подписи APK различаются" }
            "INSTALL_FAILED_DEXOPT"                        { return "ошибка оптимизации dex" }
            "INSTALL_FAILED_MISSING_SPLIT"                 { return "не хватает split-APK — bundle повреждён" }
            default                                         { return "ошибка установки: $installCode" }
        }
    }

    if ($clean.Length -gt 200) { $clean = $clean.Substring(0, 200) + "..." }
    return $clean
}

# ===== ФОНОВАЯ УСТАНОВКА =====
function Start-BackgroundApkInstall {
    param([array]$Files)

    Write-Log -Message "=== Запуск установки $($Files.Count) файлов ===" -Level "Info"

    $script:ApkInstallInProgress = $true

    $logBoxRef  = $script:LogBox
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

        function Convert-InstallError {
            param([string]$RawOutput)
            if (-not $RawOutput) { return "неизвестная ошибка" }
            $clean = $RawOutput -replace "`r?`n", " "
            $clean = $clean -replace '#<\s*CLIXML.*?</\s*CLIXML>', ''
            $clean = $clean -replace 'System\.Management\.Automation\.RemoteException', ''
            $clean = ($clean -replace '\s+', ' ').Trim()
            if ($clean -match 'INSTALL_[A-Z_]+') {
                $code = $matches[0]
                switch ($code) {
                    "INSTALL_FAILED_VERSION_DOWNGRADE"   { return "версия ниже установленной" }
                    "INSTALL_FAILED_UPDATE_INCOMPATIBLE" { return "подпись не совпадает" }
                    "INSTALL_FAILED_MISSING_SPLIT"       { return "не хватает split-APK" }
                    "INSTALL_FAILED_INVALID_APK"         { return "повреждённый APK" }
                    "INSTALL_FAILED_NO_MATCHING_ABIS"    { return "APK не подходит под архитектуру" }
                    default                              { return "ошибка: $code" }
                }
            }
            if ($clean.Length -gt 200) { $clean = $clean.Substring(0, 200) + "..." }
            return $clean
        }

        $success        = 0
        $failed         = 0
        $installedPaths = @()
        $total          = $files.Count

        for ($i = 0; $i -lt $total; $i++) {
            $f = $files[$i]
            $num = $i + 1

            $ext = [System.IO.Path]::GetExtension($f.FullName).ToLower()
            $isBundle = ($ext -in @(".apks", ".xapk", ".apkm"))

            if ($isBundle) {
                Write-BgLog "[$num/$total] Bundle: $($f.Name) — распаковка и установка" "Info"
            } else {
                Write-BgLog "[$num/$total] Установка: $($f.Name)" "Info"
            }

            $outText = ""
            $isSuccess = $false

            if ($isBundle) {
                # --- Bundle: распаковка + install-multiple ---
                $tempDir = Join-Path $env:TEMP "TVManager_Apk_$(Get-Random)"
                try {
                    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($f.FullName, $tempDir)

                    $allApks = Get-ChildItem -Path $tempDir -Filter "*.apk" -File -Recurse | Select-Object -ExpandProperty FullName

                    if (-not $allApks -or $allApks.Count -eq 0) {
                        Write-BgLog "  В архиве нет APK" "Error"
                        $failed++
                        continue
                    }

                    # Базовый APK первым
                    $baseApk = $allApks | Where-Object { $_ -match '\\base\.apk$' } | Select-Object -First 1
                    if (-not $baseApk) {
                        $baseApk = $allApks | Where-Object { (Split-Path $_ -Leaf) -notmatch '^split' } | Select-Object -First 1
                    }
                    $splits = $allApks | Where-Object { $_ -ne $baseApk }
                    $apkList = @($baseApk) + @($splits)

                    Write-BgLog "  Базовый + $($splits.Count) split'ов" "Info"

                    $adbArgs = @("install-multiple", "-r", "-g", "-d") + $apkList
                    $out = & $adbPath @adbArgs 2>&1
                    $outText = ($out | Out-String).Trim()

                    if ($outText -match "Success") {
                        $isSuccess = $true
                    }
                } catch {
                    Write-BgLog "  Ошибка bundle: $_" "Error"
                } finally {
                    if ($tempDir -and (Test-Path $tempDir)) {
                        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                # --- Обычный APK ---
                $out = & $adbPath install -r -g -d $f.FullName 2>&1
                $outText = ($out | Out-String).Trim()
                if ($outText -match "Success") { $isSuccess = $true }
            }

            if ($isSuccess) {
                Write-BgLog "  OK: $($f.Name)" "Success"
                $success++
                $installedPaths += $f.FullName
            } else {
                $humanMsg = Convert-InstallError -RawOutput $outText
                Write-BgLog "  FAIL: $($f.Name) — $humanMsg" "Error"

                if ($outText -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
                    Write-BgLog "  ──────────────────────────────────────────────" "Info"
                    Write-BgLog "  ПОДСКАЗКА: Android блокирует старую версию поверх новой." "Warning"
                    Write-BgLog "  Решение — удалить старую версию и установить заново:" "Info"
                    Write-BgLog "    1. Setup → Управление пакетами" "Info"
                    Write-BgLog "    2. Найти пакет и удалить" "Info"
                    Write-BgLog "    3. Вернуться сюда и установить заново" "Info"
                    Write-BgLog "  Или вручную (Сервис → Своя команда):" "Info"
                    Write-BgLog "    shell pm uninstall --user 0 <имя_пакета>" "Info"
                    Write-BgLog "  ──────────────────────────────────────────────" "Info"
                }
                elseif ($outText -match 'INSTALL_FAILED_MISSING_SPLIT') {
                    Write-BgLog "  ──────────────────────────────────────────────" "Info"
                    Write-BgLog "  ПОДСКАЗКА: bundle повреждён — не хватает split-APK." "Warning"
                    Write-BgLog "  Скачайте .apks / .xapk заново из надёжного источника." "Info"
                    Write-BgLog "  ──────────────────────────────────────────────" "Info"
                }

                $failed++
            }
            Start-Sleep -Milliseconds 200
        }

        Write-BgLog "=== Готово: успешно $success, ошибок $failed из $total ===" "Success"
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
                if ($result -and $result.InstalledPaths) {
                    foreach ($p in $result.InstalledPaths) {
                        if ($script:ApkInstalledFiles -notcontains $p) {
                            $script:ApkInstalledFiles += $p
                        }
                        $script:ApkSelectedFiles = $script:ApkSelectedFiles | Where-Object { $_ -ne $p }
                    }
                }
            } catch {
                Write-Log -Message "Ошибка установки: $_" -Level "Error"
            }

            $script:ApkPS.Dispose()

            $script:ApkInstallInProgress = $false

            Switch-View -ViewName "Apk"
        }
    })
    $script:ApkTimer.Start()
}

# ===== СПИСКИ ПАКЕТОВ =====
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