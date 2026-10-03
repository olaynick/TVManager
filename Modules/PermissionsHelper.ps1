# ============================================================================
#  Permissions Helper — управление разрешениями приложений
# ============================================================================

function Invoke-PermAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ===== СПИСОК ОПАСНЫХ РАЗРЕШЕНИЙ (для быстрых пресетов) =====
function Get-DangerousPermissions {
    return @(
        "android.permission.CAMERA"
        "android.permission.RECORD_AUDIO"
        "android.permission.ACCESS_FINE_LOCATION"
        "android.permission.ACCESS_COARSE_LOCATION"
        "android.permission.READ_CONTACTS"
        "android.permission.WRITE_CONTACTS"
        "android.permission.READ_CALENDAR"
        "android.permission.WRITE_CALENDAR"
        "android.permission.READ_SMS"
        "android.permission.SEND_SMS"
        "android.permission.RECEIVE_SMS"
        "android.permission.READ_PHONE_STATE"
        "android.permission.CALL_PHONE"
        "android.permission.READ_EXTERNAL_STORAGE"
        "android.permission.WRITE_EXTERNAL_STORAGE"
        "android.permission.BODY_SENSORS"
        "android.permission.READ_CALL_LOG"
        "android.permission.WRITE_CALL_LOG"
    )
}

# ===== СПИСОК СТОРОННИХ ПРИЛОЖЕНИЙ =====
function Get-ThirdPartyAppsForPermissions {
    $out = Invoke-PermAdb @("shell", "pm", "list", "packages", "-3")
    $list = @()
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match '^package:(.+)$') {
            $list += $matches[1].Trim()
        }
    }
    return ,$list
}

# ===== ТЕКУЩИЕ РАЗРЕШЕНИЯ ПАКЕТА =====
function Get-PackagePermissions {
    param([string]$Package)

    $result = @{
        Granted = @()
        Denied  = @()
        All     = @()
    }

    $allSet = @{}   # Для дедупликации

    try {
        $out = Invoke-PermAdb @("shell", "dumpsys", "package", $Package)

        foreach ($line in ($out -split "`r?`n")) {
            # Ловим строки вида:
            #   android.permission.INTERNET: granted=true
            #   android.permission.CAMERA: granted=false
            if ($line -match '^\s+(android\.permission\.[a-zA-Z_]+|[a-z][a-z0-9_\.]+\.[a-zA-Z_]+):\s+granted=(true|false)') {
                $perm = $matches[1]
                $granted = ($matches[2] -eq "true")

                # Дедупликация
                if ($allSet.ContainsKey($perm)) {
                    # Если уже есть — обновляем статус на "granted=true", если хоть раз true
                    if ($granted -and $perm -in $result.Denied) {
                        $result.Denied = @($result.Denied | Where-Object { $_ -ne $perm })
                        $result.Granted += $perm
                    }
                    continue
                }
                $allSet[$perm] = $true
                $result.All += $perm

                if ($granted) {
                    $result.Granted += $perm
                } else {
                    $result.Denied += $perm
                }
            }
        }
    } catch { }

    return $result
}

# ===== ВЫДАТЬ РАЗРЕШЕНИЕ =====
function Grant-Permission {
    param([string]$Package, [string]$Permission)
    $out = Invoke-PermAdb @("shell", "pm", "grant", $Package, $Permission)
    if ($out -match 'error|Error|Exception|not a changeable permission') {
        return $false
    }
    return $true
}

# ===== ОТОЗВАТЬ РАЗРЕШЕНИЕ =====
function Revoke-Permission {
    param([string]$Package, [string]$Permission)
    $out = Invoke-PermAdb @("shell", "pm", "revoke", $Package, $Permission)
    if ($out -match 'error|Error|Exception|not a changeable permission') {
        return $false
    }
    return $true
}

# ============================================================================
#  ОПИСАНИЯ РАЗРЕШЕНИЙ
# ============================================================================
function Get-PermissionDescription {
    param([string]$Permission)

    # =========================================================================
    #  ПРИОРИТЕТНЫЕ ПАТТЕРНЫ (проверяются ДО словаря)
    #  Здесь ловим динамические разрешения, которые генерируются автоматически
    #  и содержат имя пакета в начале (io.lift.app.DYNAMIC_RECEIVER_...)
    # =========================================================================

    if ($Permission -match 'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION') {
        return "Системное разрешение для динамических ресиверов (Android 14+)"
    }
    if ($Permission -match 'READ_EPG_DATA$') {
        return "Чтение данных ТВ-программы (EPG)"
    }
    if ($Permission -match 'WRITE_EPG_DATA$') {
        return "Запись данных ТВ-программы (EPG)"
    }
    if ($Permission -match 'ACCESS_VIDEO_DATA_QG$') {
        return "Доступ к видеоданным (QG)"
    }
    if ($Permission -match 'ACCESS_ADSERVICES_AD_ID$') {
        return "Доступ к рекламному ID"
    }
    if ($Permission -match 'ACCESS_ADSERVICES_ATTRIBUTION$') {
        return "Доступ к атрибуции рекламы"
    }
    if ($Permission -match 'ACCESS_ADSERVICES_CUSTOM_AUDIENCE$') {
        return "Доступ к пользовательской аудитории рекламы"
    }
    if ($Permission -match 'ACCESS_ADSERVICES_TOPICS$') {
        return "Доступ к рекламным темам (Privacy Sandbox)"
    }
    if ($Permission -match '\.AD_ID$' -or $Permission -eq 'com.google.android.gms.permission.AD_ID') {
        return "Рекламный идентификатор (реклама)"
    }
    if ($Permission -match 'WRITE_SECURE_SETTINGS$') {
        return "Запись защищённых системных настроек"
    }

    # =========================================================================
    #  СЛОВАРЬ СТАТИЧНЫХ РАЗРЕШЕНИЙ
    # =========================================================================
    $descriptions = @{
        # ===== ОСНОВНЫЕ =====
        "android.permission.INTERNET"                       = "Доступ в интернет"
        "android.permission.ACCESS_NETWORK_STATE"           = "Просмотр состояния сети"
        "android.permission.ACCESS_WIFI_STATE"              = "Просмотр состояния Wi-Fi"
        "android.permission.CHANGE_WIFI_STATE"              = "Управление Wi-Fi"
        "android.permission.CHANGE_NETWORK_STATE"           = "Управление сетью"

        # ===== КАМЕРА / МИКРОФОН =====
        "android.permission.CAMERA"                         = "Камера"
        "android.permission.RECORD_AUDIO"                   = "Запись звука (микрофон)"
        "android.permission.MODIFY_AUDIO_SETTINGS"          = "Изменение настроек звука"

        # ===== ГЕОЛОКАЦИЯ =====
        "android.permission.ACCESS_FINE_LOCATION"           = "Точное местоположение (GPS)"
        "android.permission.ACCESS_COARSE_LOCATION"         = "Примерное местоположение"
        "android.permission.ACCESS_BACKGROUND_LOCATION"     = "Местоположение в фоне"

        # ===== КОНТАКТЫ / КАЛЕНДАРЬ =====
        "android.permission.READ_CONTACTS"                  = "Чтение контактов"
        "android.permission.WRITE_CONTACTS"                 = "Изменение контактов"
        "android.permission.GET_ACCOUNTS"                   = "Просмотр аккаунтов"
        "android.permission.READ_CALENDAR"                  = "Чтение календаря"
        "android.permission.WRITE_CALENDAR"                 = "Изменение календаря"

        # ===== SMS / ЗВОНКИ =====
        "android.permission.READ_SMS"                       = "Чтение SMS"
        "android.permission.SEND_SMS"                       = "Отправка SMS"
        "android.permission.RECEIVE_SMS"                    = "Получение SMS"
        "android.permission.READ_PHONE_STATE"               = "Состояние телефона"
        "android.permission.READ_PHONE_NUMBERS"             = "Номера телефонов"
        "android.permission.CALL_PHONE"                     = "Звонки"
        "android.permission.ANSWER_PHONE_CALLS"             = "Ответ на звонки"
        "android.permission.READ_CALL_LOG"                  = "Чтение журнала вызовов"
        "android.permission.WRITE_CALL_LOG"                 = "Изменение журнала вызовов"

        # ===== ХРАНИЛИЩЕ =====
        "android.permission.READ_EXTERNAL_STORAGE"          = "Чтение внешнего хранилища"
        "android.permission.WRITE_EXTERNAL_STORAGE"         = "Запись во внешнее хранилище"
        "android.permission.MANAGE_EXTERNAL_STORAGE"        = "Полный доступ к файлам"
        "android.permission.MANAGE_MEDIA"                   = "Управление медиатекой"

        # ===== ДАТЧИКИ =====
        "android.permission.BODY_SENSORS"                   = "Датчики тела"
        "android.permission.ACTIVITY_RECOGNITION"           = "Распознавание активности"
        "android.permission.HIGH_SAMPLING_RATE_SENSORS"     = "Датчики с высокой частотой"

        # ===== СИСТЕМА =====
        "android.permission.FOREGROUND_SERVICE"             = "Служба переднего плана"
        "android.permission.RECEIVE_BOOT_COMPLETED"         = "Автозапуск при загрузке"
        "android.permission.WAKE_LOCK"                      = "Блокировка сна"
        "android.permission.VIBRATE"                        = "Вибрация"
        "android.permission.POST_NOTIFICATIONS"             = "Показ уведомлений"
        "android.permission.SYSTEM_ALERT_WINDOW"            = "Поверх других окон"
        "android.permission.REQUEST_INSTALL_PACKAGES"       = "Установка приложений"
        "android.permission.REQUEST_DELETE_PACKAGES"        = "Удаление приложений"
        "android.permission.QUERY_ALL_PACKAGES"             = "Просмотр всех приложений"
        "android.permission.PACKAGE_USAGE_STATS"            = "Статистика использования"
        "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" = "Отключение оптимизации батареи"
        "android.permission.ACCESS_NOTIFICATION_POLICY"     = "Доступ к политике уведомлений"
        "android.permission.USE_FULL_SCREEN_INTENT"         = "Полноэкранные уведомления"
        "android.permission.SCHEDULE_EXACT_ALARM"           = "Точные будильники"
        "android.permission.USE_EXACT_ALARM"                = "Точные будильники (системные)"
        "android.permission.DETECT_SCREEN_CAPTURE"          = "Обнаружение захвата экрана"
        "android.permission.WRITE_SECURE_SETTINGS"          = "Запись защищённых системных настроек"

        # ===== РЕКЛАМА И АНАЛИТИКА =====
        "android.permission.AD_ID"                          = "Рекламный идентификатор (реклама)"
        "com.google.android.gms.permission.AD_ID"           = "Рекламный идентификатор Google"
        "android.permission.ACCESS_ADSERVICES_AD_ID"        = "Доступ к рекламному ID"
        "android.permission.ACCESS_ADSERVICES_ATTRIBUTION"  = "Доступ к атрибуции рекламы"
        "android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE" = "Доступ к пользовательской аудитории рекламы"
        "android.permission.ACCESS_ADSERVICES_TOPICS"       = "Доступ к рекламным темам (Privacy Sandbox)"

        # ===== BLUETOOTH / NFC =====
        "android.permission.BLUETOOTH"                      = "Bluetooth"
        "android.permission.BLUETOOTH_ADMIN"                = "Управление Bluetooth"
        "android.permission.BLUETOOTH_CONNECT"              = "Подключение по Bluetooth"
        "android.permission.BLUETOOTH_SCAN"                 = "Поиск Bluetooth-устройств"
        "android.permission.NEARBY_WIFI_DEVICES"            = "Wi-Fi-устройства рядом"
        "android.permission.UWB_RANGING"                    = "UWB-пеленгация"
        "android.permission.NFC"                            = "NFC"

        # ===== ЭКРАН / UI =====
        "android.permission.SET_WALLPAPER"                  = "Установка обоев"
        "android.permission.EXPAND_STATUS_BAR"              = "Управление статус-баром"
        "android.permission.STATUS_BAR"                     = "Управление статус-баром (система)"
        "android.permission.DISABLE_KEYGUARD"               = "Отключение блокировки экрана"
        "android.permission.SCREEN_CAPTURE"                 = "Захват экрана"

        # ===== ЗАДАЧИ =====
        "android.permission.REORDER_TASKS"                  = "Изменение порядка задач"
        "android.permission.KILL_BACKGROUND_PROCESSES"      = "Остановка фоновых процессов"
        "android.permission.GET_TASKS"                      = "Просмотр задач"
        "android.permission.REAL_GET_TASKS"                 = "Просмотр всех задач"

        # ===== СИСТЕМНЫЕ =====
        "android.permission.WRITE_SETTINGS"                 = "Изменение системных настроек"
        "android.permission.READ_LOGS"                      = "Чтение системных логов"
        "android.permission.DUMP"                           = "Дамп системы"
        "android.permission.MOUNT_UNMOUNT_FILESYSTEMS"      = "Монтирование файловых систем"
        "android.permission.CHANGE_CONFIGURATION"           = "Изменение конфигурации"
        "android.permission.MODIFY_PHONE_STATE"             = "Изменение состояния телефона"
        "android.permission.READ_BASIC_PHONE_STATE"         = "Базовое состояние телефона"

        # ===== АУДИО / ВИДЕО =====
        "android.permission.CAPTURE_AUDIO_OUTPUT"           = "Запись звука приложения"
        "android.permission.CAPTURE_VIDEO_OUTPUT"           = "Запись видео приложения"

        # ===== FOREGROUND SERVICE (Android 10+) =====
        "android.permission.FOREGROUND_SERVICE_DATA_SYNC"        = "Фоновая синхронизация данных"
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"   = "Фоновое воспроизведение медиа"
        "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" = "Фоновая проекция экрана"
        "android.permission.FOREGROUND_SERVICE_LOCATION"         = "Фоновая геолокация"
        "android.permission.FOREGROUND_SERVICE_CAMERA"           = "Фоновая работа с камерой"
        "android.permission.FOREGROUND_SERVICE_MICROPHONE"       = "Фоновая работа с микрофоном"
        "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" = "Фоновая работа с устройствами"
        "android.permission.FOREGROUND_SERVICE_PHONE_CALL"       = "Фоновые звонки"
        "android.permission.FOREGROUND_SERVICE_HEALTH"           = "Фоновые медицинские сервисы"
        "android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING" = "Фоновые сообщения"
        "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED"  = "Системная служба переднего плана"
        "android.permission.FOREGROUND_SERVICE_SPECIAL_USE"      = "Специальное использование службы"

        # ===== МЕДИА (Android 13+) =====
        "android.permission.READ_MEDIA_IMAGES"                   = "Чтение изображений"
        "android.permission.READ_MEDIA_VIDEO"                    = "Чтение видео"
        "android.permission.READ_MEDIA_AUDIO"                    = "Чтение аудио"
        "android.permission.READ_MEDIA_VISUAL_USER_SELECTED"     = "Доступ к выбранным медиа"
        "android.permission.ACCESS_MEDIA_LOCATION"               = "Местоположение в медиафайлах"

        # ===== TV =====
        "android.permission.READ_TV_LISTINGS"                    = "Чтение ТВ-программы"
        "android.permission.TV_INPUT_HARDWARE"                   = "ТВ-вход (аппаратный)"
        "android.permission.ACCESS_TV_CHANNEL"                   = "Доступ к ТВ-каналам"
        "android.permission.ACCESS_ALL_DOWNLOADS"                = "Доступ ко всем загрузкам в системе"
        "android.permission.RECEIVE_BILLING"                     = "Приём событий биллинга (Google Play)"
        "com.android.vending.BILLING"                            = "Внутренние покупки (Google Play)"
        "com.google.android.c2dm.permission.RECEIVE"             = "Приём push-сообщений (GCM/FCM)"
        "android.permission.WRITE_EPG_DATA"                      = "Запись данных ТВ-программы (EPG)"
        "android.permission.READ_EPG_DATA"                       = "Чтение данных ТВ-программы (EPG)"
        "android.permission.ACCESS_VIDEO_DATA_QG"                = "Доступ к видеоданным (QG)"
    }

    # =========================================================================
    #  ПРЯМОЕ СОВПАДЕНИЕ
    # =========================================================================
    if ($descriptions.ContainsKey($Permission)) {
        return $descriptions[$Permission]
    }

    # =========================================================================
    #  КОРОТКОЕ ИМЯ (убираем префикс пакета)
    # =========================================================================
    if ($Permission -match '\.permission\.') {
        $short = $Permission -replace '^.*\.permission\.', ''
        if ($descriptions.ContainsKey("android.permission.$short")) {
            return $descriptions["android.permission.$short"]
        }
    }

    # =========================================================================
    #  _QG-СУФФИКС (вендорские разрешения)
    # =========================================================================
    if ($Permission -match '\.permission\.(.+)_QG$') {
        $base = $matches[1]
        return "Вендорское разрешение: $base (QG)"
    }

    return ""
}