## LLM API Playground
https://llm.teamsp.pmirnc.io/
(사내에서만 접근 가능)

엔터프라이즈급 LLM API 프롬프트 테스팅 및 최적화 플랫폼



### 🚀 주요 기능
- **다중 LLM 지원**: OpenAI(GPT-4o/4o-mini), Anthropic(Claude 3.5/4.x), Google(Gemini 2.5)
- **파라미터 조정**: Temperature, Max Tokens, Top P 실시간 조정
- **반복 실행**: 동일 프롬프트를 1–10회 반복하여 일관성 검증
- **실시간 스트리밍**: SSE + ActionCable로 토큰 단위 스트리밍
- **Dark UI**: 70:30 듀얼 패널 레이아웃, 비교 뷰, 코드 스니펫 자동 생성

### 📋 사전 요구 사항
- Ruby 3.3.0+
- Rails 8.0.2+
- PostgreSQL 16.0+
- Python 3.11+
  
참고: 본 프로젝트는 Rails 8 Importmap + `tailwindcss-rails`를 사용하며 별도의 Node.js 번들러가 필요하지 않습니다.

---

## 🛠️ 설치

### 1) 저장소 준비
```bash
cd /Volumes/ygmac_external/Projects_e/LLM_Play
```

### 2) 의존성 설치
```bash
# Ruby gems
bundle install

# Python packages
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3) 환경 변수 설정 (.env)
`.env` 파일을 생성 후 아래 값을 채워주세요. (`.env.example`가 없으면 직접 생성하세요)
```env
# LLM API Keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_GEMINI_API_KEY=AIza...

# Database (개발용 선택)
DB_USERNAME=your_username
DB_PASSWORD=your_password
```

Rails는 `dotenv-rails`, Python은 `python-dotenv`를 통해 `.env`를 자동 로드합니다.

### 4) 데이터베이스 준비
```bash
rails db:create
rails db:migrate
```

---

## 🎮 실행 방법

### 전체 서비스 동시 실행
```bash
bin/dev
```
동시에 다음이 실행됩니다.
- Rails 서버: http://localhost:3000
- Python FastAPI 서버: http://localhost:8000
- Tailwind CSS watcher

### 개별 실행 (선택)
```bash
# Rails
bin/rails server

# Python (별도 터미널)
source venv/bin/activate
python lib/llm_api_server.py
# 또는
uvicorn lib.llm_api_server:app --host 0.0.0.0 --port 8000 --reload
```

### 간단 실행 스크립트 (선택)
```bash
./start_servers.sh
```
동시에 Rails(3000), Python(8000)을 백그라운드로 기동합니다.

---

## 💡 빠른 시작
1) 헤더의 🔑 API Status에서 키 인식 여부 확인
2) 모델 선택 (예: `gpt-4o`, `claude-3-5-haiku-20241022`, `gemini-2.5-pro`)
3) System/User Prompt 입력 후 파라미터 조정
4) Iterations(1–10) 지정 후 Execute
5) 결과 카드 클릭 → 코드 스니펫 모달에서 Python/JS/cURL 확인 및 복사

단축키: `Cmd/Ctrl + Enter` 실행, `ESC` 모달 닫기

---

## 🧩 구성 요소 요약

- Rails API
  - `POST /api/prompts/execute`: 프롬프트 저장 → `LlmExecutionJob` 큐잉 → Python 호출
  - `GET /api/prompts/:id/status`: 실행/결과 조회
  - `GET /api/prompts/:id/code`: 코드 스니펫 생성
  - `GET /api/prompts/:id/export`: JSON/Markdown 내보내기
  - 모델 메타: `GET /api/models`

- Python FastAPI
  - `GET /health`: 헬스 체크
  - `GET /models`: 사용 가능 모델 목록 반환 (환경 변수 기반)
  - `POST /generate`: 단발 요청 또는 `stream=true` 시 SSE 스트리밍
  - `POST /batch_generate`: 병렬 반복 실행

- 스트리밍 경로
  - Rails `LlmExecutionJob#stream_llm_response`가 FastAPI SSE를 읽어 `PromptChannel`로 브로드캐스트
  - 프론트는 `app/javascript/channels/prompt_channel.js` 구독 후 실시간 반영

---

## 🗄️ 데이터 모델 (요약)
- `prompts(system_prompt, user_prompt, parameters(jsonb), selected_model)`
- `executions(prompt_id, iterations, status, started_at, completed_at)`
- `results(execution_id, iteration_number, response_text, tokens_used(jsonb), response_time_ms, status, error_message)`

---

## 📡 FastAPI 예시 요청
```bash
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model_id": "gpt-4o",
    "system_prompt": "You are a helpful assistant",
    "user_prompt": "Explain SSE vs WebSocket concisely",
    "temperature": 0.7,
    "max_tokens": 512,
    "top_p": 1.0,
    "stream": false
  }'
```

---

## 🔧 트러블슈팅

### PostgreSQL 연결 오류
```bash
brew services list | grep postgresql
brew services start postgresql@16
```

### Python 모듈 누락
```bash
source venv/bin/activate
pip install -r requirements.txt
```

### 포트 충돌
```bash
lsof -i :3000; lsof -i :8000 | cat
kill -9 <PID>
```

### CORS 또는 403 응답
- `lib/llm_api_server.py`에서 CORS 허용 오리진은 기본 `http://localhost:3000`입니다. 다른 도메인/포트를 쓰면 여기에 추가하세요.

---

## 🧪 테스트
```bash
# Rails
rails test

# Python
pytest
```

---

## 📚 추가 문서
- `Architecture.md`: 전체 아키텍처와 데이터/스트림 흐름
- `structure.md`: 폴더/파일별 상세 설명
- `Studyguide.md`: 풀스택+Python 서버 심층 학습 가이드

---

## 라이선스
Private use only
