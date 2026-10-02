# ===== ПОДКЛЮЧАЕМ СБОРКИ =====
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ===== ЛОГГЕР =====
$script:LogBox = $null

function Set-LogBox {
    param([System.Windows.Controls.RichTextBox]$Box)
    $script:LogBox = $Box
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    if ($script:LogBox) {
        $time = Get-Date -Format "HH:mm:ss"
        $prefix = switch ($Level) {
            "Error"   { "[ОШИБКА]" }
            "Warning" { "[!]" }
            "Success" { "[OK]" }
            default   { "[i]" }
        }
        $line = "$time $prefix $Message"

        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = New-Object System.Windows.Thickness(0)

        $run = New-Object System.Windows.Documents.Run
        $run.Text = "$line`r`n"

        $color = switch ($Level) {
            "Error"   { [System.Windows.Media.Brushes]::LightCoral }
            "Warning" { [System.Windows.Media.Brushes]::Khaki }
            "Success" { [System.Windows.Media.Brushes]::LightGreen }
            default   { [System.Windows.Media.Brushes]::LightGray }
        }
        $run.Foreground = $color
        $para.Inlines.Add($run)

        $script:LogBox.Document.Blocks.Add($para)
        $script:LogBox.ScrollToEnd()
    }
}

# ===== ХЕЛПЕР: ЦВЕТ ИЗ ТЕМЫ =====
# ===== ЦВЕТА =====
$script:Theme = @{
    Background      = "#F7F7FA"
    Card            = "#FFFFFF"
    CardBorder      = "#E1E1E6"
    Text            = "#2D2D30"
    TextLight       = "#96969B"
    Primary         = "#4A90E2"
    Success         = "#66BB6A"
    Warning         = "#FFB74D"
    Danger          = "#E57373"
    Purple          = "#9C27B0"
    Cyan            = "#00BCD4"
    Gray            = "#607D8B"
    LightGray       = "#9E9E9E"
    TabBg           = "#F0F0F5"
    TabHover        = "#E4E4EC"
    TabActive       = "#4A90E2"
    LogBg           = "#282A30"
    LogText         = "#D2D2D7"
    BottomBarBg     = "#F0F0F5"
    BottomBarBorder = "#E1E1E6"
}

function Get-ThemeColor {
    param([string]$Key, [string]$Default = "#4A90E2")
    if ($script:Theme.ContainsKey($Key)) {
        return $script:Theme[$Key]
    }
    return $Default
}

function New-ThemeBrush {
    param([string]$Key, [string]$Default = "#4A90E2")
    $hex = Get-ThemeColor -Key $Key -Default $Default
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    return New-Object System.Windows.Media.SolidColorBrush($color)
}

# ===== ЗАГОЛОВОК =====
function New-ViewHeader {
    param(
        [string]$Text,
        [int]$X = 20,
        [int]$Y = 15,
        [int]$Width = 700
    )
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.FontSize = 18
    $label.FontWeight = "Bold"
    $label.Foreground = New-ThemeBrush -Key "Text" -Default "#2D2D30"
    $label.Margin = "0,0,0,20"
    return $label
}

# ===== ПОДЗАГОЛОВОК ШАГА =====
function New-StepTitle {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 15
    $tb.FontWeight = "SemiBold"
    $tb.Foreground = New-ThemeBrush -Key "Text" -Default "#2D2D30"
    $tb.Margin = "0,15,0,10"
    return $tb
}

# ===== ПОДПИСЬ =====
function New-ViewLabel {
    param(
        [string]$Text,
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 400,
        [int]$Height = 22,
        [switch]$Light
    )
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.FontSize = 12
    if ($Light) {
        $label.Foreground = New-ThemeBrush -Key "TextLight" -Default "#96969B"
    } else {
        $label.Foreground = New-ThemeBrush -Key "Text" -Default "#2D2D30"
    }
    $label.TextWrapping = "Wrap"
    $label.Margin = "0,0,0,8"
    return $label
}

# ===== КНОПКА =====
function New-ViewButton {
    param(
        [string]$Text,
        [string]$Color = $null,
        [scriptblock]$OnClick,
        [string]$Margin = "0,0,10,0",
        [string]$Padding = "20,8"
    )

    if (-not $Color) {
        $Color = Get-ThemeColor -Key "Primary" -Default "#4A90E2"
    }

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Text
    $btn.Style = $window.Resources["RoundedButton"]
    $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    )
    $btn.Padding = $Padding
    $btn.HorizontalAlignment = "Left"
    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

# ===== КНОПКА "НАЗАД" =====
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

# ===== ОБЁРТКА ЭКРАНА =====
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
    $script:BottomBarContent.Children.Clear()   # ← есть ли эта строка?
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

# ===== СООБЩЕНИЕ =====
function Show-GuiMessage {
    param(
        [string]$Text,
        [string]$Title = "Сообщение",
        [string]$Type = "Info"
    )
    $icon = switch ($Type) {
        "Error"   { [System.Windows.MessageBoxImage]::Error }
        "Warning" { [System.Windows.MessageBoxImage]::Warning }
        default   { [System.Windows.MessageBoxImage]::Information }
    }
    [System.Windows.MessageBox]::Show($Text, $Title, [System.Windows.MessageBoxButton]::OK, $icon) | Out-Null
}

function Show-GuiQuestion {
    param(
        [string]$Text,
        [string]$Title = "Подтверждение"
    )
    $result = [System.Windows.MessageBox]::Show(
        $Text, $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

# ===== ПАНЕЛЬ ЛОГА (создаётся в XAML) =====
function New-LogPanel {
    param(
        [System.Windows.Window]$Window,
        [int]$Height = 140
    )
    # Лог-панель уже определена в XAML. Функция оставлена для совместимости.
    return $null
}

# ===== ПАНЕЛЬ СО СПИСКОМ УСТРОЙСТВ =====
function New-DeviceListPanel {
    param(
        [array]$Devices,
        [scriptblock]$OnSelect
    )

    $container = New-Object System.Windows.Controls.Panel
    $container.Size = New-Object System.Drawing.Size(700, 300)
    return $container
}