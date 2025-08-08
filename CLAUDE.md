# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an LLM API Playground - an enterprise-grade prompt testing and optimization platform for AI models (OpenAI GPT, Anthropic Claude, Google Gemini). The project is designed as a professional tool for prompt engineers and AI developers to optimize prompts through iterative testing and parameter tuning on a single selected model.

## Tech Stack

### Backend
- **Python 3.11+**: LLM API integration layer, async processing, response streaming
  - Key libraries: python-dotenv for API key management
- **Ruby on Rails 7.1.2**: RESTful API endpoints, WebSocket communication, authentication
  - Key gems: dotenv-rails for environment variables
- **PostgreSQL 16.0**: Data persistence
  - Location: `/Volumes/ygmac_external/pgdata`

### Frontend
- **Tailwind CSS**: Dark mode UI, responsive 70:30 layout grid
- **Stimulus.js**: Rails-integrated JavaScript framework
- **Turbo**: Real-time updates

## Development Commands

### Initial Setup
```bash
# Install Python dependencies
pip install -r requirements.txt

# Install Ruby dependencies
bundle install

# Setup database
rails db:create
rails db:migrate

# Install Node packages
npm install
```

### Running the Application
```bash
# Start Rails server
rails server

# Or use the development script
bin/dev

# Run Python API service (if separate)
python app/services/llm_service.py
```

### Testing
```bash
# Run Rails tests
rails test

# Run Python tests
pytest

# Run JavaScript tests
npm test
```

### Database Operations
```bash
# Create migration
rails generate migration MigrationName

# Run migrations
rails db:migrate

# Rollback migration
rails db:rollback

# Database console
rails db
```

## Architecture Overview

### Directory Structure (Expected)
```
/
├── app/
│   ├── controllers/     # Rails API controllers
│   ├── models/          # ActiveRecord models
│   ├── services/        # Business logic & Python LLM services
│   ├── javascript/      # Stimulus controllers
│   └── views/           # Rails views (minimal, mostly API)
├── config/
│   ├── database.yml     # PostgreSQL configuration
│   └── routes.rb        # API routing
├── db/                  # Database migrations and schema
├── lib/                 # Python LLM integration modules
└── public/              # Static assets
```

### Key Components

1. **API Key Management**: Uses `.env` file for storing API keys (OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_GEMINI_API_KEY)

2. **Model Selection System**: Dropdown interface supporting 7 LLM models with pricing information

3. **Prompt System**: Separate System and User prompt inputs with template management

4. **Parameter Controls**: Temperature (0-2), Max Tokens (1-4096), Top P (0-1) adjustable via sliders

5. **Iteration System**: Execute same prompt 1-10 times for consistency testing

6. **Results Display**: Tab-based interface showing individual results with comparison mode

## API Integration

### Supported Models
- Claude 3.5 Haiku, Sonnet 4, Opus 4.1
- Gemini 2.5 Flash, Pro
- GPT-5 Mini, GPT-5o

### Environment Variables
Create a `.env` file in the root directory:
```bash
# Required API Keys
OPENAI_API_KEY=sk-xxxxxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxxxxx
GOOGLE_GEMINI_API_KEY=AIzaxxxxxxxx

# Optional Settings
API_REQUEST_TIMEOUT=30
API_MAX_RETRIES=3
```

## UI/UX Guidelines

- **Layout**: 70% main workspace, 30% control panel
- **Theme**: Dark mode by default (Tailwind slate color palette)
- **Responsive**: Desktop-first, with tablet/mobile adaptations
- **Components**: Card-based design with consistent spacing and borders

## Development Workflow

1. Check API keys in `.env` before testing API features
2. Use Rails conventions for controllers and models
3. Keep Python services modular in `app/services/` or `lib/`
4. Follow Stimulus.js patterns for frontend interactivity
5. Maintain PostgreSQL database at specified external volume path
6. Use Turbo for real-time updates without full page reloads

## Important Notes

- Database is stored on external volume at `/Volumes/ygmac_external/pgdata`
- Project focuses on single model selection (not parallel multi-model testing)
- Iteration feature runs same prompt multiple times for consistency verification
- All API responses should be streamed in real-time when possible
- Price reference modal embeds external pricing information