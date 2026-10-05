#Requires -Version 5.1
# ============================================================================
#  TVManagerTCL — точка входа
# ============================================================================

# ---------------------------------------------------------------------------
#  ВЕРСИЯ ПРИЛОЖЕНИЯ
# ---------------------------------------------------------------------------
$script:AppVersion = "0.0.10"
$global:AppVersion  = $script:AppVersion

# ---------------------------------------------------------------------------
#  0. Глобальный флаг завершения (используется всеми таймерами и UI)
# ---------------------------------------------------------------------------
$global:AppClosing = $false

# ---------------------------------------------------------------------------
#  1. Сборки WPF
# ---------------------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ---------------------------------------------------------------------------
#  2. Определяем корень приложения
#     (работает и из .ps1, и из .exe после PS2EXE)
# ---------------------------------------------------------------------------
if ($MyInvocation.MyCommand.Path -and (Test-Path $MyInvocation.MyCommand.Path)) {
    $script:AppRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
} else {
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $script:AppRoot = Split-Path $exePath -Parent
    } catch {
        $script:AppRoot = $PWD.Path
    }
}

# ---------------------------------------------------------------------------
#  3. Модули (порядок важен!)
# ---------------------------------------------------------------------------
. "$script:AppRoot\Modules\Config.ps1"           # списки пакетов, пути
. "$script:AppRoot\Modules\CommandValidator.ps1" # проверка критических пакетов и команд
. "$script:AppRoot\Modules\AdbHelper.ps1"        # ADB-команды
. "$script:AppRoot\Modules\ScrcpyHelper.ps1" 
. "$script:AppRoot\Modules\AdbKeyboard.ps1"      # ADBKeyboard
. "$script:AppRoot\Modules\NetworkScanner.ps1"   # сканер сети
. "$script:AppRoot\Modules\ChangeLogger.ps1"     # откат изменений
. "$script:AppRoot\Modules\GuiHelper.ps1"        # логгер + тема
. "$script:AppRoot\Modules\AppConfig.ps1"        # config.json + профили
. "$script:AppRoot\Modules\SnapshotHelper.ps1"
. "$script:AppRoot\Modules\DeviceDump.ps1"       # экспорт дампа
. "$script:AppRoot\Modules\ScenarioEngine.ps1"   # пакетный режим (сценарии)
. "$script:AppRoot\Modules\AppOpsHelper.ps1"
. "$script:AppRoot\Modules\ThermalHelper.ps1"
. "$script:AppRoot\Modules\BluetoothHelper.ps1"
. "$script:AppRoot\Modules\TrafficHelper.ps1"
. "$script:AppRoot\Modules\HttpServer.ps1"
. "$script:AppRoot\Modules\PermissionsHelper.ps1"
. "$script:AppRoot\Modules\AppsHelper.ps1"
. "$script:AppRoot\Modules\MonitoringHelper.ps1"

# ---------------------------------------------------------------------------
#  4. Состояние
# ---------------------------------------------------------------------------
. "$script:AppRoot\Views\ViewState.ps1"

# ---------------------------------------------------------------------------
#  5. Загрузка XAML
# ---------------------------------------------------------------------------
try {
    [xml]$xaml = Get-Content -Raw -Path "$script:AppRoot\Views\MainWindow.xaml"
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.Windows.MessageBox]::Show(
        "Не удалось загрузить MainWindow.xaml:`n`n$_",
        "Ошибка запуска",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    exit 1
}

# Делаем окно глобально доступным для UI-хелперов и вьюх
$global:window = $window

# ---------------------------------------------------------------------------
#  6. Привязка элементов из XAML
# ---------------------------------------------------------------------------
$contentGrid = $window.FindName("ContentGrid")
$statusText  = $window.FindName("StatusText")
$logBox      = $window.FindName("LogBox")
$script:BottomBar        = $window.FindName("BottomBar")
$script:BottomBarContent = $window.FindName("BottomBarContent")

# Прогресс-бар (если есть в XAML)
$script:BottomBarProgress     = $window.FindName("BottomBarProgress")
$script:BottomBarProgressText = $window.FindName("BottomBarProgressText")

# HTTP-статус в статус-баре (справа)
$script:HttpStatusText = $window.FindName("HttpStatusText")

# Делаем contentGrid, statusText и HttpStatusText доступными из вьюх
$global:contentGrid    = $contentGrid
$global:statusText     = $statusText
$global:HttpStatusText = $script:HttpStatusText

Set-LogBox -Box $logBox

# ---------------------------------------------------------------------------
#  7. Конфиг приложения + сценарии
# ---------------------------------------------------------------------------
Load-AppConfig
Load-Scenarios

# Однократная миграция старых профилей в снимки
try {
    $migrated = Migrate-LegacyProfiles
    if ($migrated -gt 0) {
        Write-Log -Message "Мигрировано старых профилей: $migrated" -Level "Success"
    }
} catch {
    Write-Log -Message "Ошибка миграции профилей: $_" -Level "Warning"
}

# ---------------------------------------------------------------------------
#  8. UI-хелперы (после Load-AppConfig, т.к. некоторые хелперы читают конфиг)
# ---------------------------------------------------------------------------
. "$script:AppRoot\Views\ViewHelpers.ps1"

# ---------------------------------------------------------------------------
#  9. Вьюхи
# ---------------------------------------------------------------------------
. "$script:AppRoot\Views\ViewMain.ps1"

# Setup
. "$script:AppRoot\Views\ViewSetup.ps1"
. "$script:AppRoot\Views\Setup\SetupConnected.ps1"
. "$script:AppRoot\Views\Setup\SetupDevices.ps1"
. "$script:AppRoot\Views\Setup\SetupOta.ps1"

# Остальные
. "$script:AppRoot\Views\ViewCleanup.ps1"
. "$script:AppRoot\Views\ViewApk.ps1"
. "$script:AppRoot\Views\ViewFiles.ps1"
. "$script:AppRoot\Views\ViewRemote.ps1"
. "$script:AppRoot\Views\ViewAnimation.ps1"
. "$script:AppRoot\Views\ViewSettings.ps1"
. "$script:AppRoot\Views\ViewRollback.ps1"
. "$script:AppRoot\Views\ViewScreenshot.ps1"
. "$script:AppRoot\Views\ViewInfo.ps1"
. "$script:AppRoot\Views\ViewPower.ps1"
. "$script:AppRoot\Views\ViewLogcat.ps1"
. "$script:AppRoot\Views\ViewScrcpy.ps1"
. "$script:AppRoot\Views\ViewService.ps1"
. "$script:AppRoot\Views\ViewWifi.ps1"
. "$script:AppRoot\Views\ViewBluetooth.ps1"
. "$script:AppRoot\Views\ViewTraffic.ps1"
. "$script:AppRoot\Views\ViewDisplay.ps1"
. "$script:AppRoot\Views\ViewPresets.ps1"
. "$script:AppRoot\Views\ViewProcesses.ps1"
. "$script:AppRoot\Views\ViewIntegrity.ps1"
. "$script:AppRoot\Views\ViewScenarios.ps1"
. "$script:AppRoot\Views\ViewAutostart.ps1"
. "$script:AppRoot\Views\ViewThermal.ps1"
. "$script:AppRoot\Views\ViewPermissions.ps1"
. "$script:AppRoot\Views\ViewApps.ps1"
. "$script:AppRoot\Views\ViewHttpServer.ps1"
. "$script:AppRoot\Views\ViewSnapshots.ps1"
. "$script:AppRoot\Views\ViewMonitoring.ps1"

# ---------------------------------------------------------------------------
#  10. Проверка ADB в PATH
# ---------------------------------------------------------------------------
Write-Host "Проверяю наличие ADB в PATH..." -ForegroundColor Cyan
$adbReady = Initialize-AdbPath
if (-not $adbReady) {
    Write-Host "[!] ADB не настроен. Программа может работать некорректно." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
#  11. Автоподключение (если включено)
# ---------------------------------------------------------------------------
$autoConnect = Get-ConfigValue -Key "AutoConnect"
$lastIp      = Get-ConfigValue -Key "LastIp"

if ($autoConnect -and $lastIp) {
    Write-Log -Message "Автоподключение к $lastIp..." -Level "Info"
    $result = Connect-AdbDevice -Ip $lastIp

    if ($result.Success) {
        Check-OtaState
        Write-Log -Message "Автоподключение успешно" -Level "Success"
        $script:AutoConnectFailed = $false
    } else {
        Write-Log -Message "Автоподключение не удалось: $($result.Message)" -Level "Warning"
        Write-Log -Message "Запущу сканирование сети в фоне — результаты появятся на экране «Настройка»" -Level "Info"
        $script:AutoConnectFailed = $true
        $script:NeedAutoScan = $true
    }
} else {
    $script:AutoConnectFailed = $false
    $script:NeedAutoScan = $false
}

# ---------------------------------------------------------------------------
#  12. Функция обновления статуса HTTP в статус-баре
# ---------------------------------------------------------------------------
function Update-HttpStatusBar {
    # ===== ЗАЩИТА =====
    if ($global:AppClosing) { return }
    if (-not $script:HttpStatusText) { return }

    try {
        if ($script:HttpServerRunning) {
            $localIp = Get-LocalIpAddress
            $port    = $script:HttpPort
            $token   = $script:HttpToken

            if ($script:HttpLocalOnly) {
                $script:HttpStatusText.Text = "HTTP: localhost:$Port (только локально)"
                $script:HttpStatusText.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
                )
                $script:HttpStatusText.ToolTip = "Сервер слушает только localhost. С телефона подключиться нельзя."
            } else {
                $url = "http://$($localIp):$Port/?token=$token"
                $script:HttpStatusText.Text = "HTTP: $url"
                $script:HttpStatusText.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
                )
                $script:HttpStatusText.ToolTip = "HTTP-сервер запущен. Откройте этот URL на телефоне."
            }
        } else {
            $script:HttpStatusText.Text = ""
            $script:HttpStatusText.ToolTip = $null
        }
    } catch { }
}

# Делаем доступной глобально
$global:UpdateHttpStatusBar = ${function:Update-HttpStatusBar}

# ---------------------------------------------------------------------------
#  13. Точка входа (переключение на главный экран)
# ---------------------------------------------------------------------------
. "$script:AppRoot\Views\MainWindow.xaml.ps1"

# =====================================================================
#  ДИАГНОСТИКА: AppDomain.UnhandledException (ловит всё, включая WPF)
# =====================================================================
[System.AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $e)
    Write-Host "=== AppDomain.UnhandledException ===" -ForegroundColor Red
    Write-Host "Message: $($e.ExceptionObject.Message)" -ForegroundColor Yellow
    Write-Host "Type: $($e.ExceptionObject.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "StackTrace:" -ForegroundColor Yellow
    Write-Host $e.ExceptionObject.StackTrace
    if ($e.ExceptionObject.InnerException) {
        Write-Host "--- InnerException ---" -ForegroundColor Magenta
        Write-Host "Message: $($e.ExceptionObject.InnerException.Message)" -ForegroundColor Yellow
        Write-Host "StackTrace:" -ForegroundColor Yellow
        Write-Host $e.ExceptionObject.InnerException.StackTrace
    }
})

# ---------------------------------------------------------------------------
#  14. Запуск окна
# ---------------------------------------------------------------------------
$window.WindowState = "Maximized"

try {
    $window.ShowDialog() | Out-Null
} finally {
    # =====================================================================
    #  1. ФЛАГ ЗАВЕРШЕНИЯ — все таймеры и обновляторы проверяют его
    # =====================================================================
    $global:AppClosing = $true
    Write-Host "Начато завершение работы..." -ForegroundColor Cyan

    # =====================================================================
    #  2. ТАЙМЕРЫ (первыми, чтобы не дёргали UI)
    # =====================================================================
    try { if ($script:StatusTimer)              { $script:StatusTimer.Stop() } } catch { }
    try { if ($script:ScanTimer)                { $script:ScanTimer.Stop() } } catch { }
    try { if ($script:ApkTimer)                 { $script:ApkTimer.Stop() } } catch { }
    try { if ($script:ThermalRefreshTimer)      { $script:ThermalRefreshTimer.Stop() } } catch { }
    try { if ($script:TrafficRefreshTimer)      { $script:TrafficRefreshTimer.Stop() } } catch { }
    try { if ($script:RecordProgressTimer)      { $script:RecordProgressTimer.Stop() } } catch { }
    try { if ($script:MonitoringRefreshTimer)   { $script:MonitoringRefreshTimer.Stop() } } catch { }
    try { if ($script:MonitoringTrafficTimer)   { $script:MonitoringTrafficTimer.Stop() } } catch { }
    try { if ($script:MonTrafTimer)             { $script:MonTrafTimer.Stop() } } catch { }
    try { if ($script:MonSlowTimer)             { $script:MonSlowTimer.Stop() } } catch { }
    try { if ($script:ScenarioRun -and $script:ScenarioRun.Timer) { $script:ScenarioRun.Timer.Stop() } } catch { }

    # =====================================================================
    #  3. HTTP-сервер (первым среди Runspace'ов, чтобы не висел accept-loop)
    # =====================================================================
    try { if ($script:HttpServerRunning) { Stop-HttpServer } } catch { }

    # =====================================================================
    #  4. Logcat
    # =====================================================================
    try { if ($script:LogcatProcess) { Stop-Logcat -Proc $script:LogcatProcess } } catch { }

    # =====================================================================
    #  5. Runspace'ы сканирования и установки APK
    # =====================================================================
    try { if ($script:ScanPS)        { $script:ScanPS.Stop();  $script:ScanPS.Dispose() } } catch { }
    try { if ($script:ApkPS)         { $script:ApkPS.Stop();   $script:ApkPS.Dispose() } } catch { }
    try { if ($script:ApkRunspace)   { $script:ApkRunspace.Close() } } catch { }

    # =====================================================================
    #  6. СБРАСЫВАЕМ ССЫЛКИ НА UI (в самом конце, чтобы поздние вызовы
    #     не падали с "Не удается найти свойство 'Text'")
    # =====================================================================
    $global:statusText     = $null
    $global:contentGrid    = $null
    $global:HttpStatusText = $null

    Write-Host "Приложение закрыто." -ForegroundColor Cyan
}