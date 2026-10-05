# ============================================================================
#  CommandValidator — проверка безопасности команд и критических пакетов
#
#  Загружается ПОСЛЕ Config.ps1 и ДО AdbHelper.ps1.
#  Использует $script:CriticalPackagesMap из Config.ps1.
# ============================================================================

# ============================================================================
#  ЧАСТЬ 1: ВАЛИДАЦИЯ КОМАНД ОТКАТА
# ============================================================================

# Разрешённые "корневые" подкоманды adb
$script:AllowedRestorePrefixes = @(
    'shell pm enable ',
    'shell pm disable-user ',
    'shell cmd package install-existing ',
    'shell cmd package set-home-activity ',
    'shell settings put global ',
    'shell settings put system ',
    'shell settings put secure ',
    'shell settings delete global ',
    'shell settings delete system ',
    'shell settings delete secure ',
    'shell wm size ',
    'shell wm density ',
    'shell svc wifi ',
    'shell svc bluetooth ',
    'shell am start ',
    'shell input keyevent ',
    'shell setprop persist.',
    'shell reboot',
    'install ',
    'uninstall ',
    'pull ',
    'push ',
    'connect ',
    'disconnect'
)

# Запрещённые символы/паттерны (инъекции)
$script:ForbiddenPatterns = @(
    '[;&|`]',          # разделители команд
    '\$\(',            # подстановка команд
    '>\s*[A-Za-z]:',   # перенаправление в файл на диске
    '\brm\s+-rf\s+/',  # опасное rm
    '\bformat\b',
    '\bdel\s+/[fsq]',
    '\brmdir\s+/s',
    '\breg\s+delete',
    '\bnet\s+user',
    '\bpowershell\b',
    '\bcmd\s+/c',
    '\bwget\b',
    '\bcurl\b'
)

function Test-RestoreCommand {
    param(
        [Parameter(Mandatory)][string]$Command
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return @{ Safe = $false; Reason = "Пустая команда" }
    }

    # 1. Убираем префикс "adb "
    $clean = $Command.Trim() -replace '^adb\s+', ''

    # 2. Проверяем на запрещённые паттерны
    foreach ($pattern in $script:ForbiddenPatterns) {
        if ($clean -match $pattern) {
            return @{
                Safe   = $false
                Reason = "Обнаружен запрещённый паттерн: $pattern"
            }
        }
    }

    # 3. Проверяем по whitelist
    $allowed = $false
    foreach ($prefix in $script:AllowedRestorePrefixes) {
        if ($clean.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
        }
    }

    if (-not $allowed) {
        return @{
            Safe   = $false
            Reason = "Команда не входит в список разрешённых"
        }
    }

    return @{ Safe = $true; Reason = "OK" }
}

# ============================================================================
#  ЧАСТЬ 2: ЗАЩИТА КРИТИЧЕСКИХ ПАКЕТОВ
# ============================================================================

function Test-CriticalPackage {
    param(
        [Parameter(Mandatory)][string]$Package
    )

    if (-not $script:CriticalPackagesMap -or $script:CriticalPackagesMap.Count -eq 0) {
        return @{ IsCritical = $false; Risk = ""; Reason = "" }
    }

    if ($script:CriticalPackagesMap.ContainsKey($Package)) {
        $info = $script:CriticalPackagesMap[$Package]
        return @{
            IsCritical = $true
            Risk       = $info.Risk     # "block" или "warn"
            Reason     = $info.Reason
        }
    }

    return @{ IsCritical = $false; Risk = ""; Reason = "" }
}

# ============================================================================
#  УНИВЕРСАЛЬНАЯ ПРОВЕРКА ПЕРЕД ОПАСНОЙ ОПЕРАЦИЕЙ
#  Возвращает:
#    @{ Allowed = $true/false; NeedConfirm = $true/false; Reason = "..." }
# ============================================================================
function Test-PackageOperation {
    param(
        [Parameter(Mandatory)][string]$Package,
        [Parameter(Mandatory)][ValidateSet("remove","disable","clear")]
        [string]$Operation
    )

    $check = Test-CriticalPackage -Package $Package

    if (-not $check.IsCritical) {
        return @{ Allowed = $true; NeedConfirm = $false; Reason = "" }
    }

    # ===== BLOCK: полностью запрещаем =====
    if ($check.Risk -eq "block") {
        return @{
            Allowed     = $false
            NeedConfirm = $false
            Reason      = "Критический пакет ($($check.Reason)). Операция '$Operation' запрещена."
        }
    }

    # ===== WARN: разрешаем, но с подтверждением =====
    return @{
        Allowed     = $true
        NeedConfirm = $true
        Reason      = "$($check.Reason). Операция '$Operation' может нарушить работу ТВ."
    }
}