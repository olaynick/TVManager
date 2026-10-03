function Show-MainView {
    $outerGrid = New-Object System.Windows.Controls.Grid

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    $outerGrid.Children.Add($scroll) | Out-Null

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.HorizontalAlignment = "Center"
    $stack.VerticalAlignment = "Top"
    $stack.Width = 500
    $stack.Margin = "0,40,0,40"
    $scroll.Content = $stack

    # ===== Заголовок =====
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "TCL TV Manager"
    $title.FontSize = 32
    $title.FontWeight = "Bold"
    $title.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $title.HorizontalAlignment = "Center"
    $title.Margin = "0,0,0,6"
    $stack.Children.Add($title) | Out-Null

    $subtitle = New-Object System.Windows.Controls.TextBlock
    $subtitle.Text = "Управление телевизором через ADB"
    $subtitle.FontSize = 13
    $subtitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $subtitle.HorizontalAlignment = "Center"
    $subtitle.Margin = "0,0,0,30"
    $stack.Children.Add($subtitle) | Out-Null

    # ===== Основные кнопки =====
    $btnSetup = New-Object System.Windows.Controls.Button
    $btnSetup.Content = "Настройка"
    $btnSetup.Style = $window.Resources["RoundedButton"]
    $btnSetup.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnSetup.Width = 400
    $btnSetup.Height = 50
    $btnSetup.FontSize = 14
    $btnSetup.Margin = "0,0,0,10"
    $btnSetup.HorizontalAlignment = "Center"
    $btnSetup.Add_Click({ Switch-View -ViewName "Setup" })
    $stack.Children.Add($btnSetup) | Out-Null

    $btnRollback = New-Object System.Windows.Controls.Button
    $btnRollback.Content = "Откат изменений"
    $btnRollback.Style = $window.Resources["RoundedButton"]
    $btnRollback.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
    )
    $btnRollback.Width = 400
    $btnRollback.Height = 50
    $btnRollback.FontSize = 14
    $btnRollback.Margin = "0,0,0,10"
    $btnRollback.HorizontalAlignment = "Center"
    $btnRollback.Add_Click({ Switch-View -ViewName "Rollback" })
    $stack.Children.Add($btnRollback) | Out-Null

    $btnAppSettings = New-Object System.Windows.Controls.Button
    $btnAppSettings.Content = "Настройки приложения"
    $btnAppSettings.Style = $window.Resources["RoundedButton"]
    $btnAppSettings.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnAppSettings.Width = 400
    $btnAppSettings.Height = 50
    $btnAppSettings.FontSize = 14
    $btnAppSettings.Margin = "0,0,0,10"
    $btnAppSettings.HorizontalAlignment = "Center"
    $btnAppSettings.Add_Click({ Switch-View -ViewName "Settings" })
    $stack.Children.Add($btnAppSettings) | Out-Null

    $btnExit = New-Object System.Windows.Controls.Button
    $btnExit.Content = "Выход"
    $btnExit.Style = $window.Resources["RoundedButton"]
    $btnExit.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
    )
    $btnExit.Width = 400
    $btnExit.Height = 50
    $btnExit.FontSize = 14
    $btnExit.HorizontalAlignment = "Center"
    $btnExit.Add_Click({ $window.Close() })
    $stack.Children.Add($btnExit) | Out-Null

    # ===== Статус ADB (внизу) =====
    $adbReady = Test-AdbInPath

    $statusPanel = New-Object System.Windows.Controls.StackPanel
    $statusPanel.Orientation = "Horizontal"
    $statusPanel.HorizontalAlignment = "Center"
    $statusPanel.Margin = "0,30,0,10"

    $statusDot = New-Object System.Windows.Shapes.Ellipse
    $statusDot.Width = 8
    $statusDot.Height = 8
    if ($adbReady) {
        $statusDot.Fill = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } else {
        $statusDot.Fill = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FF6B6B")
        )
    }
    $statusDot.VerticalAlignment = "Center"
    $statusDot.Margin = "0,0,8,0"
    $statusPanel.Children.Add($statusDot) | Out-Null

    $statusLabel = New-Object System.Windows.Controls.TextBlock
    $statusLabel.Text = if ($adbReady) { "ADB найден — программа готова к работе" } else { "ADB не настроен — потребуется установка" }
    $statusLabel.FontSize = 12
    $statusLabel.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $statusLabel.VerticalAlignment = "Center"
    $statusPanel.Children.Add($statusLabel) | Out-Null

    $stack.Children.Add($statusPanel) | Out-Null

    # ===== Кнопка "Как установить ADB" =====
    if (-not $adbReady) {
        $btnAdbHelp = New-Object System.Windows.Controls.Button
        $btnAdbHelp.Content = "Как установить ADB?"
        $btnAdbHelp.Style = $window.Resources["RoundedButton"]
        $btnAdbHelp.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
        )
        $btnAdbHelp.Padding = "15,8"
        $btnAdbHelp.HorizontalAlignment = "Center"
        $btnAdbHelp.Margin = "0,0,0,10"
        $btnAdbHelp.Add_Click({ Show-AdbHelpDialog })
        $stack.Children.Add($btnAdbHelp) | Out-Null
    }

    # ===== Карточка "Помощь" (внизу) =====
    $helpCard = New-Object System.Windows.Controls.Border
    $helpCard.Background = "#1A2A3A"
    $helpCard.BorderBrush = "#3A5A7A"
    $helpCard.BorderThickness = "1"
    $helpCard.CornerRadius = "8"
    $helpCard.Padding = "15"
    $helpCard.Margin = "0,10,0,10"
    $helpCard.Width = 400

    $helpStack = New-Object System.Windows.Controls.StackPanel

    $helpTitle = New-Object System.Windows.Controls.TextBlock
    $helpTitle.Text = "Помощь"
    $helpTitle.FontSize = 13
    $helpTitle.FontWeight = "Bold"
    $helpTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
    )
    $helpTitle.Margin = "0,0,0,8"
    $helpStack.Children.Add($helpTitle) | Out-Null

    $helpDesc = New-Object System.Windows.Controls.TextBlock
    $helpDesc.Text = "Описание программы, руководство по подключению и подсказки."
    $helpDesc.FontSize = 11
    $helpDesc.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $helpDesc.TextWrapping = "Wrap"
    $helpDesc.Margin = "0,0,0,10"
    $helpStack.Children.Add($helpDesc) | Out-Null

    $helpBtnPanel = New-Object System.Windows.Controls.StackPanel
    $helpBtnPanel.Orientation = "Horizontal"
    $helpBtnPanel.HorizontalAlignment = "Center"

    $btnAbout = New-Object System.Windows.Controls.Button
    $btnAbout.Content = "О программе"
    $btnAbout.Style = $window.Resources["RoundedButton"]
    $btnAbout.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnAbout.Padding = "10,5"
    $btnAbout.FontSize = 11
    $btnAbout.Margin = "0,0,6,0"
    $btnAbout.Add_Click({ Show-HelpDialog -Tab "About" })
    $helpBtnPanel.Children.Add($btnAbout) | Out-Null

    $btnConnect = New-Object System.Windows.Controls.Button
    $btnConnect.Content = "Как подключить"
    $btnConnect.Style = $window.Resources["RoundedButton"]
    $btnConnect.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnConnect.Padding = "10,5"
    $btnConnect.FontSize = 11
    $btnConnect.Margin = "0,0,6,0"
    $btnConnect.Add_Click({ Show-HelpDialog -Tab "Connect" })
    $helpBtnPanel.Children.Add($btnConnect) | Out-Null

    $btnFeatures = New-Object System.Windows.Controls.Button
    $btnFeatures.Content = "Возможности"
    $btnFeatures.Style = $window.Resources["RoundedButton"]
    $btnFeatures.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#6c547e")
    )
    $btnFeatures.Padding = "10,5"
    $btnFeatures.FontSize = 11
    $btnFeatures.Add_Click({ Show-HelpDialog -Tab "Features" })
    $helpBtnPanel.Children.Add($btnFeatures) | Out-Null

    $helpStack.Children.Add($helpBtnPanel) | Out-Null

    $helpCard.Child = $helpStack
    $stack.Children.Add($helpCard) | Out-Null

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
    $dialog.Background = "#202020"

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
    $aboutTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $aboutTitle.Margin = "0,0,0,8"
    $aboutStack.Children.Add($aboutTitle) | Out-Null

    $aboutVersion = New-Object System.Windows.Controls.TextBlock
    $aboutVersion.Text = "Версия 0.0.4"
    $aboutVersion.FontSize = 12
    $aboutVersion.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $aboutVersion.Margin = "0,0,0,20"
    $aboutStack.Children.Add($aboutVersion) | Out-Null

    $aboutText = New-Object System.Windows.Controls.TextBlock
    $aboutText.Text = "Приложение для управления телевизорами TCL на Android TV через ADB. Позволяет настраивать систему, очищать предустановленный мусор, устанавливать приложения, управлять пультом и многое другое — прямо с ПК.`n`nПрограмма не требует установки сторонних приложений на телевизор. Всё делается через встроенный ADB-протокол."
    $aboutText.FontSize = 13
    $aboutText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $aboutText.TextWrapping = "Wrap"
    $aboutText.Margin = "0,0,0,20"
    $aboutStack.Children.Add($aboutText) | Out-Null

    $advHeader = New-Object System.Windows.Controls.TextBlock
    $advHeader.Text = "Важно понимать"
    $advHeader.FontSize = 15
    $advHeader.FontWeight = "Bold"
    $advHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $advHeader.Margin = "0,0,0,8"
    $aboutStack.Children.Add($advHeader) | Out-Null

    $advText = New-Object System.Windows.Controls.TextBlock
    $advText.Text = "• Отключение и удаление системных пакетов может нарушить работу телевизора.`n• Все изменения сохраняются в историю — их можно откатить через раздел «Откат изменений».`n• Перед серьёзными операциями рекомендуется сделать бэкап через «Экспорт дампа устройства».`n• Программа работает напрямую с ADB — если ТВ отключится, изменения не применятся."
    $advText.FontSize = 12
    $advText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
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
    $connTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $connTitle.Margin = "0,0,0,15"
    $connStack.Children.Add($connTitle) | Out-Null

    $steps = @(
        @{
            Title = "Шаг 1. Включите режим разработчика на ТВ"
            Text = "Откройте «Настройки» → «О телевизоре» → «Сборка». Нажмите на «Сборка» 7 раз подряд. Появится сообщение «Вы стали разработчиком»."
        },
        @{
            Title = "Шаг 2. Включите отладку по ADB"
            Text = "Зайдите в «Настройки» → «Для разработчиков». Включите: «Отладка по ADB» и «Отладка по сети» (если есть)."
        },
        @{
            Title = "Шаг 3. Узнайте IP-адрес телевизора"
            Text = "«Настройки» → «Сеть» → «Wi-Fi» → выберите текущую сеть. IP-адрес будет указан в деталях подключения."
        },
        @{
            Title = "Шаг 4. Подключитесь в программе"
            Text = "На главном экране нажмите «Настройка». Введите IP-адрес телевизора или нажмите «Сканировать» для поиска в сети."
        },
        @{
            Title = "Шаг 5. Разрешите отладку на ТВ"
            Text = "На экране телевизора появится запрос «Разрешить отладку по USB?». Поставьте галочку «Всегда разрешать» и нажмите «ОК»."
        }
    )

    foreach ($step in $steps) {
        $stepTitle = New-Object System.Windows.Controls.TextBlock
        $stepTitle.Text = $step.Title
        $stepTitle.FontSize = 14
        $stepTitle.FontWeight = "Bold"
        $stepTitle.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $stepTitle.Margin = "0,0,0,6"
        $connStack.Children.Add($stepTitle) | Out-Null

        $stepText = New-Object System.Windows.Controls.TextBlock
        $stepText.Text = $step.Text
        $stepText.FontSize = 12
        $stepText.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $stepText.TextWrapping = "Wrap"
        $stepText.Margin = "0,0,0,15"
        $connStack.Children.Add($stepText) | Out-Null
    }

    $troubleHeader = New-Object System.Windows.Controls.TextBlock
    $troubleHeader.Text = "Если что-то не работает"
    $troubleHeader.FontSize = 15
    $troubleHeader.FontWeight = "Bold"
    $troubleHeader.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $troubleHeader.Margin = "0,10,0,10"
    $connStack.Children.Add($troubleHeader) | Out-Null

    $troubleText = New-Object System.Windows.Controls.TextBlock
    $troubleText.Text = "• «Не удалось подключиться» — проверьте, что ПК и ТВ в одной Wi-Fi сети.`n`n• «Unauthorized» — на экране ТВ не появилось окно подтверждения. Отзовите разрешения через «Для разработчиков» → «Отозвать разрешения отладки» и попробуйте снова.`n`n• «Connection refused» — отладка по сети выключена. Включите её в «Для разработчиков».`n`n• ТВ не подключается после перезагрузки — подождите 30-60 секунд, отладка включается не сразу."
    $troubleText.FontSize = 12
    $troubleText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
    )
    $troubleText.TextWrapping = "Wrap"
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
    $featTitle.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $featTitle.Margin = "0,0,0,15"
    $featStack.Children.Add($featTitle) | Out-Null

    $features = @(
        @{ Title = "Управление приложениями";  Where = "Setup → Управление пакетами"; Text = "Отключение и удаление предустановленного мусора. 6 категорий, поиск, сквозной фильтр." }
        @{ Title = "Установка приложений";     Where = "Setup → Установить APK";       Text = "Установка .apk, .apks, .xapk, .apkm, .zip. Пакетно, в фоне." }
        @{ Title = "Пульт";                    Where = "Setup → Инструменты → Пульт";  Text = "Управление с клавиатуры ПК. Хоткеи, ввод текста." }
        @{ Title = "Разрешение и DPI";         Where = "Setup → Система";              Text = "Пресеты 720p – 4K. Кастомные значения, сброс." }
        @{ Title = "Пресеты настроек";         Where = "Setup → Система";              Text = "30 готовых пресетов: тайм-аут, анимации, яркость." }
        @{ Title = "Сценарии";                 Where = "Setup → Система";              Text = "Пакетный режим — набор шагов, выполняется одной кнопкой." }
        @{ Title = "Автозапуск и фон";         Where = "Setup → Система";              Text = "Управление фоновой активностью через appops." }
        @{ Title = "Разрешения приложений";    Where = "Setup → Система";              Text = "Просмотр и управление разрешениями с описаниями." }
        @{ Title = "Температура ТВ";           Where = "Setup → Система";              Text = "Мониторинг термодатчиков, график." }
        @{ Title = "Проверка целостности";     Where = "Setup → Система";              Text = "Сравнение ТВ с сохранённым дампом." }
        @{ Title = "Экспорт дампа";            Where = "Setup → Система";              Text = "Полный дамп устройства в JSON или TXT." }
        @{ Title = "Процессы ТВ";              Where = "Setup → Система";              Text = "Топ по CPU/RAM, остановка приложений." }
        @{ Title = "Откат изменений";          Where = "Главное меню";                 Text = "История действий с командой восстановления." }
    )

    foreach ($feat in $features) {
        $itemCard = New-Object System.Windows.Controls.Border
        $itemCard.Background = "#2B2B2B"
        $itemCard.BorderBrush = "#3A3A3A"
        $itemCard.BorderThickness = "1"
        $itemCard.CornerRadius = "8"
        $itemCard.Padding = "12"
        $itemCard.Margin = "0,0,0,10"

        $itemStack = New-Object System.Windows.Controls.StackPanel

        $itemTitle = New-Object System.Windows.Controls.TextBlock
        $itemTitle.Text = $feat.Title
        $itemTitle.FontSize = 14
        $itemTitle.FontWeight = "Bold"
        $itemTitle.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
        )
        $itemStack.Children.Add($itemTitle) | Out-Null

        $itemWhere = New-Object System.Windows.Controls.TextBlock
        $itemWhere.Text = "Где найти: $($feat.Where)"
        $itemWhere.FontSize = 11
        $itemWhere.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#60CDFF")
        )
        $itemWhere.Margin = "0,3,0,5"
        $itemStack.Children.Add($itemWhere) | Out-Null

        $itemText = New-Object System.Windows.Controls.TextBlock
        $itemText.Text = $feat.Text
        $itemText.FontSize = 12
        $itemText.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
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
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
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