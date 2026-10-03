# Modules\GuiHelper.ps1
# ============================================================================
#  Логгер, тема, диалоги.
#  UI-хелперы (New-ViewButton, New-ViewHeader и т.д.) — в Views\ViewHelpers.ps1.
#  НЕ ДУБЛИРОВАТЬ!
# ============================================================================

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

    $time = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "Error"   { "[ОШИБКА]" }
        "Warning" { "[!]" }
        "Success" { "[OK]" }
        default   { "[i]" }
    }
    $line = "$time $prefix $Message"

    # --- 1. В GUI ---
    if ($script:LogBox) {
        try {
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

            # Ограничиваем размер лога в GUI (защита от утечки памяти)
            if ($script:LogBox.Document.Blocks.Count -gt 2000) {
                $script:LogBox.Document.Blocks.Remove($script:LogBox.Document.Blocks.FirstBlock)
            }

            $script:LogBox.ScrollToEnd()
        } catch { }
    }

    # --- 2. В файл ---
    # --- 2. В файл (рядом с программой, в папку Logs) ---
    try {
        # Определяем папку программы: сначала script:AppRoot (установлен в Main.ps1),
        # потом fallback на $PSScriptRoot, потом на текущую директорию
        $appRoot = $null
        if ($script:AppRoot -and (Test-Path $script:AppRoot)) {
            $appRoot = $script:AppRoot
        } elseif ($PSScriptRoot) {
            $appRoot = Split-Path $PSScriptRoot -Parent
        } else {
            $appRoot = $PWD.Path
        }

        $logDir = Join-Path $appRoot "Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
        "$(Get-Date -Format 'HH:mm:ss.fff') [$Level] $Message" |
            Out-File -FilePath $logFile -Append -Encoding UTF8
    } catch {
        # Не роняем UI, если нет прав на запись — просто пропускаем
    }
}

# ===== ТЕМА =====
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

# ===== СООБЩЕНИЯ =====
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