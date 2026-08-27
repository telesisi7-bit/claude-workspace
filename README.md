# claude-workspace

레오의 Claude Code 작업 공간입니다.
작업 규칙, 할 일 기록, 그리고 실제로 돌아가는 자동화 스크립트를 한곳에 모아둔 저장소입니다.

---

## 폴더 구조

```
claude-workspace/
│
├── claude.md                  # Claude Code 지침서 (작업 규칙·보안 규칙)
├── CLAUDE_템플릿.md            # 위 지침서의 빈 템플릿 (새 프로젝트용)
├── README.md                  # 이 문서
├── SECURITY.md                # 보안 사고 비상 대응 매뉴얼
├── .gitignore                 # GitHub에 올리지 않을 파일 목록
│
├── tasks/                     # 작업 기록
│   ├── todo.md                #   할 일 (진행 중 / 대기 / 완료)
│   └── progress.md            #   한 일 (날짜순 누적, 지우지 않음)
│
├── wader/                     # 날씨 자동 수집 (매일 09:00 자동 실행)
│   ├── weather_fetch.ps1      #   날씨·미세먼지 수집 + 디스코드 전송
│   ├── register_task.ps1      #   윈도우 작업 스케줄러 등록용
│   ├── weather.txt            #   수집 결과 (계속 쌓임)
│   └── .env.example           #   설정 견본 (실제 .env는 올리지 않음)
│
├── docx/                      # 실습용 자료
│   ├── sales.csv              #   매출 샘플 데이터
│   └── resume.pdf             #   이력서 샘플
│
├── portfolio.html             # 포트폴리오 (책 샘플 - 김수민)
├── portfolio-leo.html         # 포트폴리오 (레오 버전, 작성 중)
│
├── resume_sample.pdf          # 이력서 샘플
├── 부록A_GitHub_슬라이드.pdf
├── 부록B_Vercel_슬라이드.pdf
└── 부록C_Supabase_슬라이드.pdf
```

---

## 각 문서의 역할

| 문서 | 언제 보나 |
|---|---|
| `claude.md` | Claude Code가 작업 시작할 때 자동으로 읽는 규칙서 |
| `tasks/todo.md` | 새 작업을 시작하기 전, 계획을 적고 확인받는 곳 |
| `tasks/progress.md` | 작업을 마칠 때마다 "무엇을 왜 했는지" 남기는 곳 |
| `SECURITY.md` | 키가 유출됐거나 파일을 날렸을 때 |

---

## 돌아가고 있는 자동화

**순천 용당동 날씨 수집** (`wader/`)

- 매일 오전 9시 · 윈도우 작업 스케줄러 `SuncheonWeatherDaily`
- 날씨 + 미세먼지를 받아 `weather.txt`에 누적 저장
- 동시에 디스코드 채널로 카드 알림 전송
- API 키 불필요 (Open-Meteo 무료 서비스 사용)

---

## 보안 원칙

이 저장소는 **프라이빗**이지만, 그래도 비밀 정보는 올리지 않습니다.

- 실제 키·주소는 `.env`에만 두고, `.gitignore`가 막습니다
- 공유가 필요하면 값이 빈 `.env.example`을 씁니다
- 자세한 규칙은 `claude.md`, 사고 대응은 `SECURITY.md` 참고

### 처음 받아서 쓸 때

```bash
cd wader
cp .env.example .env
# .env 를 열어 디스코드 Webhook 주소를 채워 넣으세요
```

---

*마지막 업데이트: 2026-08-28*
