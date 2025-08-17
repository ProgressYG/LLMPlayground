# 데이터 플로우

## 개요

LLM API Playground의 데이터 흐름을 보여주는 다이어그램입니다. 비스트리밍 모드와 스트리밍 모드의 요청-응답 플로우를 시각화합니다.

## 다이어그램

### 비스트리밍 요청 플로우

```mermaid
sequenceDiagram
    participant U as 🙋 User
    participant B as 🌐 Browser
    participant R as 🚂 Rails API
    participant Q as ⚙️ Solid Queue
    participant J as 📋 LlmExecutionJob
    participant F as 🐍 FastAPI
    participant L as 🤖 LLM Provider
    participant D as 💾 PostgreSQL

    U->>B: 프롬프트 입력 및 실행
    B->>R: POST /api/prompts/execute
    R->>D: Prompt 저장
    R->>D: Execution 생성 (status: pending)
    R->>Q: Job 큐에 추가
    R-->>B: { execution_id, status: "pending" }
    
    Note over Q,J: 비동기 처리 시작
    
    Q->>J: perform(execution_id, streaming: false)
    J->>D: Execution 업데이트 (status: running)
    
    loop 각 iteration마다
        J->>F: POST /generate<br/>{prompt, model, parameters}
        F->>L: API 호출
        L-->>F: 전체 응답
        F-->>J: { text, tokens, model_info }
        J->>D: Result 저장
    end
    
    J->>D: Execution 업데이트 (status: completed)
    
    Note over B,R: 상태 폴링
    
    loop 완료될 때까지
        B->>R: GET /api/prompts/:id/status
        R->>D: 상태 조회
        R-->>B: { status, results }
    end
```

### 스트리밍 요청 플로우

```mermaid
sequenceDiagram
    participant U as 🙋 User
    participant B as 🌐 Browser
    participant W as 🔌 WebSocket
    participant R as 🚂 Rails API
    participant A as 📡 ActionCable
    participant J as 📋 LlmExecutionJob
    participant F as 🐍 FastAPI
    participant L as 🤖 LLM Provider
    participant D as 💾 PostgreSQL

    U->>B: 프롬프트 입력 및 스트리밍 실행
    B->>W: ActionCable 구독<br/>channel: "PromptChannel"
    W->>A: subscribed(execution_id)
    
    B->>R: POST /api/prompts/execute<br/>{streaming: true}
    R->>D: Prompt 저장
    R->>D: Execution 생성
    R->>J: perform_later(execution_id, true)
    R-->>B: { execution_id }
    
    Note over J,L: 스트리밍 시작
    
    J->>F: POST /generate<br/>{stream: true}
    F->>L: 스트리밍 요청
    
    rect rgb(240, 248, 255)
        Note right of L: 토큰 생성 중
        loop 각 토큰 청크
            L-->>F: 텍스트 청크
            F-->>J: SSE: data: {"text": "..."}
            J->>A: broadcast_chunk
            A-->>W: { type: "chunk", content: "..." }
            W-->>B: UI에 실시간 표시
        end
    end
    
    L-->>F: [DONE]
    F-->>J: SSE: data: {"done": true}
    J->>D: Result 저장
    J->>A: broadcast_complete
    A-->>W: { type: "complete", result: {...} }
    W-->>B: 최종 결과 표시
```

### 에러 처리 플로우

```mermaid
flowchart TD
    Start([요청 시작]) --> TryAPI{API 호출}
    TryAPI -->|성공| Process[응답 처리]
    TryAPI -->|실패| CheckRetry{재시도 가능?}
    
    CheckRetry -->|Yes<br/>attempts < 3| Wait[지수 백오프<br/>대기]
    Wait --> TryAPI
    
    CheckRetry -->|No| HandleError[에러 처리]
    
    HandleError --> SaveError[DB에 에러 저장]
    SaveError --> BroadcastError[ActionCable<br/>에러 브로드캐스트]
    BroadcastError --> ShowError[사용자에게<br/>에러 표시]
    
    Process --> SaveResult[결과 저장]
    SaveResult --> Complete([완료])
    
    style Start fill:#e1f5fe
    style Complete fill:#c8e6c9
    style HandleError fill:#ffcdd2
```

## 설명

### 비스트리밍 모드
1. 사용자가 프롬프트를 실행하면 Rails API가 요청을 받음
2. Prompt와 Execution을 DB에 저장하고 백그라운드 Job 생성
3. Job이 FastAPI를 통해 LLM Provider 호출
4. 전체 응답을 받아 DB에 저장
5. 브라우저는 폴링으로 상태를 확인

### 스트리밍 모드
1. WebSocket 연결 먼저 설정 (ActionCable 구독)
2. 실행 요청 시 streaming: true 파라미터 전달
3. FastAPI가 SSE로 LLM 응답을 스트리밍
4. 각 청크를 ActionCable로 실시간 브로드캐스트
5. 브라우저에서 토큰이 생성되는 대로 표시

### 에러 처리
- 최대 3회 재시도 (지수 백오프)
- 실패 시 에러를 DB에 저장하고 사용자에게 알림
- Gemini 안전 필터 등 특수 에러 처리

## 참고사항

- SSE (Server-Sent Events): FastAPI → Rails 간 스트리밍
- WebSocket: Rails → Browser 간 실시간 통신
- 폴링은 비스트리밍 모드에서만 사용 (1초 간격)
- 모든 통신은 JSON 형식으로 이루어짐
