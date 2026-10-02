# ===== ПУТИ =====
$script:adbPath = "adb"
$script:backupFile = "$env:USERPROFILE\Desktop\tv_changes_backup.json"

# ===== КАТЕГОРИИ ПАКЕТОВ =====
$script:adwarePackages = @(
    @{Package="com.tcl.waterfall";     Desc="TCL Channel — загрузчик рекламы"},
    @{Package="com.tcl.bi";            Desc="TCL Telemetry — сборщик статистики"},
    @{Package="com.tcl.guard";         Desc="Safety Guard — оптимизатор памяти"},
    @{Package="com.tcl.tvwebrs";       Desc="TCL Ads — рекламные баннеры"},
    @{Package="com.tcl.bootadservice"; Desc="Реклама при загрузке"},
    @{Package="com.tcl.c2dm.client";   Desc="Рекламные push-уведомления"}
)

$script:tclServicesPackages = @(
    @{Package="com.tcl.browser";       Desc="BrowseHere — браузер"},
    @{Package="com.tcl.appmarket2";    Desc="TCL App Store"},
    @{Package="com.tcl.usercenter";    Desc="Центр отзывов"},
    @{Package="com.tcl.tcast";         Desc="MagiConnect — каст"},
    @{Package="com.tcl.gamecenter";    Desc="Игровой центр"},
    @{Package="com.tcl.tshop";         Desc="T慧购 — магазин"},
    @{Package="com.tcl.playskill";     Desc="玩机技巧 — советы"},
    @{Package="com.tcl.ffeducation";   Desc="Образование"},
    @{Package="com.tcl.weixin";        Desc="WeChat для ТВ"},
    @{Package="com.tcl.videocall";     Desc="Видеозвонки"},
    @{Package="com.tcl.appreciate.art";Desc="艺生活 — арт-галерея"},
    @{Package="com.tcl.vod";           Desc="Video On Demand"},
    @{Package="com.tcl.tvsmartalbum";  Desc="Умный альбом"}
)

$script:googleJunkPackages = @(
    @{Package="com.google.android.youtube.tvmusic"; Desc="YouTube Music"},
    @{Package="com.google.android.videos";          Desc="Google Play Фильмы"},
    @{Package="com.google.android.apps.tachyon";    Desc="Google Meet"},
    @{Package="com.google.android.play.games";      Desc="Play Игры"},
    @{Package="com.android.camera2";                Desc="Камера"},
    @{Package="com.google.android.music";           Desc="Google Music"}
)

$script:systemJunkPackages = @(
    @{Package="com.android.providers.contacts";       Desc="Контакты"},
    @{Package="com.android.providers.calendar";       Desc="Календарь"},
    @{Package="com.android.printspooler";             Desc="Служба печати"},
    @{Package="com.google.android.marvin.talkback";   Desc="TalkBack"},
    @{Package="com.android.dreams.basic";             Desc="Заставки"},
    @{Package="com.android.htmlviewer";               Desc="HTML-просмотрщик"},
    @{Package="com.android.wallpaperbackup";          Desc="Бэкап обоев"},
    @{Package="com.android.sharedstoragebackup";      Desc="Общий бэкап"},
    @{Package="com.android.backupconfirm";            Desc="Подтверждение бэкапа"},
    @{Package="com.android.providers.userdictionary"; Desc="Словарь"}
)

$script:otaPackages = @(
    @{Package="com.snm.upgrade";          Desc="Системный апдейтер SNM"},
    @{Package="com.tcl.versionUpdateApp"; Desc="TCL-обновлятор прошивки"}
)

$script:launcherList = @(
    @{Name="ATV Launcher Pro";      Package="ca.dstudio.atvlauncher.pro"; Activity="ca.dstudio.atvlauncher.pro/.ui.MainActivity"},
    @{Name="Projectivy Launcher";   Package="com.spocky.projengmenu";     Activity="com.spocky.projengmenu/.ui.home.MainActivity"},
    @{Name="FLauncher";             Package="me.efesser.flauncher";       Activity="me.efesser.flauncher/.MainActivity"},
    @{Name="Monet Launcher";        Package="com.klevico.monet";          Activity="com.klevico.monet/.MainActivity"}
)

# ===== СОСТОЯНИЕ =====
$script:deviceIp = ""
$script:allChanges = @()
$script:connected = $false