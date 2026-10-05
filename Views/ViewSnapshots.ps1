# ============================================================================
#  Экран: Резервные копии ТВ
# ============================================================================

function Show-SnapshotsView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Резервные копии ТВ"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Резервная копия сохраняет состояние ТВ: пакеты, системные настройки, лаунчер, Wi-Fi и Bluetooth. Копию можно применить к другому ТВ (для быстрой настройки) или сравнить с текущим состоянием (чтобы увидеть, что изменилось)." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,15"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== Список копий =====
    Write-Log -Message "Читаю список резервных копий..." -Level "Info"
    $snapshots = Get-Snapshots
    Write-Log -Message "Найдено резервных копий: $($snapshots.Count)" -Level "Info"

    if ($snapshots.Count -eq 0) {
        $emptyCard = New-Object System.Windows.Controls.Border
        $emptyCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#1A1F2A")
        )
        $emptyCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A5A7A")
        )
        $emptyCard.BorderThickness = "1"
        $emptyCard.CornerRadius = "8"
        $emptyCard.Padding = "20"
        $emptyCard.Margin = "0,0,0,15"

        $emptyText = New-Object System.Windows.Controls.TextBlock
        $emptyText.Text = "Резервных копий пока нет.`n`nНажмите «Создать резервную копию» внизу, чтобы сохранить текущее состояние ТВ."
        $emptyText.FontSize = 13
        $emptyText.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0C8E8")
        )
        $emptyText.TextWrapping = "Wrap"
        $emptyCard.Child = $emptyText
        $mainStack.Children.Add($emptyCard) | Out-Null
    } else {
        $listBox = New-Object System.Windows.Controls.ListBox
        $listBox.FontSize = 13
        $listBox.BorderThickness = "1"
        $listBox.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
        )
        $listBox.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#1F1F1F")
        )
        $listBox.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
        $listBox.MinHeight = 300
        $listBox.Padding = "5"
        $listBox.Margin = "0,0,0,15"

        foreach ($snap in $snapshots) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Padding = "10"
            $item.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
            )

            $itemStack = New-Object System.Windows.Controls.StackPanel

            $nameTb = New-Object System.Windows.Controls.TextBlock
            $nameTb.Text = $snap.Name
            $nameTb.FontSize = 13
            $nameTb.FontWeight = "Bold"
            $nameTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
            )
            $itemStack.Children.Add($nameTb) | Out-Null

            $metaTb = New-Object System.Windows.Controls.TextBlock
            $metaTb.Text = "$($snap.CreatedAt) · $($snap.DeviceModel) · $($snap.DeviceIp)"
            $metaTb.FontSize = 11
            $metaTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
            )
            $metaTb.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)
            $itemStack.Children.Add($metaTb) | Out-Null

            $statsTb = New-Object System.Windows.Controls.TextBlock
            $statsTb.Text = "Пакетов: $($snap.InstalledCount) · Отключено: $($snap.DisabledCount) · Удалено: $($snap.RemovedCount)"
            $statsTb.FontSize = 11
            $statsTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#909090")
            )
            $statsTb.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
            $itemStack.Children.Add($statsTb) | Out-Null

            if ($snap.Description) {
                $descTb = New-Object System.Windows.Controls.TextBlock
                $descTb.Text = $snap.Description
                $descTb.FontSize = 11
                $descTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#808080")
                )
                $descTb.TextWrapping = "Wrap"
                $descTb.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
                $itemStack.Children.Add($descTb) | Out-Null
            }

            $item.Content = $itemStack
            $item.Tag = $snap
            [void]$listBox.Items.Add($item)
        }

        if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }

        $script:SnapshotsListBox = $listBox
        $mainStack.Children.Add($listBox) | Out-Null
    }

    # ===== ROOT =====
    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    # --- Создать ---
    $btnCreate = New-Object System.Windows.Controls.Button
    $btnCreate.Content = "Создать копию"
    $btnCreate.Style = $window.Resources["RoundedButton"]
    $btnCreate.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnCreate.Padding = "12,6"
    $btnCreate.Margin = "0,0,8,0"
    $btnCreate.Add_Click({ Show-CreateSnapshotDialog })
    $buttons += $btnCreate

    if ($snapshots.Count -gt 0) {
        # --- Просмотр ---
        $btnView = New-Object System.Windows.Controls.Button
        $btnView.Content = "Просмотр"
        $btnView.Style = $window.Resources["RoundedButton"]
        $btnView.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#4e7891")
        )
        $btnView.Padding = "12,6"
        $btnView.Margin = "0,0,8,0"
        $btnView.Add_Click({
            if (-not $script:SnapshotsListBox.SelectedItem) { return }
            $snap = $script:SnapshotsListBox.SelectedItem.Tag
            Show-SnapshotDetailsDialog -SnapshotMeta $snap
        })
        $buttons += $btnView

        # --- Восстановить ---
        $btnApply = New-Object System.Windows.Controls.Button
        $btnApply.Content = "Восстановить"
        $btnApply.Style = $window.Resources["RoundedButton"]
        $btnApply.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
        )
        $btnApply.Padding = "12,6"
        $btnApply.Margin = "0,0,8,0"
        $btnApply.Add_Click({
            if (-not $script:SnapshotsListBox.SelectedItem) { return }
            $snap = $script:SnapshotsListBox.SelectedItem.Tag
            Show-ApplySnapshotDialog -Snapshot $snap
        })
        $buttons += $btnApply

        # --- Сравнить ---
        $btnCompare = New-Object System.Windows.Controls.Button
        $btnCompare.Content = "Сравнить"
        $btnCompare.Style = $window.Resources["RoundedButton"]
        $btnCompare.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6c547e")
        )
        $btnCompare.Padding = "12,6"
        $btnCompare.Margin = "0,0,8,0"
        $btnCompare.Add_Click({
            if (-not $script:SnapshotsListBox.SelectedItem) { return }
            $snap = $script:SnapshotsListBox.SelectedItem.Tag
            $diff = Compare-SnapshotWithCurrent -Snapshot $snap.FullData
            Show-SnapshotDiffDialog -Diff $diff -Snapshot $snap
        })
        $buttons += $btnCompare

        # --- Экспорт ---
        $btnExport = New-Object System.Windows.Controls.Button
        $btnExport.Content = "Экспорт"
        $btnExport.Style = $window.Resources["RoundedButton"]
        $btnExport.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
        )
        $btnExport.Padding = "12,6"
        $btnExport.Margin = "0,0,8,0"
        $btnExport.Add_Click({
            if (-not $script:SnapshotsListBox.SelectedItem) { return }
            $snap = $script:SnapshotsListBox.SelectedItem.Tag

            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object System.Windows.Forms.SaveFileDialog
            $dlg.Filter = "TV Snapshot (*.tvsnap)|*.tvsnap|All files (*.*)|*.*"
            $dlg.FileName = $snap.FileName

            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                Export-SnapshotToFile -SourcePath $snap.FilePath -DestPath $dlg.FileName | Out-Null
            }
        })
        $buttons += $btnExport

        # --- Удалить ---
        $btnDelete = New-Object System.Windows.Controls.Button
        $btnDelete.Content = "Удалить"
        $btnDelete.Style = $window.Resources["RoundedButton"]
        $btnDelete.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
        )
        $btnDelete.Padding = "12,6"
        $btnDelete.Margin = "0,0,8,0"
        $btnDelete.Add_Click({
            if (-not $script:SnapshotsListBox.SelectedItem) { return }
            $snap = $script:SnapshotsListBox.SelectedItem.Tag

            $confirm = [System.Windows.MessageBox]::Show(
                "Удалить резервную копию «$($snap.Name)»?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            Remove-Snapshot -FilePath $snap.FilePath | Out-Null
            Switch-View -ViewName "Snapshots"
        })
        $buttons += $btnDelete
    }

    # --- Импорт ---
    $btnImport = New-Object System.Windows.Controls.Button
    $btnImport.Content = "Импорт"
    $btnImport.Style = $window.Resources["RoundedButton"]
    $btnImport.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnImport.Padding = "12,6"
    $btnImport.Margin = "0,0,8,0"
    $btnImport.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "TV Snapshot (*.tvsnap)|*.tvsnap|All files (*.*)|*.*"
        $dlg.Title = "Выберите файл резервной копии"

        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $imported = Import-SnapshotFromFile -SourcePath $dlg.FileName
            if ($imported) {
                Switch-View -ViewName "Snapshots"
            }
        }
    })
    $buttons += $btnImport

    # --- Обновить ---
    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({ Switch-View -ViewName "Snapshots" })
    $buttons += $btnRefresh

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран резервных копий (копий: $($snapshots.Count))" -Level "Info"
}

# ============================================================================
#  ДИАЛОГ: СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ
# ============================================================================
function Show-CreateSnapshotDialog {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Создать резервную копию ТВ"
    $dialog.Width = 520
    $dialog.Height = 340
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#202020")
    )

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "25"

    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = "Новая резервная копия"
    $h.FontSize = 18
    $h.FontWeight = "Bold"
    $h.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $h.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $stack.Children.Add($h) | Out-Null

    $lblName = New-Object System.Windows.Controls.TextBlock
    $lblName.Text = "Название:"
    $lblName.FontSize = 13
    $lblName.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblName.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $stack.Children.Add($lblName) | Out-Null

    $txtName = New-Object System.Windows.Controls.TextBox
    $txtName.Style = $window.Resources["RoundedTextBox"]
    $txtName.FontSize = 13
    $txtName.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    $txtName.Text = "Копия $(Get-Date -Format 'yyyy-MM-dd HH-mm')"
    $stack.Children.Add($txtName) | Out-Null

    $lblDesc = New-Object System.Windows.Controls.TextBlock
    $lblDesc.Text = "Описание (необязательно):"
    $lblDesc.FontSize = 13
    $lblDesc.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $lblDesc.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $stack.Children.Add($lblDesc) | Out-Null

    $txtDesc = New-Object System.Windows.Controls.TextBox
    $txtDesc.Style = $window.Resources["RoundedTextBox"]
    $txtDesc.FontSize = 13
    $txtDesc.Height = 60
    $txtDesc.AcceptsReturn = $true
    $txtDesc.TextWrapping = "Wrap"
    $txtDesc.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $stack.Children.Add($txtDesc) | Out-Null

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"

    $btnSave = New-Object System.Windows.Controls.Button
    $btnSave.Content = "Создать"
    $btnSave.Style = $window.Resources["RoundedButton"]
    $btnSave.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnSave.Padding = "15,8"
    $btnSave.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $btnSave.Add_Click({
        $name = $txtName.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            [System.Windows.MessageBox]::Show("Введите название", "Ошибка",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        $dialog.Close()

        Write-Log -Message "Создание резервной копии «$name»..." -Level "Info"
        $result = New-Snapshot -Name $name -Description $txtDesc.Text.Trim()

        if ($result) {
            [System.Windows.MessageBox]::Show(
                "Резервная копия создана:`n`n$(Split-Path $result -Leaf)",
                "Готово",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
            Switch-View -ViewName "Snapshots"
        } else {
            [System.Windows.MessageBox]::Show(
                "Не удалось создать резервную копию. Подробности в логе.",
                "Ошибка",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    })
    $btnPanel.Children.Add($btnSave) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Отмена"
    $btnCancel.Style = $window.Resources["RoundedButton"]
    $btnCancel.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnCancel.Padding = "15,8"
    $btnCancel.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnCancel) | Out-Null

    $stack.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $stack
    $dialog.ShowDialog() | Out-Null
}

# ============================================================================
#  ДИАЛОГ: ВОССТАНОВЛЕНИЕ ИЗ РЕЗЕРВНОЙ КОПИИ
# ============================================================================
function Show-ApplySnapshotDialog {
    param([PSCustomObject]$Snapshot)

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Восстановить из резервной копии"
    $dialog.Width = 560
    $dialog.Height = 440
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#202020")
    )

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = "25"

    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = "Восстановить из «$($Snapshot.Name)»"
    $h.FontSize = 16
    $h.FontWeight = "Bold"
    $h.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $h.TextWrapping = "Wrap"
    $h.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    $stack.Children.Add($h) | Out-Null

    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text = "Что синхронизировать с ТВ:"
    $info.FontSize = 13
    $info.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $info.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    $stack.Children.Add($info) | Out-Null

    $chkPackages = New-Object System.Windows.Controls.CheckBox
    $chkPackages.Style = $window.Resources["MiuiCheckBox"]
    $chkPackages.Content = "Пакеты (включить/отключить/восстановить)"
    $chkPackages.IsChecked = $true
    $chkPackages.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
    $stack.Children.Add($chkPackages) | Out-Null

    $chkSettings = New-Object System.Windows.Controls.CheckBox
    $chkSettings.Style = $window.Resources["MiuiCheckBox"]
    $chkSettings.Content = "Системные настройки (анимация, тайм-аут, immersive и др.)"
    $chkSettings.IsChecked = $true
    $chkSettings.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
    $stack.Children.Add($chkSettings) | Out-Null

    $chkLauncher = New-Object System.Windows.Controls.CheckBox
    $chkLauncher.Style = $window.Resources["MiuiCheckBox"]
    $chkLauncher.Content = "Лаунчер"
    $chkLauncher.IsChecked = $true
    $chkLauncher.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $stack.Children.Add($chkLauncher) | Out-Null

    $warnCard = New-Object System.Windows.Controls.Border
    $warnCard.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3D3520")
    )
    $warnCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#5A4A2A")
    )
    $warnCard.BorderThickness = "1"
    $warnCard.CornerRadius = "6"
    $warnCard.Padding = "10"
    $warnCard.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)

    $warnText = New-Object System.Windows.Controls.TextBlock
    $warnText.Text = "Восстановление может занять несколько минут, если много пакетов. Лог появится в основном окне."
    $warnText.TextWrapping = "Wrap"
    $warnText.FontSize = 11
    $warnText.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
    )
    $warnCard.Child = $warnText
    $stack.Children.Add($warnCard) | Out-Null

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"

    $btnApply = New-Object System.Windows.Controls.Button
    $btnApply.Content = "Восстановить"
    $btnApply.Style = $window.Resources["RoundedButton"]
    $btnApply.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnApply.Padding = "15,8"
    $btnApply.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    $btnApply.Add_Click({
        $dialog.Close()

        Write-Log -Message "=== Восстановление из резервной копии ===" -Level "Info"
        Apply-Snapshot -Snapshot $Snapshot.FullData `
                       -SyncPackages:$chkPackages.IsChecked `
                       -SyncSettings:$chkSettings.IsChecked `
                       -SyncLauncher:$chkLauncher.IsChecked | Out-Null

        [System.Windows.MessageBox]::Show(
            "Восстановление завершено. Подробности в логе.",
            "Готово",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information) | Out-Null

        Switch-View -ViewName "Snapshots"
    })
    $btnPanel.Children.Add($btnApply) | Out-Null

    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = "Отмена"
    $btnCancel.Style = $window.Resources["RoundedButton"]
    $btnCancel.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnCancel.Padding = "15,8"
    $btnCancel.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnCancel) | Out-Null

    $stack.Children.Add($btnPanel) | Out-Null

    $dialog.Content = $stack
    $dialog.ShowDialog() | Out-Null
}

# ============================================================================
#  ДИАЛОГ: СРАВНЕНИЕ С РЕЗЕРВНОЙ КОПИЕЙ
# ============================================================================
function Show-SnapshotDiffDialog {
    param(
        [PSCustomObject]$Diff,
        [PSCustomObject]$Snapshot
    )

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Сравнение с резервной копией"
    $dialog.Width = 800
    $dialog.Height = 700
    $dialog.WindowStartupLocation = "CenterOwner"
    $dialog.Owner = $window
    $dialog.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#202020")
    )

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "20"

    $row1 = New-Object System.Windows.Controls.RowDefinition; $row1.Height = "Auto"
    $row2 = New-Object System.Windows.Controls.RowDefinition; $row2.Height = "*"
    $row3 = New-Object System.Windows.Controls.RowDefinition; $row3.Height = "Auto"
    $grid.RowDefinitions.Add($row1)
    $grid.RowDefinitions.Add($row2)
    $grid.RowDefinitions.Add($row3)

    $headerPanel = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    if ($Diff.IsSame) {
        $title.Text = "Изменений не обнаружено"
        $title.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
    } else {
        $title.Text = "Обнаружены различия"
        $title.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#FFC83D")
        )
    }
    $title.FontSize = 20
    $title.FontWeight = "Bold"
    $title.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $headerPanel.Children.Add($title) | Out-Null

    $infoTb = New-Object System.Windows.Controls.TextBlock
    $infoTb.FontSize = 11
    $infoTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $infoTb.TextWrapping = "Wrap"
    $infoTb.Text = "Копия: $($Diff.RefName)`nСоздана: $($Diff.RefCreatedAt)`nУстройство: $($Diff.RefDeviceIp)"
    $infoTb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 15)
    $headerPanel.Children.Add($infoTb) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($headerPanel, 0)
    $grid.Children.Add($headerPanel) | Out-Null

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $grid.Children.Add($scroll) | Out-Null

    $content = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $content

    if ($Diff.IsSame) {
        $okCard = New-Object System.Windows.Controls.Border
        $okCard.Background = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#1F3A1F")
        )
        $okCard.BorderBrush = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#3A5A3A")
        )
        $okCard.BorderThickness = "1"
        $okCard.CornerRadius = "8"
        $okCard.Padding = "20"

        $okText = New-Object System.Windows.Controls.TextBlock
        $okText.Text = "Состояние ТВ полностью совпадает с резервной копией.`nНичего не установлено, не удалено, не отключено и не изменено с момента её создания."
        $okText.FontSize = 13
        $okText.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
        )
        $okText.TextWrapping = "Wrap"
        $okCard.Child = $okText
        $content.Children.Add($okCard) | Out-Null
    } else {
        $content.Children.Add((New-DiffSection -Title "Установленные после копии" -Items $Diff.Packages.Added -Color "#60CDFF")) | Out-Null
        $content.Children.Add((New-DiffSection -Title "Удалённые с момента копии" -Items $Diff.Packages.Removed -Color "#FF6B6B")) | Out-Null
        $content.Children.Add((New-DiffSection -Title "Отключённые с момента копии" -Items $Diff.Packages.DisabledNow -Color "#FFC83D")) | Out-Null
        $content.Children.Add((New-DiffSection -Title "Включённые обратно" -Items $Diff.Packages.EnabledNow -Color "#6CCB5F")) | Out-Null

        if ($Diff.Settings.Changed.Count -gt 0) {
            $settingsSection = New-Object System.Windows.Controls.Border
            $settingsSection.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
            )
            $settingsSection.BorderBrush = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
            )
            $settingsSection.BorderThickness = "1"
            $settingsSection.CornerRadius = "6"
            $settingsSection.Padding = "12"
            $settingsSection.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

            $settingsStack = New-Object System.Windows.Controls.StackPanel

            $settingsHeader = New-Object System.Windows.Controls.TextBlock
            $settingsHeader.Text = "Изменённые настройки ($($Diff.Settings.Changed.Count))"
            $settingsHeader.FontSize = 14
            $settingsHeader.FontWeight = "Bold"
            $settingsHeader.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
            )
            $settingsHeader.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
            $settingsStack.Children.Add($settingsHeader) | Out-Null

            foreach ($s in $Diff.Settings.Changed) {
                $row = New-Object System.Windows.Controls.TextBlock
                $row.FontFamily = "Consolas"
                $row.FontSize = 12
                $row.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
                )
                $row.Margin = New-Object System.Windows.Thickness(10, 2, 0, 2)
                $row.Text = "$($s.Namespace).$($s.Key):  было «$($s.Snapshot)» → стало «$($s.Current)»"
                $settingsStack.Children.Add($row) | Out-Null
            }

            $settingsSection.Child = $settingsStack
            $content.Children.Add($settingsSection) | Out-Null
        }

        if ($Diff.Launcher.Changed) {
            $launcherSection = New-Object System.Windows.Controls.Border
            $launcherSection.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
            )
            $launcherSection.BorderBrush = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
            )
            $launcherSection.BorderThickness = "1"
            $launcherSection.CornerRadius = "6"
            $launcherSection.Padding = "12"

            $launcherStack = New-Object System.Windows.Controls.StackPanel

            $launcherHeader = New-Object System.Windows.Controls.TextBlock
            $launcherHeader.Text = "Изменён лаунчер"
            $launcherHeader.FontSize = 14
            $launcherHeader.FontWeight = "Bold"
            $launcherHeader.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
            )
            $launcherHeader.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
            $launcherStack.Children.Add($launcherHeader) | Out-Null

            $launcherInfo = New-Object System.Windows.Controls.TextBlock
            $launcherInfo.FontFamily = "Consolas"
            $launcherInfo.FontSize = 12
            $launcherInfo.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
            )
            $launcherInfo.Text = "Было: $($Diff.Launcher.Snapshot)`nСейчас: $($Diff.Launcher.Current)"
            $launcherStack.Children.Add($launcherInfo) | Out-Null

            $launcherSection.Child = $launcherStack
            $content.Children.Add($launcherSection) | Out-Null
        }
    }

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Right"
    [System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
    $grid.Children.Add($btnPanel) | Out-Null

    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = "Закрыть"
    $btnClose.Style = $window.Resources["RoundedButton"]
    $btnClose.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A4A")
    )
    $btnClose.Padding = "15,8"
    $btnClose.Add_Click({ $dialog.Close() })
    $btnPanel.Children.Add($btnClose) | Out-Null

    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

function New-DiffSection {
    param(
        [string]$Title,
        [array]$Items,
        [string]$Color
    )

    $section = New-Object System.Windows.Controls.Border
    $section.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#2B2B2B")
    )
    $section.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3A3A3A")
    )
    $section.BorderThickness = "1"
    $section.CornerRadius = "6"
    $section.Padding = "12"
    $section.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

    $stack = New-Object System.Windows.Controls.StackPanel

    $headerStack = New-Object System.Windows.Controls.StackPanel
    $headerStack.Orientation = "Horizontal"

    $titleTb = New-Object System.Windows.Controls.TextBlock
    $titleTb.Text = $Title
    $titleTb.FontSize = 14
    $titleTb.FontWeight = "Bold"
    $titleTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    )
    $titleTb.VerticalAlignment = "Center"
    $headerStack.Children.Add($titleTb) | Out-Null

    $countTb = New-Object System.Windows.Controls.TextBlock
    $countTb.Text = "   ($(@($Items).Count))"
    $countTb.FontSize = 13
    $countTb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
    )
    $countTb.VerticalAlignment = "Center"
    $headerStack.Children.Add($countTb) | Out-Null

    $stack.Children.Add($headerStack) | Out-Null

    if (@($Items).Count -eq 0) {
        $empty = New-Object System.Windows.Controls.TextBlock
        $empty.Text = "  (нет)"
        $empty.FontSize = 12
        $empty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
        )
        $empty.Margin = New-Object System.Windows.Thickness(10, 6, 0, 0)
        $stack.Children.Add($empty) | Out-Null
    } else {
        $listStack = New-Object System.Windows.Controls.StackPanel
        $listStack.Margin = New-Object System.Windows.Thickness(10, 8, 0, 0)

        $maxShow = 50
        $shown = 0
        foreach ($item in $Items) {
            if ($shown -ge $maxShow) {
                $moreTb = New-Object System.Windows.Controls.TextBlock
                $moreTb.Text = "  ... и ещё $(@($Items).Count - $maxShow)"
                $moreTb.FontSize = 11
                $moreTb.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
                )
                $moreTb.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
                $listStack.Children.Add($moreTb) | Out-Null
                break
            }

            $itemTb = New-Object System.Windows.Controls.TextBlock
            $itemTb.Text = "  $item"
            $itemTb.FontFamily = "Consolas"
            $itemTb.FontSize = 12
            $itemTb.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
            )
            $itemTb.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
            $listStack.Children.Add($itemTb) | Out-Null
            $shown++
        }

        $stack.Children.Add($listStack) | Out-Null
    }

    $section.Child = $stack
    return $section
}