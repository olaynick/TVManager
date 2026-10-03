#Requires -Version 5.1
# ============================================================================
#  TVManagerTCL — точка входа
# ============================================================================

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
. "$script:AppRoot\Modules\AdbHelper.ps1"        # ADB-команды
. "$script:AppRoot\Modules\AdbKeyboard.ps1"      # ADBKeyboard
. "$script:AppRoot\Modules\NetworkScanner.ps1"   # сканер сети
. "$script:AppRoot\Modules\ChangeLogger.ps1"     # откат изменений
. "$script:AppRoot\Modules\GuiHelper.ps1"        # логгер + тема
. "$script:AppRoot\Modules\AppConfig.ps1"        # config.json + профили
. "$script:AppRoot\Modules\DeviceDump.ps1"       # экспорт дампа
. "$script:AppRoot\Modules\ScenarioEngine.ps1"   # пакетный режим (сценарии)
. "$script:AppRoot\Modules\AppOpsHelper.ps1"
. "$script:AppRoot\Modules\ThermalHelper.ps1"
. "$script:AppRoot\Modules\PermissionsHelper.ps1"

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

# Делаем contentGrid и statusText доступными из вьюх
$global:contentGrid = $contentGrid
$global:statusText  = $statusText

Set-LogBox -Box $logBox

# ---------------------------------------------------------------------------
#  7. Конфиг приложения + сценарии
# ---------------------------------------------------------------------------
Load-AppConfig
Load-Scenarios

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
. "$script:AppRoot\Views\Setup\SetupConnect.ps1"
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
. "$script:AppRoot\Views\ViewProfiles.ps1"
. "$script:AppRoot\Views\ViewLogcat.ps1"
. "$script:AppRoot\Views\ViewService.ps1"
. "$script:AppRoot\Views\ViewWifi.ps1"
. "$script:AppRoot\Views\ViewDisplay.ps1"
. "$script:AppRoot\Views\ViewPresets.ps1"
. "$script:AppRoot\Views\ViewProcesses.ps1"
. "$script:AppRoot\Views\ViewIntegrity.ps1"
. "$script:AppRoot\Views\ViewScenarios.ps1"
. "$script:AppRoot\Views\ViewAutostart.ps1"
. "$script:AppRoot\Views\ViewThermal.ps1"
. "$script:AppRoot\Views\ViewPermissions.ps1"
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
#  12. Точка входа (переключение на главный экран)
# ---------------------------------------------------------------------------
. "$script:AppRoot\Views\MainWindow.xaml.ps1"

# ---------------------------------------------------------------------------
#  13. Запуск окна
# ---------------------------------------------------------------------------
$window.WindowState = "Maximized"

try {
    $window.ShowDialog() | Out-Null
} finally {
    # -----------------------------------------------------------------
    #  Корректное завершение фоновых Runspace'ов
    # -----------------------------------------------------------------
    try { if ($script:LogcatProcess) { Stop-Logcat -Proc $script:LogcatProcess } } catch { }
    try { if ($script:ScanPS)        { $script:ScanPS.Stop();  $script:ScanPS.Dispose() } } catch { }
    try { if ($script:ApkPS)         { $script:ApkPS.Stop();   $script:ApkPS.Dispose() } } catch { }
    try { if ($script:ApkRunspace)   { $script:ApkRunspace.Close() } } catch { }

    try { if ($script:ScanTimer) { $script:ScanTimer.Stop() } } catch { }
    try { if ($script:ApkTimer)  { $script:ApkTimer.Stop()  } } catch { }

    Write-Host "Приложение закрыто." -ForegroundColor Cyan
}