# ============================================================================
#  Bluetooth Helper — чтение состояния BT, сопряжённые устройства, поиск
#
#  ВАЖНО: TVManager НЕ выключает Bluetooth удалённо, если к нему
#  потенциально подключены устройства (пульт, геймпад, звук).
#  При необходимости пользователь выключает BT через настройки ТВ.
# ============================================================================

function Invoke-BtAdb {
    param([string[]]$AdbArgs)
    try {
        $out = & $script:adbPath @AdbArgs 2>&1
        return ($out | Out-String).Trim()
    } catch {
        return ""
    }
}

# ============================================================================
#  ОСНОВНАЯ ИНФОРМАЦИЯ О BLUETOOTH
# ============================================================================
function Get-BluetoothInfo {
    Write-Log -Message "Читаю информацию о Bluetooth..." -Level "Info"

    $info = [ordered]@{
        Enabled       = $false
        State         = "—"
        Name          = "—"
        Address       = "—"
        ScanMode      = "—"
        Discoverable  = $false
        BondedCount   = 0
        ConnectedCount = 0
    }

    try {
        # --- dumpsys bluetooth_manager ---
        $dump = Invoke-BtAdb @("shell", "dumpsys", "bluetooth_manager")

        if ($dump) {
            # Состояние
            if ($dump -match 'enabled:\s*(true|false)') {
                $info.Enabled = ($matches[1] -eq "true")
            } elseif ($dump -match 'State:\s*(\w+)') {
                $info.State = $matches[1]
                $info.Enabled = ($matches[1] -match 'ON|enabled')
            }

            if ($info.Enabled) {
                $info.State = "ON"
            } elseif ($info.State -eq "—") {
                $info.State = "OFF"
            }

            # Имя
            if ($dump -match 'name:\s*([^\r\n]+)') {
                $nameVal = $matches[1].Trim()
                if ($nameVal -and $nameVal -notmatch '^null$') {
                    $info.Name = $nameVal
                }
            }
            if ($info.Name -eq "—" -and $dump -match 'mName:\s*([^\r\n]+)') {
                $nameVal = $matches[1].Trim()
                if ($nameVal -and $nameVal -notmatch '^null$') {
                    $info.Name = $nameVal
                }
            }

            # MAC-адрес
            if ($dump -match 'address:\s*([0-9A-Fa-f:]{17})') {
                $addrVal = $matches[1]
                if ($addrVal -ne "00:00:00:00:00:00") {
                    $info.Address = $addrVal
                }
            }
            if ($info.Address -eq "—" -and $dump -match 'mAddress:\s*([0-9A-Fa-f:]{17})') {
                $addrVal = $matches[1]
                if ($addrVal -ne "00:00:00:00:00:00") {
                    $info.Address = $addrVal
                }
            }

            # Режим сканирования
            if ($dump -match 'ScanMode:\s*(\w+)') {
                $info.ScanMode = $matches[1]
            }

            # Discoverable
            if ($dump -match 'discoverable:\s*(true|false)') {
                $info.Discoverable = ($matches[1] -eq "true")
            }
        }

        # --- Fallback через settings ---
        if ($info.State -eq "—") {
            $btState = Invoke-BtAdb @("shell", "settings", "get", "global", "bluetooth_on")
            $btStateClean = ($btState -replace '[^\d]', '')
            if ($btStateClean -eq "1") {
                $info.Enabled = $true
                $info.State = "ON (settings)"
            } elseif ($btStateClean -eq "0") {
                $info.Enabled = $false
                $info.State = "OFF (settings)"
            }
        }

        # --- Имя через getprop ---
        if ($info.Name -eq "—") {
            $btName = Invoke-BtAdb @("shell", "getprop", "net.hostname")
            if ($btName -and $btName -notmatch '^null$') {
                $info.Name = $btName.Trim()
            }
        }

        # --- MAC через getprop ---
        if ($info.Address -eq "—") {
            $btMac = Invoke-BtAdb @("shell", "settings", "get", "secure", "bluetooth_address")
            if ($btMac -match '([0-9A-Fa-f:]{17})') {
                $addrVal = $matches[1]
                if ($addrVal -ne "00:00:00:00:00:00") {
                    $info.Address = $addrVal
                }
            }
        }

        # --- Счётчики сопряжённых / подключённых ---
        if ($dump) {
            $bondedMatches = [regex]::Matches($dump, 'Bonded devices:')
            $connectedMatches = [regex]::Matches($dump, 'Connected devices:')

            # Более точный подсчёт: секция "Bonded devices:" содержит список
            $bondedSection = ""
            if ($dump -match '(?s)Bonded devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:)') {
                $bondedSection = $matches[1]
            }
            if ($bondedSection) {
                $info.BondedCount = ([regex]::Matches($bondedSection, '\*?\s*([0-9A-Fa-f:]{17})')).Count
            }

            $connectedSection = ""
            if ($dump -match '(?s)Connected devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:)') {
                $connectedSection = $matches[1]
            }
            if ($connectedSection) {
                $info.ConnectedCount = ([regex]::Matches($connectedSection, '\*?\s*([0-9A-Fa-f:]{17})')).Count
            }
        }

        Write-Log -Message "BT: Enabled=$($info.Enabled), Name='$($info.Name)', MAC=$($info.Address), Bonded=$($info.BondedCount), Connected=$($info.ConnectedCount)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения Bluetooth: $_" -Level "Error"
    }

    return [PSCustomObject]$info
}

# ============================================================================
#  СПИСОК СОПРЯЖЁННЫХ УСТРОЙСТВ
# ============================================================================
function Get-BluetoothBondedDevices {
    Write-Log -Message "Читаю сопряжённые Bluetooth-устройства..." -Level "Info"

    $devices = @()

    try {
        $dump = Invoke-BtAdb @("shell", "dumpsys", "bluetooth_manager")

        if (-not $dump) {
            Write-Log -Message "dumpsys bluetooth_manager пуст" -Level "Warning"
            return ,$devices
        }

        # Ищем секцию "Bonded devices:"
        $bondedSection = ""
        if ($dump -match '(?s)Bonded devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:|$)') {
            $bondedSection = $matches[1]
        }

        if (-not $bondedSection) {
            Write-Log -Message "Секция 'Bonded devices' не найдена" -Level "Warning"
            return ,$devices
        }

        # Парсим строки. Формат обычно:
        #   * AA:BB:CC:DD:EE:FF DeviceName [BR/EDR] ...  OR
        #     AA:BB:CC:DD:EE:FF (name)
        $lines = $bondedSection -split "`r?`n"
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            # MAC-адрес
            if ($line -match '([0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5})') {
                $mac = $matches[1]

                # Имя устройства — всё после MAC, кроме служебных маркеров
                $name = "—"
                $rest = $line.Substring($line.IndexOf($mac) + $mac.Length).Trim()

                # Отрезаем хвосты типа " [BR/EDR]" " [LE]" "type=..."
                $rest = $rest -replace '\s*\[[^\]]*\]', ''
                $rest = $rest -replace '\s*type=.*', ''
                $rest = $rest -replace '^\s*[\(\*]', ''
                $rest = $rest.Trim()

                if ($rest -and $rest -notmatch '^[\(\*\-]*$') {
                    $name = $rest
                }

                # Определяем тип подключения
                $connected = ($line -match '\*\s*' -or $line -match 'connected')
                $isLE = ($line -match '\[LE\]' -or $line -match 'LE_ONLY')

                $devices += [PSCustomObject]@{
                    Mac       = $mac
                    Name      = $name
                    Connected = $connected
                    IsLE      = $isLE
                }
            }
        }

        Write-Log -Message "Сопряжённых устройств: $($devices.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка чтения сопряжённых устройств: $_" -Level "Error"
    }

    return ,$devices
}

# ============================================================================
#  ПОИСК ДОСТУПНЫХ BLUETOOTH-УСТРОЙСТВ
#  Требует включения BT и запуска discovery.
# ============================================================================
function Get-BluetoothDiscoverableDevices {
    param([int]$ScanSeconds = 12)

    Write-Log -Message "Сканирую Bluetooth-устройства ($ScanSeconds сек)..." -Level "Info"

    $devices = @()

    try {
        # Проверяем, что BT включён
        $btInfo = Get-BluetoothInfo
        if (-not $btInfo.Enabled) {
            Write-Log -Message "Bluetooth выключен — сканирование невозможно" -Level "Warning"
            return ,$devices
        }

        # Запускаем discovery через cmd bluetooth_manager
        # На Android TV это работает нестабильно, но попробуем
        Write-Log -Message "Запускаю discovery на $ScanSeconds сек..." -Level "Info"
        & $script:adbPath shell cmd bluetooth_manager start-discovery 2>&1 | Out-Null

        Start-Sleep -Seconds $ScanSeconds

        # Останавливаем discovery
        & $script:adbPath shell cmd bluetooth_manager stop-discovery 2>&1 | Out-Null

        # Читаем результат
        $dump = Invoke-BtAdb @("shell", "dumpsys", "bluetooth_manager")

        # Пытаемся вытащить секцию найденных устройств
        # Разные версии Android кладут их в разные места
        $foundSection = ""

        if ($dump -match '(?s)Found devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:|$)') {
            $foundSection = $matches[1]
        }
        elseif ($dump -match '(?s)Discovered devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:|$)') {
            $foundSection = $matches[1]
        }
        elseif ($dump -match '(?s)Remote devices:(.*?)(?=\r?\n\r?\n|\r?\n[A-Z][a-z]+:|$)') {
            $foundSection = $matches[1]
        }

        # Получаем список уже сопряжённых (их не нужно показывать в "новых")
        $bonded = Get-BluetoothBondedDevices
        $bondedMacs = @{}
        foreach ($b in $bonded) { $bondedMacs[$b.Mac.ToUpper()] = $true }

        if ($foundSection) {
            $lines = $foundSection -split "`r?`n"
            $seen = @{}

            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                if ($line -match '([0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5})') {
                    $mac = $matches[1]
                    $macUpper = $mac.ToUpper()

                    if ($seen.ContainsKey($macUpper)) { continue }
                    if ($bondedMacs.ContainsKey($macUpper)) { continue }  # уже сопряжён
                    $seen[$macUpper] = $true

                    # Имя
                    $name = "—"
                    $rest = $line.Substring($line.IndexOf($mac) + $mac.Length).Trim()
                    $rest = $rest -replace '\s*\[[^\]]*\]', ''
                    $rest = $rest -replace '^\s*[\(\*\-]', ''
                    $rest = $rest.Trim()
                    if ($rest -and $rest -notmatch '^[\(\*\-]*$') {
                        $name = $rest
                    }

                    $devices += [PSCustomObject]@{
                        Mac  = $mac
                        Name = $name
                    }
                }
            }
        }

        Write-Log -Message "Найдено новых устройств: $($devices.Count)" -Level "Success"
    } catch {
        Write-Log -Message "Ошибка сканирования Bluetooth: $_" -Level "Error"
    }

    return ,$devices
}

# ============================================================================
#  ОТКРЫТЬ НАСТРОЙКИ BLUETOOTH НА ТВ
# ============================================================================
function Open-BluetoothSettings {
    Write-Log -Message "Открываю настройки Bluetooth на ТВ..." -Level "Info"
    try {
        & $script:adbPath shell am start -a android.settings.BLUETOOTH_SETTINGS 2>&1 | Out-Null
        Write-Log -Message "OK" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ВКЛЮЧИТЬ / ВЫКЛЮЧИТЬ BT
#  Используется только в явных сценариях (например, если BT завис).
#  По умолчанию в UI показывается только с предупреждением.
# ============================================================================
function Enable-Bluetooth {
    Write-Log -Message "Включаю Bluetooth..." -Level "Info"
    try {
        $out = & $script:adbPath shell svc bluetooth enable 2>&1
        Start-Sleep -Seconds 2
        $info = Get-BluetoothInfo
        if ($info.Enabled) {
            Write-Log -Message "OK: Bluetooth включён" -Level "Success"
            return $true
        }
        Write-Log -Message "Не удалось подтвердить включение" -Level "Warning"
        return $false
    } catch {
        Write-Log -Message "Ошибка включения BT: $_" -Level "Error"
        return $false
    }
}

function Disable-Bluetooth {
    Write-Log -Message "Выключаю Bluetooth..." -Level "Warning"
    try {
        $out = & $script:adbPath shell svc bluetooth disable 2>&1
        Start-Sleep -Seconds 2
        $info = Get-BluetoothInfo
        if (-not $info.Enabled) {
            Write-Log -Message "OK: Bluetooth выключен" -Level "Success"
            return $true
        }
        Write-Log -Message "Не удалось подтвердить выключение" -Level "Warning"
        return $false
    } catch {
        Write-Log -Message "Ошибка выключения BT: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
#  ОТКЛЮЧИТЬ (UNPAIR) СОПРЯЖЁННОЕ УСТРОЙСТВО
#  Через cmd bluetooth_manager (не всегда доступно)
# ============================================================================
function Remove-BluetoothBond {
    param([string]$Mac)

    if (-not $Mac -or $Mac -notmatch '([0-9A-Fa-f:]{17})') {
        Write-Log -Message "Некорректный MAC: $Mac" -Level "Error"
        return $false
    }

    Write-Log -Message "Отключаю сопряжение с $Mac..." -Level "Info"

    try {
        # Пробуем через cmd bluetooth_manager
        $out = & $script:adbPath shell cmd bluetooth_manager unpair $Mac 2>&1
        $outText = ($out | Out-String).Trim()

        if ($outText -match 'error|Error|Exception|not found') {
            Write-Log -Message "Команда unpair не поддерживается: $outText" -Level "Warning"
            return $false
        }

        Write-Log -Message "OK: сопряжение отключено (или команда отправлена)" -Level "Success"
        return $true
    } catch {
        Write-Log -Message "Ошибка unpair: $_" -Level "Error"
        return $false
    }
}