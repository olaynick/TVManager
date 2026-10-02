function Check-OtaState {
    Write-Log -Message "Проверяю состояние OTA..." -Level "Info"
    $script:OtaDisabled = $false
    foreach ($item in $script:otaPackages) {
        $out = & $script:adbPath shell pm list packages -d 2>&1 | Select-String $item.Package
        if ($out) {
            $script:OtaDisabled = $true
            Write-Log -Message "OTA отключены (найден: $($item.Package))" -Level "Info"
            break
        }
    }
    if (-not $script:OtaDisabled) {
        Write-Log -Message "OTA включены." -Level "Info"
    }
}