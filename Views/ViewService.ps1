function Show-ServiceView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Сервис — полезные ADB-команды"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Готовые команды для диагностики и управления ТВ. Выполняются с текущим подключением." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    $commands = Get-AdbCommandsList
    Write-Log -Message "Команд получено: $(@($commands).Count)" -Level "Info"

    $categories = $commands | Group-Object Category
    Write-Log -Message "Категорий: $(@($categories).Count)" -Level "Info"

    # ===== ВКЛАДКИ КАТЕГОРИЙ =====
    $catTabs = New-Object System.Windows.Controls.TabControl
    $catTabs.Style = $window.Resources["MiuiTabControlTemplate"]
    $catTabs.Margin = "0,10,0,0"

    foreach ($cat in $categories) {
        $tab = New-Object System.Windows.Controls.TabItem
        $tab.Header = "$($cat.Name) ($($cat.Count))"
        $tab.Style = $window.Resources["MiuiTabItem"]

        $tabPanel = New-Object System.Windows.Controls.StackPanel
        $tabPanel.Margin = "15"

        $grid = New-Object System.Windows.Controls.Grid
        $cols = 2
        for ($i = 0; $i -lt $cols; $i++) {
            $col = New-Object System.Windows.Controls.ColumnDefinition
            $col.Width = "*"
            $grid.ColumnDefinitions.Add($col)
        }

        $rowCount = [math]::Ceiling($cat.Group.Count / $cols)
        for ($r = 0; $r -lt $rowCount; $r++) {
            $row = New-Object System.Windows.Controls.RowDefinition
            $row.Height = "Auto"
            $grid.RowDefinitions.Add($row)
        }

        $index = 0
        foreach ($cmd in $cat.Group) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Content = $cmd.Name
            $btn.Style = $window.Resources["RoundedButton"]
            $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
            )
            $btn.Padding = "10,8"
            $btn.Margin = "0,0,8,8"
            $btn.FontSize = 11
            $btn.HorizontalAlignment = "Stretch"

            $localCmd = $cmd.Command
            $localDesc = $cmd.Desc
            $btn.Add_Click({
                Invoke-AdbCommand -Command $localCmd -Description $localDesc
            }.GetNewClosure())

            $row = [math]::Floor($index / $cols)
            $col = $index % $cols
            [System.Windows.Controls.Grid]::SetRow($btn, $row)
            [System.Windows.Controls.Grid]::SetColumn($btn, $col)
            $grid.Children.Add($btn) | Out-Null
            $index++
        }

        $tabPanel.Children.Add($grid) | Out-Null
        $tab.Content = $tabPanel
        $catTabs.Items.Add($tab) | Out-Null
    }

    $mainStack.Children.Add($catTabs) | Out-Null
    Write-Log -Message "Вкладки добавлены: $($catTabs.Items.Count)" -Level "Info"

    # ===== СВОЯ КОМАНДА =====
    $mainStack.Children.Add((New-StepTitle -Text "Своя команда")) | Out-Null

    $customPanel = New-Object System.Windows.Controls.StackPanel
    $customPanel.Orientation = "Horizontal"
    $customPanel.Margin = "0,5,0,0"

    $script:ServiceCustomBox = New-Object System.Windows.Controls.TextBox
    $script:ServiceCustomBox.Style = $window.Resources["RoundedTextBox"]
    $script:ServiceCustomBox.FontSize = 13
    $script:ServiceCustomBox.Width = 500
    $customPanel.Children.Add($script:ServiceCustomBox) | Out-Null

    # "Выполнить"
    $btnRun = New-Object System.Windows.Controls.Button
    $btnRun.Content = "Выполнить"
    $btnRun.Style = $window.Resources["RoundedButton"]
    $btnRun.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
    )
    $btnRun.Padding = "15,6"
    $btnRun.Margin = "10,0,0,0"
    $btnRun.Add_Click({
        $cmd = $script:ServiceCustomBox.Text.Trim()
        if ($cmd) {
            Invoke-AdbCommand -Command $cmd -Description "Пользовательская команда"
        } else {
            Write-Log -Message "Введите команду" -Level "Warning"
        }
    })
    $customPanel.Children.Add($btnRun) | Out-Null

    # "Просмотреть список"
    $btnViewList = New-Object System.Windows.Controls.Button
    $btnViewList.Content = "Просмотреть список"
    $btnViewList.Style = $window.Resources["RoundedButton"]
    $btnViewList.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#64B5F6")
    )
    $btnViewList.Padding = "15,6"
    $btnViewList.Margin = "10,0,0,0"
    $btnViewList.Add_Click({
        Show-AdbCommandsList
    })
    $customPanel.Children.Add($btnViewList) | Out-Null

    $mainStack.Children.Add($customPanel) | Out-Null

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран сервиса" -Level "Info"
}

# ===== ДИАЛОГ "ПРОСМОТР СПИСКА КОМАНД" =====
function Show-AdbCommandsList {
    $commands = Get-AdbExtraCommands
    Write-Log -Message "Доп. команд: $(@($commands).Count)" -Level "Info"

    $categories = $commands | Group-Object Category

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Справочник ADB-команд"
    $dialog.Width = 900
    $dialog.Height = 700
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

    $header = New-ViewHeader -Text "Справочник ADB-команд ($($commands.Count))" -X 0 -Y 0
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $grid.Children.Add($header) | Out-Null

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $stack = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $stack

    foreach ($cat in $categories) {
        # Заголовок категории
        $catHeader = New-Object System.Windows.Controls.TextBlock
        $catHeader.Text = "$($cat.Name) ($($cat.Count))"
        $catHeader.FontSize = 15
        $catHeader.FontWeight = "Bold"
        $catHeader.Foreground = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#4A90E2")
        )
        $catHeader.Margin = "0,15,0,8"
        $stack.Children.Add($catHeader) | Out-Null

        foreach ($cmd in $cat.Group) {
            # Карточка команды
            $card = New-Object System.Windows.Controls.Border
            $card.Background = "White"
            $card.BorderBrush = "#E1E1E6"
            $card.BorderThickness = "1"
            $card.CornerRadius = "6"
            $card.Padding = "10"
            $card.Margin = "0,0,0,6"

            $cardGrid = New-Object System.Windows.Controls.Grid
            $cc1 = New-Object System.Windows.Controls.ColumnDefinition
            $cc1.Width = "*"
            $cc2 = New-Object System.Windows.Controls.ColumnDefinition
            $cc2.Width = "Auto"
            $cc3 = New-Object System.Windows.Controls.ColumnDefinition
            $cc3.Width = "Auto"
            $cardGrid.ColumnDefinitions.Add($cc1)
            $cardGrid.ColumnDefinitions.Add($cc2)
            $cardGrid.ColumnDefinitions.Add($cc3)

            # Текст
            $textStack = New-Object System.Windows.Controls.StackPanel
            [System.Windows.Controls.Grid]::SetColumn($textStack, 0)

            $nameTb = New-Object System.Windows.Controls.TextBlock
            $nameTb.Text = $cmd.Name
            $nameTb.FontSize = 13
            $nameTb.FontWeight = "Bold"
            $nameTb.Foreground = "#2D2D30"
            $textStack.Children.Add($nameTb) | Out-Null

            $cmdTb = New-Object System.Windows.Controls.TextBlock
            $cmdTb.Text = "adb $($cmd.Command)"
            $cmdTb.FontFamily = "Consolas"
            $cmdTb.FontSize = 11
            $cmdTb.Foreground = "#4A90E2"
            $cmdTb.Margin = "0,2,0,2"
            $textStack.Children.Add($cmdTb) | Out-Null

            $descTb = New-Object System.Windows.Controls.TextBlock
            $descTb.Text = $cmd.Desc
            $descTb.FontSize = 11
            $descTb.Foreground = "#96969B"
            $textStack.Children.Add($descTb) | Out-Null

            $cardGrid.Children.Add($textStack) | Out-Null

            # Кнопка "Вставить"
            $btnInsert = New-Object System.Windows.Controls.Button
            $btnInsert.Content = "Вставить"
            $btnInsert.Style = $window.Resources["RoundedButton"]
            $btnInsert.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#64B5F6")
            )
            $btnInsert.Padding = "10,5"
            $btnInsert.Margin = "10,0,5,0"
            $btnInsert.FontSize = 11
            $btnInsert.VerticalAlignment = "Center"
            $localCmd = $cmd.Command
            $btnInsert.Add_Click({
                $script:ServiceCustomBox.Text = $localCmd
                Write-Log -Message "Команда вставлена: $localCmd" -Level "Info"
            }.GetNewClosure())
            [System.Windows.Controls.Grid]::SetColumn($btnInsert, 1)
            $cardGrid.Children.Add($btnInsert) | Out-Null

            # Кнопка "Выполнить"
            $btnExec = New-Object System.Windows.Controls.Button
            $btnExec.Content = "Выполнить"
            $btnExec.Style = $window.Resources["RoundedButton"]
            $btnExec.Background = New-Object System.Windows.Media.SolidColorBrush(
                [System.Windows.Media.ColorConverter]::ConvertFromString("#66BB6A")
            )
            $btnExec.Padding = "10,5"
            $btnExec.Margin = "5,0,0,0"
            $btnExec.FontSize = 11
            $btnExec.VerticalAlignment = "Center"
            $localDesc = $cmd.Desc
            $btnExec.Add_Click({
                Invoke-AdbCommand -Command $localCmd -Description $localDesc
            }.GetNewClosure())
            [System.Windows.Controls.Grid]::SetColumn($btnExec, 2)
            $cardGrid.Children.Add($btnExec) | Out-Null

            $card.Child = $cardGrid
            $stack.Children.Add($card) | Out-Null
        }
    }

    # Кнопка "Закрыть"
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