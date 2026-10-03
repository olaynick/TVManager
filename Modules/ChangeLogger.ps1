# ===== ЛОГИРОВАНИЕ ИЗМЕНЕНИЙ =====

# Путь к файлу истории — рядом с программой
$script:ChangesFilePath = Join-Path (Split-Path $PSScriptRoot -Parent) "tv_changes_backup.json"

function Save-Change {
    param(
        [string]$Type,
        [string]$Target,
        [string]$RestoreCommand,
        [string]$Namespace = "",
        [string]$PreviousValue = ""
    )
    $script:allChanges += [PSCustomObject]@{
        Type           = $Type
        Target         = $Target
        RestoreCommand = $RestoreCommand
        Namespace      = $Namespace
        PreviousValue  = $PreviousValue
        Timestamp      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Save-AllChanges {
    $data = [PSCustomObject]@{
        DeviceIP = $script:deviceIp
        SavedAt  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Changes  = @($script:allChanges)
    }
    try {
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ChangesFilePath -Encoding UTF8
        Write-Log -Message "История сохранена: $($script:ChangesFilePath)" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка сохранения истории: $_" -Level "Error"
    }
}

function Load-Changes {
    if (-not (Test-Path $script:ChangesFilePath)) {
        return $null
    }
    try {
        return Get-Content $script:ChangesFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-ChangesFilePath {
    return $script:ChangesFilePath
}

function Remove-Change {
    param(
        [string]$Type,
        [string]$Target,
        [string]$Timestamp
    )
    $script:allChanges = @($script:allChanges | Where-Object {
        -not ($_.Type -eq $Type -and $_.Target -eq $Target -and $_.Timestamp -eq $Timestamp)
    })
    Save-AllChanges
}

function Test-TvConnected {
    # Если знаем IP — проверяем конкретно его
    if ($script:deviceIp) {
        try {
            $stateOut = & $script:adbPath -s "$($script:deviceIp):5555" get-state 2>&1
            $stateText = ($stateOut | Out-String).Trim()
            return ($stateText -eq "device")
        } catch {
            return $false
        }
    }

    # Иначе ищем любое device
    try {
        $devices = & $script:adbPath devices 2>&1
        foreach ($line in $devices) {
            if ($line -match '^\S+\s+device$') {
                return $true
            }
        }
        return $false
    } catch {
        return $false
    }
}