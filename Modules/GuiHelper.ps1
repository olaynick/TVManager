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
                "Error"   { [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#a57777")
                ) }
                "Warning" { [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#a39571")
                ) }
                "Success" { [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#8eac89")
                ) }
                default   { [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#b4b3b3")
                ) }
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
    Background      = "#202020"
    Card            = "#2B2B2B"
    CardBorder      = "#3A3A3A"
    Text            = "#FFFFFF"
    TextLight       = "#A0A0A0"
    Primary         = "#3e5f6e"
    Success         = "#588653"
    Warning         = "#9c8e6a"
    Danger          = "#724c4c"
    Purple          = "#6c547e"
    Cyan            = "#569097"
    Gray            = "#909090"
    LightGray       = "#707070"
    TabBg           = "#2B2B2B"
    TabHover        = "#2A2A2A"
    TabActive       = "#333333"
    LogBg           = "#181818"
    LogText         = "#D0D0D0"
    BottomBarBg     = "#2B2B2B"
    BottomBarBorder = "#3A3A3A"
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