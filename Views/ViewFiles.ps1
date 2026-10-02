function Show-FilesView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "30,25,30,25"

    $header = New-ViewHeader -Text "Файловый менеджер"
    $mainStack.Children.Add($header) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    if (-not $script:CurrentRemotePath) {
        $script:CurrentRemotePath = "/sdcard/"
    }

    # Панель навигации
    $navPanel = New-Object System.Windows.Controls.StackPanel
    $navPanel.Orientation = "Horizontal"
    $navPanel.Margin = "0,0,0,10"

    $btnRefresh = New-Object System.Windows.Controls.Button
    $btnRefresh.Content = "Обновить"
    $btnRefresh.Style = $window.Resources["RoundedButton"]
    $btnRefresh.Background = "#4A90E2"
    $btnRefresh.Padding = "12,6"
    $btnRefresh.Margin = "0,0,8,0"
    $btnRefresh.Add_Click({ Switch-View -ViewName "Files" })
    $navPanel.Children.Add($btnRefresh) | Out-Null

    # Быстрые пути — создаём вручную, без цикла
    $quickPaths = @("/", "/sdcard/", "/sdcard/Download/", "/storage/", "/data/")

    $btn0 = New-Object System.Windows.Controls.Button
    $btn0.Content = "/"
    $btn0.Style = $window.Resources["RoundedButton"]
    $btn0.Background = "#B0BEC5"
    $btn0.Padding = "10,6"
    $btn0.FontSize = 11
    $btn0.Margin = "0,0,8,0"
    $btn0.Add_Click({ $script:CurrentRemotePath = "/"; Switch-View -ViewName "Files" })
    $navPanel.Children.Add($btn0) | Out-Null

    $btn1 = New-Object System.Windows.Controls.Button
    $btn1.Content = "/sdcard/"
    $btn1.Style = $window.Resources["RoundedButton"]
    $btn1.Background = "#B0BEC5"
    $btn1.Padding = "10,6"
    $btn1.FontSize = 11
    $btn1.Margin = "0,0,8,0"
    $btn1.Add_Click({ $script:CurrentRemotePath = "/sdcard/"; Switch-View -ViewName "Files" })
    $navPanel.Children.Add($btn1) | Out-Null

    $btn2 = New-Object System.Windows.Controls.Button
    $btn2.Content = "/sdcard/Download/"
    $btn2.Style = $window.Resources["RoundedButton"]
    $btn2.Background = "#B0BEC5"
    $btn2.Padding = "10,6"
    $btn2.FontSize = 11
    $btn2.Margin = "0,0,8,0"
    $btn2.Add_Click({ $script:CurrentRemotePath = "/sdcard/Download/"; Switch-View -ViewName "Files" })
    $navPanel.Children.Add($btn2) | Out-Null

    $btn3 = New-Object System.Windows.Controls.Button
    $btn3.Content = "/storage/"
    $btn3.Style = $window.Resources["RoundedButton"]
    $btn3.Background = "#B0BEC5"
    $btn3.Padding = "10,6"
    $btn3.FontSize = 11
    $btn3.Margin = "0,0,8,0"
    $btn3.Add_Click({ $script:CurrentRemotePath = "/storage/"; Switch-View -ViewName "Files" })
    $navPanel.Children.Add($btn3) | Out-Null

    $btn4 = New-Object System.Windows.Controls.Button
    $btn4.Content = "/data/"
    $btn4.Style = $window.Resources["RoundedButton"]
    $btn4.Background = "#B0BEC5"
    $btn4.Padding = "10,6"
    $btn4.FontSize = 11
    $btn4.Margin = "0,0,8,0"
    $btn4.Add_Click({ $script:CurrentRemotePath = "/data/"; Switch-View -ViewName "Files" })
    $navPanel.Children.Add($btn4) | Out-Null

    $mainStack.Children.Add($navPanel) | Out-Null

    # Текущий путь
    $pathLabel = New-Object System.Windows.Controls.TextBlock
    $pathLabel.Text = "Путь: $($script:CurrentRemotePath)"
    $pathLabel.FontSize = 14
    $pathLabel.FontWeight = "SemiBold"
    $pathLabel.Foreground = "#2D2D30"
    $pathLabel.Margin = "0,0,0,10"
    $mainStack.Children.Add($pathLabel) | Out-Null

    # Загружаем файлы
    Write-Log -Message "Загружаю список файлов: $($script:CurrentRemotePath)" -Level "Info"
    $files = Get-RemoteFiles -Path $script:CurrentRemotePath

    $listBox = New-Object System.Windows.Controls.ListBox
    $listBox.FontSize = 13
    $listBox.BorderThickness = "1"
    $listBox.BorderBrush = "#E1E1E6"
    $listBox.MinHeight = 400
    $listBox.Padding = "5"

    if ($script:CurrentRemotePath -ne "/") {
        $upItem = New-Object System.Windows.Controls.ListBoxItem
        $upItem.Content = "[..]  Перейти на уровень выше"
        $upItem.Foreground = [System.Windows.Media.Brushes]::DarkOrange
        $upItem.FontWeight = "Bold"
        $upItem.Padding = "5"
        $upItem.Tag = [PSCustomObject]@{ IsUp = $true }
        [void]$listBox.Items.Add($upItem)
    }

    if ($files.Count -eq 0) {
        $emptyItem = New-Object System.Windows.Controls.ListBoxItem
        $emptyItem.Content = "(папка пуста)"
        $emptyItem.Foreground = [System.Windows.Media.Brushes]::Gray
        $emptyItem.Padding = "5"
        $emptyItem.IsEnabled = $false
        [void]$listBox.Items.Add($emptyItem)
    } else {
        $files = $files | Sort-Object @{Expression={ if ($_.IsDir) { 0 } else { 1 } }}, Name

        foreach ($f in $files) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            if ($f.IsDir) {
                $item.Content = "[ПАПКА]  $($f.Name)"
                $item.Foreground = [System.Windows.Media.Brushes]::SteelBlue
                $item.FontWeight = "SemiBold"
            } else {
                $sizeKB = [math]::Round($f.Size / 1KB, 1)
                $item.Content = "[ФАЙЛ]   $($f.Name)   ($sizeKB КБ)"
                $item.Foreground = [System.Windows.Media.Brushes]::Black
            }
            $item.Tag = $f
            $item.Padding = "5"
            [void]$listBox.Items.Add($item)
        }
    }

    if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }

    # Двойной клик
    $listBox.Add_MouseDoubleClick({
        if ($script:FileListBox.SelectedItem) {
            $tag = $script:FileListBox.SelectedItem.Tag
            if ($tag.IsUp) {
                $parent = $script:CurrentRemotePath.TrimEnd('/')
                if ($parent -eq "") {
                    $script:CurrentRemotePath = "/"
                } else {
                    $lastSlash = $parent.LastIndexOf('/')
                    if ($lastSlash -gt 0) {
                        $script:CurrentRemotePath = $parent.Substring(0, $lastSlash + 1)
                    } else {
                        $script:CurrentRemotePath = "/"
                    }
                }
                Switch-View -ViewName "Files"
            } elseif ($tag.IsDir) {
                $script:CurrentRemotePath = if ($tag.FullPath.EndsWith("/")) { $tag.FullPath } else { "$($tag.FullPath)/" }
                Switch-View -ViewName "Files"
            }
        }
    })

    $mainStack.Children.Add($listBox) | Out-Null
    $script:FileListBox = $listBox

    # Кнопки — СРАЗУ в BottomBar, а не в actionPanel
    $script:BottomBarContent.Children.Clear()

    $btnOpen = New-Object System.Windows.Controls.Button
    $btnOpen.Content = "Открыть"
    $btnOpen.Style = $window.Resources["RoundedButton"]
    $btnOpen.Background = "#4A90E2"
    $btnOpen.Padding = "12,8"
    $btnOpen.Margin = "0,0,8,0"
    $btnOpen.Add_Click({
        if ($script:FileListBox.SelectedItem) {
            $tag = $script:FileListBox.SelectedItem.Tag
            if ($tag.IsUp) {
                $parent = $script:CurrentRemotePath.TrimEnd('/')
                if ($parent -eq "") {
                    $script:CurrentRemotePath = "/"
                } else {
                    $lastSlash = $parent.LastIndexOf('/')
                    if ($lastSlash -gt 0) {
                        $script:CurrentRemotePath = $parent.Substring(0, $lastSlash + 1)
                    } else {
                        $script:CurrentRemotePath = "/"
                    }
                }
                Switch-View -ViewName "Files"
            } elseif ($tag.IsDir) {
                $script:CurrentRemotePath = if ($tag.FullPath.EndsWith("/")) { $tag.FullPath } else { "$($tag.FullPath)/" }
                Switch-View -ViewName "Files"
            }
        }
    })
    $script:BottomBarContent.Children.Add($btnOpen) | Out-Null

    $btnDownload = New-Object System.Windows.Controls.Button
    $btnDownload.Content = "Скачать на ПК"
    $btnDownload.Style = $window.Resources["RoundedButton"]
    $btnDownload.Background = "#66BB6A"
    $btnDownload.Padding = "12,8"
    $btnDownload.Margin = "0,0,8,0"
    $btnDownload.Add_Click({
        if ($script:FileListBox.SelectedItem) {
            $tag = $script:FileListBox.SelectedItem.Tag
            if ($tag.IsUp) { return }
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object System.Windows.Forms.SaveFileDialog
            $dlg.FileName = $tag.Name
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                Pull-RemoteFile -RemotePath $tag.FullPath -LocalPath $dlg.FileName
            }
        }
    })
    $script:BottomBarContent.Children.Add($btnDownload) | Out-Null

    $btnUpload = New-Object System.Windows.Controls.Button
    $btnUpload.Content = "Загрузить на ТВ"
    $btnUpload.Style = $window.Resources["RoundedButton"]
    $btnUpload.Background = "#FFB74D"
    $btnUpload.Padding = "12,8"
    $btnUpload.Margin = "0,0,8,0"
    $btnUpload.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Push-LocalFile -LocalPath $dlg.FileName -RemotePath $script:CurrentRemotePath
            Switch-View -ViewName "Files"
        }
    })
    $script:BottomBarContent.Children.Add($btnUpload) | Out-Null

    $btnNewFolder = New-Object System.Windows.Controls.Button
    $btnNewFolder.Content = "Создать папку"
    $btnNewFolder.Style = $window.Resources["RoundedButton"]
    $btnNewFolder.Background = "#64B5F6"
    $btnNewFolder.Padding = "12,8"
    $btnNewFolder.Margin = "0,0,8,0"
    $btnNewFolder.Add_Click({
        Add-Type -AssemblyName Microsoft.VisualBasic
        $name = [Microsoft.VisualBasic.Interaction]::InputBox("Имя новой папки:", "Создание папки", "NewFolder")
        if ($name) {
            $fullPath = if ($script:CurrentRemotePath.EndsWith("/")) { "$($script:CurrentRemotePath)$name" } else { "$($script:CurrentRemotePath)/$name" }
            New-RemoteFolder -Path $fullPath
            Switch-View -ViewName "Files"
        }
    })
    $script:BottomBarContent.Children.Add($btnNewFolder) | Out-Null

    $btnDelete = New-Object System.Windows.Controls.Button
    $btnDelete.Content = "Удалить"
    $btnDelete.Style = $window.Resources["RoundedButton"]
    $btnDelete.Background = "#E57373"
    $btnDelete.Padding = "12,8"
    $btnDelete.Add_Click({
        if ($script:FileListBox.SelectedItem) {
            $tag = $script:FileListBox.SelectedItem.Tag
            if ($tag.IsUp) { return }
            $confirm = [System.Windows.MessageBox]::Show(
                "Удалить «$($tag.Name)»?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                Remove-RemoteItem -Path $tag.FullPath
                Switch-View -ViewName "Files"
            }
        }
    })
    $script:BottomBarContent.Children.Add($btnDelete) | Out-Null

    $script:BottomBar.Visibility = "Visible"

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    Write-Log -Message "Экран файлового менеджера" -Level "Info"
}