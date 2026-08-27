# register_task.ps1
# weather_fetch.ps1을 매일 오전 9시에 자동 실행하도록 Windows 작업 스케줄러에 등록.
# 사용법: PowerShell에서 이 파일을 한 번만 실행하면 됩니다.
#   powershell -ExecutionPolicy Bypass -File register_task.ps1

$taskName = "SuncheonWeatherDaily"
$script   = Join-Path $PSScriptRoot "weather_fetch.ps1"

# 기존 동일 작업이 있으면 제거 후 재등록
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName `
    -Action $action -Trigger $trigger -Settings $settings `
    -Description "매일 오전 9시 순천 용당동 날씨/미세먼지를 WEATHER.TXT에 저장" `
    -RunLevel Limited | Out-Null

Write-Host "등록 완료: '$taskName' (매일 09:00)"
Write-Host "확인:  Get-ScheduledTask -TaskName $taskName"
Write-Host "수동 실행 테스트:  Start-ScheduledTask -TaskName $taskName"
Write-Host "삭제:  Unregister-ScheduledTask -TaskName $taskName -Confirm:`$false"
