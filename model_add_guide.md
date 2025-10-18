# LLM 모델 추가 가이드

이 문서는 LLM API Playground에 새로운 LLM 모델을 추가하는 방법을 단계별로 설명합니다.

---

## 📋 목차

1. [개요](#개요)
2. [필수 수정 파일](#필수-수정-파일)
3. [단계별 가이드](#단계별-가이드)
4. [예시: Claude Sonnet 4.5 추가](#예시-claude-sonnet-45-추가)
5. [체크리스트](#체크리스트)
6. [문제 해결](#문제-해결)

---

## 개요

새로운 LLM 모델을 추가하려면 **4개의 파일**을 수정해야 합니다:

1. **Rails 모델 정의** (`app/services/llm_models_service.rb`)
2. **Python LLM 구현** (`lib/llm_services/[provider]_llm.py`)
3. **코드 생성 서비스** (`app/services/code_generator_service.rb`)
4. **프론트엔드 UI** (`app/views/playground/index.html.erb`)

---

## 필수 수정 파일

### 파일 구조

```
LLM_Play/
├── app/
│   ├── services/
│   │   ├── llm_models_service.rb          # ① Rails 모델 정의
│   │   └── code_generator_service.rb      # ③ 코드 생성 매핑
│   └── views/
│       └── playground/
│           └── index.html.erb             # ④ 프론트엔드 UI
└── lib/
    └── llm_services/
        ├── openai_llm.py                  # ② OpenAI 모델용
        ├── anthropic_llm.py               # ② Anthropic 모델용
        └── gemini_llm.py                  # ② Google 모델용
```

---

## 단계별 가이드

### Step 1: Rails 모델 정의 추가

**파일**: `app/services/llm_models_service.rb`

**위치**: `MODELS` 해시 내부, 같은 provider 모델들과 함께 그룹화

**추가할 정보**:

```ruby
'your-model-id' => {
  provider: 'anthropic',    # 제공자 선택
  display_name: 'Claude Haiku4.5-$1.00/$5.00',      # 드롭다운에 표시될 이름
  icon: '🔷',                              # 이모지 아이콘
  characteristics: 'Fast & Efficiend',    # 특징 (예: 'Fast & Efficient')
  pricing: {
    input: 1.00,                           # 입력 토큰 가격 (per 1M tokens)
    output: 5.00,                          # 출력 토큰 가격 (per 1M tokens)
    display: '$1.00/$5.00'                 # 표시용 문자열
  },
  max_tokens: 4096,                        # 최대 출력 토큰 수
  context_window: 128000,                  # 컨텍스트 윈도우 크기
  supports_streaming: true                 # 스트리밍 지원 여부
}
```

**특수 파라미터** (선택사항):

```ruby
# GPT-5 같은 reasoning 모델의 경우
min_tokens: 2000,                          # 최소 토큰 요구사항
parameters: {
  reasoning_effort: ['minimal', 'low', 'medium', 'high'],
  verbosity: ['low', 'medium', 'high']
}
```

**예시 위치**:

```ruby
MODELS = {
  # ... 기존 모델들 ...

  'claude-sonnet-4-5-20250929' => { ... },   # 기존 Anthropic 마지막 모델

  # ✅ 여기에 새 Anthropic 모델 추가
  'claude-haiku-4-5-20251001' => {
    provider: 'anthropic',
    display_name: 'Claude haiku 4.5',
    # ...
  },

  'gemini-2.5-flash' => { ... }            # 다음 provider 시작
}
```

---

### Step 2: Python LLM 구현 업데이트

**파일**: Provider에 따라 선택
- OpenAI: `lib/llm_services/openai_llm.py`
- Anthropic: `lib/llm_services/anthropic_llm.py`
- Google: `lib/llm_services/gemini_llm.py`

#### 2-1. Anthropic 모델 추가

**위치**: `__init__` 메서드의 `model_mapping` 딕셔너리

```python
class AnthropicLLM(BaseLLM):
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        self.client = AsyncAnthropic(api_key=api_key)

        self.model_mapping = {
            'claude-3-5-haiku-20241022': 'claude-3-5-haiku-20241022',
            'claude-sonnet-4-20250514': 'claude-sonnet-4-20250514',
            'claude-opus-4-1-20250805': 'claude-opus-4-1-20250805',
            'claude-sonnet-4-5-20250929': 'claude-sonnet-4-5-20250929',
            # ✅ 여기에 추가
            'claude-haiku-4-5-20251001': 'claude-haiku-4-5-20251001'
        }
```

#### 2-2. OpenAI 모델 추가

**위치**: `__init__` 메서드의 `model_mapping` 딕셔너리

```python
class OpenAILLM(BaseLLM):
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        self.client = AsyncOpenAI(api_key=api_key)

        self.model_mapping = {
            'gpt-4o-mini': 'gpt-4o-mini',
            'gpt-4o': 'gpt-4o',
            # ✅ 여기에 추가
            'gpt-4.5': 'gpt-4.5-turbo-2025-01-15'
        }

        # Reasoning 모델인 경우 (temperature/top_p 미지원)
        self.reasoning_models = {'gpt-5', 'gpt-5-mini', 'gpt-4.5'}
```

#### 2-3. Google 모델 추가

**위치**: `__init__` 메서드의 `model_mapping` 딕셔너리

```python
class GeminiLLM(BaseLLM):
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        genai.configure(api_key=api_key)

        self.model_mapping = {
            'gemini-2.5-flash': 'gemini-2.5-flash',
            'gemini-2.5-pro': 'gemini-2.5-pro',
            # ✅ 여기에 추가
            'gemini-3.0-ultra': 'gemini-3.0-ultra'
        }
```

---

### Step 3: 코드 생성 서비스 업데이트

**파일**: `app/services/code_generator_service.rb`

**위치**: Provider별 매핑 메서드

#### 3-1. Anthropic 모델 매핑

**메서드**: `map_anthropic_model` (Line 390-402)

```ruby
def self.map_anthropic_model(model)
  case model
  when 'claude-3-5-haiku-20241022'
    'claude-3-5-haiku-20241022'
  when 'claude-sonnet-4-20250514'
    'claude-sonnet-4-20250514'
  when 'claude-opus-4-1-20250805'
    'claude-opus-4-1-20250805'
  # ✅ 여기에 추가
  when 'claude-sonnet-4-5-20250929'
    'claude-sonnet-4-5-20250929'
  when 'claude-haiku-4-5-20251001'
    'claude-haiku-4-5-20251001'
    else
    model
  end
end
```

#### 3-2. OpenAI 모델 매핑

OpenAI는 별도 매핑 메서드가 없으며, `generate_openai_python` 메서드에서 모델명을 직접 사용합니다.

**특수 처리 필요 시**:

```ruby
def self.generate_openai_python(prompt, result)
  # GPT-5 계열 체크
  is_gpt5 = prompt.selected_model.start_with?('gpt-5')

  # ✅ GPT-4.5가 reasoning 모델이면 추가
  is_reasoning = is_gpt5 || prompt.selected_model == 'gpt-4.5'

  if is_reasoning
    # max_completion_tokens 사용, temperature/top_p 제외
  else
    # 일반 파라미터 사용
  end
end
```

#### 3-3. Google 모델 매핑

**메서드**: `map_gemini_model` (Line 404-414)

```ruby
def self.map_gemini_model(model)
  case model
  when 'gemini-2.5-flash'
    'gemini-2.5-flash'
  when 'gemini-2.5-pro'
    'gemini-2.5-pro'
  # ✅ 여기에 추가
  when 'gemini-3.0-ultra'
    'gemini-3.0-ultra'
  else
    model
  end
end
```

---

### Step 4: 프론트엔드 Hyperparameter 정보 추가

**파일**: `app/views/playground/index.html.erb`

**위치**: Hyperparameter 모달의 Provider별 테이블 (Line 792-877)

#### 4-1. Anthropic 섹션에 추가

**위치**: Line 809-831 (Anthropic 테이블 tbody 내부)

```html
<!-- Anthropic (Claude) Section -->
<tbody class="divide-y divide-gray-100">
  <tr class="hover:bg-purple-50 transition-colors">
    <td class="px-4 py-3 font-medium text-gray-800">Claude 3.5 Haiku</td>
    <td class="px-4 py-3 text-gray-600">8,192</td>
    <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
    <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
    <td class="px-4 py-3 text-gray-600">All parameters supported</td>
  </tr>
  <!-- ... 기존 모델들 ... -->

  <!-- ✅ 여기에 새 행 추가 -->
  <tr class="hover:bg-purple-50 transition-colors">
    <td class="px-4 py-3 font-medium text-gray-800">Claude Sonnet 4.5</td>
    <td class="px-4 py-3 text-gray-600">8,192</td>
    <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
    <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
    <td class="px-4 py-3 text-gray-600">All parameters supported</td>
  </tr>
</tbody>
```

#### 4-2. OpenAI 섹션에 추가

**위치**: Line 729-789 (OpenAI 테이블 tbody 내부)

```html
<tr class="hover:bg-blue-50 transition-colors">
  <td class="px-4 py-3 font-medium text-gray-800">GPT-4.5</td>
  <td class="px-4 py-3 text-gray-600">16,384</td>
  <td class="px-4 py-3 text-gray-600">0.0–2.0</td>
  <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
  <td class="px-4 py-3 text-gray-600">—</td>
  <td class="px-4 py-3 text-gray-600">All parameters supported</td>
</tr>
```

**Reasoning 모델인 경우** (GPT-5 스타일):

```html
<tr class="hover:bg-yellow-50 transition-colors">
  <td class="px-4 py-3 font-medium text-gray-800">
    GPT-4.5 <span class="text-xs bg-yellow-100 text-yellow-700 px-2 py-1 rounded">REASONING</span>
  </td>
  <td class="px-4 py-3 text-gray-600">
    <div>Input: 272K</div>
    <div>Output: 128K</div>
  </td>
  <td class="px-4 py-3 text-gray-400">Not supported</td>
  <td class="px-4 py-3 text-gray-400">Not supported</td>
  <td class="px-4 py-3 text-gray-600">
    <div class="text-xs">
      <div><code class="bg-gray-100 px-1 rounded">reasoning.effort</code>: minimal/low/medium/high</div>
    </div>
  </td>
  <td class="px-4 py-3 text-gray-600">
    <span class="text-xs bg-orange-100 text-orange-700 px-2 py-1 rounded">Min 2000 tokens</span>
  </td>
</tr>
```

#### 4-3. Google 섹션에 추가

**위치**: Line 853-876 (Gemini 테이블 tbody 내부)

```html
<tr class="hover:bg-blue-50 transition-colors">
  <td class="px-4 py-3 font-medium text-gray-800">Gemini 3.0 Ultra</td>
  <td class="px-4 py-3 text-gray-600">8,192–65,536</td>
  <td class="px-4 py-3 text-gray-600">0.0–2.0</td>
  <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
  <td class="px-4 py-3 text-gray-600">
    <code class="bg-gray-100 px-1 rounded text-xs">thinking_budget</code>
  </td>
  <td class="px-4 py-3 text-gray-600">All parameters supported</td>
</tr>
```

---

## 예시: Claude Sonnet 4.5 추가

### 요구사항

- **Display Name**: Claude haiku 4.5
- **Model ID**: `claude-haiku-4-5-20251001`
- **API Model Name**: `claude-haiku-4-5-20251001`
- **Pricing**: $1.00 (input) / $5.00 (output)
- **Max Tokens**: 8,192
- **Context Window**: 200K
- **위치**: Anthropic 모델 섹션 마지막

### 실제 코드

#### 1. `llm_models_service.rb` (Line 31 이후)

```ruby
'claude-sonnet-4-5-20250929' => {
  provider: 'anthropic',
  display_name: 'Claude Sonnet 4.5',
  icon: '⚡',
  characteristics: 'Ultra-Fast & Smart',
  pricing: {
    input: 3.00,
    output: 15.00,
    display: '$3.00/$15.00'
  },
  max_tokens: 8192,
  context_window: 200000,
  supports_streaming: true
},
# ✅ 새 모델 추가
'claude-Haiku-4-5' => {
  provider: 'anthropic',
  display_name: 'Claude Sonnet 4.5',
  icon: '⚡',
  characteristics: 'Ultra-Fast & Smart',
  pricing: {
    input: 3.00,
    output: 15.00,
    display: '$3.00/$15.00'
  },
  max_tokens: 8192,
  context_window: 200000,
  supports_streaming: true
},
'gemini-2.5-flash' => {
  # 다음 provider 시작
```



#### 2. `anthropic_llm.py` (Line 20)

```python
self.model_mapping = {
    'claude-3-5-haiku-20241022': 'claude-3-5-haiku-20241022',
    'claude-sonnet-4-20250514': 'claude-sonnet-4-20250514',
    'claude-opus-4-1-20250805': 'claude-opus-4-1-20250805',
    'claude-sonnet-4-5-20250929': 'claude-sonnet-4-5-20250929'  # ✅ 추가
}
```

#### 3. `code_generator_service.rb` (Line 397)

```ruby
def self.map_anthropic_model(model)
  case model
  when 'claude-3-5-haiku-20241022'
    'claude-3-5-haiku-20241022'
  when 'claude-sonnet-4-20250514'
    'claude-sonnet-4-20250514'
  when 'claude-opus-4-1-20250805'
    'claude-opus-4-1-20250805'
  when 'claude-sonnet-4-5-20250929'           # ✅ 추가
    'claude-sonnet-4-5-20250929'
  else
    model
  end
end
```

#### 4. `index.html.erb` (Line 829)

```html
<tr class="hover:bg-purple-50 transition-colors">
  <td class="px-4 py-3 font-medium text-gray-800">Claude Opus 4.1</td>
  <td class="px-4 py-3 text-gray-600">32,000</td>
  <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
  <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
  <td class="px-4 py-3 text-gray-600">All parameters supported</td>
</tr>
<!-- ✅ 새 행 추가 -->
<tr class="hover:bg-purple-50 transition-colors">
  <td class="px-4 py-3 font-medium text-gray-800">Claude Sonnet 4.5</td>
  <td class="px-4 py-3 text-gray-600">8,192</td>
  <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
  <td class="px-4 py-3 text-gray-600">0.0–1.0</td>
  <td class="px-4 py-3 text-gray-600">All parameters supported</td>
</tr>
```

---

## 체크리스트

모델 추가 후 다음 사항을 확인하세요:

### ✅ Rails 서버

```bash
# 서버 재시작
rails server

# 또는 bin/dev 사용 시
bin/dev
```

**확인 사항**:
- [ ] 모델이 드롭다운에 표시되는가?
- [ ] 가격 정보가 올바른가?
- [ ] API 키가 있으면 선택 가능한가?

### ✅ Python 서버

```bash
# 서버 재시작
source venv/bin/activate
python lib/llm_api_server.py
```

**확인 사항**:
- [ ] `GET /models` 엔드포인트에 모델이 포함되는가?
- [ ] 모델 ID가 올바르게 매핑되는가?

### ✅ 기능 테스트

1. **모델 선택**
   - [ ] 드롭다운에서 새 모델 선택 가능
   - [ ] 가격과 아이콘이 올바르게 표시

2. **프롬프트 실행**
   - [ ] Execute 버튼 클릭 시 정상 작동
   - [ ] 결과가 올바르게 반환됨
   - [ ] 토큰 사용량 표시 정확

3. **코드 생성**
   - [ ] "Get Code" 버튼 클릭
   - [ ] Python 코드에 올바른 모델명 포함
   - [ ] JavaScript 코드 정상 생성
   - [ ] cURL 코드 정상 생성

4. **Hyperparameter 모달**
   - [ ] ⚙️ Hyperparameter Info 버튼 클릭
   - [ ] 해당 provider 섹션에 모델 정보 표시
   - [ ] 파라미터 범위 정보 정확

### ✅ API 테스트

```bash
# Rails API 테스트
curl http://localhost:3000/api/models

# Python API 테스트
curl http://localhost:8000/models

# 실제 프롬프트 실행 테스트
curl -X POST http://localhost:3000/api/prompts/execute \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: YOUR_TOKEN" \
  -d '{
    "prompt": {
      "system_prompt": "You are a helpful assistant",
      "user_prompt": "Say hello",
      "selected_model": "claude-sonnet-4-5-20250929",
      "parameters": {
        "temperature": 0.7,
        "max_tokens": 100,
        "top_p": 1.0
      }
    },
    "iterations": 1
  }'
```

---

## 문제 해결

### 1. 모델이 드롭다운에 표시되지 않음

**원인**: Rails 서버가 재시작되지 않음

**해결**:
```bash
# 서버 재시작
rails server
# 또는
bin/dev
```

### 2. "API key required" 메시지 표시

**원인**: `.env` 파일에 해당 provider API 키가 없음

**해결**:
```bash
# .env 파일 확인
cat .env

# API 키 추가
echo "ANTHROPIC_API_KEY=sk-ant-..." >> .env

# 서버 재시작
```

### 3. Python 서버 오류: "Unknown model"

**원인**: Python `model_mapping`에 모델 ID가 없음

**해결**:
- `lib/llm_services/[provider]_llm.py` 파일 확인
- `model_mapping` 딕셔너리에 모델 ID 추가
- Python 서버 재시작

### 4. 코드 생성 시 모델명 오류

**원인**: `code_generator_service.rb`의 매핑 메서드 누락

**해결**:
- `app/services/code_generator_service.rb` 확인
- `map_[provider]_model` 메서드에 case 문 추가
- Rails 서버 재시작

### 5. API 호출 실패: 401 Unauthorized

**원인**: API 키가 유효하지 않거나 만료됨

**해결**:
```bash
# API 키 재확인
echo $ANTHROPIC_API_KEY

# 새 키로 업데이트
export ANTHROPIC_API_KEY=sk-ant-...
```

### 6. 파라미터 미지원 오류

**원인**: Reasoning 모델에 temperature/top_p 전달

**해결**:
- OpenAI reasoning 모델의 경우 `openai_llm.py`의 `reasoning_models` 세트에 추가
- Python 코드가 자동으로 `max_completion_tokens` 사용

```python
self.reasoning_models = {'gpt-5', 'gpt-5-mini', 'gpt-4.5'}  # 추가
```

### 7. Hyperparameter 모달에 정보 없음

**원인**: HTML 테이블에 행이 추가되지 않음

**해결**:
- `app/views/playground/index.html.erb` 확인
- 해당 provider 테이블 tbody에 `<tr>` 추가
- 브라우저 캐시 클리어 (Cmd+Shift+R)

---

## 고급: 새 Provider 추가

새 LLM Provider(예: Cohere, AI21)를 추가하려면:

### 1. Python LLM 클래스 생성

**파일**: `lib/llm_services/cohere_llm.py`

```python
from .base_llm import BaseLLM, LLMResponse
import cohere
import time

class CohereLLM(BaseLLM):
    """Cohere models implementation"""

    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        self.client = cohere.Client(api_key=api_key)

        self.model_mapping = {
            'command-r-plus': 'command-r-plus',
            'command-r': 'command-r'
        }

    async def generate(self, system_prompt: str, user_prompt: str, **kwargs):
        # 구현...
        pass

    async def stream_generate(self, system_prompt: str, user_prompt: str, **kwargs):
        # 구현...
        pass
```

### 2. Factory에 Provider 등록

**파일**: `lib/llm_services/llm_factory.py`

```python
from .cohere_llm import CohereLLM

class LLMFactory:
    @staticmethod
    def create_llm(model_id: str) -> BaseLLM:
        # ... 기존 코드 ...

        elif model_id.startswith('command-'):
            api_key = os.getenv('COHERE_API_KEY')
            if not api_key:
                raise ValueError("COHERE_API_KEY not found")
            return CohereLLM(api_key, model_id)
```

### 3. Rails 서비스 업데이트

**파일**: `app/services/api_key_manager.rb`

```ruby
def self.available_keys
  {
    openai: ENV['OPENAI_API_KEY'].present?,
    anthropic: ENV['ANTHROPIC_API_KEY'].present?,
    google: ENV['GOOGLE_GEMINI_API_KEY'].present?,
    cohere: ENV['COHERE_API_KEY'].present?  # ✅ 추가
  }
end
```

### 4. 코드 생성 서비스 확장

**파일**: `app/services/code_generator_service.rb`

```ruby
def self.detect_provider(model)
  case model
  when /^gpt/
    'openai'
  when /^claude/
    'anthropic'
  when /^gemini/
    'google'
  when /^command/     # ✅ 추가
    'cohere'
  else
    'unknown'
  end
end

def self.generate_cohere_python(prompt, result)
  # 구현...
end
```

---

## 참고 자료

- **Architecture.md**: 전체 시스템 아키텍처
- **CLAUDE.md**: 프로젝트 설정 및 가이드
- **README.md**: 빠른 시작 가이드

---

## 버전 히스토리

| 버전 | 날짜 | 변경 사항 |
|------|------|----------|
| 1.0 | 2025-09-30 | 초기 문서 작성 |

---

**작성자**: LLM API Playground Team
**최종 업데이트**: 2025-09-30