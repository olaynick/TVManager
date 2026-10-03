function Show-MainView {
    $outerGrid = New-Object System.Windows.Controls.Grid

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    $outerGrid.Children.Add($scroll) | Out-Null

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.HorizontalAlignment = "Center"
    $stack.VerticalAlignment = "Center"
    $stack.Width = 540
    $stack.Margin = "0,40,0,40"
    $scroll.Content = $stack

    # ===== Заголовок =====
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "TCL TV Manager"
    $title.FontSize = 34
    $title.FontWeight = "Bold"
    $title.HorizontalAlignment = "Center"
    $title.Margin = "0,0,0,10"
    $stack.Children.Add($title) | Out-Null

    $subtitle = New-Object System.Windows.Controls.TextBlock
    $subtitle.Text = "Управление телевизором через ADB"
    $subtitle.FontSize = 14
    $subtitle.Foreground = "#96969B"
    $subtitle.HorizontalAlignment = "Center"
    $subtitle.Margin = "0,0,0,30"
    $stack.Children.Add($subtitle) | Out-Null

    # ===== Статус ADB =====
    $adbReady = Test-AdbInPath

    $adbInfo = New-Object System.Windows.Controls.TextBlock
    $adbInfo.FontSize = 13
    $adbInfo.HorizontalAlignment = "Center"
    $adbInfo.Margin = "0,0,0,8"
    if ($adbReady) {
        $adbInfo.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
        )
        $adbInfo.Text = "ADB найден — программа готова к работе"
    } else {
        $adbInfo.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
        )
        $adbInfo.Text = "ADB не найден — потребуется настройка"
    }
    $stack.Children.Add($adbInfo) | Out-Null

    # ===== Кнопка "Как установить ADB" =====
    $btnAdbHelp = New-Object System.Windows.Controls.Button
    $btnAdbHelp.Content = "Как установить ADB?"
    $btnAdbHelp.Style = $window.Resources["RoundedButton"]
    if ($adbReady) {
        $btnAdbHelp.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
        )
    } else {
        $btnAdbHelp.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
        )
    }
    $btnAdbHelp.Padding = "15,8"
    $btnAdbHelp.Margin = "0,0,0,25"
    $btnAdbHelp.HorizontalAlignment = "Center"
    $btnAdbHelp.Add_Click({ Show-AdbHelpDialog })
    $stack.Children.Add($btnAdbHelp) | Out-Null

    # ===== РАЗДЕЛ: ПОМОЩЬ =====
    $helpCard = New-Object System.Windows.Controls.Border
    $helpCard.Background = "#F0F4FF"
    $helpCard.BorderBrush = "#4A90E2"
    $helpCard.BorderThickness = "1"
    $helpCard.CornerRadius = "10"
    $helpCard.Padding = "15"
    $helpCard.Margin = "0,0,0,25"

    $helpStack = New-Object System.Windows.Controls.StackPanel

    $helpTitle = New-Object System.Windows.Controls.TextBlock
    $helpTitle.Text = "Помощь"
    $helpTitle.FontSize = 14
    $helpTitle.FontWeight = "Bold"
    $helpTitle.Foreground = "#1565C0"
    $helpTitle.Margin = "0,0,0,10"
    $helpStack.Children.Add($helpTitle) | Out-Null

    $helpDesc = New-Object System.Windows.Controls.TextBlock
    $helpDesc.Text = "Описание программы, руководство по подключению и подсказки по работе с TCL-телевизором."
    $helpDesc.FontSize = 12
    $helpDesc.Foreground = "#2D2D30"
    $helpDesc.TextWrapping = "Wrap"
    $helpDesc.Margin = "0,0,0,12"
    $helpStack.Children.Add($helpDesc) | Out-Null

    $helpBtnPanel = New-Object System.Windows.Controls.StackPanel
    $helpBtnPanel.Orientation = "Horizontal"
    $helpBtnPanel.HorizontalAlignment = "Center"

    # --- Кнопка "О программе" ---
    $btnAbout = New-Object System.Windows.Controls.Button
    $btnAbout.Content = "О программе"
    $btnAbout.Style = $window.Resources["RoundedButton"]
    $btnAbout.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnAbout.Padding = "15,8"
    $btnAbout.Margin = "0,0,8,0"
    $btnAbout.Add_Click({
        Show-HelpDialog -Tab "About"
    })
    $helpBtnPanel.Children.Add($btnAbout) | Out-Null

    # --- Кнопка "Как подключить ТВ" ---
    $btnConnect = New-Object System.Windows.Controls.Button
    $btnConnect.Content = "Как подключить ТВ"
    $btnConnect.Style = $window.Resources["RoundedButton"]
    $btnConnect.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
    )
    $btnConnect.Padding = "15,8"
    $btnConnect.Margin = "0,0,8,0"
    $btnConnect.Add_Click({
        Show-HelpDialog -Tab "Connect"
    })
    $helpBtnPanel.Children.Add($btnConnect) | Out-Null

    # --- Кнопка "Возможности" ---
    $btnFeatures = New-Object System.Windows.Controls.Button
    $btnFeatures.Content = "Возможности"
    $btnFeatures.Style = $window.Resources["RoundedButton"]
    $btnFeatures.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9C27B0")
    )
    $btnFeatures.Padding = "15,8"
    $btnFeatures.Add_Click({
        Show-HelpDialog -Tab "Features"
    })
    $helpBtnPanel.Children.Add($btnFeatures) | Out-Null

    $helpStack.Children.Add($helpBtnPanel) | Out-Null

    $helpCard.Child = $helpStack
    $stack.Children.Add($helpCard) | Out-Null

    # ===== Основные кнопки меню =====
    $btnSetup = New-Object System.Windows.Controls.Button
    $btnSetup.Content = "Настройка"
    $btnSetup.Style = $window.Resources["RoundedButton"]
    $btnSetup.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
    )
    $btnSetup.Width = 400
    $btnSetup.Height = 55
    $btnSetup.FontSize = 15
    $btnSetup.Margin = "0,0,0,12"
    $btnSetup.HorizontalAlignment = "Center"
    $btnSetup.Add_Click({ Switch-View -ViewName "Setup" })
    $stack.Children.Add($btnSetup) | Out-Null

    $btnRollback = New-Object System.Windows.Controls.Button
    $btnRollback.Content = "Откат изменений"
    $btnRollback.Style = $window.Resources["RoundedButton"]
    $btnRollback.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFB74D")
    )
    $btnRollback.Width = 400
    $btnRollback.Height = 55
    $btnRollback.FontSize = 15
    $btnRollback.Margin = "0,0,0,12"
    $btnRollback.HorizontalAlignment = "Center"
    $btnRollback.Add_Click({ Switch-View -ViewName "Rollback" })
    $stack.Children.Add($btnRollback) | Out-Null

    $btnAppSettings = New-Object System.Windows.Controls.Button
    $btnAppSettings.Content = "Настройки приложения"
    $btnAppSettings.Style = $window.Resources["RoundedButton"]
    $btnAppSettings.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#607D8B")
    )
    $btnAppSettings.Width = 400
    $btnAppSettings.Height = 55
    $btnAppSettings.FontSize = 15
    $btnAppSettings.Margin = "0,0,0,12"
    $btnAppSettings.HorizontalAlignment = "Center"
    $btnAppSettings.Add_Click({ Switch-View -ViewName "Settings" })
    $stack.Children.Add($btnAppSettings) | Out-Null

    $btnExit = New-Object System.Windows.Controls.Button
    $btnExit.Content = "Выход"
    $btnExit.Style = $window.Resources["RoundedButton"]
    $btnExit.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E57373")
    )
    $btnExit.Width = 400
    $btnExit.Height = 55
    $btnExit.FontSize = 15
    $btnExit.HorizontalAlignment = "Center"
    $btnExit.Add_Click({ $window.Close() })
    $stack.Children.Add($btnExit) | Out-Null

    $contentGrid.Children.Add($outerGrid) | Out-Null
    Write-Log -Message "Главное меню" -Level "Info"
}

# ============================================================================
#  ДИАЛОГ "ПОМОЩЬ" — вкладки: О программе / Как подключить / Возможности
# ============================================================================
function Show-HelpDialog {
    param([string]$Tab = "About")

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Помощь — TCL TV Manager"
    $dialog.Width = 800
    $dialog.Height = 640
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#F7F7FA"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "20"

    $row1 = New-Object System.Windows.Controls.RowDefinition
    $row1.Height = "Auto"
    $grid.RowDefinitions.Add($row1)

    $row2 = New-Object System.Windows.Controls.RowDefinition
    $row2.Height = "*"
    $grid.RowDefinitions.Add($row2)

    $row3 = New-Object System.Windows.Controls.RowDefinition
    $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row3)

    # --- Вкладки ---
    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Style = $window.Resources["MiuiTabControlTemplate"]
    [System.Windows.Controls.Grid]::SetRow($tabControl, 1)
    $grid.Children.Add($tabControl) | Out-Null

    # ================================================================
    #  ВКЛАДКА 1: О ПРОГРАММЕ
    # ================================================================
    $aboutTab = New-Object System.Windows.Controls.TabItem
    $aboutTab.Header = "О программе"
    $aboutTab.Style = $window.Resources["MiuiTabItem"]

    $aboutScroll = New-Object System.Windows.Controls.ScrollViewer
    $aboutScroll.VerticalScrollBarVisibility = "Auto"

    $aboutStack = New-Object System.Windows.Controls.StackPanel
    $aboutStack.Margin = "20"
    $aboutScroll.Content = $aboutStack

    $aboutTitle = New-Object System.Windows.Controls.TextBlock
    $aboutTitle.Text = "TCL TV Manager"
    $aboutTitle.FontSize = 22
    $aboutTitle.FontWeight = "Bold"
    $aboutTitle.Foreground = "#2D2D30"
    $aboutTitle.Margin = "0,0,0,8"
    $aboutStack.Children.Add($aboutTitle) | Out-Null

    $aboutVersion = New-Object System.Windows.Controls.TextBlock
    $aboutVersion.Text = "Версия 0.0.3"
    $aboutVersion.FontSize = 12
    $aboutVersion.Foreground = "#96969B"
    $aboutVersion.Margin = "0,0,0,20"
    $aboutStack.Children.Add($aboutVersion) | Out-Null

    $aboutText = New-Object System.Windows.Controls.TextBlock
    $aboutText.Text = "Приложение для управления телевизорами TCL на Android TV через ADB. Позволяет настраивать систему, очищать предустановленный мусор, устанавливать приложения, управлять пультом и многое другое — прямо с ПК.`n`nПрограмма не требует установки сторонних приложений на телевизор. Всё делается через встроенный ADB-протокол, который уже используется вашей системой для отладки."
    $aboutText.FontSize = 13
    $aboutText.Foreground = "#2D2D30"
    $aboutText.TextWrapping = "Wrap"
    $aboutText.Margin = "0,0,0,20"
    $aboutStack.Children.Add($aboutText) | Out-Null

    $advHeader = New-Object System.Windows.Controls.TextBlock
    $advHeader.Text = "Важно понимать"
    $advHeader.FontSize = 15
    $advHeader.FontWeight = "Bold"
    $advHeader.Foreground = "#E57373"
    $advHeader.Margin = "0,0,0,8"
    $aboutStack.Children.Add($advHeader) | Out-Null

    $advText = New-Object System.Windows.Controls.TextBlock
    $advText.Text = "• Отключение и удаление системных пакетов может нарушить работу телевизора.`n• Все изменения сохраняются в историю — их можно откатить через раздел «Откат изменений».`n• Перед серьёзными операциями рекомендуется сделать бэкап через «Экспорт дампа устройства».`n• Программа работает напрямую с ADB — если ТВ отключится, изменения не применятся."
    $advText.FontSize = 12
    $advText.Foreground = "#2D2D30"
    $advText.TextWrapping = "Wrap"
    $aboutStack.Children.Add($advText) | Out-Null

    $aboutTab.Content = $aboutScroll
    $tabControl.Items.Add($aboutTab) | Out-Null

    # ================================================================
    #  ВКЛАДКА 2: КАК ПОДКЛЮЧИТЬ ТВ
    # ================================================================
    $connectTab = New-Object System.Windows.Controls.TabItem
    $connectTab.Header = "Как подключить ТВ"
    $connectTab.Style = $window.Resources["MiuiTabItem"]

    $connScroll = New-Object System.Windows.Controls.ScrollViewer
    $connScroll.VerticalScrollBarVisibility = "Auto"

    $connStack = New-Object System.Windows.Controls.StackPanel
    $connStack.Margin = "20"
    $connScroll.Content = $connStack

    $connTitle = New-Object System.Windows.Controls.TextBlock
    $connTitle.Text = "Пошаговая инструкция"
    $connTitle.FontSize = 18
    $connTitle.FontWeight = "Bold"
    $connTitle.Foreground = "#2D2D30"
    $connTitle.Margin = "0,0,0,15"
    $connStack.Children.Add($connTitle) | Out-Null

    # Шаг 1
    $step1 = New-Object System.Windows.Controls.TextBlock
    $step1.FontSize = 14
    $step1.FontWeight = "Bold"
    $step1.Foreground = "#4A90E2"
    $step1.Text = "Шаг 1. Включите режим разработчика на ТВ"
    $step1.Margin = "0,0,0,6"
    $connStack.Children.Add($step1) | Out-Null

    $step1Text = New-Object System.Windows.Controls.TextBlock
    $step1Text.FontSize = 12
    $step1Text.Foreground = "#2D2D30"
    $step1Text.TextWrapping = "Wrap"
    $step1Text.Margin = "0,0,0,15"
    $step1Text.Text = "Откройте «Настройки» → «О телевизоре» → «Сборка». Нажмите на «Сборка» 7 раз подряд. Появится сообщение «Вы стали разработчиком»."
    $connStack.Children.Add($step1Text) | Out-Null

    # Шаг 2
    $step2 = New-Object System.Windows.Controls.TextBlock
    $step2.FontSize = 14
    $step2.FontWeight = "Bold"
    $step2.Foreground = "#4A90E2"
    $step2.Text = "Шаг 2. Включите отладку по ADB"
    $step2.Margin = "0,0,0,6"
    $connStack.Children.Add($step2) | Out-Null

    $step2Text = New-Object System.Windows.Controls.TextBlock
    $step2Text.FontSize = 12
    $step2Text.Foreground = "#2D2D30"
    $step2Text.TextWrapping = "Wrap"
    $step2Text.Margin = "0,0,0,15"
    $step2Text.Text = "Зайдите в «Настройки» → «Для разработчиков». Включите: «Отладка по ADB» и «Отладка по сети» (если есть). Также рекомендуется отключить «Автообновление системы»."
    $connStack.Children.Add($step2Text) | Out-Null

    # Шаг 3
    $step3 = New-Object System.Windows.Controls.TextBlock
    $step3.FontSize = 14
    $step3.FontWeight = "Bold"
    $step3.Foreground = "#4A90E2"
    $step3.Text = "Шаг 3. Узнайте IP-адрес телевизора"
    $step3.Margin = "0,0,0,6"
    $connStack.Children.Add($step3) | Out-Null

    $step3Text = New-Object System.Windows.Controls.TextBlock
    $step3Text.FontSize = 12
    $step3Text.Foreground = "#2D2D30"
    $step3Text.TextWrapping = "Wrap"
    $step3Text.Margin = "0,0,0,15"
    $step3Text.Text = "«Настройки» → «Сеть» → «Wi-Fi» → выберите текущую сеть. IP-адрес будет указан в деталях подключения (например, 192.168.0.104)."
    $connStack.Children.Add($step3Text) | Out-Null

    # Шаг 4
    $step4 = New-Object System.Windows.Controls.TextBlock
    $step4.FontSize = 14
    $step4.FontWeight = "Bold"
    $step4.Foreground = "#4A90E2"
    $step4.Text = "Шаг 4. Подключитесь в программе"
    $step4.Margin = "0,0,0,6"
    $connStack.Children.Add($step4) | Out-Null

    $step4Text = New-Object System.Windows.Controls.TextBlock
    $step4Text.FontSize = 12
    $step4Text.Foreground = "#2D2D30"
    $step4Text.TextWrapping = "Wrap"
    $step4Text.Margin = "0,0,0,15"
    $step4Text.Text = "На главном экране нажмите «Настройка». Введите IP-адрес телевизора или нажмите «Сканировать» для поиска в сети. Нажмите «Подключиться»."
    $connStack.Children.Add($step4Text) | Out-Null

    # Шаг 5
    $step5 = New-Object System.Windows.Controls.TextBlock
    $step5.FontSize = 14
    $step5.FontWeight = "Bold"
    $step5.Foreground = "#4A90E2"
    $step5.Text = "Шаг 5. Разрешите отладку на ТВ"
    $step5.Margin = "0,0,0,6"
    $connStack.Children.Add($step5) | Out-Null

    $step5Text = New-Object System.Windows.Controls.TextBlock
    $step5Text.FontSize = 12
    $step5Text.Foreground = "#2D2D30"
    $step5Text.TextWrapping = "Wrap"
    $step5Text.Margin = "0,0,0,20"
    $step5Text.Text = "На экране телевизора появится запрос «Разрешить отладку по USB?». Поставьте галочку «Всегда разрешать с этого компьютера» и нажмите «ОК». Готово — программа подключится автоматически."
    $connStack.Children.Add($step5Text) | Out-Null

    # --- Возможные проблемы ---
    $troubleHeader = New-Object System.Windows.Controls.TextBlock
    $troubleHeader.Text = "Если что-то не работает"
    $troubleHeader.FontSize = 15
    $troubleHeader.FontWeight = "Bold"
    $troubleHeader.Foreground = "#E57373"
    $troubleHeader.Margin = "0,10,0,10"
    $connStack.Children.Add($troubleHeader) | Out-Null

    $troubleText = New-Object System.Windows.Controls.TextBlock
    $troubleText.FontSize = 12
    $troubleText.Foreground = "#2D2D30"
    $troubleText.TextWrapping = "Wrap"
    $troubleText.Text = "• «Не удалось подключиться» — проверьте, что ПК и ТВ в одной Wi-Fi сети. Если ПК по кабелю, а ТВ по Wi-Fi — сканирование может не работать, вводите IP вручную.`n`n• «Unauthorized» — на экране ТВ не появилось окно подтверждения. Отзовите разрешения через «Для разработчиков» → «Отозвать разрешения отладки» и попробуйте снова.`n`n• «Connection refused» — отладка по сети выключена. Включите её в «Для разработчиков».`n`n• ТВ не подключается после перезагрузки — подождите 30-60 секунд после включения, отладка по сети включается не сразу."
    $connStack.Children.Add($troubleText) | Out-Null

    $connectTab.Content = $connScroll
    $tabControl.Items.Add($connectTab) | Out-Null

    # ================================================================
    #  ВКЛАДКА 3: ВОЗМОЖНОСТИ
    # ================================================================
    $featuresTab = New-Object System.Windows.Controls.TabItem
    $featuresTab.Header = "Возможности"
    $featuresTab.Style = $window.Resources["MiuiTabItem"]

    $featScroll = New-Object System.Windows.Controls.ScrollViewer
    $featScroll.VerticalScrollBarVisibility = "Auto"

    $featStack = New-Object System.Windows.Controls.StackPanel
    $featStack.Margin = "20"
    $featScroll.Content = $featStack

    $featTitle = New-Object System.Windows.Controls.TextBlock
    $featTitle.Text = "Что умеет программа"
    $featTitle.FontSize = 18
    $featTitle.FontWeight = "Bold"
    $featTitle.Foreground = "#2D2D30"
    $featTitle.Margin = "0,0,0,15"
    $featStack.Children.Add($featTitle) | Out-Null

    $features = @(
        @{
            Title = "📦 Управление приложениями"
            Where = "Setup → Управление пакетами"
            Text  = "Отключение и удаление предустановленного мусора (реклама, телеметрия, TCL-сервисы). Просмотр всех установленных, системных и сторонних приложений. Очистка данных и кэша."
        },
        @{
            Title = "📥 Установка приложений"
            Where = "Setup → Установить APK"
            Text  = "Пакетная установка .apk, .apks, .xapk, .apkm из папки или по одному файлу. Установка APK, лежащего на самом ТВ, через файловый менеджер."
        },
        @{
            Title = "🎮 Пульт"
            Where = "Setup → Инструменты → Пульт"
            Text  = "Полноценный пульт с крестовиной, громкостью, медиа-кнопками. Управление с клавиатуры ПК (стрелки, Enter, Space, +/-). Ввод текста с возможностью использования ADBKeyboard для кириллицы."
        },
        @{
            Title = "🖥 Разрешение и DPI"
            Where = "Setup → Система → Разрешение и DPI"
            Text  = "Смена разрешения экрана (720p / 1080p / 1440p / 4K) и плотности пикселей (DPI). Пресеты + кастомные значения. Возможность сброса к заводским."
        },
        @{
            Title = "⚙️ Пресеты настроек"
            Where = "Setup → Система → Пресеты настроек"
            Text  = "30 готовых настроек в 3 вкладках: тайм-аут экрана, яркость, анимации, immersive-режим, dev-настройки. Применяются одним кликом, сохраняются для отката."
        },
        @{
            Title = "📊 Сведения и дамп"
            Where = "Setup → Система → Сведения об устройстве"
            Text  = "Полная информация о ТВ: модель, Android, CPU, RAM, Storage, IP. Экспорт дампа в JSON или TXT для бэкапа перед экспериментами."
        },
        @{
            Title = "🧩 Проверка целостности"
            Where = "Setup → Система → Проверка целостности"
            Text  = "Сравнение текущего состояния ТВ с сохранённым дампом. Показывает, что изменилось с момента снятия дампа."
        },
        @{
            Title = "📸 Скриншоты и запись"
            Where = "Setup → Инструменты → Скриншот"
            Text  = "Скриншоты экрана и запись видео с прогресс-баром. Галерея сохранённых файлов. Автосохранение в Desktop\\screenshot_tv\\."
        },
        @{
            Title = "📜 Logcat"
            Where = "Setup → Система → ADB-команды"
            Text  = "Живые логи Android в реальном времени. Фильтр по тегу и уровню. Сохранение в файл."
        },
        @{
            Title = "🛠 Сервис — 100+ команд"
            Where = "Setup → Система → ADB-команды"
            Text  = "Готовые команды по категориям: информация, производительность, сеть, экран, звук, приложения, отладка. Возможность ввести свою команду."
        },
        @{
            Title = "👤 Профили и сценарии"
            Where = "Setup → Система → Профили устройств"
            Text  = "Сохранение состояния ТВ как профиля (какие пакеты отключены, какие настройки). Применение профиля к другому ТВ одним кликом."
        },
        @{
            Title = "⏪ Откат изменений"
            Where = "Главное меню → Откат изменений"
            Text  = "Все действия логируются. Каждое изменение хранит команду восстановления. Массовый откат выбранных операций."
        },
        @{
            Title = "📶 Wi-Fi"
            Where = "Setup → Система → Wi-Fi"
            Text  = "Просмотр текущего подключения (SSID, IP, MAC, шлюз, DNS, сигнал). Список доступных сетей. Без переключения из приложения (чтобы не разорвать ADB)."
        },
        @{
            Title = "📊 Процессы ТВ"
            Where = "Setup → Система → Процессы ТВ"
            Text  = "Топ процессов по CPU или памяти. Возможность остановить приложение (force-stop)."
        }
    )

    foreach ($feat in $features) {
        $itemCard = New-Object System.Windows.Controls.Border
        $itemCard.Background = "White"
        $itemCard.BorderBrush = "#E1E1E6"
        $itemCard.BorderThickness = "1"
        $itemCard.CornerRadius = "8"
        $itemCard.Padding = "12"
        $itemCard.Margin = "0,0,0,10"

        $itemStack = New-Object System.Windows.Controls.StackPanel

        $itemTitle = New-Object System.Windows.Controls.TextBlock
        $itemTitle.Text = $feat.Title
        $itemTitle.FontSize = 14
        $itemTitle.FontWeight = "Bold"
        $itemTitle.Foreground = "#2D2D30"
        $itemStack.Children.Add($itemTitle) | Out-Null

        $itemWhere = New-Object System.Windows.Controls.TextBlock
        $itemWhere.Text = "Где найти: $($feat.Where)"
        $itemWhere.FontSize = 11
        $itemWhere.Foreground = "#4A90E2"
        $itemWhere.Margin = "0,3,0,5"
        $itemStack.Children.Add($itemWhere) | Out-Null

        $itemText = New-Object System.Windows.Controls.TextBlock
        $itemText.Text = $feat.Text
        $itemText.FontSize = 12
        $itemText.Foreground = "#2D2D30"
        $itemText.TextWrapping = "Wrap"
        $itemStack.Children.Add($itemText) | Out-Null

        $itemCard.Child = $itemStack
        $featStack.Children.Add($itemCard) | Out-Null
    }

    $featuresTab.Content = $featScroll
    $tabControl.Items.Add($featuresTab) | Out-Null

    # --- Выбор вкладки по умолчанию ---
    switch ($Tab) {
        "Connect"  { $tabControl.SelectedIndex = 1 }
        "Features" { $tabControl.SelectedIndex = 2 }
        default    { $tabControl.SelectedIndex = 0 }
    }

    # --- Кнопка "Закрыть" ---
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnClose.Padding = "15,8"
    $btnClose.HorizontalAlignment = "Right"
    $btnClose.Margin = "0,15,0,0"
    $btnClose.Add_Click({ $dialog.Close() })
    [System.Windows.Controls.Grid]::SetRow($btnClose, 2)
    $grid.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}