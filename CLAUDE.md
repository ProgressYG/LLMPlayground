# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LLM API Playground - An enterprise-grade prompt testing and optimization platform for AI models. The project enables prompt engineers and AI developers to optimize prompts through iterative testing and parameter tuning on multiple LLM models.

### Supported Models (12 total)
- **OpenAI**: GPT-4o, GPT-4o-mini, GPT-5, GPT-5-mini, GPT-4.1, GPT-4.1-mini, GPT-4.1-nano
- **Anthropic**: Claude 3.5 Haiku, Claude Sonnet 4, Claude Opus 4.1
- **Google**: Gemini 2.5 Flash, Gemini 2.5 Pro

## Tech Stack

### Backend
- **Ruby on Rails 8.0.2+**: RESTful API, WebSocket via ActionCable, authentication
- **Python 3.11+**: FastAPI server for LLM API integration, async processing, SSE streaming
- **PostgreSQL 16.0**: Data persistence (external volume: `/Volumes/ygmac_external/pgdata`)
- **Redis**: ActionCable pub/sub and caching (optional)

### Frontend
- **Tailwind CSS**: Dark mode UI, responsive 70:30 layout grid
- **Stimulus.js**: Rails-integrated JavaScript framework
- **Turbo**: Real-time updates without full page reloads
- **Importmap**: No Node.js bundler required (Rails 8 default)

## Development Commands

### Initial Setup
```bash
# Ruby dependencies
bundle install

# Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Database setup
rails db:create
rails db:migrate

# Install Tailwind CSS dependencies
npm install
```

### Running the Application
```bash
# Recommended: Run all services together
bin/dev

# This starts:
# - Rails server on port 3000
# - Python FastAPI on port 8000  
# - Tailwind CSS watcher
```

### Individual Services (if needed)
```bash
# Rails only
rails server

# Python API only (separate terminal)
source venv/bin/activate
python lib/llm_api_server.py

# Tailwind CSS watcher
rails tailwindcss:watch
```

### Testing & Quality
```bash
# Rails tests
rails test

# Python tests (if available)
pytest

# Rails console for debugging
rails console

# Database console
rails db
```

### Database Operations
```bash
# Create migration
rails generate migration MigrationName

# Run migrations
rails db:migrate

# Rollback
rails db:rollback

# Reset database
rails db:reset
```

### Docker Deployment
```bash
# Full stack with Docker Compose
cd docker
docker-compose up

# Services included:
# - PostgreSQL 16
# - Redis
# - Python FastAPI
# - Rails app
# - Nginx reverse proxy
```

## Architecture Overview

### Request Flow
1. **Frontend** → Rails API (`/api/prompts/execute`)
2. **Rails** → Creates Prompt & Execution records → Queues `LlmExecutionJob`
3. **Job** → Calls Python FastAPI server (`http://localhost:8000/generate`)
4. **Python** → Calls LLM provider APIs (OpenAI/Anthropic/Google)
5. **Streaming** → Python SSE → Rails ActionCable → Frontend real-time updates

### Key Services & Models

#### Rails Services (`app/services/`)
- `LlmModelsService`: Model definitions, pricing, capabilities
- `ApiKeyManager`: API key validation and management
- `CodeGeneratorService`: Generates Python/JS/cURL code snippets
- `ExportService`: JSON/Markdown export functionality
- `UsageHistoryService`: Token usage tracking

#### Python LLM Services (`lib/llm_services/`)
- `base_llm.py`: Abstract base class for LLM providers
- `openai_llm.py`: OpenAI GPT models (includes GPT-5 reasoning models)
- `anthropic_llm.py`: Claude models implementation
- `gemini_llm.py`: Google Gemini models
- `llm_factory.py`: Factory pattern for LLM instantiation

#### Database Models
- `Prompt`: System/user prompts, parameters, selected model
- `Execution`: Iteration count, status tracking
- `Result`: Response text, tokens used, timing
- `Template`: Saved prompt templates

### API Endpoints

#### Rails API (`config/routes.rb`)
- `POST /api/prompts/execute`: Execute prompt with iterations
- `GET /api/prompts/:id/status`: Get execution status and results
- `GET /api/prompts/:id/code`: Generate code snippets
- `GET /api/prompts/:id/export`: Export results
- `GET /api/models`: List available models
- `GET /api/usage_history`: Token usage history

#### Python FastAPI (`lib/llm_api_server.py`)
- `GET /health`: Health check
- `GET /models`: Available models based on API keys
- `POST /generate`: Single generation (stream or non-stream)
- `POST /batch_generate`: Parallel batch execution

## Environment Variables

Create `.env` file in root:
```bash
# Required API Keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_GEMINI_API_KEY=AIza...

# Database (optional for development)
DB_HOST=localhost
DB_USERNAME=your_username
DB_PASSWORD=your_password

# Optional
REDIS_URL=redis://localhost:6379/1
PYTHON_API_URL=http://localhost:8000
API_REQUEST_TIMEOUT=30
API_MAX_RETRIES=3
```

## Adding New Models

To add a new LLM model:

1. **Update Rails Model Definition** (`app/services/llm_models_service.rb`):
   - Add model to `MODELS` hash with pricing, tokens, capabilities

2. **Update Python Model Mapping** (`lib/llm_services/openai_llm.py` or relevant provider):
   - Add to `model_mapping` dictionary
   - Handle any special parameters (e.g., reasoning models)

3. **Update Code Generator** (`app/services/code_generator_service.rb`):
   - Add model-specific code generation if needed

## Model-Specific Considerations

### GPT-5 Reasoning Models
- Use `max_completion_tokens` instead of `max_tokens`
- Don't support `temperature` or `top_p` parameters
- Minimum 2000 tokens required

### GPT-4.1 Series
- Support 1M token context window
- Standard OpenAI parameters apply

### Claude Models
- Support streaming via SSE
- 200K token context window
- System prompts supported

### Gemini Models
- Up to 1M token context window
- Require combined system+user prompt format

## Development Tips

1. **Database Location**: PostgreSQL data stored at `/Volumes/ygmac_external/pgdata`
2. **Streaming**: Uses Server-Sent Events (SSE) from Python → Rails ActionCable
3. **Parameter Tuning**: Temperature (0-2), Max Tokens (1-128000), Top P (0-1)
4. **Iteration Testing**: Run same prompt 1-10 times for consistency analysis
5. **Code Export**: Automatic generation of implementation code in Python/JS/cURL

## Common Issues & Solutions

### Port Conflicts
```bash
lsof -i :3000 | grep LISTEN
lsof -i :8000 | grep LISTEN
# Kill if needed: kill -9 <PID>
```

### Python Module Issues
```bash
source venv/bin/activate
pip install -r requirements.txt
```

### Database Connection
```bash
# Check PostgreSQL status
brew services list | grep postgresql
brew services restart postgresql@16

# Verify connection
rails db
```

### API Key Validation
- Check `.env` file has correct keys
- Verify in header: 🔑 API Status indicator
- Keys are validated on startup

## Project Structure

```
/
├── app/
│   ├── controllers/api/   # API endpoints
│   ├── services/          # Business logic
│   ├── models/           # ActiveRecord models
│   ├── jobs/             # Background jobs
│   └── javascript/       # Stimulus controllers
├── lib/
│   ├── llm_api_server.py # FastAPI server
│   └── llm_services/     # Python LLM integrations
├── config/
│   ├── routes.rb         # Rails routing
│   └── database.yml      # DB configuration
├── docker/               # Docker deployment files
└── db/                  # Migrations and schema
```