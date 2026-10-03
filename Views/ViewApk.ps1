# ============================================================================
#  Экран: Установка APK
# ============================================================================

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
            Set-ConfigValue -Key "LastApkFolder" -Value $script:ApkFolderPath
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

# ===== ПРЕОБРАЗОВАНИЕ ОШИБКИ ADB INSTALL В ЧИТАЕМЫЙ ВИД =====
function Convert-InstallError {
    param([string]$RawOutput)

    if (-not $RawOutput) { return "неизвестная ошибка (пустой вывод adb)" }

    # Нормализуем: убираем CLIXML-мусор от PowerShell и лишние переводы строк
    $clean = $RawOutput -replace "`r?`n", " "
    $clean = $clean -replace '#<\s*CLIXML.*?</\s*CLIXML>', ''
    $clean = $clean -replace 'System\.Management\.Automation\.RemoteException', ''
    $clean = ($clean -replace '\s+', ' ').Trim()

    # --- Ищем все INSTALL_* коды в тексте ---
    $installCode = $null
    if ($clean -match 'INSTALL_[A-Z_]+') {
        $installCode = $matches[0]
    }

    if ($installCode) {
        switch ($installCode) {
            "INSTALL_FAILED_VERSION_DOWNGRADE"             { return "версия APK ниже установленной. Нужен флаг -d или удаление старой версии (см. подсказку в логе)." }
            "INSTALL_FAILED_UPDATE_INCOMPATIBLE"            { return "подпись APK не совпадает с установленной. Удалите старую версию через «Управление пакетами»." }
            "INSTALL_FAILED_ALREADY_EXISTS"                 { return "приложение уже установлено" }
            "INSTALL_FAILED_INSUFFICIENT_STORAGE"           { return "недостаточно места на ТВ" }
            "INSTALL_FAILED_INVALID_APK"                    { return "повреждённый или невалидный APK" }
            "INSTALL_FAILED_INVALID_URI"                    { return "неверный путь к файлу" }
            "INSTALL_FAILED_CONFLICTING_PROVIDER"           { return "конфликт с другим приложением (общий ContentProvider)" }
            "INSTALL_FAILED_DUPLICATE_PACKAGE"              { return "пакет уже установлен под другим именем" }
            "INSTALL_FAILED_NO_MATCHING_ABIS"               { return "APK не подходит под архитектуру ТВ" }
            "INSTALL_FAILED_OLDER_SDK"                      { return "APK требует более старую версию Android" }
            "INSTALL_FAILED_NEWER_SDK"                      { return "APK требует более новую версию Android" }
            "INSTALL_FAILED_MISSING_SHARED_LIBRARY"         { return "APK требует отсутствующую библиотеку" }
            "INSTALL_FAILED_USER_RESTRICTED"                { return "установка запрещена политикой устройства" }
            "INSTALL_PARSE_FAILED_NO_CERTIFICATES"          { return "APK не подписан" }
            "INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES" { return "подписи разных APK одного пакета различаются" }
            "INSTALL_FAILED_DEXOPT"                         { return "ошибка оптимизации dex — APK повреждён" }
            default                                          { return "ошибка установки: $installCode" }
        }
    }

    # Если не нашли INSTALL_*, вернём хотя бы часть сообщения
    if ($clean.Length -gt 200) { $clean = $clean.Substring(0, 200) + "..." }
    return $clean
}

# ===== ФОНОВАЯ УСТАНОВКА APK =====
function Start-BackgroundApkInstall {
    param([array]$Files)

    Write-Log -Message "=== Запуск установки $($Files.Count) APK ===" -Level "Info"

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

        # --- Функция разбора ошибки ---
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
                    "INSTALL_FAILED_VERSION_DOWNGRADE"             { return "версия APK ниже установленной. Смотрите подсказку ниже." }
                    "INSTALL_FAILED_UPDATE_INCOMPATIBLE"           { return "подпись APK не совпадает с установленной. Смотрите подсказку ниже." }
                    "INSTALL_FAILED_ALREADY_EXISTS"                { return "приложение уже установлено" }
                    "INSTALL_FAILED_INSUFFICIENT_STORAGE"          { return "недостаточно места на ТВ" }
                    "INSTALL_FAILED_INVALID_APK"                   { return "повреждённый или невалидный APK" }
                    "INSTALL_FAILED_INVALID_URI"                   { return "неверный путь к файлу" }
                    "INSTALL_FAILED_CONFLICTING_PROVIDER"          { return "конфликт с другим приложением (общий ContentProvider)" }
                    "INSTALL_FAILED_DUPLICATE_PACKAGE"             { return "пакет уже установлен под другим именем" }
                    "INSTALL_FAILED_NO_MATCHING_ABIS"              { return "APK не подходит под архитектуру ТВ" }
                    "INSTALL_FAILED_OLDER_SDK"                     { return "APK требует более старую версию Android" }
                    "INSTALL_FAILED_NEWER_SDK"                     { return "APK требует более новую версию Android" }
                    "INSTALL_FAILED_MISSING_SHARED_LIBRARY"        { return "APK требует отсутствующую библиотеку" }
                    "INSTALL_FAILED_USER_RESTRICTED"               { return "установка запрещена политикой устройства" }
                    "INSTALL_PARSE_FAILED_NO_CERTIFICATES"         { return "APK не подписан" }
                    "INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES" { return "подписи разных APK одного пакета различаются" }
                    "INSTALL_FAILED_DEXOPT"                        { return "ошибка оптимизации dex — APK повреждён" }
                    default                                         { return "ошибка установки: $installCode" }
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

            Write-BgLog "[$num/$total] Установка: $($f.Name)" "Info"

            # -r — перезаписать
            # -g — выдать все разрешения
            # -d — разрешить downgrade (установка старой версии поверх новой)
            $out = & $adbPath install -r -g -d $f.FullName 2>&1
            $outText = ($out | Out-String).Trim()

            if ($outText -match "Success") {
                Write-BgLog "  OK: $($f.Name)" "Success"
                $success++
                $installedPaths += $f.FullName
            } else {
                $humanMsg = Convert-InstallError -RawOutput $outText
                Write-BgLog "  FAIL: $($f.Name) — $humanMsg" "Error"

                # --- Расширенные подсказки ---
                if ($outText -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
                    Write-BgLog "  ──────────────────────────────────────────────────" "Info"
                    Write-BgLog "  ПОДСКАЗКА: Android блокирует установку старой версии поверх новой." "Warning"
                    Write-BgLog "" "Info"
                    Write-BgLog "  Вариант 1 — Разрешить downgrade (уже применён флаг -d):" "Info"
                    Write-BgLog "    Текущий вызов: adb install -r -g -d <файл>" "Info"
                    Write-BgLog "    Если всё равно отказ — подписи APK различаются." "Info"
                    Write-BgLog "" "Info"
                    Write-BgLog "  Вариант 2 — Удалить старую версию и установить заново:" "Info"
                    Write-BgLog "    Через приложение:" "Info"
                    Write-BgLog "      1. Setup → Управление пакетами" "Info"
                    Write-BgLog "      2. Найдите установленный пакет (например, ru.more.play)" "Info"
                    Write-BgLog "      3. Нажмите «Удалить»" "Info"
                    Write-BgLog "      4. Вернитесь сюда и установите APK заново" "Info"
                    Write-BgLog "" "Info"
                    Write-BgLog "    Вручную через ADB (Сервис → Своя команда):" "Info"
                    Write-BgLog "      shell pm uninstall --user 0 <имя_пакета>" "Info"
                    Write-BgLog "      Пример: shell pm uninstall --user 0 ru.more.play" "Info"
                    Write-BgLog "  ──────────────────────────────────────────────────" "Info"
                }
                elseif ($outText -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
                    Write-BgLog "  ──────────────────────────────────────────────────" "Info"
                    Write-BgLog "  ПОДСКАЗКА: Установленный APK подписан другим ключом." "Warning"
                    Write-BgLog "" "Info"
                    Write-BgLog "  Решение — удалить старую версию и установить заново:" "Info"
                    Write-BgLog "    Через приложение:" "Info"
                    Write-BgLog "      1. Setup → Управление пакетами" "Info"
                    Write-BgLog "      2. Найдите установленный пакет" "Info"
                    Write-BgLog "      3. Нажмите «Удалить»" "Info"
                    Write-BgLog "      4. Вернитесь сюда и установите APK заново" "Info"
                    Write-BgLog "" "Info"
                    Write-BgLog "    Вручную через ADB (Сервис → Своя команда):" "Info"
                    Write-BgLog "      shell pm uninstall --user 0 <имя_пакета>" "Info"
                    Write-BgLog "  ──────────────────────────────────────────────────" "Info"
                }

                $failed++
            }
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