# Progress Log

작업 이력을 최신순으로 기록합니다. 형식: `## YYYY-MM-DD` 아래에 무엇을, 왜 했는지 간단히 남깁니다.

## 2026-08-26 (3) — 디스코드 알림 연동 완료

- 요청: 날씨 정보를 디스코드 채널에도 전송.
- `weather_fetch.ps1` 개조 (기존본은 `weather_fetch.ps1.bak`으로 백업).
  - 디스코드 embed(색깔 카드) 전송 추가. 미세먼지 등급에 따라 카드 색 변경
    (좋음=파랑 / 보통=초록 / 나쁨=주황 / 매우나쁨=빨강).
  - Webhook 주소는 **`.env`에서만** 읽음. 코드 하드코딩 없음(CLAUDE.md 규칙 3).
    조회 순서: 시스템 환경변수 → 스크립트 폴더 `.env` → 상위 폴더 `.env`.
  - 화면 출력 시 주소는 항상 마스킹.
  - 전송 실패해도 `weather.txt` 저장은 이미 끝난 뒤라 안전. 실패 사유는 파일에 기록.
- **재시도 기능 추가**: 테스트 중 Open-Meteo가 실제로 503을 반환하는 걸 목격.
  하루 1회 실행이라 한 번 실패하면 그날 기록이 통째로 날아가므로 5초 간격 최대 3회 재시도.
- `.env.example`(견본, 공유 가능)과 `.gitignore`(`.env`, `*.key`, `*.pem`, `*.bak` 제외) 생성.
- 검증 단계
  1. Webhook 없을 때: 전송만 건너뛰고 파일 저장 정상 — 확인
  2. 가짜 Webhook: 404 응답 = 카드 JSON 생성·전송 경로 정상 — 확인
  3. 진짜 Webhook 수동 실행: **전송 성공** — 확인
  4. 스케줄러 자동실행(숨김 모드): 결과코드 0, 파일 45→53줄, 전송 실패 흔적 없음 — 확인
- 다음 자동 실행 예정: 2026-08-26 09:00.

## 2026-08-26 (2) — 날씨 파일 전부 `wader/` 폴더로 이동

- 요청: 날씨 관련 파일을 `wader` 폴더로 모으고, 이후 결과도 거기 쌓이게 할 것.
- 이동한 파일 3개: `weather_fetch.ps1`, `register_task.ps1`, `weather.txt`
  → `~/claude-workspace/wader/` 로 이동.
- 스크립트가 `$PSScriptRoot` 기준으로 동작하도록 짜여 있어 **코드 수정 없이** 출력 경로가 따라 옮겨짐.
- 단, 작업 스케줄러는 옛 절대경로를 물고 있었으므로 `register_task.ps1`을 새 위치에서 재실행해 **재등록**함.
  - 재등록 후 실행 대상: `...\wader\weather_fetch.ps1` 확인
- 검증: 강제 실행 결과코드 0, `wader\weather.txt` 16줄 → 24줄, 옛 위치에는 파일 재생성 안 됨.
- `tasks/todo.md`, `tasks/progress.md`는 CLAUDE.md 규정 위치(`~/claude-workspace/tasks/`)에 그대로 둠.

## 2026-08-26

- **순천 용당동 날씨/미세먼지 자동 수집 완성.**
- 상황 파악: `register_task.ps1`과 작업 스케줄러 등록(`SuncheonWeatherDaily`, 매일 09:00)은 이미 되어 있었으나,
  정작 실행 대상인 `weather_fetch.ps1`이 없어 **매일 9시마다 조용히 실패하던 상태**였음.
- `weather_fetch.ps1` 신규 작성. API 키 없이 Open-Meteo 무료 서비스 사용.
  - 날씨: `api.open-meteo.com` (기온/체감/최고최저/습도/강수확률/바람)
  - 미세먼지: `air-quality-api.open-meteo.com` (PM10, PM2.5 + 한국 환경부 기준 등급)
  - 좌표 34.9629 / 127.5039, 결과는 `weather.txt`에 **이어붙이기(누적)**
- 함정 하나: Windows PowerShell 5.1은 UTF-8 BOM이 없으면 한글이 깨짐 → 스크립트를 BOM 포함 UTF-8로 저장해 해결.
- 검증: 수동 실행 성공, 스케줄러 강제 실행 결과코드 0, 다음 실행 예정 2026-08-26 09:00 확인.
- `weather.txt` 앞부분 2건은 테스트로 남은 기록임.

## 2026-07-17

- 작업 환경 초기 구축: `tasks/` 폴더, `todo.md`, `progress.md`, `SECURITY.md`, `README.md` 생성.
- `claude.md`는 현재 비어 있음 — 규칙 미정.

## 2026-08-26 — 레오 포트폴리오 웹페이지 초안
- 새 파일 생성: `portfolio-leo.html` (기존 `portfolio.html`(김수민 샘플)은 그대로 보존)
- 구성: 히어로 / 소개 / 경력 3개(타임라인) / 스킬 / 연락처 / 푸터
- 반응형(모바일 1단 전환) + 라이트/다크 모드 자동 대응
- 태그 짝 검사 통과, 브라우저 열람 확인
- 남은 일: 「 」 표시된 실제 경력·연락처 정보 채우기 (레오님 확인 필요)

## 2026-08-28 — GitHub CLI(gh) 설치

- 요청: 내 OS(Windows 11 Pro)에 맞는 방법으로 gh 설치.
- 사전 확인: gh 없음 / winget 있음 / scoop·choco 없음 / git 2.55.0 이미 설치됨.
- 방법: Windows 기본 패키지 관리자인 `winget` 사용 (별도 다운로드 불필요, 이후 `winget upgrade`로 관리 가능).
  - `winget install --id GitHub.cli`
- 결과: **gh 2.98.0 설치 완료** — 확인함.
  - 설치 위치: `C:\Program Files\GitHub CLI\gh.exe`
- 주의: 설치 직후 기존에 열려 있던 터미널은 PATH가 갱신되지 않음 → **새 터미널을 열어야** `gh` 명령이 잡힘.
- 다음 단계였던 `gh auth login`도 같은 날 완료 (아래 항목 참고).

## 2026-08-28 (2) — gh 계정 로그인 완료

- `gh auth login`은 원래 키보드 메뉴를 고르는 대화형 명령 → Claude 실행 환경에선 입력을 못 넣어 멈춤.
- 해결: 물어볼 항목을 전부 옵션으로 미리 지정해 비대화형으로 실행.
  - `gh auth login --hostname github.com --git-protocol https --web`
  - 백그라운드 실행 + 출력 파일을 읽어 일회용 코드를 레오님께 전달하는 방식
- 결과: **로그인 성공** — `gh auth status`로 확인.
  - 계정: telesisi7-bit / 방식: https / 권한: gist, read:org, repo
  - 토큰은 Windows 자격 증명 관리자(keyring)에 저장됨. 파일로 남지 않음.
- 배운 점(다음에 재사용): 대화형 CLI는 ① 옵션으로 질문 제거 ② 백그라운드 실행 ③ 출력 파일 읽어 중계 — 이 3단계로 처리 가능.
