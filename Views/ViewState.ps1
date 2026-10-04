# ============================================================================
#  ОБЩЕЕ СОСТОЯНИЕ ПРИЛОЖЕНИЯ
# ============================================================================

$script:connected     = $false
$script:deviceIp      = ""
$script:allChanges    = @()
$script:FoundDevices  = @()

# ===== СОСТОЯНИЕ ЭКРАНА ОЧИСТКИ =====
$script:SelectedPackages = @()

# ===== СОСТОЯНИЕ ЭКРАНА APK =====
$script:ApkFolderPath = ""
$script:ApkCheckboxes = @()
$script:ApkSelectedFiles = @()
$script:ApkBtnInstall = $null
$script:ApkFolderLabel = $null
$script:ApkListContainer = $null
$script:ApkInstallInProgress = $false
$script:ApkInstalledFiles = @()

# Ссылки на Runspace/Timer для APK
$script:ApkRunspace = $null
$script:ApkPS = $null
$script:ApkHandle = $null
$script:ApkTimer = $null

# ===== СОСТОЯНИЕ ЭКРАНА АНИМАЦИИ =====
$script:AnimationCurrentValue = $null

# ===== СОСТОЯНИЕ ЭКРАНА ОТКАТА =====
$script:RollbackChanges = @()
$script:RollbackCheckboxes = @()
$script:RollbackBtnApply = $null

# ===== СОСТОЯНИЕ OTA =====
$script:OtaDisabled = $false
$script:OtaBtn = $null

# ===== СОСТОЯНИЕ ОЧИСТКИ =====
$script:PackageCheckboxes = @()
$script:RemovedPackages = @()
$script:InstalledPackagesSet = @{}
$script:DisabledPackagesSet = @{}
$script:TabCheckboxesMap = @{}

# ===== СОСТОЯНИЕ ФАЙЛОВОГО МЕНЕДЖЕРА =====
$script:CurrentRemotePath = "/sdcard/"
$script:FileListBox = $null

# ===== СОСТОЯНИЕ ПУЛЬТА =====
$script:RemoteTextInput = ""
$script:RemoteMuted = $false

# ===== СОСТОЯНИЕ СКРИНШОТА / ВИДЕО =====
$script:LastScreenshotPath = ""
$script:ScreenshotGallery = @()

# ===== СОСТОЯНИЕ СВЕДЕНИЙ =====
$script:DeviceInfo = $null

# ===== LOGCAT =====
$script:LogcatProcess = $null

# ===== ТАЙМЕР СТАТУСА =====
$script:StatusTimer = $null

# ===== WI-FI =====
$script:WifiNetworksContainer = $null

# ===== DISPLAY =====
$script:DisplayViewInfo = $null

# ===== REMOTE HOTKEYS =====
$script:RemoteKeyHandler     = $null
$script:RemoteHotkeysEnabled = $true

# ===== АВТО-СКАНИРОВАНИЕ =====
$script:AutoConnectFailed = $false
$script:NeedAutoScan      = $false

# ===== ПРОЦЕССЫ =====
$script:ProcessesSortBy = "cpu"

# ===== ПРОВЕРКА ЦЕЛОСТНОСТИ =====
$script:IntegrityReference = $null

# ===== ADBKEYBOARD =====
# Переменные определены в Modules\AdbKeyboard.ps1

# ===== APK BUNDLES =====
$script:ApkExtraFiles = @()

# ===== PERMISSIONS =====
$script:PermLoadTimer = $null

# ===== SETUP — последняя активная вкладка =====
$script:SetupLastTab = 0

# ===== ТЕКУЩИЙ ЭКРАН =====
$script:CurrentView = "Main"

# ===== BLUETOOTH =====
$script:BtScanResults = @()

# ===== TRAFFIC =====
$script:TrafficHistory = @()
$script:TrafficPrevCounters = $null
$script:TrafficLastSampleTime = $null
$script:TrafficActiveIface = $null
$script:TrafficRefreshTimer = $null
$script:TrafficWatcherRunning = $false
$script:TrafficBtnToggle = $null
$script:TrafficChartCanvas = $null
$script:TrafficChartMaxLabel = $null
$script:TrafficAppsContainer = $null
$script:TrafficRxLine = $null
$script:TrafficTxLine = $null
$script:TrafficTotalRxLine = $null
$script:TrafficTotalTxLine = $null

# ===== HTTP SERVER =====
$script:HttpListener      = $null
$script:HttpPS            = $null
$script:HttpRunspace      = $null
$script:HttpHandle        = $null
$script:HttpToken         = ""
$script:HttpPort          = 8080
$script:HttpServerRunning = $false
$script:HttpLocalOnly = $false