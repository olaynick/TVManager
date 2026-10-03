# ============================================================================
#  Экран: Сценарии (пакетный режим)
# ============================================================================

# ===== ПОЛУЧИТЬ ОПИСАНИЕ ШАГА =====
function Get-StepDisplayText {
    param([PSCustomObject]$Step)
    switch ($Step.Type) {
        "disable_package" { return "Отключить: $($Step.Package)" }
        "enable_package"  { return "Включить: $($Step.Package)" }
        "remove_package"  { return "Удалить: $($Step.Package)" }
        "clear_package"   { return "Очистить данные: $($Step.Package)" }
        "install_apk"     { return "Установить APK: $(Split-Path $Step.Path -Leaf)" }
        "set_animation"   { return "Анимация: $($Step.Value)" }
        "set_setting"     { return "Настройка: $($Step.Namespace).$($Step.SettingKey) = $($Step.Value)" }
        "send_key"        { return "Клавиша: $($Step.KeyCode)" }
        "send_text"       { return "Текст: $($Step.Text)" }
        "wait"            { return "Пауза: $($Step.Seconds) сек" }
        "screenshot"      { return "Скриншот" }
        "reboot"          { return "Перезагрузка ТВ" }
        default           { return "Неизвестный шаг: $($Step.Type)" }
    }
}

# ============================================================================
#  ОСНОВНОЙ ЭКРАН
# ============================================================================
function Show-ScenariosView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Сценарии"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Пакетный режим: набор шагов, который выполняется одной кнопкой. Например, «Настройка нового ТВ» — отключить рекламу, установить APK, поставить анимацию 0.5x. Результат виден в основном логе внизу окна." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== СПИСОК СЦЕНАРИЕВ =====
    $scenarios = Get-Scenarios
    $scenarios = @($scenarios)

    if ($scenarios.Count -eq 0) {
        $emptyCard = New-Object System.Windows.Controls.Border
        $emptyCard.Background = "#1A1F2A"
        $emptyCard.BorderBrush = "#C8C8C8"
        $emptyCard.BorderThickness = "1"
        $emptyCard.CornerRadius = "8"
        $emptyCard.Padding = "20"
        $emptyCard.Margin = "0,0,0,15"

        $emptyText = New-Object System.Windows.Controls.TextBlock
        $emptyText.Text = "Пока нет сохранённых сценариев.`n`nНажмите «Создать сценарий» внизу, чтобы начать.`nИли «Импорт», чтобы загрузить готовые сценарии из JSON-файла."
        $emptyText.FontSize = 13
        $emptyText.Foreground = "#1565C0"
        $emptyText.TextWrapping = "Wrap"
        $emptyCard.Child = $emptyText
        $mainStack.Children.Add($emptyCard) | Out-Null
    } else {
        $script:ScenariosListBox = New-Object System.Windows.Controls.ListBox
        $script:ScenariosListBox.FontSize = 13
        $script:ScenariosListBox.BorderThickness = "1"
        $script:ScenariosListBox.BorderBrush = "#3A3A3A"
        $script:ScenariosListBox.MinHeight = 250
        $script:ScenariosListBox.Padding = "5"
        $script:ScenariosListBox.Margin = "0,0,0,15"

        foreach ($sc in $scenarios) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $stepCount = @($sc.Steps).Count
            $item.Content = "$($sc.Name)  —  шагов: $stepCount   |   $($sc.Description)"
            $item.Tag = $sc
            $item.Padding = "8"
            [void]$script:ScenariosListBox.Items.Add($item)
        }
        if ($script:ScenariosListBox.Items.Count -gt 0) {
            $script:ScenariosListBox.SelectedIndex = 0
        }

        $mainStack.Children.Add($script:ScenariosListBox) | Out-Null

        # ===== ПРОСМОТР ШАГОВ ВЫБРАННОГО СЦЕНАРИЯ =====
        $mainStack.Children.Add((New-StepTitle -Text "Шаги выбранного сценария")) | Out-Null

        $script:ScenarioStepsContainer = New-Object System.Windows.Controls.StackPanel
        $script:ScenarioStepsContainer.Margin = "0,5,0,15"
        $mainStack.Children.Add($script:ScenarioStepsContainer) | Out-Null

        Update-ScenarioStepsList

        $script:ScenariosListBox.Add_SelectionChanged({
            Update-ScenarioStepsList
        })
    }

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    # --- Создать ---
    $btnNew = New-Object System.Windows.Controls.Button
    $btnNew.Content = "Создать"
    $btnNew.Style = $window.Resources["RoundedButton"]
    $btnNew.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnNew.Padding = "12,6"
    $btnNew.Margin = "0,0,8,0"
    $btnNew.Add_Click({
        Show-ScenarioEditor -Scenario $null
    })
    $buttons += $btnNew

    # --- Импорт (всегда доступен) ---
    $btnImport = New-Object System.Windows.Controls.Button
    $btnImport.Content = "Импорт"
    $btnImport.Style = $window.Resources["RoundedButton"]
    $btnImport.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnImport.Padding = "12,6"
    $btnImport.Margin = "0,0,8,0"
    $btnImport.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "JSON (*.json)|*.json|All files (*.*)|*.*"
        $dlg.Title = "Выберите файл со сценариями"

        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $mode = [System.Windows.MessageBox]::Show(
            "Как импортировать сценарии?`n`nДа — заменить все существующие`nНет — добавить к существующим (обновит совпадающие по имени)`nОтмена — отменить импорт",
            "Импорт сценариев",
            [System.Windows.MessageBoxButton]::YesNoCancel,
            [System.Windows.MessageBoxImage]::Question)

        if ($mode -eq [System.Windows.MessageBoxResult]::Cancel) { return }

        $replace = ($mode -eq [System.Windows.MessageBoxResult]::Yes)
        $ok = Import-Scenarios -FilePath $dlg.FileName -Replace:$replace

        if ($ok) {
            Switch-View -ViewName "Scenarios"
        }
    })
    $buttons += $btnImport

    if ($scenarios.Count -gt 0) {
        # --- Запустить ---
        $btnRun = New-Object System.Windows.Controls.Button
        $btnRun.Content = "Запустить"
        $btnRun.Style = $window.Resources["RoundedButton"]
        $btnRun.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnRun.Padding = "12,6"
        $btnRun.Margin = "0,0,8,0"
        $btnRun.Add_Click({
            if (-not $script:ScenariosListBox.SelectedItem) { return }
            $sc = $script:ScenariosListBox.SelectedItem.Tag

            $confirm = [System.Windows.MessageBox]::Show(
                "Запустить сценарий «$($sc.Name)»?`n`nШагов: $(@($sc.Steps).Count)`n`nРезультат будет виден в логе внизу окна.",
                "Запуск сценария",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            Invoke-Scenario -Scenario $sc
        })
        $buttons += $btnRun

        # --- Редактировать ---
        $btnEdit = New-Object System.Windows.Controls.Button
        $btnEdit.Content = "Редактировать"
        $btnEdit.Style = $window.Resources["RoundedButton"]
        $btnEdit.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnEdit.Padding = "12,6"
        $btnEdit.Margin = "0,0,8,0"
        $btnEdit.Add_Click({
            if (-not $script:ScenariosListBox.SelectedItem) { return }
            $sc = $script:ScenariosListBox.SelectedItem.Tag
            Show-ScenarioEditor -Scenario $sc
        })
        $buttons += $btnEdit

        # --- Экспорт ---
        $btnExport = New-Object System.Windows.Controls.Button
        $btnExport.Content = "Экспорт"
        $btnExport.Style = $window.Resources["RoundedButton"]
        $btnExport.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnExport.Padding = "12,6"
        $btnExport.Margin = "0,0,8,0"
        $btnExport.Add_Click({
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object System.Windows.Forms.SaveFileDialog
            $dlg.Filter = "JSON (*.json)|*.json"
            $dlg.FileName = "scenarios_$(Get-Date -Format 'yyyy-MM-dd').json"
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                Export-Scenarios -FilePath $dlg.FileName | Out-Null
            }
        })
        $buttons += $btnExport

        # --- Удалить ---
        $btnDelete = New-Object System.Windows.Controls.Button
        $btnDelete.Content = "Удалить"
        $btnDelete.Style = $window.Resources["RoundedButton"]
        $btnDelete.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnDelete.Padding = "12,6"
        $btnDelete.Margin = "0,0,8,0"
        $btnDelete.Add_Click({
            if (-not $script:ScenariosListBox.SelectedItem) { return }
            $sc = $script:ScenariosListBox.SelectedItem.Tag

            $confirm = [System.Windows.MessageBox]::Show(
                "Удалить сценарий «$($sc.Name)»?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            Remove-Scenario -Name $sc.Name
            Switch-View -ViewName "Scenarios"
        })
        $buttons += $btnDelete
    }

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран сценариев" -Level "Info"
}

# ============================================================================
#  ЗАПУСК СЦЕНАРИЯ (без отдельного окна)
# ============================================================================
function Invoke-Scenario {
    param([PSCustomObject]$Scenario)

    if (-not $script:connected) {
        Write-Log -Message "Нет подключения к ТВ" -Level "Error"
        return
    }

    $steps = @($Scenario.Steps)
    $total = $steps.Count

    if ($total -eq 0) {
        Write-Log -Message "Сценарий пуст — нечего выполнять" -Level "Warning"
        return
    }

    Write-Log -Message "=== Сценарий: $($Scenario.Name) ===" -Level "Info"
    Write-Log -Message "Шагов: $total" -Level "Info"

    $ok = 0
    $fail = 0

    for ($i = 0; $i -lt $total; $i++) {
        $step = $steps[$i]
        Write-Log -Message "[$($i+1)/$total] $(Get-StepDisplayText -Step $step)" -Level "Info"

        $stepOk = Invoke-ScenarioStep -Step $step -LogCallback {
            param($msg, $lvl)
            Write-Log -Message "  $msg" -Level $lvl
        }

        if ($stepOk) { $ok++ } else { $fail++ }
    }

    if ($fail -eq 0) {
        Write-Log -Message "=== Готово: успешно $ok из $total ===" -Level "Success"
    } else {
        Write-Log -Message "=== Готово: успешно $ok, ошибок $fail из $total ===" -Level "Warning"
    }
}

# ===== ОБНОВИТЬ СПИСОК ШАГОВ =====
function Update-ScenarioStepsList {
    if (-not $script:ScenarioStepsContainer) { return }
    $script:ScenarioStepsContainer.Children.Clear()

    if (-not $script:ScenariosListBox -or -not $script:ScenariosListBox.SelectedItem) { return }
    $sc = $script:ScenariosListBox.SelectedItem.Tag

    $steps = @($sc.Steps)
    if ($steps.Count -eq 0) {
        $empty = New-ViewLabel -Text "(В сценарии нет шагов)" -Light
        $script:ScenarioStepsContainer.Children.Add($empty) | Out-Null
        return
    }

    $idx = 1
    foreach ($step in $steps) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "#2B2B2B"
        $row.BorderBrush = "#3A3A3A"
        $row.BorderThickness = "1"
        $row.CornerRadius = "5"
        $row.Padding = "8,6"
        $row.Margin = "0,0,0,5"

        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "$idx.  $(Get-StepDisplayText -Step $step)"
        $tb.FontSize = 12
        $tb.Foreground = "#FFFFFF"
        $tb.TextWrapping = "Wrap"
        $row.Child = $tb

        $script:ScenarioStepsContainer.Children.Add($row) | Out-Null
        $idx++
    }
}

# ============================================================================
#  РЕДАКТОР СЦЕНАРИЯ
# ============================================================================
function Show-ScenarioEditor {
    param([PSCustomObject]$Scenario)

    $isNew = ($null -eq $Scenario)

    $dialog = New-Object System.Windows.Window
    $dialog.Title = if ($isNew) { "Новый сценарий" } else { "Редактирование сценария" }
    $dialog.Width = 900
    $dialog.Height = 720
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#202020"

    # --- Рабочая копия ---
    if ($isNew) {
        $script:EditScenario = [PSCustomObject]@{
            Name = ""
            Description = ""
            Steps = @()
        }
    } else {
        $script:EditScenario = [PSCustomObject]@{
            Name = $Scenario.Name
            Description = $Scenario.Description
            Steps = @($Scenario.Steps | ForEach-Object { $_ })
        }
    }

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

    # ===== ВЕРХ: Имя + Описание =====
    $topStack = New-Object System.Windows.Controls.StackPanel
    $topStack.Margin = "0,0,0,15"

    $nameLabel = New-Object System.Windows.Controls.TextBlock
    $nameLabel.Text = "Название сценария:"
    $nameLabel.FontSize = 12
    $nameLabel.Foreground = "#A0A0A0"
    $nameLabel.Margin = "0,0,0,4"
    $topStack.Children.Add($nameLabel) | Out-Null

    $script:EditorNameBox = New-Object System.Windows.Controls.TextBox
    $script:EditorNameBox.Style = $window.Resources["RoundedTextBox"]
    $script:EditorNameBox.Text = $script:EditScenario.Name
    $script:EditorNameBox.Margin = "0,0,0,10"
    $topStack.Children.Add($script:EditorNameBox) | Out-Null

    $descLabel = New-Object System.Windows.Controls.TextBlock
    $descLabel.Text = "Описание:"
    $descLabel.FontSize = 12
    $descLabel.Foreground = "#A0A0A0"
    $descLabel.Margin = "0,0,0,4"
    $topStack.Children.Add($descLabel) | Out-Null

    $script:EditorDescBox = New-Object System.Windows.Controls.TextBox
    $script:EditorDescBox.Style = $window.Resources["RoundedTextBox"]
    $script:EditorDescBox.Text = $script:EditScenario.Description
    $topStack.Children.Add($script:EditorDescBox) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($topStack, 0)
    $grid.Children.Add($topStack) | Out-Null

    # ===== СЕРЕДИНА: Шаги =====
    $midGrid = New-Object System.Windows.Controls.Grid
    $mg1 = New-Object System.Windows.Controls.ColumnDefinition; $mg1.Width = "*"
    $mg2 = New-Object System.Windows.Controls.ColumnDefinition; $mg2.Width = "260"
    $midGrid.ColumnDefinitions.Add($mg1)
    $midGrid.ColumnDefinitions.Add($mg2)

    # --- Левая: список шагов ---
    $leftStack = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)

    $stepsHeader = New-Object System.Windows.Controls.TextBlock
    $stepsHeader.Text = "Шаги сценария:"
    $stepsHeader.FontSize = 13
    $stepsHeader.FontWeight = "Bold"
    $stepsHeader.Foreground = "#FFFFFF"
    $stepsHeader.Margin = "0,0,0,8"
    $leftStack.Children.Add($stepsHeader) | Out-Null

    $script:EditorStepsBox = New-Object System.Windows.Controls.ListBox
    $script:EditorStepsBox.FontSize = 12
    $script:EditorStepsBox.BorderThickness = "1"
    $script:EditorStepsBox.BorderBrush = "#3A3A3A"
    $script:EditorStepsBox.MinHeight = 380
    $script:EditorStepsBox.Padding = "5"
    $script:EditorStepsBox.Margin = "0,0,15,0"
    $leftStack.Children.Add($script:EditorStepsBox) | Out-Null

    $midGrid.Children.Add($leftStack) | Out-Null

    # --- Правая: кнопки управления ---
    $rightStack = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($rightStack, 1)

    $addHeader = New-Object System.Windows.Controls.TextBlock
    $addHeader.Text = "Добавить шаг:"
    $addHeader.FontSize = 13
    $addHeader.FontWeight = "Bold"
    $addHeader.Foreground = "#C8C8C8"
    $addHeader.Margin = "0,0,0,8"
    $rightStack.Children.Add($addHeader) | Out-Null

    $stepTypes = Get-ScenarioStepTypes
    foreach ($st in $stepTypes) {
        $btnAdd = New-Object System.Windows.Controls.Button
        $btnAdd.Content = $st.Name
        $btnAdd.Style = $window.Resources["RoundedButton"]
        $btnAdd.Background = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
        )
        $btnAdd.Padding = "10,6"
        $btnAdd.FontSize = 12
        $btnAdd.HorizontalAlignment = "Stretch"
        $btnAdd.Margin = "0,0,0,5"
        $btnAdd.Add_Click({
            Show-AddStepDialog -StepType $st
        }.GetNewClosure())
        $rightStack.Children.Add($btnAdd) | Out-Null
    }

    $sep = New-Object System.Windows.Controls.Separator
    $sep.Margin = "0,15,0,10"
    $rightStack.Children.Add($sep) | Out-Null

    # --- Редактировать / Удалить / Вверх / Вниз ---
    $btnEditStep = New-Object System.Windows.Controls.Button
    $btnEditStep.Content = "Редактировать шаг"
    $btnEditStep.Style = $window.Resources["RoundedButton"]
    $btnEditStep.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnEditStep.Padding = "10,6"
    $btnEditStep.FontSize = 12
    $btnEditStep.HorizontalAlignment = "Stretch"
    $btnEditStep.Margin = "0,0,0,5"
    $btnEditStep.Add_Click({
        if ($script:EditorStepsBox.SelectedItem) {
            $idx = $script:EditorStepsBox.SelectedIndex
            Show-EditStepDialog -StepIndex $idx
        }
    })
    $rightStack.Children.Add($btnEditStep) | Out-Null

    $btnDelStep = New-Object System.Windows.Controls.Button
    $btnDelStep.Content = "Удалить шаг"
    $btnDelStep.Style = $window.Resources["RoundedButton"]
    $btnDelStep.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnDelStep.Padding = "10,6"
    $btnDelStep.FontSize = 12
    $btnDelStep.HorizontalAlignment = "Stretch"
    $btnDelStep.Margin = "0,0,0,5"
    $btnDelStep.Add_Click({
        if ($script:EditorStepsBox.SelectedItem) {
            $idx = $script:EditorStepsBox.SelectedIndex
            $list = @($script:EditScenario.Steps)
            $newList = @()
            for ($j = 0; $j -lt $list.Count; $j++) {
                if ($j -ne $idx) { $newList += $list[$j] }
            }
            $script:EditScenario.Steps = $newList
            Update-EditorStepsBox
        }
    })
    $rightStack.Children.Add($btnDelStep) | Out-Null

    $btnUp = New-Object System.Windows.Controls.Button
    $btnUp.Content = "↑ Вверх"
    $btnUp.Style = $window.Resources["RoundedButton"]
    $btnUp.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnUp.Padding = "10,6"
    $btnUp.FontSize = 12
    $btnUp.HorizontalAlignment = "Stretch"
    $btnUp.Margin = "0,0,0,5"
    $btnUp.Add_Click({
        if (-not $script:EditorStepsBox.SelectedItem) { return }
        $idx = $script:EditorStepsBox.SelectedIndex
        if ($idx -le 0) { return }
        $list = @($script:EditScenario.Steps)
        $tmp = $list[$idx - 1]
        $list[$idx - 1] = $list[$idx]
        $list[$idx] = $tmp
        $script:EditScenario.Steps = $list
        Update-EditorStepsBox
        $script:EditorStepsBox.SelectedIndex = $idx - 1
    })
    $rightStack.Children.Add($btnUp) | Out-Null

    $btnDown = New-Object System.Windows.Controls.Button
    $btnDown.Content = "↓ Вниз"
    $btnDown.Style = $window.Resources["RoundedButton"]
    $btnDown.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnDown.Padding = "10,6"
    $btnDown.FontSize = 12
    $btnDown.HorizontalAlignment = "Stretch"
    $btnDown.Add_Click({
        if (-not $script:EditorStepsBox.SelectedItem) { return }
        $idx = $script:EditorStepsBox.SelectedIndex
        $list = @($script:EditScenario.Steps)
        if ($idx -ge $list.Count - 1) { return }
        $tmp = $list[$idx + 1]
        $list[$idx + 1] = $list[$idx]
        $list[$idx] = $tmp
        $script:EditScenario.Steps = $list
        Update-EditorStepsBox
        $script:EditorStepsBox.SelectedIndex = $idx + 1
    })
    $rightStack.Children.Add($btnDown) | Out-Null

    $midGrid.Children.Add($rightStack) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($midGrid, 1)
    $grid.Children.Add($midGrid) | Out-Null

    # ===== НИЗ: Сохранить / Отмена =====
    $botPanel = New-Object System.Windows.Controls.StackPanel
    $botPanel.Orientation = "Horizontal"
    $botPanel.HorizontalAlignment = "Right"
    $botPanel.Margin = "0,15,0,0"

    $btnSave = New-Object System.Windows.Controls.Button
    $btnSave.Content = "Сохранить"
    $btnSave.Style = $window.Resources["RoundedButton"]
    $btnSave.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnSave.Padding = "15,8"
    $btnSave.Margin = "0,0,8,0"
    $btnSave.Add_Click({
        $name = $script:EditorNameBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            [System.Windows.MessageBox]::Show("Введите название сценария", "Ошибка",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        $sc = [PSCustomObject]@{
            Name = $name
            Description = $script:EditorDescBox.Text.Trim()
            Steps = @($script:EditScenario.Steps)
        }
        Save-Scenario -Scenario $sc | Out-Null
        $dialog.Close()
        Switch-View -ViewName "Scenarios"
    })
    $botPanel.Children.Add($btnSave) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Отмена"
    $btnCancel.Style = $window.Resources["RoundedButton"]
    $btnCancel.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnCancel.Padding = "15,8"
    $btnCancel.Add_Click({ $dialog.Close() })
    $botPanel.Children.Add($btnCancel) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($botPanel, 2)
    $grid.Children.Add($botPanel) | Out-Null

    $dialog.Content = $grid

    # Обновляем список шагов после показа
    $dialog.Add_ContentRendered({
        Update-EditorStepsBox
    })

    $dialog.ShowDialog() | Out-Null
}

# ===== ОБНОВИТЬ СПИСОК ШАГОВ В РЕДАКТОРЕ =====
function Update-EditorStepsBox {
    if (-not $script:EditorStepsBox) { return }
    $script:EditorStepsBox.Items.Clear()
    $steps = @($script:EditScenario.Steps)
    $idx = 1
    foreach ($step in $steps) {
        [void]$script:EditorStepsBox.Items.Add("$idx. $(Get-StepDisplayText -Step $step)")
        $idx++
    }
}

# ============================================================================
#  ДИАЛОГИ ШАГОВ
# ============================================================================
function Show-AddStepDialog {
    param([PSCustomObject]$StepType)
    Show-StepFormDialog -StepType $StepType -ExistingStep $null
}

function Show-EditStepDialog {
    param([int]$StepIndex)

    $step = @($script:EditScenario.Steps)[$StepIndex]
    $typeInfo = Get-StepTypeInfo -Type $step.Type
    if (-not $typeInfo) {
        Write-Log -Message "Неизвестный тип шага: $($step.Type)" -Level "Error"
        return
    }

    Show-StepFormDialog -StepType $typeInfo -ExistingStep $step -StepIndex $StepIndex
}

function Show-StepFormDialog {
    param(
        [PSCustomObject]$StepType,
        [PSCustomObject]$ExistingStep = $null,
        [int]$StepIndex = -1
    )

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "$($StepType.Name)"
    $dialog.Width = 480
    $dialog.Height = 320
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = "#202020"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "25"

    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = $StepType.Name
    $h.FontSize = 16
    $h.FontWeight = "Bold"
    $h.Margin = "0,0,0,10"
    $stack.Children.Add($h) | Out-Null

    $d = New-Object System.Windows.Controls.TextBlock
    $d.Text = $StepType.Desc
    $d.FontSize = 11
    $d.Foreground = "#A0A0A0"
    $d.Margin = "0,0,0,15"
    $stack.Children.Add($d) | Out-Null

    $fields = @{}
    foreach ($f in $StepType.Fields) {
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $f.Label
        $lbl.FontSize = 12
        $lbl.Foreground = "#FFFFFF"
        $lbl.Margin = "0,0,0,4"
        $stack.Children.Add($lbl) | Out-Null

        $box = New-Object System.Windows.Controls.TextBox
        $box.Style = $window.Resources["RoundedTextBox"]
        $box.FontSize = 13
        $box.Margin = "0,0,0,10"

        $defaultVal = ""
        if ($ExistingStep) {
            if ($ExistingStep.PSObject.Properties[$f.Key]) {
                $defaultVal = "$($ExistingStep.$($f.Key))"
            }
        }
        $box.Text = $defaultVal

        $stack.Children.Add($box) | Out-Null
        $fields[$f.Key] = $box
    }

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"

    $btnOk = New-Object System.Windows.Controls.Button
    $btnOk.Content = "Сохранить"
    $btnOk.Style = $window.Resources["RoundedButton"]
    $btnOk.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $btnOk.Padding = "15,8"
    $btnOk.Margin = "0,0,8,0"
    $btnOk.Add_Click({
        $newStep = @{ Type = $StepType.Type }
        $valid = $true

        foreach ($key in $fields.Keys) {
            $val = $fields[$key].Text.Trim()
            if ([string]::IsNullOrWhiteSpace($val)) {
                $valid = $false
                [System.Windows.MessageBox]::Show("Заполните поле: $key", "Ошибка",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                break
            }
            if ($key -eq "Seconds") {
                $newStep[$key] = [int]$val
            } else {
                $newStep[$key] = $val
            }
        }

        if (-not $valid) { return }

        $obj = [PSCustomObject]$newStep

        $list = @($script:EditScenario.Steps)
        if ($StepIndex -ge 0) {
            $list[$StepIndex] = $obj
        } else {
            $list += $obj
        }
        $script:EditScenario.Steps = $list

        Update-EditorStepsBox
        $dialog.Close()
    })
    $btnPanel.Children.Add($btnOk) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Отмена"
    $btnCancel.Style = $window.Resources["RoundedButton"]
    $btnCancel.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#B0BEC5")
    )
    $btnCancel.Padding = "15,8"
    $btnCancel.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnCancel) | Out-Null

    $stack.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $stack
    $dialog.ShowDialog() | Out-Null
}