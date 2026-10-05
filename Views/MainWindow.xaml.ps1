# ==== ПЕРЕКЛЮЧЕНИЕ ЭКРАНОВ ====
function Switch-View {
    param([string]$ViewName)

    # ============================================================
    #  СБРОС ЛОГКАТ-ОБРАБОТЧИКОВ
    # ============================================================
    if ($script:LogcatClosingHandler) {
        try { $window.Remove_Closing($script:LogcatClosingHandler) } catch { }
        $script:LogcatClosingHandler = $null
    }
    $script:LogcatBackBtn = $null

    # ============================================================
    #  АВТООЧИСТКА RUNSPACE ПРИ ПЕРЕКЛЮЧЕНИИ ЭКРАНОВ
    #  HTTP-сервер и Monitoring продолжают работать в фоне.
    # ============================================================
    try {
        if (Get-Command Stop-AllScreenRunspaces -ErrorAction SilentlyContinue) {
            Stop-AllScreenRunspaces -Except @("http", "monitoring")
        }
    } catch {
        Write-Log -Message "Ошибка автоочистки Runspace: $_" -Level "Warning"
    }

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
        "Snapshots"    { Show-SnapshotsView }
        "Logcat"       { Show-LogcatView }
        "Scrcpy"       { Show-ScrcpyView }
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
        "Monitoring"   { Show-MonitoringView }
        default        { Write-Log -Message "Неизвестный экран: $ViewName" -Level "Warning" }
    }
    Update-StatusBar
}

function Update-StatusBar {
    param([switch]$Silent)

    if ($global:AppClosing) { return }
    if (-not $global:statusText) { return }

    $previousState = $script:connected
    $previousIp    = $script:deviceIp

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

            # Обновляем имя устройства при смене IP
            if (-not $script:DeviceModelName -or $script:DeviceModelNameIp -ne $script:deviceIp) {
                $script:DeviceModelName = ""
                $deviceName = Get-DeviceDisplayName
                $script:DeviceModelNameIp = $script:deviceIp
            } else {
                $deviceName = $script:DeviceModelName
            }

            if ($deviceName) {
                $global:statusText.Text = "● Подключено к $($script:deviceIp) ($deviceName)"
            } else {
                $global:statusText.Text = "● Подключено к $($script:deviceIp)"
            }
            $global:statusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        } else {
            $script:connected = $true
            $global:statusText.Text = "● Подключено"
            $global:statusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        }
    } else {
        $script:connected = $false
        $global:statusText.Text = "● Не подключено"
        $global:statusText.Foreground = [System.Windows.Media.Brushes]::LightCoral

        $script:DeviceModelName = ""
        $script:DeviceModelNameIp = ""
    }

    $stateChanged = ($previousState -ne $script:connected) -or ($previousIp -ne $script:deviceIp)

    if ($stateChanged) {
        if ($script:connected) {
            Write-Log -Message "Связь с ТВ установлена ($($script:deviceIp))" -Level "Success"
        } else {
            $ipInfo = if ($previousIp) { " (был $previousIp)" } else { "" }
            Write-Log -Message "Связь с ТВ потеряна$ipInfo" -Level "Warning"
        }

        if ($script:CurrentView -and
            $script:CurrentView -ne "Main" -and
            $script:CurrentView -ne "Logcat") {
            try {
                Switch-View -ViewName $script:CurrentView
            } catch {
                Write-Log -Message "Не удалось перерисовать экран $($script:CurrentView): $_" -Level "Warning"
            }
        }
    }
}

function Start-StatusWatcher {
    if ($script:StatusTimer) {
        $script:StatusTimer.Stop()
        $script:StatusTimer = $null
    }

    $script:StatusTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:StatusTimer.Interval = [TimeSpan]::FromSeconds(5)
    $script:StatusTimer.Add_Tick({
        try {
            if ($global:AppClosing) {
                $script:StatusTimer.Stop()
                return
            }
            Update-StatusBar -Silent
        } catch { }
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