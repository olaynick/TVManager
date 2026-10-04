# ==== ПЕРЕКЛЮЧЕНИЕ ЭКРАНОВ ====
function Switch-View {
    param([string]$ViewName)

    # Сохраняем текущий экран
    $script:CurrentView = $ViewName

    $contentGrid.Children.Clear()

    Hide-BottomBar

    switch ($ViewName) {
        "Main"         { Show-MainView }
        "Setup"        { Show-SetupView }
        "Cleanup"      { Show-CleanupView }
        "Apk"          { Show-ApkView }
        "Files"        { Show-FilesView }
        "Remote"       { Show-RemoteView }
        "Animation"    { Show-AnimationView }
        "Settings"     { Show-SettingsView }
        "Screenshot"   { Show-ScreenshotView }
        "Info"         { Show-InfoView }
        "Power"        { Show-PowerView }
        "Rollback"     { Show-RollbackView }
        "DisabledApps" { Show-DisabledAppsView }
        "Profiles"     { Show-ProfilesView }
        "Logcat"       { Show-LogcatView }
        "Service"      { Show-ServiceView }
        "Wifi"         { Show-WifiView }
        "Display"      { Show-DisplayView }
        "Presets"      { Show-PresetsView }
        "Processes"    { Show-ProcessesView }
        "Integrity"    { Show-IntegrityView }
        "Scenarios"    { Show-ScenariosView }
        "Thermal"      { Show-ThermalView }
        "Autostart"    { Show-AutostartView }
        "Permissions"  { Show-PermissionsView }
        "Apps"         { Show-AppsView }
        "Bluetooth"    { Show-BluetoothView }
        "Traffic"      { Show-TrafficView }
        "HttpServer"   { Show-HttpServerView }
        default        { Write-Log -Message "Неизвестный экран: $ViewName" -Level "Warning" }
    }
    Update-StatusBar
}

function Update-StatusBar {
    param([switch]$Silent)

    $previousState = $script:connected
    $previousIp    = $script:deviceIp

    # Проверяем реальное состояние ТВ
    $isConnected = $false
    try {
        $isConnected = Test-TvConnected
    } catch {
        $isConnected = $false
    }

    if ($isConnected) {
        if (-not $script:deviceIp) {
            $devices = & $script:adbPath devices 2>&1
            foreach ($line in $devices) {
                if ($line -match '^(\S+):5555\s+device$') {
                    $script:deviceIp = $matches[1]
                    break
                }
            }
        }

        if ($script:deviceIp) {
            $script:connected = $true
            $statusText.Text = "● Подключено к $($script:deviceIp)"
            $statusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        } else {
            $script:connected = $true
            $statusText.Text = "● Подключено"
            $statusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        }
    } else {
        $script:connected = $false
        $statusText.Text = "● Не подключено"
        $statusText.Foreground = [System.Windows.Media.Brushes]::LightCoral
    }

    # --- Логируем смену состояния ---
    $stateChanged = ($previousState -ne $script:connected) -or ($previousIp -ne $script:deviceIp)

    if ($stateChanged) {
        if ($script:connected) {
            Write-Log -Message "Связь с ТВ установлена ($($script:deviceIp))" -Level "Success"
        } else {
            $ipInfo = if ($previousIp) { " (был $previousIp)" } else { "" }
            Write-Log -Message "Связь с ТВ потеряна$ipInfo" -Level "Warning"
        }

        # ===== ПЕРЕРИСОВКА ЭКРАНА ПРИ СМЕНЕ СОСТОЯНИЯ =====
        # Не перерисовываем Main — он не зависит от подключения
        # Не перерисовываем Logcat — он может быть запущен
        if ($script:CurrentView -and $script:CurrentView -ne "Main" -and $script:CurrentView -ne "Logcat") {
            try {
                Switch-View -ViewName $script:CurrentView
            } catch {
                Write-Log -Message "Не удалось перерисовать экран $($script:CurrentView): $_" -Level "Warning"
            }
        }
    }
}

# ==== АВТО-ОБНОВЛЕНИЕ СТАТУСА ====
function Start-StatusWatcher {
    if ($script:StatusTimer) {
        $script:StatusTimer.Stop()
        $script:StatusTimer = $null
    }

    $script:StatusTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:StatusTimer.Interval = [TimeSpan]::FromSeconds(5)
    $script:StatusTimer.Add_Tick({
        try {
            Update-StatusBar -Silent
        } catch {
            # тихо игнорируем ошибки таймера — он не должен ронять UI
        }
    })
    $script:StatusTimer.Start()
    Write-Log -Message "Авто-обновление статуса запущено (каждые 5 сек)" -Level "Info"
}

function Stop-StatusWatcher {
    if ($script:StatusTimer) {
        $script:StatusTimer.Stop()
        $script:StatusTimer = $null
    }
}

# ==== ЗАПУСК ====
Update-StatusBar
Switch-View -ViewName "Main"
Start-StatusWatcher
Write-Log -Message "Приложение запущено" -Level "Info"