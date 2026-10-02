# ==== ПЕРЕКЛЮЧЕНИЕ ЭКРАНОВ ====
function Switch-View {
    param([string]$ViewName)
    $contentGrid.Children.Clear()

    Hide-BottomBar

    switch ($ViewName) {
        "Main"       { Show-MainView }
        "Setup"      { Show-SetupView }
        "Cleanup"    { Show-CleanupView }
        "Apk"        { Show-ApkView }
        "Files"      { Show-FilesView }
        "Remote"     { Show-RemoteView }
        "Animation"  { Show-AnimationView }
        "Settings"   { Show-SettingsView }
        "Screenshot" { Show-ScreenshotView }
        "Info"       { Show-InfoView }
        "Power"      { Show-PowerView }
        "Rollback"   { Show-RollbackView }
        "DisabledApps" { Show-DisabledAppsView }
        "Profiles"     { Show-ProfilesView }
        "Logcat"       { Show-LogcatView }
        "Service"      { Show-ServiceView }
    }
    Update-StatusBar
}

function Update-StatusBar {
    # Проверяем реальное состояние ТВ
    $isConnected = Test-TvConnected

    if ($isConnected -and $script:deviceIp) {
        $statusText.Text = "● Подключено к $($script:deviceIp)"
        $statusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $script:connected = $true
    } else {
        # Пробуем определить IP из adb devices
        $devices = & $script:adbPath devices 2>&1
        $deviceIp = ""
        foreach ($line in $devices) {
            if ($line -match '^(\S+):5555\s+device$') {
                $deviceIp = $matches[1]
                break
            }
        }

        if ($deviceIp) {
            $script:deviceIp = $deviceIp
            $script:connected = $true
            $statusText.Text = "● Подключено к $deviceIp"
            $statusText.Foreground = [System.Windows.Media.Brushes]::LightGreen
        } else {
            $script:connected = $false
            $script:deviceIp = ""
            $statusText.Text = "● Не подключено"
            $statusText.Foreground = [System.Windows.Media.Brushes]::LightCoral
        }
    }
}

# ==== ЗАПУСК ====
Update-StatusBar
Switch-View -ViewName "Main"
Write-Log -Message "Приложение запущено" -Level "Info"