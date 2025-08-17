## LLM API Playground 학습 가이드 (Full-stack + Python 서버 심화)

이 문서는 풀스택(Rails 8 + Tailwind + Stimulus)과 Python(FastAPI) 기반의 LLM 통합 아키텍처를 실무 수준으로 학습하기 위한 체계적 커리큘럼을 제공합니다. 실제 취업 면접과 포트폴리오에 즉시 활용 가능한 내용으로 구성했습니다.

---

### 📚 학습 로드맵 개요

```
1주차: 환경 설정 + 전체 구조 파악
2주차: Rails 백엔드 심화 (MVC, ActiveJob, ActionCable)
3주차: Python FastAPI + LLM 통합
4주차: 프론트엔드 (Hotwire) + 실시간 기능
5주차: 테스트 + 보안 + 성능 최적화
6주차: 배포 + 모니터링 + 포트폴리오 완성
```

---

### 0. 학습 환경 설정 (Day 1)

#### 필수 설치 항목
```bash
# Ruby 환경
brew install rbenv postgresql@16 redis
rbenv install 3.3.0
gem install bundler foreman

# Python 환경
brew install pyenv
pyenv install 3.11.0
python -m venv venv
source venv/bin/activate

# 프로젝트 설정
bundle install
pip install -r requirements.txt
rails db:create db:migrate
```

#### 환경 변수 설정 (.env)
```bash
# LLM API Keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_GEMINI_API_KEY=AIza...

# Database
DATABASE_URL=postgresql://localhost/llm_playground_development

# Rails
RAILS_MASTER_KEY=<rails credentials:edit로 확인>
```

#### 실행 확인
```bash
# 전체 서비스 실행
bin/dev

# 개별 실행 (디버깅용)
rails server -p 3000
cd lib && uvicorn llm_api_server:app --reload --port 8000
bin/rails tailwindcss:watch

# 간편 실행
./start_servers.sh
```

**학습 포인트**: 
- Procfile.dev의 역할과 Foreman 사용법
- 환경 변수 관리의 중요성
- 개발 환경 자동화의 가치

---

### 1. 전체 아키텍처 이해 (Week 1)

#### 학습 목표
- Rails + FastAPI 이중 구조의 장점 이해
- 비동기 처리와 실시간 통신 개념 습득
- 데이터 흐름 전체 파악

#### 핵심 개념
1. **아키텍처 패턴**
   - Microservices: Rails(비즈니스 로직) + FastAPI(LLM 전문)
   - Event-driven: ActiveJob + ActionCable
   - Service Layer: 비즈니스 로직 캡슐화

2. **데이터 플로우**
   ```
   Browser → Rails API → ActiveJob → FastAPI → LLM Provider
      ↑                                  ↓
      ←────── ActionCable ←──────── SSE ←
   ```

3. **기술 선택 이유**
   - Rails: 성숙한 생태계, 빠른 개발, 강력한 ORM
   - FastAPI: Python AI 생태계, 비동기 성능, 타입 힌트
   - PostgreSQL: JSONB, 견고성, 확장성
   - Hotwire: SPA 복잡도 없이 실시간 UI

#### 실습 과제 1-1: 전체 흐름 추적
```ruby
# 1. 프롬프트 실행 요청 추적
# - browser console에서 네트워크 탭 열기
# - 프롬프트 실행 버튼 클릭
# - 다음 요청들 확인:
#   POST /api/prompts/execute
#   WS  /cable (ActionCable 연결)
#   GET /api/prompts/:id/status (폴링)

# 2. 로그 확인
# Rails 로그: request → job enqueue
# FastAPI 로그: /generate 요청 수신
# ActionCable 로그: 브로드캐스트

# 3. DB 확인
rails c
Prompt.last
Execution.last
Result.last.tokens_used
```

#### 면접 예상 질문
- Q: Rails와 FastAPI를 분리한 이유는?
- A: LLM 호출은 CPU 바운드가 아닌 I/O 바운드 작업으로, Python의 asyncio가 효율적입니다. 또한 AI/ML 생태계가 Python 중심이라 SDK 지원이 우수합니다. Rails는 비즈니스 로직과 웹 애플리케이션에 최적화되어 있어 역할을 분리했습니다.

---

### 2. Rails 백엔드 심화 (Week 2)

#### 학습 목표
- Rails 8의 새로운 기능 활용 (Solid Queue/Cable)
- Service Object 패턴 구현
- RESTful API 설계 원칙

#### Day 1-2: MVC + Service Layer

##### 핵심 파일 분석
```ruby
# app/controllers/api/prompts_controller.rb
class Api::PromptsController < ApplicationController
  def execute
    prompt = Prompt.create!(prompt_params)
    execution = prompt.executions.create!(
      iterations: params[:iterations],
      status: 'pending'
    )
    
    # Service Layer 활용
    LlmExecutionJob.perform_later(
      execution.id, 
      params[:streaming] == 'true'
    )
    
    render json: { 
      execution_id: execution.id, 
      status: 'started' 
    }
  end
end
```

##### Service Object 패턴 실습
```ruby
# app/services/prompt_execution_service.rb (신규 작성)
class PromptExecutionService
  attr_reader :prompt, :execution, :errors

  def initialize(prompt_params, execution_params)
    @prompt_params = prompt_params
    @execution_params = execution_params
    @errors = []
  end

  def execute
    ActiveRecord::Base.transaction do
      create_prompt
      create_execution
      enqueue_job
    end
    
    self
  rescue => e
    @errors << e.message
    self
  end

  def success?
    @errors.empty?
  end

  private

  def create_prompt
    @prompt = Prompt.create!(@prompt_params)
  end

  def create_execution
    @execution = @prompt.executions.create!(@execution_params)
  end

  def enqueue_job
    LlmExecutionJob.perform_later(@execution.id)
  end
end
```

#### Day 3-4: ActiveJob + Solid Queue

##### Job 구현 분석
```ruby
# app/jobs/llm_execution_job.rb 핵심 부분
class LlmExecutionJob < ApplicationJob
  queue_as :default
  
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 3
  
  def perform(execution_id, streaming = false)
    execution = Execution.find(execution_id)
    execution.update!(status: 'running', started_at: Time.current)
    
    execution.iterations.times do |i|
      if streaming
        stream_llm_response(execution, i + 1)
      else
        call_llm_service(execution, i + 1)
      end
    end
    
    execution.update!(status: 'completed', completed_at: Time.current)
  rescue => e
    execution.update!(status: 'failed')
    raise
  end
end
```

##### Solid Queue 설정 이해
```yaml
# config/queue.yml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 0.1
```

#### Day 5: ActionCable 실시간 통신

##### Channel 구현 분석
```ruby
# app/channels/prompt_channel.rb
class PromptChannel < ApplicationCable::Channel
  def subscribed
    execution = Execution.find(params[:execution_id])
    stream_for execution
  end

  def self.broadcast_chunk(execution, iteration, content)
    broadcast_to execution, {
      type: 'chunk',
      iteration: iteration,
      content: content
    }
  end
end
```

##### JavaScript 구독 구현
```javascript
// app/javascript/channels/prompt_channel.js
export function subscribeToExecution(executionId, handlers) {
  return consumer.subscriptions.create(
    { 
      channel: "PromptChannel", 
      execution_id: executionId 
    },
    {
      received(data) {
        switch(data.type) {
          case 'chunk':
            handlers.onChunk?.(data);
            break;
          case 'complete':
            handlers.onComplete?.(data);
            break;
          case 'error':
            handlers.onError?.(data);
            break;
        }
      }
    }
  );
}
```

#### 실습 과제 2-1: 새로운 API 엔드포인트 추가
```ruby
# 과제: 실행 취소 기능 구현
# 1. POST /api/prompts/:id/cancel 엔드포인트 추가
# 2. 실행 중인 Job 취소 로직 구현
# 3. ActionCable로 취소 알림 브로드캐스트
# 4. 테스트 코드 작성

# 힌트:
# - ActiveJob의 job_id 활용
# - Solid Queue의 Job 조회 API
# - execution.update!(status: 'cancelled')
```

#### 면접 대비 포인트
- Solid Queue vs Sidekiq 비교
- Service Object의 장단점
- ActionCable의 스케일링 전략
- RESTful API 설계 원칙

---

### 3. Python FastAPI + LLM 통합 (Week 3)

#### 학습 목표
- FastAPI 비동기 프로그래밍 마스터
- LLM SDK 통합 패턴 이해
- SSE (Server-Sent Events) 구현

#### Day 1-2: FastAPI 기초와 비동기

##### FastAPI 앱 구조 분석
```python
# lib/llm_api_server.py
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
import asyncio

app = FastAPI(title="LLM API Service")

@app.post("/generate")
async def generate(request: GenerateRequest):
    # 비동기 처리의 핵심
    llm = LLMFactory.create_llm(request.model_id)
    
    if request.stream:
        # SSE 스트리밍
        return StreamingResponse(
            stream_generator(),
            media_type="text/event-stream"
        )
    else:
        # 일반 응답
        response = await llm.generate(...)
        return GenerateResponse(...)
```

##### Pydantic 모델 활용
```python
# 요청/응답 검증
class GenerateRequest(BaseModel):
    model_id: str
    system_prompt: Optional[str] = ""
    user_prompt: str
    temperature: float = Field(ge=0, le=2, default=1.0)
    max_tokens: int = Field(ge=1, le=8192, default=2048)
    stream: bool = False

    @validator('model_id')
    def validate_model(cls, v):
        if not LLMFactory.is_valid_model(v):
            raise ValueError(f"Unknown model: {v}")
        return v
```

#### Day 3-4: LLM 프로바이더 통합

##### Factory 패턴 구현
```python
# lib/llm_services/llm_factory.py
class LLMFactory:
    @staticmethod
    def create_llm(model_id: str) -> BaseLLM:
        if model_id.startswith('gpt'):
            return OpenAILLM(model_id)
        elif model_id.startswith('claude'):
            return AnthropicLLM(model_id)
        elif model_id.startswith('gemini'):
            return GeminiLLM(model_id)
        else:
            raise ValueError(f"Unknown model: {model_id}")
```

##### 추상 베이스 클래스
```python
# lib/llm_services/base_llm.py
from abc import ABC, abstractmethod

class BaseLLM(ABC):
    @abstractmethod
    async def generate(self, **kwargs) -> LLMResponse:
        pass
    
    @abstractmethod
    async def stream_generate(self, **kwargs):
        pass
    
    @retry_with_exponential_backoff(max_retries=3)
    async def _make_api_call(self, func, **kwargs):
        """공통 재시도 로직"""
        return await func(**kwargs)
```

##### 프로바이더별 구현 예시
```python
# lib/llm_services/openai_llm.py
class OpenAILLM(BaseLLM):
    def __init__(self, model_id: str):
        self.client = AsyncOpenAI()
        self.model_id = model_id
    
    async def generate(self, **kwargs) -> LLMResponse:
        start_time = time.time()
        
        # GPT-5 시리즈 특별 처리
        if self.model_id.startswith('gpt-5'):
            # max_completion_tokens 사용
            kwargs.pop('temperature', None)
            kwargs.pop('top_p', None)
            kwargs['max_completion_tokens'] = kwargs.pop('max_tokens')
        
        response = await self.client.chat.completions.create(
            model=self.model_id,
            messages=self._format_messages(**kwargs),
            **kwargs
        )
        
        return LLMResponse(
            text=response.choices[0].message.content,
            tokens_used={
                'input': response.usage.prompt_tokens,
                'output': response.usage.completion_tokens
            },
            response_time_ms=int((time.time() - start_time) * 1000)
        )
```

#### Day 5: SSE 스트리밍 구현

##### 스트림 생성기
```python
async def stream_generate(self, **kwargs):
    """SSE 형식으로 스트리밍"""
    stream = await self.client.chat.completions.create(
        model=self.model_id,
        messages=self._format_messages(**kwargs),
        stream=True,
        **kwargs
    )
    
    async for chunk in stream:
        if chunk.choices[0].delta.content:
            yield f"data: {json.dumps({'text': chunk.choices[0].delta.content})}\n\n"
    
    yield f"data: {json.dumps({'done': True})}\n\n"
```

##### Rails에서 SSE 수신
```ruby
# app/jobs/llm_execution_job.rb
def stream_llm_response(execution, iteration)
  uri = URI("#{LLM_API_URL}/generate")
  
  Net::HTTP.start(uri.host, uri.port) do |http|
    request = Net::HTTP::Post.new(uri)
    request.body = { stream: true, ... }.to_json
    
    http.request(request) do |response|
      response.read_body do |chunk|
        # SSE 파싱
        if chunk.start_with?("data: ")
          data = JSON.parse(chunk[6..-1])
          
          if data['done']
            # 완료 처리
          else
            # 청크 브로드캐스트
            PromptChannel.broadcast_chunk(
              execution, iteration, data['text']
            )
          end
        end
      end
    end
  end
end
```

#### 실습 과제 3-1: 새로운 LLM 프로바이더 추가
```python
# 과제: Ollama (로컬 LLM) 지원 추가
# 1. lib/llm_services/ollama_llm.py 작성
# 2. LLMFactory에 ollama 모델 매핑 추가
# 3. 스트리밍 지원 구현
# 4. 환경 변수 OLLAMA_BASE_URL 지원

# 힌트:
# - httpx 라이브러리 사용
# - Ollama API: POST /api/generate
# - 스트림 응답 형식이 다름 (JSON lines)
```

#### 면접 대비 포인트
- asyncio vs threading 비교
- Factory 패턴의 장점
- SSE vs WebSocket 선택 기준
- 재시도 전략과 Circuit Breaker

---

### 4. 프론트엔드 Hotwire + 실시간 UI (Week 4)

#### 학습 목표
- Stimulus 컨트롤러 아키텍처 이해
- Turbo와 함께 SPA 수준 UX 구현
- ActionCable 실시간 통합

#### Day 1-2: Stimulus 컨트롤러 패턴

##### 기본 컨트롤러 구조
```javascript
// app/javascript/controllers/execute_controller.js
import { Controller } from "@hotwired/stimulus"
import { subscribeToExecution } from "../channels/prompt_channel"

export default class extends Controller {
  static targets = [
    "submitButton", "streamingOutput", 
    "resultCard", "progressBar"
  ]
  static values = {
    executionId: Number,
    streaming: Boolean
  }
  
  connect() {
    console.log("Execute controller connected")
    this.resetUI()
  }
  
  async execute(event) {
    event.preventDefault()
    
    const formData = new FormData(event.target)
    const response = await fetch('/api/prompts/execute', {
      method: 'POST',
      body: formData
    })
    
    const data = await response.json()
    this.executionIdValue = data.execution_id
    
    if (this.streamingValue) {
      this.startStreaming()
    } else {
      this.startPolling()
    }
  }
  
  startStreaming() {
    // UI 준비
    this.streamingOutputTarget.innerHTML = ''
    this.streamingOutputTarget.classList.remove('hidden')
    
    // ActionCable 구독
    this.subscription = subscribeToExecution(
      this.executionIdValue,
      {
        onChunk: this.handleChunk.bind(this),
        onComplete: this.handleComplete.bind(this),
        onError: this.handleError.bind(this)
      }
    )
  }
  
  handleChunk({ content, iteration }) {
    // 스트리밍 텍스트 추가
    const outputEl = this.streamingOutputTarget
    outputEl.insertAdjacentHTML('beforeend', content)
    
    // 자동 스크롤
    outputEl.scrollTop = outputEl.scrollHeight
  }
}
```

##### 파라미터 슬라이더 컨트롤러
```javascript
// app/javascript/controllers/parameter_slider_controller.js
export default class extends Controller {
  static targets = [
    "temperatureSlider", "temperatureValue",
    "maxTokensSlider", "maxTokensValue"
  ]
  
  connect() {
    this.updateAllValues()
  }
  
  updateTemperature(event) {
    const value = parseFloat(event.target.value)
    this.temperatureValueTarget.textContent = value.toFixed(1)
    
    // 실시간 프리뷰 (선택)
    this.previewEffect('temperature', value)
  }
  
  applyPreset(event) {
    const preset = event.target.dataset.preset
    const presets = {
      precise: { temperature: 0.2, top_p: 0.1 },
      balanced: { temperature: 1.0, top_p: 0.4 },
      creative: { temperature: 1.8, top_p: 0.9 }
    }
    
    const settings = presets[preset]
    this.applySettings(settings)
  }
}
```

#### Day 3-4: Turbo Integration

##### Turbo Frame 활용
```erb
<!-- app/views/playground/index.html.erb -->
<turbo-frame id="results-section">
  <div id="results-container">
    <% @recent_executions.each do |execution| %>
      <%= render 'result_card', execution: execution %>
    <% end %>
  </div>
</turbo-frame>

<!-- Turbo Stream 업데이트 -->
<turbo-stream action="append" target="results-container">
  <template>
    <%= render 'result_card', execution: @execution %>
  </template>
</turbo-stream>
```

##### Turbo와 Stimulus 연동
```javascript
// 결과 비교 모달
export default class extends Controller {
  static targets = ["modal", "comparison"]
  
  async compare(event) {
    const resultIds = this.getSelectedResults()
    
    // Turbo로 모달 콘텐츠 로드
    const response = await fetch(
      `/api/prompts/compare?ids=${resultIds.join(',')}`
    )
    const html = await response.text()
    
    this.comparisonTarget.innerHTML = html
    this.modalTarget.showModal()
  }
}
```

#### Day 5: UI/UX 최적화

##### 다크모드 지원
```javascript
// app/javascript/controllers/theme_controller.js
export default class extends Controller {
  static values = { current: String }
  static targets = ["icon"]
  
  connect() {
    // 시스템 설정 감지
    if (!this.currentValue) {
      const prefersDark = window.matchMedia(
        '(prefers-color-scheme: dark)'
      ).matches
      this.currentValue = prefersDark ? 'dark' : 'light'
    }
    
    this.applyTheme()
  }
  
  toggle() {
    this.currentValue = 
      this.currentValue === 'dark' ? 'light' : 'dark'
    this.applyTheme()
    
    // 로컬 스토리지 저장
    localStorage.setItem('theme', this.currentValue)
  }
  
  applyTheme() {
    document.documentElement.classList.toggle(
      'dark',
      this.currentValue === 'dark'
    )
    
    // 아이콘 업데이트
    this.updateIcon()
  }
}
```

##### 로딩 상태 관리
```javascript
// 통합 로딩 관리
export default class extends Controller {
  static targets = ["spinner", "content"]
  
  showLoading() {
    this.spinnerTarget.classList.remove('hidden')
    this.contentTarget.classList.add('opacity-50')
  }
  
  hideLoading() {
    this.spinnerTarget.classList.add('hidden')
    this.contentTarget.classList.remove('opacity-50')
  }
  
  withLoading(asyncFn) {
    return async (...args) => {
      this.showLoading()
      try {
        return await asyncFn(...args)
      } finally {
        this.hideLoading()
      }
    }
  }
}
```

#### 실습 과제 4-1: 고급 UI 기능 구현
```javascript
// 과제: 실시간 타이핑 효과 구현
// 1. 스트리밍 텍스트를 문자 단위로 표시
// 2. 타이핑 속도 조절 가능
// 3. 일시정지/재개 기능
// 4. 코드 블록 syntax highlighting

// 힌트:
// - requestAnimationFrame 활용
// - Prism.js 또는 highlight.js 통합
// - IntersectionObserver로 가시영역 최적화
```

#### 면접 대비 포인트
- Stimulus vs React/Vue 비교
- Turbo의 장단점
- WebSocket 연결 관리 전략
- 프론트엔드 성능 최적화 기법

---

### 5. 테스트 + 보안 + 성능 최적화 (Week 5)

#### 학습 목표
- TDD로 안정적인 코드 작성
- 보안 취약점 해결
- 성능 병목 현상 분석과 개선

#### Day 1-2: 테스트 전략

##### Rails 테스트 (Minitest)
```ruby
# test/services/llm_models_service_test.rb
class LlmModelsServiceTest < ActiveSupport::TestCase
  test "returns all configured models" do
    models = LlmModelsService.all_models
    
    assert_equal 9, models.count
    assert models.any? { |m| m[:id] == 'gpt-4o' }
  end
  
  test "calculates cost correctly" do
    cost = LlmModelsService.calculate_cost(
      'gpt-4o',
      input_tokens: 1000,
      output_tokens: 500
    )
    
    # Input: 1000 * $2.50/1M = $0.0025
    # Output: 500 * $10.00/1M = $0.005
    assert_equal 0.0075, cost
  end
  
  test "filters by available API keys" do
    # Mock 환경 변수
    ENV.stub(:[], nil) do
      ENV.stub(:[], 'sk-test').with('OPENAI_API_KEY') do
        available = LlmModelsService.available_models
        
        assert available.all? { |m| m[:provider] == 'openai' }
      end
    end
  end
end
```

##### Python 테스트 (pytest)
```python
# tests/test_llm_factory.py
import pytest
from unittest.mock import Mock, patch
from llm_services.llm_factory import LLMFactory

@pytest.fixture
def mock_env():
    with patch.dict('os.environ', {
        'OPENAI_API_KEY': 'sk-test',
        'ANTHROPIC_API_KEY': 'sk-ant-test'
    }):
        yield

class TestLLMFactory:
    def test_create_openai_llm(self, mock_env):
        llm = LLMFactory.create_llm('gpt-4o')
        assert llm.__class__.__name__ == 'OpenAILLM'
    
    def test_unknown_model_raises_error(self):
        with pytest.raises(ValueError, match="Unknown model"):
            LLMFactory.create_llm('unknown-model')
    
    @pytest.mark.asyncio
    async def test_retry_mechanism(self, mock_env):
        # 재시도 로직 테스트
        llm = LLMFactory.create_llm('gpt-4o')
        
        with patch.object(llm.client.chat.completions, 'create') as mock:
            # 첫 2번 실패, 3번째 성공
            mock.side_effect = [
                Exception("API Error"),
                Exception("API Error"),
                Mock(choices=[Mock(message=Mock(content="Success"))])
            ]
            
            response = await llm.generate(
                system_prompt="test",
                user_prompt="test"
            )
            
            assert response.text == "Success"
            assert mock.call_count == 3
```

##### 통합 테스트
```ruby
# test/integration/llm_execution_flow_test.rb
class LlmExecutionFlowTest < ActionDispatch::IntegrationTest
  test "complete execution flow with streaming" do
    # 1. 프롬프트 실행 요청
    post api_prompts_execute_path, params: {
      user_prompt: "Hello",
      selected_model: "gpt-4o-mini",
      streaming: true,
      iterations: 1
    }
    
    assert_response :success
    execution_id = JSON.parse(response.body)['execution_id']
    
    # 2. Job 실행
    perform_enqueued_jobs
    
    # 3. 결과 확인
    get api_prompts_status_path(execution_id)
    data = JSON.parse(response.body)
    
    assert_equal 'completed', data['execution']['status']
    assert_equal 1, data['results'].count
  end
end
```

#### Day 3-4: 보안 강화

##### API 키 관리
```ruby
# config/initializers/security.rb
Rails.application.config.before_initialize do
  # API 키 검증
  required_keys = %w[
    OPENAI_API_KEY 
    ANTHROPIC_API_KEY 
    GOOGLE_GEMINI_API_KEY
  ]
  
  missing_keys = required_keys.select { |key| ENV[key].blank? }
  
  if missing_keys.any? && Rails.env.production?
    raise "Missing API keys: #{missing_keys.join(', ')}"
  end
end

# 키 노출 방지
class ApiKeyFilter
  PATTERNS = [
    /sk-[a-zA-Z0-9]{48}/,           # OpenAI
    /sk-ant-[a-zA-Z0-9]{50}/,       # Anthropic  
    /AIza[a-zA-Z0-9]{35}/           # Google
  ]
  
  def self.filter(text)
    PATTERNS.each do |pattern|
      text = text.gsub(pattern, '[REDACTED]')
    end
    text
  end
end
```

##### CORS 및 CSP 설정
```python
# lib/llm_api_server.py
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "https://yourdomain.com"  # 프로덕션
    ],
    allow_credentials=True,
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
    max_age=3600  # preflight 캐싱
)

# 호스트 검증
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["localhost", "*.yourdomain.com"]
)
```

##### 입력 검증 및 Sanitization
```ruby
# app/models/prompt.rb
class Prompt < ApplicationRecord
  # XSS 방지
  validates :user_prompt, 
    presence: true,
    length: { maximum: 10_000 }
    
  validates :system_prompt,
    length: { maximum: 5_000 },
    allow_blank: true
    
  # 악성 패턴 감지
  validate :no_injection_attempts
  
  private
  
  def no_injection_attempts
    suspicious_patterns = [
      /ignore previous instructions/i,
      /<script/i,
      /DROP TABLE/i
    ]
    
    if suspicious_patterns.any? { |p| user_prompt&.match?(p) }
      errors.add(:user_prompt, "contains suspicious content")
    end
  end
end
```

#### Day 5: 성능 최적화

##### 데이터베이스 최적화
```ruby
# db/migrate/add_indexes_for_performance.rb
class AddIndexesForPerformance < ActiveRecord::Migration[8.0]
  def change
    # 기본 인덱스
    add_index :executions, :prompt_id
    add_index :executions, :status
    add_index :results, [:execution_id, :iteration_number], 
              unique: true
    
    # 부분 인덱스 (PostgreSQL)
    add_index :prompts, :created_at, order: { created_at: :desc }
    
    # JSONB 인덱스
    execute <<-SQL
      CREATE INDEX idx_prompts_model 
      ON prompts((parameters->>'selected_model'));
    SQL
  end
end
```

##### 캐싱 전략
```ruby
# app/controllers/api/models_controller.rb
class Api::ModelsController < ApplicationController
  def index
    # HTTP 캐싱
    expires_in 1.hour, public: true
    
    # Rails 캐싱
    @models = Rails.cache.fetch('llm_models', expires_in: 1.hour) do
      LlmModelsService.all_models
    end
    
    render json: { models: @models }
  end
end

# Solid Cache 설정
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

##### 비동기 최적화
```python
# lib/llm_services/batch_processor.py
import asyncio
from typing import List

class BatchProcessor:
    def __init__(self, max_concurrent: int = 5):
        self.semaphore = asyncio.Semaphore(max_concurrent)
    
    async def process_batch(self, requests: List[GenerateRequest]):
        """동시 실행 제한을 두고 배치 처리"""
        async def process_with_limit(request):
            async with self.semaphore:
                llm = LLMFactory.create_llm(request.model_id)
                return await llm.generate(**request.dict())
        
        tasks = [process_with_limit(req) for req in requests]
        return await asyncio.gather(*tasks, return_exceptions=True)
```

#### 실습 과제 5-1: 성능 프로파일링
```ruby
# 과제: 병목 현상 분석 및 개선
# 1. rack-mini-profiler 설정
# 2. bullet gem으로 N+1 쿼리 감지
# 3. 느린 쿼리 분석 (EXPLAIN ANALYZE)
# 4. 메모리 사용량 최적화

# 힌트:
# - includes/preload 사용
# - 배치 처리로 DB 호출 최소화
# - 적절한 인덱스 추가
```

#### 면접 대비 포인트
- 테스트 피라미드 (단위/통합/E2E)
- OWASP Top 10 보안 취약점
- 성능 병목 현상 분석 방법
- 캐싱 전략과 트레이드오프

### 6. 배포 + 모니터링 + 포트폴리오 완성 (Week 6)

#### 학습 목표
- 프로덕션 환경 배포
- 모니터링 시스템 구축
- 취업용 포트폴리오 준비

#### Day 1-2: 컨테이너화와 배포

##### Docker 설정
```dockerfile
# Dockerfile.rails
FROM ruby:3.3.0-slim

# 필수 패키지
RUN apt-get update -qq && apt-get install -y \
  postgresql-client \
  nodejs \
  build-essential \
  libpq-dev \
  git

WORKDIR /app

# 의존성 캐싱
COPY Gemfile Gemfile.lock ./
RUN bundle install

# 앱 코드
COPY . .

# Assets 컴파일
RUN bundle exec rails assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

```dockerfile
# Dockerfile.python
FROM python:3.11-slim

WORKDIR /app

# 의존성 캐싱
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 코드
COPY lib/ ./lib/

EXPOSE 8000
CMD ["uvicorn", "lib.llm_api_server:app", "--host", "0.0.0.0", "--port", "8000"]
```

##### Docker Compose
```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    
  rails:
    build:
      context: .
      dockerfile: Dockerfile.rails
    depends_on:
      - postgres
      - redis
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres/llm_playground
      REDIS_URL: redis://redis:6379/1
    env_file: .env
    ports:
      - "3000:3000"
    command: >
      bash -c "rails db:prepare &&
               bundle exec rails server -b 0.0.0.0"
  
  python:
    build:
      context: .
      dockerfile: Dockerfile.python
    env_file: .env
    ports:
      - "8000:8000"
  
  worker:
    build:
      context: .
      dockerfile: Dockerfile.rails
    depends_on:
      - postgres
      - redis
      - python
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres/llm_playground
      REDIS_URL: redis://redis:6379/1
      LLM_API_URL: http://python:8000
    env_file: .env
    command: bundle exec rails solid_queue:start

volumes:
  postgres_data:
```

#### Day 3-4: Kamal로 배포

##### Kamal 설정
```yaml
# config/deploy.yml
service: llm-playground
image: yourusername/llm-playground

servers:
  web:
    - your-server.com
  job:
    hosts:
      - your-server.com
    cmd: bundle exec rails solid_queue:start

proxy:
  ssl: true
  host: llm-playground.com

registry:
  username: yourusername
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    DATABASE_URL: postgresql://user:pass@db-server/llm_playground
    RAILS_SERVE_STATIC_FILES: true
    RAILS_LOG_TO_STDOUT: true
  secret:
    - RAILS_MASTER_KEY
    - OPENAI_API_KEY
    - ANTHROPIC_API_KEY
    - GOOGLE_GEMINI_API_KEY

accessories:
  python:
    image: yourusername/llm-playground-python
    host: your-server.com
    port: 8000
    env:
      secret:
        - OPENAI_API_KEY
        - ANTHROPIC_API_KEY
        - GOOGLE_GEMINI_API_KEY
```

##### 배포 스크립트
```bash
#!/bin/bash
# deploy.sh

# 1. 테스트 실행
echo "Running tests..."
rails test
pytest

# 2. 이미지 빌드
echo "Building images..."
docker build -f Dockerfile.rails -t llm-playground:latest .
docker build -f Dockerfile.python -t llm-playground-python:latest .

# 3. Kamal 배포
echo "Deploying with Kamal..."
kamal deploy

# 4. 헬스체크
echo "Running health checks..."
curl https://llm-playground.com/up
curl https://llm-playground.com:8000/health
```

#### Day 5: 모니터링 및 로그

##### 애플리케이션 모니터링
```ruby
# config/initializers/monitoring.rb
require 'prometheus/client'

# Prometheus 메트릭
prometheus = Prometheus::Client.registry

# 커스텀 메트릭
LLM_REQUEST_COUNTER = prometheus.counter(
  :llm_requests_total,
  docstring: 'Total LLM API requests',
  labels: [:model, :status]
)

LLM_RESPONSE_TIME = prometheus.histogram(
  :llm_response_duration_seconds,
  docstring: 'LLM response time',
  labels: [:model],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 30, 60]
)

TOKEN_USAGE = prometheus.counter(
  :llm_tokens_total,
  docstring: 'Total tokens used',
  labels: [:model, :type]
)
```

##### 사용량 추적
```ruby
# app/services/usage_tracking_service.rb
class UsageTrackingService
  def self.track_request(execution, result)
    # Prometheus 메트릭
    LLM_REQUEST_COUNTER.increment(
      labels: {
        model: execution.prompt.selected_model,
        status: result.status
      }
    )
    
    LLM_RESPONSE_TIME.observe(
      result.response_time_ms / 1000.0,
      labels: { model: execution.prompt.selected_model }
    )
    
    # 토큰 사용량
    TOKEN_USAGE.increment(
      by: result.input_tokens,
      labels: { 
        model: execution.prompt.selected_model,
        type: 'input'
      }
    )
    
    # 비용 계산 및 저장
    cost = LlmModelsService.calculate_cost(
      execution.prompt.selected_model,
      input_tokens: result.input_tokens,
      output_tokens: result.output_tokens
    )
    
    DailyCost.increment_for_today(cost)
  end
end
```

##### 로그 집계
```python
# lib/llm_services/logging_config.py
import logging
import json
from pythonjsonlogger import jsonlogger

# JSON 형식 로그
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)

logger = logging.getLogger()
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# 구조화된 로그
def log_llm_request(model_id, tokens, response_time):
    logger.info(
        "llm_request",
        extra={
            "model_id": model_id,
            "tokens": tokens,
            "response_time_ms": response_time,
            "timestamp": datetime.utcnow().isoformat()
        }
    )
```

#### 포트폴리오 준비

##### README 업데이트
```markdown
# LLM API Playground

## 프로젝트 개요
여러 LLM 프로바이더(OpenAI, Anthropic, Google)를 통합하여 
실시간 스트리밍과 파라미터 조절이 가능한 테스트 플레이그라운드

## 기술 특징
- **마이크로서비스 아키텍처**: Rails + FastAPI
- **실시간 스트리밍**: SSE + ActionCable
- **비동기 처리**: Active Job + asyncio
- **현대적 UI**: Hotwire (Turbo + Stimulus)

## 성과
- 평균 응답 시간: < 100ms (UI 업데이트)
- 동시 처리: 50+ concurrent requests
- 가용성: 99.9% uptime

## 시연 영상
[Demo Link](https://your-demo-link.com)

## 설치 및 실행
...
```

##### 기술 블로그 포스트
```markdown
# Rails 8 + FastAPI로 LLM Playground 만들기

## 도입 배경
최근 AI/LLM 기술의 발전으로...

## 아키텍처 선택 이유
### Rails를 선택한 이유
- 빠른 프로토타이핑
- 강력한 ORM (Active Record)
- 내장된 보안 기능

### FastAPI를 선택한 이유
- Python AI/ML 생태계
- 비동기 성능
- 타입 힌트 지원

## 구현 과정
...

## 학습 포인트
- SSE와 WebSocket의 차이
- 비동기 프로그래밍의 중요성
- 마이크로서비스 통신

## 성과 및 개선점
...
```

#### 실습 과제 6-1: CI/CD 파이프라인
```yaml
# 과제: GitHub Actions CI/CD 구성
# .github/workflows/deploy.yml
# 
# 요구사항:
# 1. 테스트 자동화 (Rails + Python)
# 2. Docker 이미지 빌드
# 3. 보안 스캐닝
# 4. Kamal 배포
# 5. Slack 알림

# 힌트:
# - matrix 전략으로 병렬 테스트
# - Docker layer 캐싱
# - secrets 관리
```

#### 면접 대비 포인트
- 컨테이너 오케스트레이션
- 무중단 배포 전략
- 모니터링 지표 선정
- 사고 대응 프로세스

---

### 추가 학습 자료

#### 도서 추천
- 「The Rails 8 Way」 - Rails 심화
- 「FastAPI를 사용한 파이썬 웹 개발」 - FastAPI 전문
- 「Site Reliability Engineering」 - SRE 실무

#### 온라인 코스
- [Rails Performance Masterclass](https://example.com)
- [Advanced FastAPI Patterns](https://example.com)
- [Real-time Web Applications](https://example.com)

#### 커뮤니티
- Rails Korea
- Python Korea
- FastAPI Discord

---

### 최종 체크리스트

- [ ] 환경 설정 완료
- [ ] 전체 아키텍처 이해
- [ ] Rails 백엔드 구현
- [ ] FastAPI 서버 구현
- [ ] 프론트엔드 완성
- [ ] 테스트 코드 작성
- [ ] 보안 점검 완료
- [ ] 성능 최적화 적용
- [ ] 배포 환경 구성
- [ ] 모니터링 설정
- [ ] 문서화 완료
- [ ] 포트폴리오 준비

이 가이드를 완료하면 실무에서 즉시 활용 가능한 풀스택 + Python 서버 개발 역량을 갖추게 됩니다. 각 주차별 학습을 충실히 수행하고, 실습 과제를 통해 실전 경험을 쌓으세요. 화이팅! 🚀


