# 컴포넌트 구조

## 개요

LLM API Playground의 컴포넌트 구조를 계층별로 보여주는 다이어그램입니다. Rails MVC, FastAPI 서비스, Frontend 컴포넌트의 구조를 시각화합니다.

## 다이어그램

### Rails 애플리케이션 구조

```mermaid
graph TD
    subgraph "Rails MVC Structure"
        subgraph "Controllers"
            PC[PlaygroundController<br/>메인 UI]
            AC[Api::PromptsController<br/>프롬프트 API]
            MC[Api::ModelsController<br/>모델 정보 API]
        end
        
        subgraph "Models"
            PM[Prompt<br/>프롬프트 데이터]
            EM[Execution<br/>실행 단위]
            RM[Result<br/>실행 결과]
            TM[Template<br/>템플릿]
            
            PM -->|has_many| EM
            EM -->|has_many| RM
            EM -->|belongs_to| PM
            RM -->|belongs_to| EM
        end
        
        subgraph "Services"
            AKM[ApiKeyManager<br/>API 키 관리]
            LMS[LlmModelsService<br/>모델 메타데이터]
            CGS[CodeGeneratorService<br/>코드 생성]
            ES[ExportService<br/>내보내기]
        end
        
        subgraph "Jobs"
            LEJ[LlmExecutionJob<br/>LLM 실행 작업]
        end
        
        subgraph "Channels"
            PCH[PromptChannel<br/>WebSocket 채널]
        end
        
        AC --> PM
        AC --> LEJ
        AC --> ES
        AC --> CGS
        LEJ --> AKM
        LEJ --> PCH
        MC --> LMS
        LMS --> AKM
    end
    
    style PC fill:#e8f5e9
    style AC fill:#e8f5e9
    style MC fill:#e8f5e9
    style PM fill:#e3f2fd
    style EM fill:#e3f2fd
    style RM fill:#e3f2fd
    style TM fill:#e3f2fd
    style AKM fill:#fff3e0
    style LMS fill:#fff3e0
    style CGS fill:#fff3e0
    style ES fill:#fff3e0
    style LEJ fill:#fce4ec
    style PCH fill:#f3e5f5
```

### FastAPI 서비스 구조

```mermaid
classDiagram
    class BaseLLM {
        <<abstract>>
        +api_key: str
        +model: str
        +generate(prompt, params)*
        +stream_generate(prompt, params)*
        +validate_response(response)*
        +handle_error(error)*
    }
    
    class LLMFactory {
        +registered_providers: dict
        +create(provider, api_key, model)
        +register(provider, class)
        +get_available_providers(api_keys)
    }
    
    class OpenAILLM {
        +client: OpenAI
        +generate(prompt, params)
        +stream_generate(prompt, params)
        -_handle_gpt5_params(params)
    }
    
    class AnthropicLLM {
        +client: Anthropic
        +generate(prompt, params)
        +stream_generate(prompt, params)
        -_convert_to_messages(prompt)
    }
    
    class GeminiLLM {
        +client: GenerativeModel
        +generate(prompt, params)
        +stream_generate(prompt, params)
        -_configure_safety_settings()
    }
    
    class FastAPIApp {
        +health()
        +get_models()
        +generate()
        +batch_generate()
        -setup_cors()
        -setup_routes()
    }
    
    BaseLLM <|-- OpenAILLM
    BaseLLM <|-- AnthropicLLM
    BaseLLM <|-- GeminiLLM
    LLMFactory ..> BaseLLM : creates
    FastAPIApp --> LLMFactory : uses
```

### Frontend 컴포넌트 구조

```mermaid
graph TD
    subgraph "Stimulus Controllers"
        EC[ExecuteController<br/>실행 관리]
        PSC[ParameterSliderController<br/>파라미터 조정]
        CC[CompareController<br/>결과 비교]
        CMC[CodeModalController<br/>코드 모달]
        CPC[CopyController<br/>복사 기능]
        EMC[ExportModalController<br/>내보내기]
        PMC[PriceModalController<br/>가격 정보]
        RC[ResultsController<br/>결과 표시]
        SC[StatusController<br/>상태 업데이트]
        TC[TabController<br/>탭 전환]
        TMC[TemplateModalController<br/>템플릿 관리]
        TFC[TokenFormatterController<br/>토큰 포맷]
    end
    
    subgraph "ActionCable"
        PJS[prompt_channel.js<br/>WebSocket 구독]
        CON[consumer.js<br/>Cable 연결]
        
        CON --> PJS
    end
    
    subgraph "Main View"
        IDX[playground/index.html.erb<br/>메인 UI]
        
        IDX --> EC
        IDX --> PSC
        IDX --> CC
        IDX --> RC
    end
    
    EC --> PJS
    RC --> SC
    RC --> TFC
    
    style EC fill:#e1f5fe
    style PSC fill:#e1f5fe
    style CC fill:#e1f5fe
    style PJS fill:#f3e5f5
    style IDX fill:#c8e6c9
```

### 데이터 흐름 관계도

```mermaid
flowchart LR
    subgraph "User Interface"
        UI[Stimulus Controllers]
    end
    
    subgraph "Rails Backend"
        CTRL[Controllers]
        SVC[Services]
        JOB[Jobs]
        CH[Channels]
    end
    
    subgraph "Python Service"
        API[FastAPI]
        FAC[LLM Factory]
        PROV[Provider Implementations]
    end
    
    subgraph "External"
        LLM[LLM APIs]
    end
    
    UI <-->|HTTP/WebSocket| CTRL
    CTRL --> SVC
    CTRL --> JOB
    JOB <-->|HTTP/SSE| API
    API --> FAC
    FAC --> PROV
    PROV <--> LLM
    JOB --> CH
    CH <-->|WebSocket| UI
    
    style UI fill:#e1f5fe
    style CTRL fill:#c8e6c9
    style API fill:#fff3e0
    style LLM fill:#ffcdd2
```

## 설명

### Rails 컴포넌트
- **Controllers**: API 엔드포인트와 라우팅 처리
- **Models**: Active Record 모델로 데이터베이스 상호작용
- **Services**: 비즈니스 로직 캡슐화
- **Jobs**: Active Job을 통한 비동기 처리
- **Channels**: ActionCable을 통한 실시간 통신

### FastAPI 컴포넌트
- **BaseLLM**: 모든 LLM Provider의 추상 클래스
- **LLMFactory**: Provider 인스턴스 생성 팩토리
- **Provider Implementations**: 각 LLM 서비스별 구현체
- **FastAPIApp**: HTTP 엔드포인트와 CORS 설정

### Frontend 컴포넌트
- **Stimulus Controllers**: UI 상호작용 및 상태 관리
- **ActionCable**: WebSocket 통신 관리
- **Views**: ERB 템플릿 기반 UI 렌더링

## 참고사항

- Stimulus는 HTML 요소에 직접 바인딩되는 경량 JavaScript 프레임워크
- 각 Controller는 특정 UI 기능을 담당하며 data-controller 속성으로 연결
- Services는 테스트 가능하고 재사용 가능한 비즈니스 로직 제공
- Factory 패턴을 통해 새로운 LLM Provider 추가가 용이함
