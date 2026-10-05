# ===== ПУТИ =====
$script:adbPath = "adb"
$script:backupFile = "$env:USERPROFILE\Desktop\tv_changes_backup.json"

# ============================================================================
#  КАТЕГОРИИ ПАКЕТОВ
#  Risk: low = безопасно, medium = осторожно, high = может сломать
# ============================================================================

# ----------------------------------------------------------------------------
#  РЕКЛАМА И ТЕЛЕМЕТРИЯ
# ----------------------------------------------------------------------------
$script:adwarePackages = @(
    @{Package="com.tcl.waterfall.overseas"; Desc="TCL Channel — рекомендации и реклама на главном экране"; Risk="low"}
    @{Package="com.tcl.guard";              Desc="Safety Guard — телеметрия и «оптимизация» памяти";        Risk="low"}
    @{Package="com.tcl.interactive";        Desc="Интерактивные рекламные баннеры";                          Risk="low"}
    @{Package="com.tcl.tv.tclhome_passive"; Desc="Пассивная реклама на главном экране";                      Risk="medium"}
    @{Package="com.tcl.partnercustomizer";  Desc="Партнёрские рекламные плейсменты";                         Risk="low"}
    @{Package="com.tcl.useragreement";      Desc="Соглашение с пользователем и телеметрия";                  Risk="low"}
    @{Package="com.tcl.hearaid";            Desc="HearAid — сбор статистики прослушивания";                  Risk="low"}
    @{Package="com.tcl.exhibit";            Desc="Демо-контент (для магазинов) — показ рекламы";             Risk="low"}
    @{Package="com.tcl.logkit";             Desc="Сбор логов TCL для аналитики";                             Risk="low"}
    @{Package="com.tcl.suspension";         Desc="Рекламные push-уведомления";                               Risk="low"}
    @{Package="com.tcl.esticker";           Desc="Рекламные стикеры на экране";                              Risk="low"}
    @{Package="com.tcl.channelplus";        Desc="Дополнительные рекламные каналы";                          Risk="low"}
    @{Package="com.tcl.ocean.instructions"; Desc="Обучающие подсказки с рекламой";                           Risk="low"}
    @{Package="tv.mopa.ginga";              Desc="Ginga — интерактивный ТВ (реклама, Бразилия)";             Risk="low"}
    @{Package="com.google.android.feedback";Desc="Отправка отзывов Google";                                 Risk="low"}
    @{Package="com.google.android.partnersetup"; Desc="Настройка Google-партнёров";                          Risk="low"}
    @{Package="com.google.android.onetimeinitializer"; Desc="Одноразовая инициализация Google";               Risk="low"}
)

# ----------------------------------------------------------------------------
#  СТРИМИНГ И МЕДИА
# ----------------------------------------------------------------------------
$script:streamingPackages = @(
    @{Package="com.netflix.ninja";                    Desc="Netflix — приложение для просмотра";                     Risk="low"}
    @{Package="com.netflix.tokenmanager";             Desc="Токен-менеджер Netflix (нужен, если Netflix установлен)";  Risk="medium"}
    @{Package="com.amazon.amazonvideo.livingroom";    Desc="Amazon Prime Video — приложение для просмотра";            Risk="low"}
    @{Package="com.iqiyi.i18n.tv";                    Desc="iQIYI — азиатский стриминг (часто с рекламой)";            Risk="low"}
    @{Package="com.google.android.youtube.tv";        Desc="YouTube для Android TV — встроенное приложение";           Risk="medium"}
    @{Package="com.google.android.apps.mediashell";   Desc="Media Shell — приёмник Google Cast";                       Risk="medium"}
)

# ----------------------------------------------------------------------------
#  ЛАУНЧЕРЫ (главные экраны ТВ)
#  ⚠️ Отключать только после установки и проверки стороннего лаунчера!
# ----------------------------------------------------------------------------
$script:launcherPackages = @(
    @{Package="com.google.android.apps.tv.launcherx"; Desc="Google TV Launcher — стандартный главный экран";       Risk="high"}
    @{Package="com.tcl.tv";                           Desc="TCL Launcher — альтернативный главный экран от TCL";    Risk="high"}
    @{Package="com.tcl.tv.tclhome_passive";           Desc="TCL Home Passive — вспомогательный компонент лаунчера";  Risk="high"}
)

# ----------------------------------------------------------------------------
#  TCL-СЕРВИСЫ
# ----------------------------------------------------------------------------
$script:tclServicesPackages = @(
    @{Package="com.tcl.usercenter";              Desc="Центр аккаунтов TCL — если не пользуетесь";     Risk="medium"}
    @{Package="com.tcl.gamebar";                 Desc="Игровая панель — если не играете";               Risk="medium"}
    @{Package="com.tcl.ttvs";                    Desc="Магазин приложений TCL (может ломать апдейты)";  Risk="high"}
    @{Package="com.tcl.ui_mediaCenter";          Desc="Медиа-центр TCL — если не пользуетесь";          Risk="medium"}
    @{Package="com.tcl.messagebox";              Desc="Сообщения от TCL";                               Risk="low"}
    @{Package="com.tcl.repairguide";             Desc="Гид по ремонту";                                 Risk="low"}
    @{Package="com.tcl.eva";                     Desc="EVA — голосовой ассистент TCL";                  Risk="medium"}
    @{Package="com.tcl.miracast";                Desc="Miracast — трансляция экрана";                   Risk="medium"}
    @{Package="com.tcl.airplay2";                Desc="AirPlay 2 от TCL";                               Risk="medium"}
    @{Package="com.tcl.hotelmenu";               Desc="Hotel Menu — только для гостиниц";               Risk="low"}
    @{Package="com.tcl.t_solo";                  Desc="TCL Solo — сервис (назначение неизвестно)";      Risk="medium"}
    @{Package="com.mediatek.AirplayAPK";         Desc="AirPlay APK от MediaTek (дубль com.tcl.airplay2)"; Risk="medium"}
    @{Package="com.mediatek.airplaydaemon";      Desc="AirPlay daemon MediaTek";                        Risk="medium"}
    @{Package="com.tvos";                        Desc="Samsung TV OS / AirPlay совместимость";          Risk="medium"}
)

# ----------------------------------------------------------------------------
#  GOOGLE-МУСОР
# ----------------------------------------------------------------------------
$script:googleJunkPackages = @(
    @{Package="com.google.android.youtube.tvmusic";  Desc="YouTube Music";                          Risk="low"}
    @{Package="com.google.android.play.games";       Desc="Play Games";                             Risk="low"}
    @{Package="com.google.android.marvin.talkback";  Desc="TalkBack — для слабовидящих";            Risk="low"}
    @{Package="com.google.android.syncadapters.calendar"; Desc="Синхронизация календаря";           Risk="low"}
    @{Package="com.google.android.apps.tv.dreamx";   Desc="Daydream screensaver";                   Risk="low"}
    @{Package="com.google.android.katniss";          Desc="Google Assistant — если не используете"; Risk="medium"}
    @{Package="com.google.android.tv.remote.service";Desc="Сервис пульта Google TV";                Risk="low"}
    @{Package="com.google.android.tts";              Desc="Google TTS — синтез речи";               Risk="medium"}
)

# ----------------------------------------------------------------------------
#  СИСТЕМНЫЕ ДОПОЛНЕНИЯ
# ----------------------------------------------------------------------------
$script:systemJunkPackages = @(
    @{Package="com.android.providers.contacts";       Desc="Провайдер контактов — не нужен на ТВ"; Risk="low"}
    @{Package="com.android.providers.calendar";       Desc="Провайдер календаря";                   Risk="low"}
    @{Package="com.android.printspooler";             Desc="Служба печати";                         Risk="low"}
    @{Package="com.android.dreams.basic";             Desc="Базовые заставки";                      Risk="low"}
    @{Package="com.android.htmlviewer";               Desc="HTML-просмотрщик";                      Risk="low"}
    @{Package="com.android.wallpaperbackup";          Desc="Резерв обоев";                          Risk="low"}
    @{Package="com.android.sharedstoragebackup";      Desc="Общий резерв";                          Risk="low"}
    @{Package="com.android.backupconfirm";            Desc="Подтверждение резерва";                 Risk="low"}
    @{Package="com.android.providers.userdictionary"; Desc="Словарь пользователя";                  Risk="low"}
)

# ----------------------------------------------------------------------------
#  OTA-ОБНОВЛЕНИЯ
# ----------------------------------------------------------------------------
$script:otaPackages = @(
    @{Package="com.tcl.UpdatePeripheral"; Desc="Обновление периферии TCL"}
    # На этой прошивке нет com.snm.upgrade / com.tcl.versionUpdateApp
)

# ----------------------------------------------------------------------------
#  🚫 КРИТИЧЕСКИЕ ПАКЕТЫ — УДАЛЕНИЕ/ОТКЛЮЧЕНИЕ ЗАПРЕЩЕНО ИЛИ ТРЕБУЕТ ПОДТВЕРЖДЕНИЯ
#
#  Категории:
#    "block"  — полный отказ, даже с подтверждением
#    "warn"   — предупреждение с подтверждением (можно продолжить)
# ----------------------------------------------------------------------------
$script:criticalPackages = @(
    # ===== BOOTLOADER / ЯДРО =====
    @{ Package = "android";                          Risk = "block"; Reason = "Ядро Android" }
    @{ Package = "com.android.systemui";             Risk = "block"; Reason = "Системный UI (нет экрана — нет управления)" }
    @{ Package = "com.android.settings";             Risk = "block"; Reason = "Настройки Android" }
    @{ Package = "com.android.shell";                Risk = "block"; Reason = "ADB shell (потеряется управление)" }
    @{ Package = "com.android.providers.settings";   Risk = "block"; Reason = "Провайдер настроек" }
    @{ Package = "com.android.se";                   Risk = "block"; Reason = "Secure Element (NFC/Google Pay)" }

    # ===== GOOGLE CORE =====
    @{ Package = "com.google.android.gms";           Risk = "block"; Reason = "Google Play Services" }
    @{ Package = "com.google.android.gsf";           Risk = "block"; Reason = "Google Services Framework" }
    @{ Package = "com.android.vending";              Risk = "warn";  Reason = "Google Play Store" }

    # ===== ЛАУНЧЕРЫ (можно отключать, если стоит сторонний) =====
    @{ Package = "com.google.android.apps.tv.launcherx"; Risk = "warn"; Reason = "Google TV Launcher (главный экран). Отключайте ТОЛЬКО если у вас работает сторонний лаунчер" }
    @{ Package = "com.tcl.tv";                           Risk = "warn"; Reason = "TCL Launcher (главный экран). Отключайте ТОЛЬКО если у вас работает сторонний лаунчер" }
    @{ Package = "com.tcl.tv.tclhome_passive";           Risk = "warn"; Reason = "Вспомогательный компонент TCL Launcher" }

    # ===== TCL CORE =====
    @{ Package = "com.tcl.systemserver";             Risk = "block"; Reason = "Системный сервер TCL" }
    @{ Package = "com.tcl.providers.config";         Risk = "block"; Reason = "Конфиг TCL" }
    @{ Package = "com.tcl.systemui.plugin";          Risk = "block"; Reason = "Плагин SystemUI TCL" }
    @{ Package = "com.tcl.globalkeyoverlay";         Risk = "block"; Reason = "Глобальный перехват клавиш" }
    @{ Package = "com.tcl.tvinput";                  Risk = "block"; Reason = "ТВ-вход (HDMI, антенна)" }
    @{ Package = "com.tcl.autopair";                 Risk = "warn";  Reason = "Автосопряжение пульта" }
    @{ Package = "com.tcl.android.webview";          Risk = "warn";  Reason = "WebView TCL" }
    @{ Package = "com.tcl.initsetup";                Risk = "warn";  Reason = "Начальная настройка" }

    # ===== MEDIATEK =====
    @{ Package = "com.mediatek.speakerservice";      Risk = "warn";  Reason = "Сервис динамиков MediaTek" }
    @{ Package = "com.mediatek.network";             Risk = "block"; Reason = "Сеть MediaTek" }
    @{ Package = "com.mediatek.backgrounddetection"; Risk = "warn";  Reason = "Определение фона" }
    @{ Package = "com.mediatek.android.tv.mdns.offload";         Risk = "warn"; Reason = "mDNS offload" }
    @{ Package = "com.mediatek.android.tv.mdns.offload.overlay"; Risk = "warn"; Reason = "mDNS offload overlay" }
    @{ Package = "com.mediatek.support.webview";     Risk = "warn";  Reason = "WebView MediaTek" }

    # ===== DOLBY =====
    @{ Package = "com.dolby.android.audio.service";     Risk = "warn"; Reason = "Dolby Audio Service" }
    @{ Package = "com.dolby.android.audio.calibration"; Risk = "warn"; Reason = "Калибровка Dolby" }

    # ===== ОБНОВЛЕНИЯ СИСТЕМЫ =====
    @{ Package = "com.tcl.UpdatePeripheral";         Risk = "warn";  Reason = "Обновление периферии TCL" }
    @{ Package = "com.snm.upgrade";                  Risk = "warn";  Reason = "OTA-обновление" }
    @{ Package = "com.tcl.versionUpdateApp";         Risk = "warn";  Reason = "Обновление версии TCL" }
)

# ---- Кэш для быстрого поиска ----
$script:CriticalPackagesMap = @{}
foreach ($item in $script:criticalPackages) {
    $script:CriticalPackagesMap[$item.Package] = $item
}

# ---- Обратная совместимость: старый список как массив имён ----
$script:systemCriticalPackages = @($script:criticalPackages | Where-Object { $_.Risk -eq "block" } | ForEach-Object { $_.Package })

# ---- Кэш для быстрого поиска ----
$script:CriticalPackagesMap = @{}
foreach ($item in $script:criticalPackages) {
    $script:CriticalPackagesMap[$item.Package] = $item
}

# ---- Обратная совместимость: старый список как массив имён ----
$script:systemCriticalPackages = @($script:criticalPackages | Where-Object { $_.Risk -eq "block" } | ForEach-Object { $_.Package })

# ----------------------------------------------------------------------------
#  LAUNCHER LIST
# ----------------------------------------------------------------------------
$script:launcherList = @(
    @{Name="ATV Launcher Pro";      Package="ca.dstudio.atvlauncher.pro"; Activity="ca.dstudio.atvlauncher.pro/.ui.MainActivity"}
    @{Name="Projectivy Launcher";   Package="com.spocky.projengmenu";     Activity="com.spocky.projengmenu/.ui.home.MainActivity"}
    @{Name="FLauncher";             Package="me.efesser.flauncher";       Activity="me.efesser.flauncher/.MainActivity"}
    @{Name="Monet Launcher";        Package="com.klevico.monet";          Activity="com.klevico.monet/.MainActivity"}
)

# ----------------------------------------------------------------------------
#  BLUETOOTH-ПАКЕТЫ
#  Справочно, для отката. TVManager их не трогает по умолчанию.
# ----------------------------------------------------------------------------
$script:bluetoothPackages = @(
    @{Package="com.android.bluetooth";        Desc="Основной стек Bluetooth (не трогать)"; Risk="high"}
    @{Package="com.android.bluetoothmidiservice"; Desc="MIDI over Bluetooth";              Risk="low"}
    @{Package="com.android.btservices";       Desc="Сервисы Bluetooth (Android TV)";       Risk="high"}
)

# ===== СОСТОЯНИЕ =====
$script:deviceIp = ""
$script:allChanges = @()
$script:connected = $false