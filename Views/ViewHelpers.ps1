# Views\ViewHelpers.ps1
# ============================================================================
#  ЕДИНЫЙ набор UI-хелперов.
#  Все дубли из GuiHelper.ps1 удалены.
#  Поддерживает старый API (-ColorType) и новый (-Color, -Padding, -Compact).
# ============================================================================

# ===== ПАЛИТРА ПО ИМЕНАМ =====
$script:ButtonPalette = @{
    Primary = "#4A90E2"
    Danger  = "#E57373"
    Neutral = "#B0BEC5"
    Warning = "#FFB74D"
    Success = "#66BB6A"
    Purple  = "#9C27B0"
    Cyan    = "#00BCD4"
    Gray    = "#607D8B"
    LightBlue = "#64B5F6"
}

function Resolve-ButtonColor {
    param([string]$ColorType, [string]$Color)

    if ($Color) {
        # Явный hex имеет приоритет
        return $Color
    }
    if ($ColorType -and $script:ButtonPalette.ContainsKey($ColorType)) {
        return $script:ButtonPalette[$ColorType]
    }
    return $script:ButtonPalette.Primary
}

# ============================================================================
#  КНОПКА
# ============================================================================
function New-ViewButton {
    param(
        [Parameter(Mandatory)][string]$Text,
        [string]$ColorType = "Primary",     # Primary / Danger / Neutral / Warning / Success / Purple / Cyan / Gray / LightBlue
        [string]$Color = $null,             # явный hex (#RRGGBB), переопределяет ColorType
        [scriptblock]$OnClick,
        [string]$Margin = "0,0,8,0",
        [string]$Padding = $null,           # если не задан — вычисляется из -Compact
        [switch]$Compact,
        [int]$Width = 0                     # 0 = авто
    )

    $bg = Resolve-ButtonColor -ColorType $ColorType -Color $Color

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Text

    # Style может не быть в Resources — подстрахуемся
    if ($window -and $window.Resources["RoundedButton"]) {
        $btn.Style = $window.Resources["RoundedButton"]
    }

    $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($bg)
    )

    if ($Padding) {
        $btn.Padding = $Padding
    } elseif ($Compact) {
        $btn.Padding = "10,4"
    } else {
        $btn.Padding = "14,6"
    }

    $btn.FontSize = if ($Compact) { 11 } else { 13 }
    $btn.Height   = if ($Compact) { 30 } else { 36 }
    $btn.HorizontalAlignment = "Left"
    $btn.Margin = $Margin

    if ($Width -gt 0) { $btn.Width = $Width }

    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

# ============================================================================
#  ЗАГОЛОВОК ЭКРАНА
# ============================================================================
function New-ViewHeader {
    param(
        [Parameter(Mandatory)][string]$Text,
        [int]$X = 20,
        [int]$Y = 15,
        [int]$Width = 0
    )
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 26
    $tb.FontWeight = "Bold"
    $tb.Margin = "0,0,0,20"
    if ($Width -gt 0) { $tb.Width = $Width }
    return $tb
}

# ============================================================================
#  ПОДЗАГОЛОВОК ШАГА
# ============================================================================
function New-StepTitle {
    param([Parameter(Mandatory)][string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 16
    $tb.FontWeight = "SemiBold"
    $tb.Margin = "0,15,0,10"
    return $tb
}

# ============================================================================
#  ПОДПИСЬ / МЕТКА
# ============================================================================
function New-ViewLabel {
    param(
        [Parameter(Mandatory)][string]$Text,
        [switch]$Light,
        [int]$Width = 0,
        [int]$Height = 0
    )
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 12
    $tb.Foreground = if ($Light) { "#96969B" } else { "#2D2D30" }
    $tb.Margin = "0,0,0,8"
    $tb.TextWrapping = "Wrap"
    if ($Width  -gt 0) { $tb.Width  = $Width }
    if ($Height -gt 0) { $tb.Height = $Height }
    return $tb
}

# ============================================================================
#  КНОПКА "НАЗАД"
# ============================================================================
function New-BackButton {
    param([scriptblock]$OnClick)
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "← Назад"
    if ($window -and $window.Resources["BackButton"]) {
        $btn.Style = $window.Resources["BackButton"]
    }
    $btn.VerticalAlignment = "Top"
    $btn.HorizontalAlignment = "Right"
    $btn.Margin = "0,30,40,0"
    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

# ============================================================================
#  ОБЁРТКА ЭКРАНА
# ============================================================================
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

# ============================================================================
#  НИЖНЯЯ ПАНЕЛЬ КНОПОК
# ============================================================================
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

# ============================================================================
#  ПРОГРЕСС-БАР
# ============================================================================
function Show-Progress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label = ""
    )

    if (-not $script:BottomBarProgress) { return }

    $script:BottomBarProgress.Visibility = "Visible"
    $script:BottomBarProgress.Maximum = [math]::Max($Total, 1)
    $script:BottomBarProgress.Value = $Current

    if ($script:BottomBarProgressText) {
        $script:BottomBarProgressText.Visibility = "Visible"
        if ($Label) {
            $script:BottomBarProgressText.Text = "$Label $Current/$Total"
        } else {
            $script:BottomBarProgressText.Text = "$Current/$Total"
        }
    }
}

function Hide-Progress {
    if (-not $script:BottomBarProgress) { return }
    $script:BottomBarProgress.Visibility = "Collapsed"
    $script:BottomBarProgress.Value = 0
    if ($script:BottomBarProgressText) {
        $script:BottomBarProgressText.Visibility = "Collapsed"
        $script:BottomBarProgressText.Text = ""
    }
}