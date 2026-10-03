# ============================================================================
#  Scenario Engine — пакетный режим
#  Сценарий = последовательность шагов. Сохраняется в scenarios.json
# ============================================================================

$script:ScenariosPath = Join-Path $script:AppRoot "scenarios.json"
$script:Scenarios = @()

# ===== ЗАГРУЗКА / СОХРАНЕНИЕ =====
function Load-Scenarios {
    if (-not (Test-Path $script:ScenariosPath)) {
        $script:Scenarios = @()
        return
    }
    try {
        $json = Get-Content $script:ScenariosPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json -is [array]) {
            $script:Scenarios = @($json)
        } else {
            $script:Scenarios = @($json)
        }
        Write-Log -Message "Сценариев загружено: $($script:Scenarios.Count)" -Level "Info"
    } catch {
        Write-Log -Message "Ошибка чтения scenarios.json: $_" -Level "Error"
        $script:Scenarios = @()
    }
}

function Save-Scenarios {
    try {
        $data = @($script:Scenarios)
        $json = $data | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($script:ScenariosPath, $json, [System.Text.UTF8Encoding]::new($false))
    } catch {
        Write-Log -Message "Ошибка сохранения scenarios.json: $_" -Level "Error"
    }
}

function Get-Scenarios {
    return ,$script:Scenarios
}

function Get-ScenarioByName {
    param([string]$Name)
    return $script:Scenarios | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
}

function Save-Scenario {
    param([PSCustomObject]$Scenario)

    if (-not $Scenario -or [string]::IsNullOrWhiteSpace($Scenario.Name)) {
        Write-Log -Message "Сценарий без имени — не сохраняю" -Level "Error"
        return $false
    }

    $existing = $script:Scenarios | Where-Object { $_.Name -eq $Scenario.Name } | Select-Object -First 1

    if ($existing) {
        $script:Scenarios = @($script:Scenarios | ForEach-Object {
            if ($_.Name -eq $Scenario.Name) { $Scenario } else { $_ }
        })
    } else {
        $script:Scenarios = @($script:Scenarios) + @($Scenario)
    }

    Save-Scenarios
    Write-Log -Message "Сценарий сохранён: $($Scenario.Name)" -Level "Success"
    return $true
}

function Remove-Scenario {
    param([string]$Name)
    $script:Scenarios = @($script:Scenarios | Where-Object { $_.Name -ne $Name })
    Save-Scenarios
    Write-Log -Message "Сценарий удалён: $Name" -Level "Success"
}

# ===== ЭКСПОРТ / ИМПОРТ =====
function Export-Scenarios {
    param([string]$FilePath)

    try {
        $data = [PSCustomObject]@{
            Version    = "1.0"
            ExportedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Scenarios  = @($script:Scenarios)
        }
        $data | ConvertTo-Json -Depth 20 | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Log -Message "Экспортировано сценариев: $($script:Scenarios.Count)" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка экспорта: $_" -Level "Error"
        return $false
    }
}

function Import-Scenarios {
    param(
        [string]$FilePath,
        [switch]$Replace
    )

    if (-not (Test-Path $FilePath)) {
        Write-Log -Message "Файл не найден: $FilePath" -Level "Error"
        return $false
    }

    try {
        $data = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($data.Scenarios) {
            $imported = @($data.Scenarios)
        } elseif ($data -is [array]) {
            $imported = @($data)
        } else {
            $imported = @($data)
        }

        if ($Replace) {
            $script:Scenarios = $imported
        } else {
            $merged = @($script:Scenarios)
            foreach ($sc in $imported) {
                $existing = $merged | Where-Object { $_.Name -eq $sc.Name } | Select-Object -First 1
                if ($existing) {
                    $merged = @($merged | ForEach-Object {
                        if ($_.Name -eq $sc.Name) { $sc } else { $_ }
                    })
                } else {
                    $merged = @($merged) + @($sc)
                }
            }
            $script:Scenarios = $merged
        }
        Save-Scenarios
        Write-Log -Message "Импортировано сценариев: $($imported.Count)" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка импорта: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ОПИСАНИЕ ТИПОВ ШАГОВ (для UI)
# ============================================================================
function Get-ScenarioStepTypes {
    return @(
        @{
            Type = "disable_package"
            Name = "Отключить пакет"
            Desc = "pm disable-user"
            Fields = @(
                @{ Key = "Package"; Label = "Имя пакета"; Hint = "com.example.app" }
            )
        },
        @{
            Type = "enable_package"
            Name = "Включить пакет"
            Desc = "pm enable"
            Fields = @(
                @{ Key = "Package"; Label = "Имя пакета"; Hint = "com.example.app" }
            )
        },
        @{
            Type = "remove_package"
            Name = "Удалить пакет"
            Desc = "pm uninstall --user 0"
            Fields = @(
                @{ Key = "Package"; Label = "Имя пакета"; Hint = "com.example.app" }
            )
        },
        @{
            Type = "clear_package"
            Name = "Очистить данные пакета"
            Desc = "pm clear"
            Fields = @(
                @{ Key = "Package"; Label = "Имя пакета"; Hint = "com.example.app" }
            )
        },
        @{
            Type = "install_apk"
            Name = "Установить APK"
            Desc = "adb install -r -g -d"
            Fields = @(
                @{ Key = "Path"; Label = "Путь к APK"; Hint = "C:\apks\app.apk" }
            )
        },
        @{
            Type = "set_animation"
            Name = "Масштаб анимации"
            Desc = "window/transition/animator scale"
            Fields = @(
                @{ Key = "Value"; Label = "Значение (0 / 0.5 / 1.0)"; Hint = "0.5" }
            )
        },
        @{
            Type = "set_setting"
            Name = "Изменить настройку"
            Desc = "settings put <namespace> <key> <value>"
            Fields = @(
                @{ Key = "Namespace"; Label = "Namespace (global/system/secure)"; Hint = "system" }
                @{ Key = "SettingKey"; Label = "Ключ"; Hint = "screen_off_timeout" }
                @{ Key = "Value"; Label = "Значение"; Hint = "600000" }
            )
        },
        @{
            Type = "send_key"
            Name = "Отправить клавишу"
            Desc = "input keyevent"
            Fields = @(
                @{ Key = "KeyCode"; Label = "KEYCODE"; Hint = "KEYCODE_HOME" }
            )
        },
        @{
            Type = "send_text"
            Name = "Отправить текст"
            Desc = "input text"
            Fields = @(
                @{ Key = "Text"; Label = "Текст"; Hint = "hello" }
            )
        },
        @{
            Type = "wait"
            Name = "Подождать"
            Desc = "Пауза N секунд"
            Fields = @(
                @{ Key = "Seconds"; Label = "Секунд"; Hint = "3" }
            )
        },
        @{
            Type = "screenshot"
            Name = "Сделать скриншот"
            Desc = "screencap + pull"
            Fields = @()
        },
        @{
            Type = "reboot"
            Name = "Перезагрузить ТВ"
            Desc = "reboot"
            Fields = @()
        }
    )
}

function Get-StepTypeInfo {
    param([string]$Type)
    return Get-ScenarioStepTypes | Where-Object { $_.Type -eq $Type } | Select-Object -First 1
}

# ============================================================================
#  ВЫПОЛНЕНИЕ СЦЕНАРИЯ
# ============================================================================
function Invoke-ScenarioStep {
    param(
        [PSCustomObject]$Step,
        [scriptblock]$LogCallback = $null
    )

    function EmitLog {
        param([string]$Msg, [string]$Lvl = "Info")
        if ($LogCallback) { & $LogCallback $Msg $Lvl }
    }

    try {
        switch ($Step.Type) {
            "disable_package" {
                EmitLog "Отключаю: $($Step.Package)" "Info"
                $out = & $script:adbPath shell pm disable-user --user 0 $Step.Package 2>&1
                if (($out | Out-String) -match "new state: disabled") {
                    EmitLog "  OK" "Success"
                    return $true
                }
                EmitLog "  FAIL: $($out | Out-String)" "Warning"
                return $false
            }
            "enable_package" {
                EmitLog "Включаю: $($Step.Package)" "Info"
                $out = & $script:adbPath shell pm enable $Step.Package 2>&1
                if (($out | Out-String) -match "new state: enabled") {
                    EmitLog "  OK" "Success"
                    return $true
                }
                EmitLog "  FAIL: $($out | Out-String)" "Warning"
                return $false
            }
            "remove_package" {
                EmitLog "Удаляю: $($Step.Package)" "Info"
                $out = & $script:adbPath shell pm uninstall --user 0 $Step.Package 2>&1
                if (($out | Out-String) -match "Success") {
                    EmitLog "  OK" "Success"
                    return $true
                }
                EmitLog "  FAIL: $($out | Out-String)" "Warning"
                return $false
            }
            "clear_package" {
                EmitLog "Очищаю данные: $($Step.Package)" "Info"
                $out = & $script:adbPath shell pm clear $Step.Package 2>&1
                if (($out | Out-String) -match "Success") {
                    EmitLog "  OK" "Success"
                    return $true
                }
                EmitLog "  FAIL: $($out | Out-String)" "Warning"
                return $false
            }
            "install_apk" {
                EmitLog "Устанавливаю: $($Step.Path)" "Info"
                if (-not (Test-Path $Step.Path)) {
                    EmitLog "  Файл не найден: $($Step.Path)" "Error"
                    return $false
                }
                $out = & $script:adbPath install -r -g -d $Step.Path 2>&1
                $outText = ($out | Out-String).Trim()
                if ($outText -match "Success") {
                    EmitLog "  OK" "Success"
                    return $true
                }
                EmitLog "  FAIL: $outText" "Error"
                return $false
            }
            "set_animation" {
                EmitLog "Масштаб анимации: $($Step.Value)" "Info"
                & $script:adbPath shell settings put global window_animation_scale $Step.Value 2>&1 | Out-Null
                & $script:adbPath shell settings put global transition_animation_scale $Step.Value 2>&1 | Out-Null
                & $script:adbPath shell settings put global animator_duration_scale $Step.Value 2>&1 | Out-Null
                EmitLog "  OK" "Success"
                return $true
            }
            "set_setting" {
                EmitLog "Настройка: $($Step.Namespace).$($Step.SettingKey) = $($Step.Value)" "Info"
                $out = & $script:adbPath shell settings put $Step.Namespace $Step.SettingKey $Step.Value 2>&1
                $outText = ($out | Out-String).Trim()
                if ($outText -match 'error|Error|Exception|Security') {
                    EmitLog "  FAIL: $outText" "Error"
                    return $false
                }
                EmitLog "  OK" "Success"
                return $true
            }
            "send_key" {
                EmitLog "Клавиша: $($Step.KeyCode)" "Info"
                & $script:adbPath shell input keyevent $Step.KeyCode 2>&1 | Out-Null
                EmitLog "  OK" "Success"
                return $true
            }
            "send_text" {
                EmitLog "Текст: $($Step.Text)" "Info"
                $escaped = $Step.Text -replace ' ', '%s'
                $escaped = $escaped -replace '[^\w%s\-\.@]', ''
                & $script:adbPath shell input text $escaped 2>&1 | Out-Null
                EmitLog "  OK (только ASCII)" "Success"
                return $true
            }
            "wait" {
                $secs = [int]$Step.Seconds
                if ($secs -lt 1) { $secs = 1 }
                if ($secs -gt 300) { $secs = 300 }
                EmitLog "Жду $secs сек..." "Info"
                Start-Sleep -Seconds $secs
                EmitLog "  OK" "Success"
                return $true
            }
            "screenshot" {
                EmitLog "Скриншот..." "Info"
                $path = Take-Screenshot-ToFolder
                if ($path) {
                    EmitLog "  Сохранён: $path" "Success"
                    return $true
                }
                EmitLog "  Ошибка скриншота" "Error"
                return $false
            }
            "reboot" {
                EmitLog "Перезагрузка ТВ..." "Info"
                & $script:adbPath shell reboot 2>&1 | Out-Null
                $script:connected = $false
                EmitLog "  Команда отправлена (связь будет потеряна)" "Success"
                return $true
            }
            default {
                EmitLog "Неизвестный тип шага: $($Step.Type)" "Error"
                return $false
            }
        }
    } catch {
        EmitLog "  Исключение: $_" "Error"
        return $false
    }
}