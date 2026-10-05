# ============================================================================
#  UI ХЕЛПЕРЫ
# ============================================================================

# ===== ПАЛИТРА ПО ИМЕНАМ =====
$script:ButtonPalette = @{
    Primary   = "#3e5f6e"
    Danger    = "#724c4c"
    Neutral   = "#4A4A4A"
    Warning   = "#9c8e6a"
    Success   = "#588653"
    Purple    = "#6c547e"
    Cyan      = "#569097"
    Gray      = "#909090"
    LightBlue = "#4e7891"
}

function Resolve-ButtonColor {
    param([string]$ColorType, [string]$Color)

    if ($Color) {
        return $Color
    }
    if ($ColorType -and $script:ButtonPalette.ContainsKey($ColorType)) {
        return $script:ButtonPalette[$ColorType]
    }
    return $script:ButtonPalette.Primary
}

# ============================================================================
#  ЗАГОЛОВОК ЭКРАНА
# ============================================================================
function New-ViewHeader {
    param(
        [Parameter(Mandatory)][string]$Text,
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 0
    )
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 26
    $tb.FontWeight = "Bold"
    $tb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $tb.Margin = "0,0,0,12"
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
    $tb.FontSize = 15
    $tb.FontWeight = "SemiBold"
    $tb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#C8C8C8")
    )
    $tb.Margin = "0,12,0,8"
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
    if ($Light) {
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#909090")
        )
    } else {
        $tb.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")
        )
    }
    $tb.Margin = "0,0,0,8"
    $tb.TextWrapping = "Wrap"
    if ($Width  -gt 0) { $tb.Width  = $Width }
    if ($Height -gt 0) { $tb.Height = $Height }
    return $tb
}

# ============================================================================
#  КНОПКА
# ============================================================================
function New-ViewButton {
    param(
        [Parameter(Mandatory)][string]$Text,
        [string]$ColorType = "Primary",
        [string]$Color = $null,
        [scriptblock]$OnClick,
        [string]$Margin = "0,0,0,8",
        [switch]$Compact,
        [switch]$Stretch
    )

    $btn = New-Object System.Windows.Controls.Button

    $bg = Resolve-ButtonColor -ColorType $ColorType -Color $Color

    if ($Compact) {
        $btn.Height = 30
        $btn.FontSize = 11
    } else {
        $btn.Height = 40
        $btn.FontSize = 13
    }

    $btn.Padding = New-Object System.Windows.Thickness(8, 0, 8, 0)
    $btn.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $btn.Background = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($bg)
    )
    $btn.BorderThickness = New-Object System.Windows.Thickness(0)
    $btn.Cursor = [System.Windows.Input.Cursors]::Hand

    if ($Stretch) {
        $btn.HorizontalAlignment = "Stretch"
    } else {
        $btn.HorizontalAlignment = "Left"
    }
    $btn.VerticalAlignment = "Top"
    $btn.HorizontalContentAlignment = "Center"
    $btn.VerticalContentAlignment = "Center"

    $templateStr = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="{x:Type Button}">
    <Border Background="{TemplateBinding Background}"
            CornerRadius="6"
            Padding="{TemplateBinding Padding}">
        <ContentPresenter HorizontalAlignment="Center"
                          VerticalAlignment="Center"
                          RecognizesAccessKey="True"/>
    </Border>
</ControlTemplate>
"@
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$templateStr)
    $btn.Template = [System.Windows.Markup.XamlReader]::Load($reader)

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.TextTrimming = "CharacterEllipsis"
    $tb.TextWrapping = "NoWrap"
    $tb.TextAlignment = "Center"
    $tb.FontSize = if ($Compact) { 11 } else { 13 }
    $tb.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")
    )
    $tb.VerticalAlignment = "Center"
    $tb.HorizontalAlignment = "Center"
    $btn.Content = $tb

    $btn.Margin = New-Object System.Windows.Thickness(0)

    if ($OnClick) {
        $btn.Add_Click($OnClick)
    }

    return $btn
}

# ============================================================================
#  КНОПКА "НАЗАД"
# ============================================================================
function New-BackButton {
    param([scriptblock]$OnClick)
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "← Назад"
    if ($window.Resources["BackButton"]) {
        $btn.Style = $window.Resources["BackButton"]
    }
    $btn.VerticalAlignment = "Top"
    $btn.HorizontalAlignment = "Right"
    $btn.Margin = "0,30,40,0"
    if ($OnClick) {
        $btn.Add_Click($OnClick)
    }
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

    # Разворачиваем BottomBar, если он свёрнут
    if ($script:BottomBar -and $script:BottomBar.Visibility -ne "Visible") {
        $script:BottomBar.Visibility = "Visible"
    }

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

    # Если в BottomBar нет кнопок — прячем его полностью
    if ($script:BottomBar -and $script:BottomBarContent) {
        if ($script:BottomBarContent.Children.Count -eq 0) {
            $script:BottomBar.Visibility = "Collapsed"
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

# ============================================================================
#  ВИРТУАЛИЗИРОВАННЫЙ СПИСОК ЧЕКБОКСОВ
#
#  Принимает массив уже созданных CheckBox-ов и возвращает ListBox
#  с виртуализацией. Это позволяет держать в UI только видимые элементы
#  (обычно 10-15), а не все 200+ сразу — экраны открываются в разы быстрее.
#
#  Использование:
#    $chkList = New-VirtualizedCheckboxList -Checkboxes $myCheckboxes -MaxHeight 500
#    $container.Children.Add($chkList) | Out-Null
# ============================================================================
function New-VirtualizedCheckboxList {
    param(
        [Parameter(Mandatory)][array]$Checkboxes,
        [double]$MaxHeight = 0
    )

    # --- ListBox с настройками виртуализации ---
    $listBox = New-Object System.Windows.Controls.ListBox

    $listBox.Background = [System.Windows.Media.Brushes]::Transparent
    $listBox.BorderThickness = New-Object System.Windows.Thickness(0)
    $listBox.Padding = New-Object System.Windows.Thickness(0)
    $listBox.Margin = New-Object System.Windows.Thickness(0)
    $listBox.Focusable = $false

    # --- Виртуализация ---
    [System.Windows.Controls.VirtualizingPanel]::SetIsVirtualizing($listBox, $true)
    [System.Windows.Controls.VirtualizingPanel]::SetVirtualizationMode(
        $listBox,
        [System.Windows.Controls.VirtualizationMode]::Recycling
    )
    [System.Windows.Controls.ScrollViewer]::SetCanContentScroll($listBox, $true)
    [System.Windows.Controls.ScrollViewer]::SetHorizontalScrollBarVisibility(
        $listBox,
        [System.Windows.Controls.ScrollBarVisibility]::Disabled
    )
    [System.Windows.Controls.ScrollViewer]::SetVerticalScrollBarVisibility(
        $listBox,
        [System.Windows.Controls.ScrollBarVisibility]::Auto
    )

    if ($MaxHeight -gt 0) {
        $listBox.MaxHeight = $MaxHeight
    }

    # --- ItemContainerStyle: обнуляем визуал ListBoxItem ---
    $itemStyleStr = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="ListBoxItem">
    <Setter Property="Padding" Value="0"/>
    <Setter Property="Margin" Value="0"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="ListBoxItem">
                <ContentPresenter/>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$itemStyleStr)
        $listBox.ItemContainerStyle = [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-Log -Message "Не удалось применить стиль ListBoxItem: $_" -Level "Warning"
    }

    # --- Заполняем элементами ---
    foreach ($chk in $Checkboxes) {
        [void]$listBox.Items.Add($chk)
    }

    return $listBox
}