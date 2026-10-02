#Requires -version 5.1
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Модули
. "$PSScriptRoot\Modules\Config.ps1"
. "$PSScriptRoot\Modules\AdbHelper.ps1"
. "$PSScriptRoot\Modules\NetworkScanner.ps1"
. "$PSScriptRoot\Modules\ChangeLogger.ps1"
. "$PSScriptRoot\Modules\GuiHelper.ps1"
. "$PSScriptRoot\Modules\AppConfig.ps1"

# Состояние
. "$PSScriptRoot\Views\ViewState.ps1"

# Загружаем XAML
[xml]$xaml = Get-Content -Raw -Path "$PSScriptRoot\Views\MainWindow.xaml"
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Привязываем элементы
$contentGrid = $window.FindName("ContentGrid")
$statusText  = $window.FindName("StatusText")
$logBox      = $window.FindName("LogBox")
$script:BottomBar = $window.FindName("BottomBar")
$script:BottomBarContent = $window.FindName("BottomBarContent")

Set-LogBox -Box $logBox

# Загружаем конфиг
Load-AppConfig

# Хелперы (включая Set-BottomButtons) — ДО вьюх
. "$PSScriptRoot\Views\ViewHelpers.ps1"

# Вьюхи
. "$PSScriptRoot\Views\ViewMain.ps1"
# Setup
. "$PSScriptRoot\Views\ViewSetup.ps1"
. "$PSScriptRoot\Views\Setup\SetupConnect.ps1"
. "$PSScriptRoot\Views\Setup\SetupConnected.ps1"
. "$PSScriptRoot\Views\Setup\SetupDevices.ps1"
. "$PSScriptRoot\Views\Setup\SetupOta.ps1"

. "$PSScriptRoot\Views\ViewCleanup.ps1"
. "$PSScriptRoot\Views\ViewApk.ps1"
. "$PSScriptRoot\Views\ViewFiles.ps1"
. "$PSScriptRoot\Views\ViewRemote.ps1"
. "$PSScriptRoot\Views\ViewAnimation.ps1"
. "$PSScriptRoot\Views\ViewSettings.ps1"
. "$PSScriptRoot\Views\ViewRollback.ps1"
. "$PSScriptRoot\Views\ViewScreenshot.ps1"
. "$PSScriptRoot\Views\ViewInfo.ps1"
. "$PSScriptRoot\Views\ViewPower.ps1"
. "$PSScriptRoot\Views\ViewProfiles.ps1"
. "$PSScriptRoot\Views\ViewLogcat.ps1"
. "$PSScriptRoot\Views\ViewService.ps1"

# ===== ПРОВЕРКА ADB В PATH =====
Write-Host "Проверяю наличие ADB в PATH..." -ForegroundColor Cyan
$adbReady = Initialize-AdbPath
if (-not $adbReady) {
    Write-Host "[!] ADB не настроен. Программа может работать некорректно." -ForegroundColor Yellow
}

# Автоподключение (если включено в конфиге)
$autoConnect = Get-ConfigValue -Key "AutoConnect"
$lastIp = Get-ConfigValue -Key "LastIp"

if ($autoConnect -and $lastIp) {
    Write-Log -Message "Автоподключение к $lastIp..." -Level "Info"
    $result = Connect-AdbDevice -Ip $lastIp
    if ($result.Success) {
        Check-OtaState
        Write-Log -Message "Автоподключение успешно" -Level "Success"
    } else {
        Write-Log -Message "Автоподключение не удалось: $($result.Message)" -Level "Warning"
    }
}

# Точка входа
. "$PSScriptRoot\Views\MainWindow.xaml.ps1"

$window.WindowState = "Maximized"
$window.ShowDialog() | Out-Null