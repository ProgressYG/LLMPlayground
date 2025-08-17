## 프로젝트 구조 상세 설명

이 문서는 LLM API Playground의 폴더/파일 구조를 상세히 설명합니다. 각 컴포넌트의 역할, 주요 메서드, 데이터 흐름을 정확히 기술하여 실무 개발과 면접 대비에 활용할 수 있습니다.

---

### 루트 디렉토리
- `README.md`: 프로젝트 개요, 설치, 실행 가이드
- `Studyguide.md`: 풀스택 + Python 서버 학습 커리큘럼
- `Architecture.md`: 시스템 구조도, 데이터/스트림 플로우
- `structure.md`: 이 문서
- `Gemfile`: Rails 의존성 정의 (Rails 8.0.2, Solid Queue/Cable/Cache, HTTParty 등)
- `Gemfile.lock`: 의존성 버전 고정
- `config.ru`: Rack 애플리케이션 부트스트랩
- `requirements.txt`: Python 의존성 (FastAPI 0.115.6, OpenAI 1.57.0, Anthropic 0.41.0, Google Generative AI 0.8.3)
- `Procfile.dev`: 개발 환경 프로세스 정의
  - web: Rails 서버 (3000)
  - css: Tailwind CSS watcher
  - llm: Python FastAPI 서버 (8000)
- `bin/dev`: Foreman으로 Procfile.dev 실행
- `start_servers.sh`: Rails/Python 서버 간편 실행 스크립트

---

### app/ (Rails 애플리케이션)

#### app/controllers/
- **api/**
  - `prompts_controller.rb`: LLM 실행 관련 API
    - `POST /api/prompts/execute`: Prompt/Execution 생성 → LlmExecutionJob 큐잉 → {execution_id} 반환
    - `GET /api/prompts/:id/status`: 실행 상태/결과 조회 (폴링용)
    - `GET /api/prompts/:id/code`: 언어별(Python/JS/cURL) 코드 스니펫 생성
    - `GET /api/prompts/:id/export`: JSON/Markdown 형식 내보내기
  - `models_controller.rb`: 모델 메타데이터 API
    - `GET /api/models`: 전체 모델 목록 + API 키 상태
    - `GET /api/models/:id`: 특정 모델 상세 정보
- `playground_controller.rb`: 메인 UI 라우팅 (`GET /`)

#### app/models/
- `prompt.rb`: 프롬프트 데이터
  - 필드: system_prompt(text), user_prompt(text), parameters(jsonb), selected_model(string)
  - 연관: has_many :executions
  - 기본값: parameters = {temperature: 1.0, max_tokens: 2031, top_p: 0.4}
- `execution.rb`: 실행 단위
  - 필드: prompt_id, iterations(1-10), status(pending/running/completed/failed/cancelled), started_at, completed_at
  - 연관: belongs_to :prompt, has_many :results
- `result.rb`: 실행 결과
  - 필드: execution_id, iteration_number, response_text, tokens_used(jsonb), response_time_ms, status(success/error/timeout/cancelled), error_message
  - 메서드: input_tokens, output_tokens, total_tokens
- `template.rb`: 프롬프트 템플릿
  - 필드: name, description, system_prompt, user_prompt, default_parameters(jsonb)

#### app/services/
- `api_key_manager.rb`: 환경 변수 기반 API 키 관리
  - 지원 프로바이더: openai, anthropic, google
  - 메서드: get_key, key_available?, validate_key_format, all_keys_status
- `llm_models_service.rb`: 모델 메타데이터 관리
  - 현재 9개 모델 지원 (Claude 3종, Gemini 2종, GPT 4종)
  - 각 모델별: 가격, 토큰 제한, 컨텍스트 윈도우, 스트리밍 지원 여부
  - GPT-5 시리즈: max_completion_tokens 사용, temperature/top_p 미지원
- `code_generator_service.rb`: 실행 결과를 SDK 코드로 변환
  - 언어: Python, JavaScript, cURL
  - 프로바이더별 차이 반영 (예: GPT-5는 max_completion_tokens 사용)
- `export_service.rb`: 실행 데이터 내보내기
  - 형식: JSON, Markdown
  - 포함 내용: 파라미터, 프롬프트, 결과, 토큰 사용량, 응답 시간

#### app/jobs/
- `llm_execution_job.rb`: 비동기 LLM 호출 처리
  - perform(execution_id, streaming=false): 반복 실행 루프
  - call_llm_service: FastAPI 호출 (비스트리밍)
  - stream_llm_response: SSE 처리 → ActionCable 브로드캐스트
  - 오류 처리: Result에 저장 + PromptChannel.broadcast_error

#### app/channels/
- `prompt_channel.rb`: 실시간 스트리밍용 ActionCable 채널
  - broadcast_chunk: 토큰 단위 전송
  - broadcast_complete: 완료 알림 + 결과
  - broadcast_error: 오류 알림

#### app/javascript/
- **controllers/** (Stimulus)
  - `execute_controller.js`: 실행 UI 제어, 스트리밍 구독
  - `code_modal_controller.js`: 코드 스니펫 모달 (언어 전환, 복사)
  - `compare_controller.js`: 결과 비교 모달
  - `parameter_slider_controller.js`: 파라미터 슬라이더 (Temperature, Max Tokens, Top P)
  - `model_select_controller.js`: 모델 선택 드롭다운
  - `prompt_input_controller.js`: 프롬프트 입력 (Cmd+Enter 실행)
  - `export_controller.js`: 내보내기 기능
- **channels/**
  - `prompt_channel.js`: ActionCable 구독 래퍼

---

### lib/ (Python FastAPI 서버)

#### lib/llm_api_server.py
- FastAPI 애플리케이션 (포트 8000)
- 엔드포인트:
  - `GET /health`: 헬스체크
  - `GET /models`: 사용 가능 모델 목록
  - `POST /generate`: LLM 생성 (stream 옵션)
  - `POST /batch_generate`: 병렬 반복 실행
- CORS: http://localhost:3000 허용

#### lib/llm_services/
- `base_llm.py`: 추상 베이스 클래스
  - LLMResponse 데이터클래스
  - 공통 메서드: generate, stream_generate, retry_with_exponential_backoff
- `llm_factory.py`: 프로바이더 팩토리
  - 모델 ID 접두어로 프로바이더 결정 (gpt→OpenAI, claude→Anthropic, gemini→Google)
  - 환경 변수에서 API 키 로드
- `openai_llm.py`: OpenAI 구현
  - AsyncOpenAI 클라이언트 사용
  - GPT-4o, GPT-4o-mini, GPT-5 시리즈 지원
- `anthropic_llm.py`: Anthropic 구현
  - AsyncAnthropic 클라이언트 사용
  - Claude 3.5 Haiku/Sonnet, Claude 4.x 지원
- `gemini_llm.py`: Google Gemini 구현
  - 동기 SDK를 asyncio executor로 비동기화
  - Safety 필터 처리, 한국어 프롬프트 특별 처리

---

### config/
- `routes.rb`: Rails 라우팅 정의
- `database.yml`: PostgreSQL 16 연결 설정
- `cable.yml`: ActionCable 어댑터 (개발: async, 운영: solid_cable)
- `queue.yml`: Solid Queue 워커 설정
- `application.rb`: Rails 앱 설정
- **environments/**: 환경별 설정 (development, test, production)
- **initializers/**: 부팅 시 실행 (assets.rb, content_security_policy.rb 등)

---

### db/
- **migrate/**: 마이그레이션 파일
  - 20250808105746_create_prompts.rb
  - 20250808105754_create_executions.rb
  - 20250808105820_create_results.rb
  - 20250808105829_create_templates.rb
- `schema.rb`: 현재 DB 스키마
- `queue_schema.rb`: Solid Queue 테이블
- `cable_schema.rb`: Solid Cable 테이블
- `cache_schema.rb`: Solid Cache 테이블

---

### 기타 주요 파일
- **bin/**: 실행 스크립트
  - dev, rails, bundle, importmap, jobs 등
- **public/**: 정적 파일
  - 에러 페이지 (404.html, 500.html 등)
- **vendor/**: 서드파티 자산
- **venv/**: Python 가상환경
- **tmp/**, **log/**, **storage/**: 런타임 생성 파일

---

### 확장 포인트
1. **새 LLM 프로바이더 추가**:
   - `lib/llm_services/<provider>_llm.py` 구현
   - `llm_factory.py`에 매핑 추가
   - `LlmModelsService`에 모델 메타 추가
   - `.env`에 API 키 추가

2. **새 Export 형식**:
   - `ExportService`에 메서드 추가
   - `prompts_controller#export`에 분기 추가

3. **추가 파라미터**:
   - DB: `prompts.parameters` JSONB에 필드 추가
   - UI: 슬라이더/입력 컴포넌트 추가
   - Python: GenerateRequest 모델 확장

---

### 주요 데이터 흐름
1. 사용자 입력 → Rails Controller → DB 저장 → Job 큐잉
2. Job → FastAPI 호출 → LLM SDK → 응답/스트림
3. 응답 → DB 저장 + ActionCable 브로드캐스트 → 브라우저 갱신

---

### 성능/보안 고려사항
- API 키는 환경 변수로만 관리 (.env 파일 커밋 금지)
- Solid Queue로 동시성 제어 (config/queue.yml)
- SSE 파싱 오류 격리 처리
- 지수 백오프 재시도 (최대 3회)
- CORS는 localhost:3000만 허용


