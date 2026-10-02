# Заголовок экрана
function New-ViewHeader {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 26
    $tb.FontWeight = "Bold"
    $tb.Margin = "0,0,0,20"
    return $tb
}

# Подзаголовок шага
function New-StepTitle {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 16
    $tb.FontWeight = "SemiBold"
    $tb.Margin = "0,15,0,10"
    return $tb
}

# Подпись
function New-ViewLabel {
    param([string]$Text, [switch]$Light)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 12
    $tb.Foreground = if ($Light) { "#96969B" } else { "#2D2D30" }
    $tb.Margin = "0,0,0,8"
    $tb.TextWrapping = "Wrap"
    return $tb
}

# Кнопка
function New-ViewButton {
    param(
        [string]$Text,
        [string]$ColorType = "Primary",   # Primary / Danger / Neutral
        [scriptblock]$OnClick,
        [string]$Margin = "0,0,8,0",
        [switch]$Compact
    )

    $colors = @{
        Primary = "#4A90E2"
        Danger  = "#E57373"
        Neutral = "#B0BEC5"
    }

    $bg = if ($colors.ContainsKey($ColorType)) { $colors[$ColorType] } else { $colors.Primary }

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Text
    $btn.Style = $window.Resources["RoundedButton"]
    $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($bg)
    )
    $btn.Padding = if ($Compact) { "10,4" } else { "14,6" }
    $btn.FontSize = if ($Compact) { 11 } else { 13 }
    $btn.Height = if ($Compact) { 30 } else { 36 }
    $btn.HorizontalAlignment = "Left"
    $btn.Margin = $Margin

    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

# Кнопка "Назад" в правом верхнем углу
function New-BackButton {
    param([scriptblock]$OnClick)
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "← Назад"
    $btn.Style = $window.Resources["BackButton"]
    $btn.VerticalAlignment = "Top"
    $btn.HorizontalAlignment = "Right"
    $btn.Margin = "0,30,40,0"
    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

# Обёртка: rootGrid + mainStack + backButton
function New-ViewRoot {
    param(
        [System.Windows.Controls.StackPanel]$Stack,
        [scriptblock]$OnBack
    )
    $rootGrid = New-Object System.Windows.Controls.Grid
    $rootGrid.Children.Add($Stack) | Out-Null
    if ($OnBack) {
        $back = New-BackButton -OnClick $OnBack
        $rootGrid.Children.Add($back) | Out-Null
    }
    return $rootGrid
}

# ===== УПРАВЛЕНИЕ НИЖНЕЙ ПАНЕЛЬЮ КНОПОК =====
function Set-BottomButtons {
    param([array]$Buttons)
    if (-not $script:BottomBarContent) { return }
    $script:BottomBarContent.Children.Clear()
    foreach ($btn in $Buttons) {
        $script:BottomBarContent.Children.Add($btn) | Out-Null
    }
    if ($script:BottomBar) {
        $script:BottomBar.Visibility = "Visible"
    }
}

function Hide-BottomBar {
    if (-not $script:BottomBarContent) { return }
    $script:BottomBarContent.Children.Clear()
    if ($script:BottomBar) {
        $script:BottomBar.Visibility = "Collapsed"
    }
}