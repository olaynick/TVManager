# ===== ОБЩЕЕ СОСТОЯНИЕ ПРИЛОЖЕНИЯ =====

$script:connected = $false
$script:deviceIp = ""
$script:allChanges = @()
$script:FoundDevices = @()

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

# Ссылки на Runspace/Timer для APK (глобальные, чтобы таймер их видел)
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
$script:RemovedPackages = @()      # Удалённые в этой сессии
$script:InstalledPackagesSet = @{} # Кэш установленных

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

# ===== Wi-Fi =====
$script:WifiNetworksContainer = $null

# ===== DISPLAY =====
$script:DisplayViewInfo = $null

# ===== REMOTE HOTKEYS =====
$script:RemoteKeyHandler    = $null
$script:RemoteHotkeysEnabled = $true

# ===== АВТО-СКАНИРОВАНИЕ =====
$script:AutoConnectFailed = $false
$script:NeedAutoScan = $false

# ===== ПРОЦЕССЫ =====
$script:ProcessesSortBy = "cpu"

# ===== ПРОВЕРКА ЦЕЛОСТНОСТИ =====
$script:IntegrityReference = $null

# ===== ADBKEYBOARD =====
# Ппеременные определены в Modules\AdbKeyboard.ps1

