# weather_fetch.ps1
# 순천시 용당동의 날씨 + 미세먼지를 가져와서
#   (1) 같은 폴더의 weather.txt 에 누적 저장하고
#   (2) 디스코드 채널로도 알림 카드를 보냅니다.
#
# * 날씨/미세먼지는 API 키가 필요 없습니다. Open-Meteo(무료 공개 서비스)를 씁니다.
# * 디스코드 Webhook 주소는 .env 파일에서만 읽습니다. 코드에 절대 쓰지 마세요.
#     .env 예시)  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
#   .env 가 없거나 주소가 비어 있으면 디스코드 전송만 건너뛰고 파일 저장은 정상 동작합니다.
# * 매일 오전 9시 자동 실행은 register_task.ps1 이 담당합니다.
#
# 수동 실행:
#   powershell -ExecutionPolicy Bypass -File weather_fetch.ps1

# --- 기본 설정 -------------------------------------------------------------

# 옛 Windows PowerShell은 기본 보안 프로토콜이 낮아 https 연결이 끊길 수 있어 명시합니다.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$지역명 = "순천시 용당동"
$위도   = 34.9629
$경도   = 127.5039

# 스크립트가 놓인 폴더에 weather.txt 를 만듭니다.
$기준폴더 = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$출력파일 = Join-Path $기준폴더 "weather.txt"

$줄바꿈 = "`r`n"

# --- 보조 함수 -------------------------------------------------------------

# .env 파일에서 값을 읽습니다. 스크립트 폴더 → 상위 폴더 순으로 찾습니다.
# 진짜 시스템 환경변수가 있으면 그것을 우선합니다.
function Get-비밀값 {
    param([string]$이름)

    $시스템값 = [Environment]::GetEnvironmentVariable($이름)
    if ($시스템값) { return $시스템값 }

    foreach ($폴더 in @($기준폴더, (Split-Path $기준폴더 -Parent))) {
        if (-not $폴더) { continue }
        $env파일 = Join-Path $폴더 ".env"
        if (-not (Test-Path $env파일)) { continue }

        foreach ($줄 in (Get-Content $env파일 -Encoding UTF8)) {
            $줄 = $줄.Trim()
            if ($줄 -eq "" -or $줄.StartsWith("#")) { continue }
            $구분 = $줄.IndexOf("=")
            if ($구분 -lt 1) { continue }
            if ($줄.Substring(0, $구분).Trim() -eq $이름) {
                return $줄.Substring($구분 + 1).Trim().Trim('"').Trim("'")
            }
        }
    }
    return $null
}

# 비밀값을 화면에 보여줄 때는 항상 가려서 보여줍니다.
function Get-마스킹 {
    param([string]$값)
    if (-not $값) { return "(없음)" }
    if ($값.Length -le 16) { return "***" }
    return $값.Substring(0, 33) + "***" + $값.Substring($값.Length - 4)
}

# 인터넷 조회는 가끔 일시적으로 실패합니다(예: 503 서버 혼잡).
# 하루 한 번만 도는 스크립트라 한 번 실패하면 그날 기록이 통째로 날아가므로,
# 몇 초 쉬었다가 최대 3번까지 다시 시도합니다.
function Invoke-조회 {
    param([string]$주소, [int]$최대시도 = 3, [int]$대기초 = 5)

    for ($시도 = 1; $시도 -le $최대시도; $시도++) {
        try {
            return Invoke-RestMethod -Uri $주소 -TimeoutSec 30
        }
        catch {
            if ($시도 -eq $최대시도) { throw }
            Write-Host ("  일시적 실패({0}/{1}) - {2}초 뒤 다시 시도합니다. [{3}]" -f `
                        $시도, $최대시도, $대기초, $_.Exception.Message)
            Start-Sleep -Seconds $대기초
        }
    }
}

# WMO 기상 코드를 한글 설명으로 바꿉니다.
function Get-날씨설명 {
    param([int]$코드)
    switch ($코드) {
        0  { "맑음" }
        1  { "대체로 맑음" }
        2  { "구름 조금" }
        3  { "흐림" }
        45 { "안개" }
        48 { "서리 안개" }
        51 { "이슬비 약함" }
        53 { "이슬비" }
        55 { "이슬비 강함" }
        56 { "얼어붙는 이슬비 약함" }
        57 { "얼어붙는 이슬비 강함" }
        61 { "비 약함" }
        63 { "비" }
        65 { "비 강함" }
        66 { "얼어붙는 비 약함" }
        67 { "얼어붙는 비 강함" }
        71 { "눈 약함" }
        73 { "눈" }
        75 { "눈 강함" }
        77 { "싸락눈" }
        80 { "소나기 약함" }
        81 { "소나기" }
        82 { "소나기 강함" }
        85 { "소낙눈 약함" }
        86 { "소낙눈 강함" }
        95 { "천둥번개" }
        96 { "천둥번개 (우박 약간)" }
        99 { "천둥번개 (우박 강함)" }
        default { "알 수 없음(코드 $코드)" }
    }
}

# 디스코드 카드 제목에 붙일 그림문자입니다.
function Get-날씨그림 {
    param([int]$코드)
    if ($코드 -eq 0 -or $코드 -eq 1) { return [char]::ConvertFromUtf32(0x2600) }      # 해
    if ($코드 -le 3)                 { return [char]::ConvertFromUtf32(0x26C5) }      # 해+구름
    if ($코드 -le 48)                { return [char]::ConvertFromUtf32(0x1F32B) }     # 안개
    if ($코드 -le 67)                { return [char]::ConvertFromUtf32(0x1F327) }     # 비
    if ($코드 -le 77)                { return [char]::ConvertFromUtf32(0x2744) }      # 눈
    if ($코드 -le 82)                { return [char]::ConvertFromUtf32(0x1F326) }     # 소나기
    if ($코드 -le 86)                { return [char]::ConvertFromUtf32(0x1F328) }     # 소낙눈
    return [char]::ConvertFromUtf32(0x26C8)                                            # 천둥번개
}

# 한국 환경부 기준 미세먼지 등급입니다.
function Get-미세먼지등급 {
    param([string]$종류, [double]$수치)
    if ($종류 -eq "PM10") {
        if     ($수치 -le 30)  { "좋음" }
        elseif ($수치 -le 80)  { "보통" }
        elseif ($수치 -le 150) { "나쁨" }
        else                   { "매우 나쁨" }
    } else {
        if     ($수치 -le 15) { "좋음" }
        elseif ($수치 -le 35) { "보통" }
        elseif ($수치 -le 75) { "나쁨" }
        else                  { "매우 나쁨" }
    }
}

# 등급이 나쁠수록 큰 숫자. 둘 중 더 나쁜 쪽으로 카드 색을 정합니다.
function Get-등급점수 {
    param([string]$등급)
    switch ($등급) {
        "좋음"      { 0 }
        "보통"      { 1 }
        "나쁨"      { 2 }
        "매우 나쁨" { 3 }
        default     { 1 }
    }
}

function Get-등급색 {
    param([int]$점수)
    switch ($점수) {
        0 { 0x3498DB }   # 파랑 - 좋음
        1 { 0x2ECC71 }   # 초록 - 보통
        2 { 0xE67E22 }   # 주황 - 나쁨
        3 { 0xE74C3C }   # 빨강 - 매우 나쁨
        default { 0x95A5A6 }
    }
}

function Get-한글요일 {
    param([datetime]$날짜)
    switch ($날짜.DayOfWeek.ToString()) {
        "Sunday"    { "일" }
        "Monday"    { "월" }
        "Tuesday"   { "화" }
        "Wednesday" { "수" }
        "Thursday"  { "목" }
        "Friday"    { "금" }
        "Saturday"  { "토" }
    }
}

# weather.txt 에 이어붙입니다. 파일이 처음 만들어질 때만 UTF-8 표식을 넣어
# 메모장에서 한글이 깨지지 않게 합니다.
function Add-기록 {
    param([string]$내용)
    $utf8 = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::AppendAllText($출력파일, $내용, $utf8)
}

# --- 데이터 가져오기 -------------------------------------------------------

$지금   = Get-Date
$머리글 = "===== {0} ({1}) {2} {3} =====" -f `
          $지금.ToString("yyyy-MM-dd"), (Get-한글요일 $지금), $지금.ToString("HH:mm"), $지역명

$본문 = New-Object System.Collections.Generic.List[string]
$본문.Add($머리글)

# 디스코드 카드에 쓸 값들. 실패하면 $null 로 남습니다.
$날씨성공 = $false
$먼지성공 = $false
$설명 = $null; $그림 = $null
$기온 = $null; $체감 = $null; $최고 = $null; $최저 = $null
$습도 = $null; $강수확률 = $null; $강수 = $null; $바람 = $null
$pm10 = $null; $pm25 = $null; $pm10등급 = $null; $pm25등급 = $null
$오류목록 = New-Object System.Collections.Generic.List[string]

# 1) 날씨
try {
    $날씨주소 = "https://api.open-meteo.com/v1/forecast" +
                "?latitude=$위도&longitude=$경도" +
                "&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m" +
                "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
                "&timezone=Asia%2FSeoul&wind_speed_unit=ms&forecast_days=1"

    $날씨 = Invoke-조회 $날씨주소

    $현재 = $날씨.current
    $오늘 = $날씨.daily
    $코드 = [int]$현재.weather_code

    $설명     = Get-날씨설명 $코드
    $그림     = Get-날씨그림 $코드
    $기온     = $현재.temperature_2m
    $체감     = $현재.apparent_temperature
    $최고     = $오늘.temperature_2m_max[0]
    $최저     = $오늘.temperature_2m_min[0]
    $습도     = $현재.relative_humidity_2m
    $강수확률 = $오늘.precipitation_probability_max[0]
    $강수     = $현재.precipitation
    $바람     = $현재.wind_speed_10m
    $날씨시각 = $현재.time
    $날씨성공 = $true

    $본문.Add(("[날씨] {0}   기온 {1}도 (체감 {2}도)" -f $설명, $기온, $체감))
    $본문.Add(("       최고 {0}도 / 최저 {1}도" -f $최고, $최저))
    $본문.Add(("       습도 {0}%   강수확률 {1}%   현재 강수 {2}mm   바람 {3}m/s" -f $습도, $강수확률, $강수, $바람))
    $본문.Add(("       (관측 {0})" -f $날씨시각))
}
catch {
    $메시지 = "날씨 가져오기 실패 - $($_.Exception.Message)"
    $본문.Add("[날씨] $메시지")
    $오류목록.Add($메시지)
}

# 2) 미세먼지
try {
    $먼지주소 = "https://air-quality-api.open-meteo.com/v1/air-quality" +
                "?latitude=$위도&longitude=$경도" +
                "&current=pm10,pm2_5&timezone=Asia%2FSeoul&forecast_days=1"

    $먼지 = Invoke-조회 $먼지주소
    $pm10 = [double]$먼지.current.pm10
    $pm25 = [double]$먼지.current.pm2_5
    $pm10등급 = Get-미세먼지등급 "PM10"  $pm10
    $pm25등급 = Get-미세먼지등급 "PM2.5" $pm25
    $먼지시각 = $먼지.current.time
    $먼지성공 = $true

    $본문.Add(("[미세먼지] PM10  {0} ㎍/㎥ ({1})" -f $pm10, $pm10등급))
    $본문.Add(("           PM2.5 {0} ㎍/㎥ ({1})" -f $pm25, $pm25등급))
    $본문.Add(("           (관측 {0})" -f $먼지시각))
}
catch {
    $메시지 = "미세먼지 가져오기 실패 - $($_.Exception.Message)"
    $본문.Add("[미세먼지] $메시지")
    $오류목록.Add($메시지)
}

# --- 1단계: 파일 저장 ------------------------------------------------------

$기록 = ($본문 -join $줄바꿈) + $줄바꿈 + $줄바꿈
Add-기록 $기록

Write-Host $기록
Write-Host "저장 위치: $출력파일"

# --- 2단계: 디스코드 전송 --------------------------------------------------
# 실패해도 위의 파일 저장은 이미 끝났으므로 안전합니다.

$웹훅주소 = Get-비밀값 "DISCORD_WEBHOOK_URL"

if (-not $웹훅주소) {
    Write-Host ""
    Write-Host "디스코드 전송 건너뜀: .env 에 DISCORD_WEBHOOK_URL 이 없습니다."
    Write-Host "  넣을 위치: $(Join-Path $기준폴더 '.env')"
    return
}

if ($웹훅주소 -notmatch '^https://(discord|discordapp)\.com/api/webhooks/') {
    Write-Host ""
    Write-Host "디스코드 전송 건너뜀: DISCORD_WEBHOOK_URL 형식이 올바르지 않습니다."
    Write-Host "  https://discord.com/api/webhooks/... 로 시작해야 합니다."
    Write-Host "  현재 값: $(Get-마스킹 $웹훅주소)"
    return
}

try {
    # 카드 색: 미세먼지가 더 나쁜 쪽 기준
    if ($먼지성공) {
        $점수 = [Math]::Max((Get-등급점수 $pm10등급), (Get-등급점수 $pm25등급))
    } else {
        $점수 = -1
    }
    $색 = Get-등급색 $점수

    $제목 = if ($날씨성공) { "$그림 $지역명 오늘의 날씨" } else { "$지역명 날씨 알림" }

    $필드 = New-Object System.Collections.Generic.List[object]

    if ($날씨성공) {
        $필드.Add(@{ name = "날씨";   value = "**$설명**";                              inline = $true })
        $필드.Add(@{ name = "기온";   value = "**$기온 도**`n체감 $체감 도";            inline = $true })
        $필드.Add(@{ name = "최고/최저"; value = "$최고 도 / $최저 도";                 inline = $true })
        $필드.Add(@{ name = "강수확률"; value = "$강수확률 %";                          inline = $true })
        $필드.Add(@{ name = "습도";   value = "$습도 %";                                inline = $true })
        $필드.Add(@{ name = "바람";   value = "$바람 m/s";                              inline = $true })
    }

    if ($먼지성공) {
        $필드.Add(@{ name = "미세먼지 PM10";      value = "**$pm10등급**`n$pm10 ㎍/㎥"; inline = $true })
        $필드.Add(@{ name = "초미세먼지 PM2.5";   value = "**$pm25등급**`n$pm25 ㎍/㎥"; inline = $true })
        $필드.Add(@{ name = [char]::ConvertFromUtf32(0x200B); value = [char]::ConvertFromUtf32(0x200B); inline = $true })
    }

    if ($오류목록.Count -gt 0) {
        $필드.Add(@{ name = "가져오지 못한 정보"; value = ($오류목록 -join "`n"); inline = $false })
    }

    $카드 = @{
        title  = $제목
        color  = $색
        fields = $필드.ToArray()
        footer = @{ text = "출처 Open-Meteo · 매일 오전 9시 자동 알림" }
        timestamp = $지금.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $보낼내용 = @{
        username = "순천 날씨 알리미"
        embeds   = @($카드)
    }

    $제이슨 = $보낼내용 | ConvertTo-Json -Depth 6 -Compress
    $바이트 = [System.Text.Encoding]::UTF8.GetBytes($제이슨)

    Invoke-RestMethod -Uri $웹훅주소 -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body $바이트 -TimeoutSec 30 | Out-Null

    Write-Host ""
    Write-Host "디스코드 전송 완료 -> $(Get-마스킹 $웹훅주소)"
}
catch {
    Write-Host ""
    Write-Host "디스코드 전송 실패 - $($_.Exception.Message)"
    Write-Host "  (weather.txt 저장은 이미 정상 완료되었습니다)"
    Add-기록 ("[알림] 디스코드 전송 실패 - $($_.Exception.Message)" + $줄바꿈 + $줄바꿈)
}
