# LLM API Playground

엔터프라이즈급 LLM API 프롬프트 테스팅 및 최적화 플랫폼

## 🚀 Features

- **다중 LLM 지원**: OpenAI GPT, Anthropic Claude, Google Gemini
- **파라미터 조정**: Temperature, Max Tokens, Top P 실시간 조정
- **반복 실행**: 동일 프롬프트를 1-10회 반복하여 일관성 검증
- **Dark Mode UI**: 70:30 레이아웃의 직관적인 인터페이스
- **실시간 스트리밍**: 응답 생성 과정을 실시간으로 확인

## 📋 Prerequisites

- Ruby 3.3.0+
- Rails 8.0.2+
- PostgreSQL 16.0+
- Python 3.11+
- Node.js 18+

## 🛠️ Installation

### 1. Clone the repository
```bash
cd /Volumes/ygmac_external/Projects_e/LLM_Play
```

### 2. Install dependencies
```bash
# Ruby gems
bundle install

# Python packages
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Node packages
npm install
```

### 3. Configure API Keys
`.env` 파일을 생성하고 API 키를 추가하세요:
```bash
cp .env.example .env
```

`.env` 파일 편집:
```env
# LLM API Keys
OPENAI_API_KEY=your_openai_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here
GOOGLE_GEMINI_API_KEY=your_gemini_key_here

# Database
DB_USERNAME=your_username
DB_PASSWORD=your_password
```

### 4. Setup Database
```bash
rails db:create
rails db:migrate
```

## 🎮 Usage

### Start the application
```bash
bin/dev
```

이 명령어는 다음 서비스들을 동시에 실행합니다:
- Rails server (Port 3000)
- Python LLM API server (Port 8000)
- Tailwind CSS watcher

### Access the application
브라우저에서 http://localhost:3000 접속

## 💡 Quick Start Guide

1. **API 키 상태 확인**: 헤더 우측의 🔑 API Status 확인
2. **모델 선택**: 드롭다운에서 사용할 LLM 모델 선택
3. **프롬프트 입력**:
   - System Prompt: 모델의 역할이나 컨텍스트 설정 (선택사항)
   - User Prompt: 실제 질문이나 요청 입력 (필수)
4. **파라미터 조정**:
   - Temperature: 창의성 조절 (0=보수적, 2=창의적)
   - Max Tokens: 최대 응답 길이
   - Top P: 단어 선택 다양성
5. **Iteration 설정**: 동일 프롬프트 반복 횟수 (1-10)
6. **Execute 클릭**: 프롬프트 실행

### Keyboard Shortcuts
- `Cmd/Ctrl + Enter`: 프롬프트 실행
- `ESC`: 모달 닫기

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────┐
│   Rails App     │────▶│  Python FastAPI  │
│   (Port 3000)   │     │   (Port 8000)    │
└─────────────────┘     └──────────────────┘
                               │
                   ┌───────────┼───────────┐
                   ▼           ▼           ▼
              ┌─────────┐ ┌─────────┐ ┌─────────┐
              │ OpenAI  │ │Anthropic│ │ Google  │
              │   API   │ │   API   │ │Gemini API│
              └─────────┘ └─────────┘ └─────────┘
```

## 📁 Project Structure

```
LLM_Play/
├── app/
│   ├── controllers/      # Rails controllers
│   ├── models/          # ActiveRecord models
│   ├── services/        # Business logic
│   ├── views/           # ERB templates
│   └── javascript/      # Stimulus controllers
├── lib/
│   ├── llm_services/    # Python LLM integrations
│   └── llm_api_server.py # FastAPI server
├── config/
│   └── database.yml     # PostgreSQL config
├── .env                 # API keys (create this)
└── requirements.txt     # Python dependencies
```

## 🔧 Troubleshooting

### PostgreSQL connection error
```bash
# PostgreSQL이 실행중인지 확인
brew services list | grep postgresql

# 필요시 시작
brew services start postgresql@16
```

### Python module not found
```bash
# 가상환경 활성화 확인
source venv/bin/activate
pip install -r requirements.txt
```

### Port already in use
```bash
# Rails 서버 종료
lsof -i :3000
kill -9 [PID]

# Python 서버 종료
lsof -i :8000
kill -9 [PID]
```

## 📝 Development

### Add a new LLM model
1. `app/services/llm_models_service.rb`에 모델 정보 추가
2. `lib/llm_services/`에 새 프로바이더 클래스 생성
3. `lib/llm_services/llm_factory.py`에 팩토리 메서드 추가

### Run tests
```bash
# Rails tests
rails test

# Python tests
pytest
```

## 🤝 Contributing

이 프로젝트는 개인 사용 목적으로 개발되었습니다.

## 📄 License

Private use only
