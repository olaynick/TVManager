# ============================================================================
#  Экран: Управление разрешениями приложений
# ============================================================================

# ============================================================================
#  ФУНКЦИЯ ЗАГРУЗКИ РАЗРЕШЕНИЙ (глобальная — вне Show-PermissionsView)
# ============================================================================
function Load-PackagePermissions {
    if (-not $script:PermCheckboxesContainer) { return }
    if (-not $script:PermPackageCombo) { return }
    if (-not $window) { return }

    $script:PermCheckboxesContainer.Children.Clear()
    $script:PermCheckboxes = @()

    $selected = $script:PermPackageCombo.SelectedItem
    if (-not $selected) { return }

    try {
        Write-Log -Message "Читаю разрешения: $selected" -Level "Info"
        $perms = Get-PackagePermissions -Package $selected

        if (-not $perms -or -not $perms.All -or $perms.All.Count -eq 0) {
            $empty = New-ViewLabel -Text "Не удалось прочитать разрешения для $selected" -Light
            $script:PermCheckboxesContainer.Children.Add($empty) | Out-Null
            return
        }

        foreach ($perm in $perms.All) {
            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.Style = $window.Resources["MiuiCheckBox"]
            $chk.FontSize = 12
            $chk.Tag = $perm
            $chk.Margin = "0,2,0,2"

            $humanDesc = Get-PermissionDescription -Permission $perm
            if ($humanDesc) {
                $chk.Content = "$humanDesc  ($perm)"
            } else {
                $chk.Content = $perm
            }

            if ($perm -in $perms.Granted) {
                $chk.IsChecked = $true
                $chk.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#6CCB5F")
                )
            } else {
                $chk.IsChecked = $false
                $chk.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#A0A0A0")
                )
            }

            $script:PermCheckboxesContainer.Children.Add($chk) | Out-Null
            $script:PermCheckboxes += $chk
        }

        Write-Log -Message "Разрешений: $($perms.All.Count) (разрешено $($perms.Granted.Count), запрещено $($perms.Denied.Count))" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка загрузки разрешений: $_" -Level "Error"
        $errLabel = New-ViewLabel -Text "Ошибка: $_" -Light
        $script:PermCheckboxesContainer.Children.Add($errLabel) | Out-Null
    }
}

# ============================================================================
#  ОСНОВНОЙ ЭКРАН
# ============================================================================
function Show-PermissionsView {
    $mainStack = New-Object System.Windows.Controls.StackPanel
    $mainStack.Margin = "25,20,25,20"

    $header = New-ViewHeader -Text "Разрешения приложений"
    $mainStack.Children.Add($header) | Out-Null

    $desc = New-ViewLabel -Text "Управление разрешениями приложений. Выберите пакет, отметьте нужные разрешения галочками и нажмите «Применить изменения». Не все разрешения можно менять — некоторые требуют системных привилегий." -Light
    $desc.TextWrapping = "Wrap"
    $desc.Margin = "0,0,0,10"
    $mainStack.Children.Add($desc) | Out-Null

    if (-not $script:connected) {
        $mainStack.Children.Add((New-ViewLabel -Text "Нет подключения к телевизору.")) | Out-Null
        $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
        $contentGrid.Children.Add($rootGrid) | Out-Null
        return
    }

    # ===== ВЫБОР ПАКЕТА =====
    $mainStack.Children.Add((New-StepTitle -Text "1. Выберите приложение")) | Out-Null

    $packageCombo = New-Object System.Windows.Controls.ComboBox
    $packageCombo.FontSize = 12
    $packageCombo.Height = 32
    $packageCombo.Margin = "0,5,0,10"
    $packageCombo.Padding = "8,4"

    try {
        $pkgs = Get-ThirdPartyAppsForPermissions
        foreach ($p in $pkgs) {
            [void]$packageCombo.Items.Add($p)
        }
        Write-Log -Message "Пакетов для разрешений: $($pkgs.Count)" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка получения пакетов: $_" -Level "Error"
    }

    $mainStack.Children.Add($packageCombo) | Out-Null

    # ===== СПИСОК РАЗРЕШЕНИЙ =====
    $mainStack.Children.Add((New-StepTitle -Text "2. Разрешения")) | Out-Null

    $permScroll = New-Object System.Windows.Controls.ScrollViewer
    $permScroll.VerticalScrollBarVisibility = "Auto"
    $permScroll.MaxHeight = 380
    $permScroll.Margin = "0,5,0,10"

    $permContainer = New-Object System.Windows.Controls.StackPanel
    $permScroll.Content = $permContainer
    $mainStack.Children.Add($permScroll) | Out-Null

    # ===== СОХРАНЯЕМ ССЫЛКИ =====
    $script:PermPackageCombo = $packageCombo
    $script:PermCheckboxesContainer = $permContainer
    $script:PermCheckboxes = @()

    # ===== SelectedIndex ПОСЛЕ сохранения ссылок =====
    if ($packageCombo.Items.Count -gt 0) {
        $packageCombo.SelectedIndex = 0
    }

    # ===== ПОДПИСКА =====
    $packageCombo.Add_SelectionChanged({
        Load-PackagePermissions
    })

    # ===== ЗАГРУЗКА — СРАЗУ =====
    Load-PackagePermissions

    $rootGrid = New-ViewRoot -Stack $mainStack -OnBack { Switch-View -ViewName "Setup" }
    $contentGrid.Children.Add($rootGrid) | Out-Null

    # ===== КНОПКИ BOTTOM BAR =====
    $buttons = @()

    # --- Применить изменения (точечно) ---
    $btnApply = New-Object System.Windows.Controls.Button
    $btnApply.Content = "Применить изменения"
    $btnApply.Style = $window.Resources["RoundedButton"]
    $btnApply.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#3e5f6e")
    )
    $btnApply.Padding = "12,6"
    $btnApply.FontSize = 11
    $btnApply.Margin = "0,0,8,0"
    $btnApply.Add_Click({
        try {
            $selected = $script:PermPackageCombo.SelectedItem
            if (-not $selected) { return }

            $currentPerms = Get-PackagePermissions -Package $selected
            $grantedSet = @{}
            foreach ($p in $currentPerms.Granted) { $grantedSet[$p] = $true }

            $grantedCount = 0
            $revokedCount = 0
            $failedCount = 0

            Write-Log -Message "=== Применяю изменения для $selected ===" -Level "Info"

            foreach ($chk in $script:PermCheckboxes) {
                $perm = $chk.Tag
                $wasGranted = $grantedSet.ContainsKey($perm)
                $wantGranted = ($chk.IsChecked -eq $true)

                if ($wantGranted -and -not $wasGranted) {
                    if (Grant-Permission -Package $selected -Permission $perm) {
                        $grantedCount++
                        Write-Log -Message "  + Разрешено: $perm" -Level "Success"
                    } else {
                        $failedCount++
                        Write-Log -Message "  ! Не удалось разрешить: $perm" -Level "Warning"
                    }
                } elseif (-not $wantGranted -and $wasGranted) {
                    if (Revoke-Permission -Package $selected -Permission $perm) {
                        $revokedCount++
                        Write-Log -Message "  - Отозвано: $perm" -Level "Success"
                    } else {
                        $failedCount++
                        Write-Log -Message "  ! Не удалось отозвать: $perm" -Level "Warning"
                    }
                }
            }

            Write-Log -Message "Итог: выдано $grantedCount, отозвано $revokedCount, ошибок $failedCount" -Level "Success"

            Load-PackagePermissions
        } catch {
            Write-Log -Message "Ошибка применения: $_" -Level "Error"
        }
    })
    $buttons += $btnApply

    # --- Запретить опасные ---
    $btnDenyDangerous = New-Object System.Windows.Controls.Button
    $btnDenyDangerous.Content = "Запретить опасные"
    $btnDenyDangerous.Style = $window.Resources["RoundedButton"]
    $btnDenyDangerous.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#724c4c")
    )
    $btnDenyDangerous.Padding = "12,6"
    $btnDenyDangerous.FontSize = 11
    $btnDenyDangerous.Margin = "0,0,8,0"
    $btnDenyDangerous.Add_Click({
        try {
            $selected = $script:PermPackageCombo.SelectedItem
            if (-not $selected) { return }

            $confirm = [System.Windows.MessageBox]::Show(
                "Запретить ВСЕ опасные разрешения для $selected?`n`nПриложение может перестать работать.",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            $dangerous = Get-DangerousPermissions
            $ok = 0
            foreach ($perm in $dangerous) {
                if (Revoke-Permission -Package $selected -Permission $perm) { $ok++ }
            }
            Write-Log -Message "Отозвано опасных разрешений: $ok" -Level "Success"
            Load-PackagePermissions
        } catch {
            Write-Log -Message "Ошибка: $_" -Level "Error"
        }
    })
    $buttons += $btnDenyDangerous

    # --- Разрешить все ---
    $btnGrantAll = New-Object System.Windows.Controls.Button
    $btnGrantAll.Content = "Разрешить все"
    $btnGrantAll.Style = $window.Resources["RoundedButton"]
    $btnGrantAll.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#588653")
    )
    $btnGrantAll.Padding = "12,6"
    $btnGrantAll.FontSize = 11
    $btnGrantAll.Margin = "0,0,8,0"
    $btnGrantAll.Add_Click({
        try {
            $selected = $script:PermPackageCombo.SelectedItem
            if (-not $selected) { return }

            $ok = 0
            foreach ($chk in $script:PermCheckboxes) {
                if (Grant-Permission -Package $selected -Permission $chk.Tag) { $ok++ }
            }
            Write-Log -Message "Разрешено: $ok" -Level "Success"
            Load-PackagePermissions
        } catch {
            Write-Log -Message "Ошибка: $_" -Level "Error"
        }
    })
    $buttons += $btnGrantAll

    # --- Отозвать все ---
    $btnRevokeAll = New-Object System.Windows.Controls.Button
    $btnRevokeAll.Content = "Отозвать все"
    $btnRevokeAll.Style = $window.Resources["RoundedButton"]
    $btnRevokeAll.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString("#9c8e6a")
    )
    $btnRevokeAll.Padding = "12,6"
    $btnRevokeAll.FontSize = 11
    $btnRevokeAll.Add_Click({
        try {
            $selected = $script:PermPackageCombo.SelectedItem
            if (-not $selected) { return }

            $confirm = [System.Windows.MessageBox]::Show(
                "Отозвать ВСЕ разрешения для $selected?",
                "Подтверждение",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            $ok = 0
            foreach ($chk in $script:PermCheckboxes) {
                if (Revoke-Permission -Package $selected -Permission $chk.Tag) { $ok++ }
            }
            Write-Log -Message "Отозвано: $ok" -Level "Success"
            Load-PackagePermissions
        } catch {
            Write-Log -Message "Ошибка: $_" -Level "Error"
        }
    })
    $buttons += $btnRevokeAll

    Set-BottomButtons -Buttons $buttons

    Write-Log -Message "Экран разрешений" -Level "Info"
}