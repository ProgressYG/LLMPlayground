## 프로젝트 구조 상세 설명

각 폴더/파일의 역할과 실무에서 어떻게 활용되는지 정리했습니다. 신규 기여자/면접관에게 구조를 빠르게 설명할 때 참고하세요.

---

### 루트
- `README.md`: 설치/실행/개요 문서
- `Studyguide.md`: 학습 로드맵 및 심화 가이드
- `Architecture.md`: 시스템 구조도와 데이터/스트림 흐름
- `structure.md`: 이 문서
- `Gemfile`: Rails 의존성 정의
- `Dockerfile`: 컨테이너 빌드 정의(옵션)
- `config.ru`: Rack 부트스트랩 파일
- `requirements.txt`: Python 의존성
 - `Procfile.dev`: 개발 시 동시 실행 프로세스 정의(web/css/llm)
 - `bin/dev`: Foreman으로 `Procfile.dev` 실행(필요 시 foreman 설치)
 - `start_servers.sh`: 간단 로컬 실행 스크립트(Rails/LLM 서버 동시 기동)

---

### app/
- `controllers/`
  - `api/`
    - `prompts_controller.rb`
      - `POST /api/prompts/execute`: 프롬프트와 파라미터를 DB에 저장 후 `LlmExecutionJob` 큐잉. 응답으로 `execution_id` 반환.
      - `GET /api/prompts/:id/status`: 실행 상태 및 `results` 목록 반환(폴링용). `execution.completed?`로 완료 여부 포함.
      - `GET /api/prompts/:id/code`: 특정 iteration 결과를 기반으로 Python/JS/cURL 코드 스니펫 생성(`CodeGeneratorService`).
      - `GET /api/prompts/:id/export`: JSON/Markdown 콘텐츠 생성(`ExportService`) 및 파일명 메타 반환.
      - 내부 `detect_provider`로 모델 접두어에 따라 프로바이더(OpenAI/Anthropic/Google) 식별.
    - `models_controller.rb`
      - `GET /api/models`(index): `LlmModelsService`의 모델 메타데이터와 `ApiKeyManager`의 키 상태를 함께 반환.
      - `GET /api/models/:id`(show): 단일 모델 메타 반환(없으면 404).
  - `playground_controller.rb`: 메인 화면 라우팅
- `models/`
  - `prompt.rb`, `execution.rb`, `result.rb`: 핵심 도메인 모델
    - 연관: `Prompt has_many :executions`, `Execution has_many :results`.
    - `Execution` 상태 필드(`pending/running/completed`)와 타임스탬프(`started_at/completed_at`)로 실행 수명주기 추적.
- `services/`
  - `api_key_manager.rb`
    - `.env`에서 `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_GEMINI_API_KEY` 조회.
    - `validate_key_format(provider, key)`: 프로바이더별 키 패턴 빠른 검증.
    - `all_keys_status`: UI 배지용 요약(가용 여부 + env 키명).
  - `llm_models_service.rb`
    - `MODELS` 상수: 모델 ID→메타데이터(표시명/아이콘/특성/가격/맥스 토큰/컨텍스트/스트리밍 여부).
    - `all_models/available_models/get_model/calculate_cost` 제공. 비용은 1M 토큰 단가 기준 계산.
  - `code_generator_service.rb`
    - 결과/프롬프트를 기반으로 재현 가능한 API 호출 스니펫을 생성.
    - Python(OpenAI/Anthropic/Gemini), JavaScript(OpenAI/Anthropic), cURL(OpenAI/Anthropic) 지원.
    - 모델 접두어로 프로바이더 식별(`detect_provider`), 벤더별 모델명 매핑 포함.
  - `export_service.rb`
    - 실행 전체 또는 특정 iteration을 **JSON/Markdown**으로 내보내기.
    - Markdown은 파라미터/프롬프트/반복별 결과를 가독성 높은 섹션으로 구성.
- `jobs/`
  - `llm_execution_job.rb`
    - `perform(execution_id, streaming=false)`: 반복 횟수만큼 LLM 호출 루프 수행.
    - `call_llm_service`: FastAPI `/generate` 호출(stream=false), JSON 응답 파싱 후 `results` 저장.
    - `stream_llm_response`: SSE 수신(stream=true) → 청크 브로드캐스트 → 누적 완료 시 DB 저장.
    - 예외 시 결과를 `status:error`로 기록하고, `PromptChannel.broadcast_error`로 UI 알림.
- `channels/`
  - `prompt_channel.rb`
    - `broadcast_chunk(execution, iteration, content)`: 토큰 청크 UI 전송.
    - `broadcast_complete(execution, iteration, result)`: 완료 시 결과 카드 갱신.
    - `broadcast_error(execution, iteration, error)`: 스트림/호출 오류 알림.
- `views/`
  - `playground/index.html.erb`: 메인 UI(모델 선택/프롬프트/파라미터/결과)
- `javascript/`
  - `controllers/`: Stimulus 컨트롤러(UI 상호작용)
    - `execute_controller.js`: 실행 탭 전환, 스트리밍 UI 초기화, ActionCable 구독 핸들러(onChunk/onComplete/onError) 연결.
    - `code_modal_controller.js`: 언어 탭(Python/JS/cURL) 전환, 콘텐츠 로드(`/api/prompts/:id/code`), 클립보드 복사.
    - `compare_controller.js`: 결과 카드 다중 선택 → 두 결과 비교 모달, 간이 diff 하이라이트/통계(응답시간/토큰) 표시.
    - `parameter_slider_controller.js`: 온도/토큰/TopP 슬라이더 바인딩 및 프리셋 버튼.
  - `channels/`
    - `prompt_channel.js`: `subscribeToExecution(executionId, handlers)`로 채널에 구독/해제 래퍼 제공.
      - 서버 브로드캐스트 타입(`chunk/complete/error`)에 따라 콜백 실행.

---

### lib/
- `llm_api_server.py`: FastAPI 애플리케이션 엔트리(헬스/모델/생성/배치)
- `llm_services/`
  - `base_llm.py`: 추상 베이스 클래스(리트라이/토큰 추정 포함)
  - `llm_factory.py`: 모델 접두어(`gpt/claude/gemini`)로 프로바이더 선택, `.env` 키 로드(`dotenv.load_dotenv()`), 사용 가능 모델 반환.
  - `openai_llm.py`: OpenAI 비동기 SDK 사용, `generate/stream_generate` 구현, usage 토큰 집계.
  - `anthropic_llm.py`: Anthropic 비동기 SDK 사용, 시스템 프롬프트/`top_p` 모델별 제약 반영, usage 집계.
  - `gemini_llm.py`: 동기 SDK를 executor로 비동기화, Safety 차단 사유 매핑/로그, 한국어 입력 힌트.

---

### config/
- `routes.rb`: API 라우트/루트 설정
- `queue.yml`: Solid Queue 워커/프로세스 동시성 설정
- `cable.yml`: ActionCable 어댑터 설정(개발 async, 운영 solid_cable)
- `environments/`: 환경별 튜닝
- `initializers/`: CSP, 자산 파이프라인 등
 - `application.rb`: `config.autoload_lib(ignore: %w[assets tasks])` 등 로딩 설정
 - (프로젝트에 따라) `database.yml`: PostgreSQL 커넥션 설정

---

### db/
- `migrate/`: `prompts`, `executions`, `results`, `templates` 스키마 정의
- `schema.rb`: 현재 스키마 스냅샷
- `queue_schema.rb`, `cable_schema.rb`, `cache_schema.rb`: Solid* 스키마
 - (선택) `seeds.rb`: 초기 데이터 시드

---

### 기타
- `bin/dev`: 개발용 동시 실행 스크립트(Foreman류). 3000(Rails)/8000(FastAPI)/Tailwind watcher.
- `public/`: 정적 리소스/에러 페이지
- `vendor/javascript/`: Importmap 자바스크립트
 - `app/assets/tailwind/`: Tailwind CSS 소스. `tailwindcss-rails` watcher가 빌드.

---

### 확장 시 변경 포인트
- 새 LLM 추가: `llm_services/<provider>_llm.py` 구현 → `llm_factory.py`에 매핑 추가 → `LlmModelsService`에 메타 추가 → UI 드롭다운 노출
- 새로운 Export 포맷: `ExportService` 확장 및 라우트 응답 분기 추가
- 추가 파라미터: DB `prompts.parameters` JSONB 확장 + 프론트 슬라이더/입력 추가 + Python 매핑 추가

---

### 운영 팁 & 면접 포인트
- 운영 팁
  - FastAPI CORS: Rails(3000) 오리진만 허용. 헬스 `/health` 모니터링.
  - Queue 동시성은 DB/LLM 레이트 제한에 맞춰 점진적 조정.
  - 결과 보존: 텍스트 압축/요약 저장 + 장기 보관 주기 정책.
- 면접 포인트
  - Rails→FastAPI→LLM→SSE→ActionCable→브라우저로 이어지는 스트림 경로 설명.
  - 벤더별(SDK/파라미터/제약) 차이를 추상화 계층으로 캡슐화한 이유.
  - 비용/성능 지표 저장과 리포팅 설계(토큰/응답시간/오류율).


