## LLM API Playground 학습 가이드 (Full-stack + Python 서버 심화)

이 문서는 풀스택(Rails 8 + Tailwind + Stimulus)과 Python(FastAPI) 기반의 LLM 통합 아키텍처를 실무 수준으로 학습하기 위한 체계적 커리큘럼을 제공합니다. 면접 대비 및 포트폴리오 작성에 필요한 근거와 실습 과제를 포함합니다. 각 섹션에는 학습 목표, 핵심 개념, 실습 과제, 심화 과제가 포함됩니다.

---

### 0. 학습 환경 및 재현성(필독)
- 언어/런타임 버전 고정: Ruby 3.3.x, Rails 8.0.2, Python 3.11.x, PostgreSQL 16.x
- `.env` 관리: Rails(`dotenv-rails`), Python(`python-dotenv`)에서 자동 로드
- 실행: `bin/dev` → Rails(3000), FastAPI(8000), Tailwind watcher
- 프로세스 확인: `Procfile.dev`에서 각 프로세스 정의(web/css/llm)
- 권장: `rbenv/pyenv`, 별도 가상환경(venv) 사용, DB는 로컬 16.x

체크리스트
- [ ] `.env`에 `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_GEMINI_API_KEY` 설정
- [ ] `rails db:create && rails db:migrate`
- [ ] `bin/dev`로 전체 구동 확인(브라우저 3000, API 8000)

---

### 1. 목표 역량
- **백엔드(Rails)**: REST API, Active Job/Solid Queue, ActionCable, 서비스 계층, Export/CodeGen 패턴
- **프론트(Hotwire)**: Stimulus 컨트롤러 아키텍처, ActionCable 구독, UI/UX(슬라이더/모달/비교뷰)
- **Python(FastAPI)**: 비동기 엔드포인트, SSE, LLM 프로바이더 추상화/팩토리, 리트라이/백오프
- **데이터/운영**: JSONB 파라미터, 비용·토큰 저장, 재현 가능한 설정, 로깅/헬스체크/에러 핸들링

---

### 2. 전체 구조 개요(End-to-End)
1) 사용자가 프롬프트/파라미터 제출 → `POST /api/prompts/execute`
2) Rails가 `prompts`, `executions` 저장 → `LlmExecutionJob` 큐잉
3) Job이 FastAPI `/generate` 호출(stream 옵션에 따라 SSE/일반)
4) FastAPI는 `LLMFactory`로 프로바이더 생성(OpenAI/Anthropic/Gemini)
5) 결과를 Rails로 반환 또는 SSE로 스트리밍 → ActionCable → 브라우저 반영

핵심 파일
- Rails: `app/controllers/api/prompts_controller.rb`, `app/jobs/llm_execution_job.rb`, `app/channels/prompt_channel.rb`
- 서비스: `app/services/llm_models_service.rb`, `code_generator_service.rb`, `export_service.rb`, `api_key_manager.rb`
- Python: `lib/llm_api_server.py`, `lib/llm_services/*`

실습 과제 A
- `iterations=3`으로 실행하여 3개의 `results`가 저장되는 흐름을 DB에서 확인(`rails c`로 조회)

---

### 3. 데이터 모델 설계 심화
스키마
- `prompts(system_prompt, user_prompt, parameters:jsonb, selected_model)`
- `executions(prompt_id, iterations, status, started_at, completed_at)`
- `results(execution_id, iteration_number, response_text, tokens_used:jsonb, response_time_ms, status, error_message)`

설계 포인트
- `parameters`를 JSONB로 두어 파라미터 확장을 유연하게 지원(예: `presence_penalty`, `top_k` 추가)
- 응답 지표(시간·토큰)를 저장 → 비용/성능 리포팅의 근거 데이터
- 대용량 시 보존 정책(예: 90일 이후 결과 텍스트 압축/요약 저장)

인덱싱 권장
- `executions(prompt_id)` / `results(execution_id, iteration_number)` 복합 인덱스
- 월별 리포팅용 파티셔닝(선택) 또는 마테뷰로 비용 요약

실습 과제 B
- `results`에 `prompt_hash`(SHA256) 컬럼 추가 후 인덱스 → 중복 프롬프트 식별과 캐시 전략 설계

---

### 4. Rails 백엔드 심화
라우팅/컨트롤러
- `POST /api/prompts/execute`: 프롬프트/실행 생성 후 잡 큐잉
- `GET /api/prompts/:id/status`: 실행/결과 조회(폴링용)
- `GET /api/prompts/:id/code`: 결과 기반 스니펫(Python/JS/cURL) 생성
- `GET /api/prompts/:id/export`: JSON/Markdown 내보내기

잡/큐/스트리밍
- `LlmExecutionJob`: 반복 실행 루프, FastAPI 호출, 결과 저장
- 스트리밍 분기: `stream_llm_response`에서 SSE 파싱 → `PromptChannel.broadcast_chunk`
- 동시성: `config/queue.yml`에서 스레드/프로세스/폴링간격 설정

서비스 계층 패턴
- `LlmModelsService`: 모델 메타(가격/컨텍스트/토큰/스트리밍 지원)
- `CodeGeneratorService`: 결과를 SDK 호출 예제로 변환(Python/JS/cURL)
- `ExportService`: 실행/결과를 JSON/Markdown 포맷으로 변환
- `ApiKeyManager`: 키 존재/형식 검증 및 상태 요약

실습 과제 C
- `ExportService`에 CSV 포맷 추가 및 API 분기(`format=csv`) 구현

---

### 5. 프론트엔드(Hotwire + Tailwind) 심화
Stimulus 컨트롤러
- `execute_controller.js`: 실행 트리거, 탭/결과 갱신, 스트림 구독 연결
- `code_modal_controller.js`: 코드 스니펫 모달, 언어 탭 전환, 복사 기능
- `compare_controller.js`: 다중 결과 선택/비교 모달, 간이 diff 표시
- `parameter_slider_controller.js`: 온도/토큰/TopP 슬라이더 바인딩 및 프리셋

ActionCable 스트림
- `PromptChannel` 브로드캐스트 → `prompt_channel.js` 구독 → UI append
- 에러/완료 이벤트 분리 처리, 누적 텍스트와 완료 시 저장 분기

Tailwind with Rails
- `tailwindcss-rails`로 watcher 구동(`bin/dev`), 다크 테마 구성, 유틸리티 우선 설계

실습 과제 D
- 파라미터 프리셋 버튼(정확/균형/창의) 추가 및 값 적용 로직 구현

---

### 6. FastAPI 서버 심화
엔드포인트
- `GET /health`: 상태 체크
- `GET /models`: 환경 변수 기반 사용 가능 모델 반환
- `POST /generate`: 비스트림/스트림(SSE) 공용 엔드포인트
- `POST /batch_generate`: `asyncio.gather`로 병렬 반복

모델/추상화
- `BaseLLM`: 공통 인터페이스(`generate`, `stream_generate`), 리트라이(지수 백오프), 토큰 추정
- `LLMFactory`: 모델 접두어로 프로바이더 선택 + `.env` 키 로드/검증
- 프로바이더: `OpenAILLM`, `AnthropicLLM`, `GeminiLLM`
  - OpenAI/Anthropic: 비동기 SDK 사용
  - Gemini: 동기 SDK를 executor로 비동기화 + Safety 차단 사유 매핑/로그 제공

SSE 구현 요령
- FastAPI에서 `StreamingResponse`와 `text/event-stream` 헤더, `data: {...}\n\n` 규격 유지
- Rails에서 `Net::HTTP`로 라인 단위 파싱, `[DONE]`/`{"done":true}` 처리 분기

실습 과제 E
- `/generate`에 `presence_penalty`, `frequency_penalty`(OpenAI 한정) 매개변수 지원과 유효성 검증 추가

---

### 7. 에러 처리/신뢰성
공통 원칙
- 사용자 친화적 메시지 + 내부 로그(스택/사유/재시도 횟수) 분리
- 네트워크/429/타임아웃/키 없음/형식 오류에 대한 별도 코드 경로

Rails
- 잡 내부 try/catch → `results`에 오류 기록 + 채널 에러 브로드캐스트
- SSE 파싱 오류 시 라인 스킵/로그/복구 전략

FastAPI
- 4xx(키 없음/모델 오류) vs 5xx(내부 오류) 구분
- Gemini Safety: 차단 사유(숫자→의미) 매핑 로그 및 사용자 안내 문구 반환

실습 과제 F
- OpenAI 429 응답 시 재시도 대기 시간을 지수+지터로 적용하고 최대 대기 한도 설정

---

### 8. 테스트 전략(실무형)
Rails(Minitest)
- 모델: 유효성/연관/스코프
- 서비스: CodeGen/Export의 포맷/이스케이프/에러
- 컨트롤러: `execute/status/code/export` 응답 계약
- 잡: 큐 인메모리 모드로 수행/저장/브로드캐스트 단언

Python(pytest)
- 프로바이더: SDK 호출 mock, 예외/리트라이/토큰 집계 단언
- 라우트: httpx.AsyncClient로 `/generate`/`/batch_generate`/SSE 테스트

통합(E2E)
- 소량 토큰으로 실제 스트림 흐름 검증 및 UI 반영 스냅샷 테스트(선택)

실습 과제 G
- 실패 주입(키 없음/타임아웃/429) 테스트 케이스 추가 및 CI 매트릭스 구성

---

### 9. 보안/운영 베스트 프랙티스
- `.env` 비밀은 커밋 금지, 운영은 Secret Manager 사용 권장
- CORS(3000→8000 허용), CSP는 상황에 맞게 강화
- 로깅: PII 마스킹, 요청 샘플링, 성능 로그(응답시간/토큰)
- 헬스체크: Rails `/up`, FastAPI `/health`를 LB/모니터링에 연결

실습 과제 H
- 감사지표(누가/언제/무엇을) 로깅 도입 및 관리용 조회 화면 추가

---

### 10. 성능/비용 최적화
- FastAPI: `asyncio.gather` 배치 처리, 타임아웃/최대 동시 실행 제한
- Rails: Solid Queue 동시성 조절(스레드/프로세스), 작업량에 따른 backpressure
- 비용: 입력/출력/총 토큰 저장 → 월별/모델별 비용 리포트/대시보드 설계

실습 과제 I
- 비용 한도(모델별/사용자별) 초과 시 경보/차단 로직 추가

---

### 11. 배포/운영
- 개발: `foreman`/`bin/dev`로 로컬 동시 실행
- 운영: Kamal(컨테이너) 또는 별도 프로세스 관리로 Rails/LLM 서버 분리 배포
- 마이그레이션/시드, 롤백 전략, 백업/보관/복구 플랜 명시

실습 과제 J
- Kamal 템플릿 작성(환경 변수/포트/CORS/헬스체크) 및 스테이징 배포 시뮬레이션

---

### 12. 확장성: 새 LLM 추가 가이드
체크리스트
1) Python: `lib/llm_services/<provider>_llm.py` 구현(모델 매핑/파라미터/리트라이)
2) `llm_factory.py`에 접두어→프로바이더 매핑 및 `.env` 키 로드 추가
3) Rails: `LlmModelsService`에 모델 메타 추가(이름/가격/지원/토큰/컨텍스트)
4) 프론트: 드롭다운/아이콘/설명 반영, CodeGen/Export 필요 시 확장
5) 문서/README/Studyguide 업데이트

심화 과제
- 이미지 입력/툴사용/함수호출 등 멀티모달/에이전트화 확장 설계

---

### 13. 인터뷰 대비 Q&A
- Q: SSE와 WebSocket의 차이와 선택 기준은?
  - A: 서버 푸시 단방향/브라우저 표준/SSE 재연결 편의 vs 양방향/바이너리/프로토콜 유연성. 본 프로젝트는 토큰 스트림 일방 전달에 SSE가 적합.
- Q: 모델별 파라미터 차이 대응은?
  - A: `BaseLLM` 추상화 + 프로바이더별 매핑. 예: Gemini Safety 차단 사유 매핑/안내.
- Q: 비용 추적은 어떻게?
  - A: SDK usage→`results.tokens_used` 저장, 월/모델 기준 집계.
- Q: 장애 복원력은?
  - A: 지수 백오프, 타입별 예외 분리, 스트림 파싱 실패 격리, 잡 재시도 정책.

---

### 14. 용어/참고 자료
- Hotwire(Stimulus/Turbo), ActionCable, SSE, FastAPI, Pydantic, AsyncIO, Backoff, Safety
- 공식 문서: Rails 8, FastAPI, OpenAI/Anthropic/Gemini SDK, SSE 가이드

---

### 15. 실습 로드맵(요약)
1) E2E 실행/스트리밍 확인
2) Export 포맷 추가(CSV)
3) 파라미터 프리셋/검증 추가
4) 비용 대시보드 초안(월/모델별)
5) 새 LLM 프로바이더 샘플 추가

필요 시 각 과제별 해설/샘플 코드를 별도 부록으로 제공 가능합니다.


