# ============================================================================
#  RunspaceManager — реестр фоновых Runspace и таймеров
#
#  Проблема: при переключении экранов Runspace'ы могут оставаться живыми.
#  Решение: единый реестр + автоочистка в Switch-View.
#
#  Использование:
#    Register-ScreenRunspace -Name "logcat" -PS $ps -RS $runspace -Handle $handle
#    Unregister-ScreenRunspace -Name "logcat"
#    Stop-AllScreenRunspaces -Except @("http", "monitoring")
# ============================================================================

# Реестр: имя → @{ PS; RS; Handle; Timer; OnCleanup }
$script:RunspaceRegistry = @{}

# ============================================================================
#  RunspaceManager — реестр фоновых Runspace и таймеров
# ============================================================================

$script:RunspaceRegistry = @{}

function Register-ScreenRunspace {
    param(
        [Parameter(Mandatory)][string]$Name,
        $PS = $null,
        $RS = $null,
        $Handle = $null,
        $Timer = $null,
        [scriptblock]$OnCleanup = $null
    )

    if ($script:RunspaceRegistry.ContainsKey($Name)) {
        Write-Log -Message "Runspace '$Name' уже зарегистрирован — закрываю старый" -Level "Warning"
        Unregister-ScreenRunspace -Name $Name
    }

    $script:RunspaceRegistry[$Name] = @{
        PS        = $PS
        RS        = $RS
        Handle    = $Handle
        Timer     = $Timer
        OnCleanup = $OnCleanup
    }

    Write-Log -Message "Runspace '$Name' зарегистрирован" -Level "Info"
}

function Unregister-ScreenRunspace {
    param([Parameter(Mandatory)][string]$Name)

    if (-not $script:RunspaceRegistry.ContainsKey($Name)) {
        return
    }

    $entry = $script:RunspaceRegistry[$Name]

    # СРАЗУ удаляем из реестра — защита от повторного вызова
    $script:RunspaceRegistry.Remove($Name)

    $timerRef    = $entry.Timer
    $psRef       = $entry.PS
    $rsRef       = $entry.RS
    $cleanupRef  = $entry.OnCleanup

    # Таймер — синхронно (это быстро)
    if ($timerRef) {
        try { $timerRef.Stop() } catch { }
    }

    # Остальное — асинхронно
    if ($cleanupRef -or $psRef -or $rsRef) {
        [System.Threading.Tasks.Task]::Run([action]{
            try {
                if ($cleanupRef) {
                    try { & $cleanupRef } catch { }
                }
            } catch { }

            try {
                if ($psRef) {
                    try { $psRef.Stop() } catch { }
                    Start-Sleep -Milliseconds 50
                    try { $psRef.Dispose() } catch { }
                }
            } catch { }

            try {
                if ($rsRef) {
                    try { $rsRef.Close() } catch { }
                    Start-Sleep -Milliseconds 50
                    try { $rsRef.Dispose() } catch { }
                }
            } catch { }
        }) | Out-Null
    }

    Write-Log -Message "Runspace '$Name' закрыт" -Level "Info"
}

function Stop-AllScreenRunspaces {
    param([string[]]$Except = @())

    $names = @($script:RunspaceRegistry.Keys)
    foreach ($name in $names) {
        if ($name -in $Except) { continue }
        Unregister-ScreenRunspace -Name $name
    }
}

function Get-ActiveRunspaces {
    return @($script:RunspaceRegistry.Keys)
}

function Unregister-ScreenRunspace {
    param([Parameter(Mandatory)][string]$Name)

    if (-not $script:RunspaceRegistry.ContainsKey($Name)) {
        return
    }

    $entry = $script:RunspaceRegistry[$Name]
    $script:RunspaceRegistry.Remove($Name)

    $timerRef    = $entry.Timer
    $psRef       = $entry.PS
    $rsRef       = $entry.RS
    $cleanupRef  = $entry.OnCleanup

    if ($timerRef) {
        try { $timerRef.Stop() } catch { }
    }

    if ($cleanupRef -or $psRef -or $rsRef) {
        [System.Threading.Tasks.Task]::Run([action]{
            try {
                if ($cleanupRef) {
                    try { & $cleanupRef } catch { }
                }
            } catch { }

            try {
                if ($psRef) {
                    try { $psRef.Stop() } catch { }
                    Start-Sleep -Milliseconds 50
                    try { $psRef.Dispose() } catch { }
                }
            } catch { }

            try {
                if ($rsRef) {
                    try { $rsRef.Close() } catch { }
                    Start-Sleep -Milliseconds 50
                    try { $rsRef.Dispose() } catch { }
                }
            } catch { }
        }) | Out-Null
    }

    Write-Log -Message "Runspace '$Name' закрыт" -Level "Info"
}

function Stop-AllScreenRunspaces {
    param([string[]]$Except = @())

    $names = @($script:RunspaceRegistry.Keys)
    foreach ($name in $names) {
        if ($name -in $Except) { continue }
        Unregister-ScreenRunspace -Name $name
    }
}

function Get-ActiveRunspaces {
    return @($script:RunspaceRegistry.Keys)
}