#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📊 LLM API Playground Service Status${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Function to check service status
check_service() {
    local SERVICE_NAME=$1
    local PORT=$2
    local URL=$3
    local PIDS=$(lsof -ti:$PORT 2>/dev/null)
    
    echo -e "${BLUE}$SERVICE_NAME:${NC}"
    if [ ! -z "$PIDS" ]; then
        echo -e "  ${GREEN}● Running${NC}"
        for PID in $PIDS; do
            PROCESS_INFO=$(ps -p $PID -o comm= 2>/dev/null)
            echo -e "  PID: $PID ($PROCESS_INFO)"
        done
        echo -e "  URL: ${CYAN}$URL${NC}"
        
        # Test if service is responding
        if curl -s -o /dev/null -w "%{http_code}" $URL | grep -q "200\|302"; then
            echo -e "  Status: ${GREEN}✅ Responding${NC}"
        else
            echo -e "  Status: ${YELLOW}⚠️  Not responding (but process is running)${NC}"
        fi
    else
        echo -e "  ${RED}● Stopped${NC}"
    fi
    echo ""
}

# Check Rails server
check_service "Rails Server" 3000 "http://localhost:3000/playground"

# Check Python API server
check_service "Python API Server" 8000 "http://localhost:8000/health"

# Check PostgreSQL
echo -e "${BLUE}PostgreSQL Database:${NC}"
if pg_isready -q 2>/dev/null; then
    echo -e "  ${GREEN}● Running${NC}"
    # Get PostgreSQL version and connection info
    PG_VERSION=$(psql --version 2>/dev/null | head -1)
    echo -e "  Version: $PG_VERSION"
    
    # Check if database exists
    if rails db:version > /dev/null 2>&1; then
        DB_VERSION=$(rails db:version 2>/dev/null | grep "Current version" | cut -d: -f2 | xargs)
        echo -e "  Database: ${GREEN}✅ Connected${NC}"
        echo -e "  Schema Version: $DB_VERSION"
    else
        echo -e "  Database: ${YELLOW}⚠️  Not initialized${NC}"
        echo -e "  Run: rails db:create db:migrate"
    fi
else
    echo -e "  ${RED}● Stopped${NC}"
    echo -e "  To start: brew services start postgresql"
fi
echo ""

# Check Redis (if configured)
if command -v redis-cli &> /dev/null; then
    echo -e "${BLUE}Redis (Optional):${NC}"
    if redis-cli ping > /dev/null 2>&1; then
        echo -e "  ${GREEN}● Running${NC}"
        REDIS_VERSION=$(redis-cli --version | cut -d' ' -f2)
        echo -e "  Version: redis $REDIS_VERSION"
    else
        echo -e "  ${YELLOW}● Not running${NC} (optional for caching)"
    fi
    echo ""
fi

# Check environment
echo -e "${BLUE}Environment:${NC}"

# Check .env file
if [ -f .env ]; then
    echo -e "  .env file: ${GREEN}✅ Present${NC}"
    
    # Check API keys (without showing them)
    if grep -q "OPENAI_API_KEY=" .env && grep -q "^OPENAI_API_KEY=..*" .env; then
        echo -e "  OpenAI API Key: ${GREEN}✅ Configured${NC}"
    else
        echo -e "  OpenAI API Key: ${YELLOW}⚠️  Not configured${NC}"
    fi
    
    if grep -q "ANTHROPIC_API_KEY=" .env && grep -q "^ANTHROPIC_API_KEY=..*" .env; then
        echo -e "  Anthropic API Key: ${GREEN}✅ Configured${NC}"
    else
        echo -e "  Anthropic API Key: ${YELLOW}⚠️  Not configured${NC}"
    fi
    
    if grep -q "GOOGLE_GEMINI_API_KEY=" .env && grep -q "^GOOGLE_GEMINI_API_KEY=..*" .env; then
        echo -e "  Gemini API Key: ${GREEN}✅ Configured${NC}"
    else
        echo -e "  Gemini API Key: ${YELLOW}⚠️  Not configured${NC}"
    fi
else
    echo -e "  .env file: ${RED}❌ Missing${NC}"
    echo -e "  Run: cp .env.example .env"
fi
echo ""

# Check logs
echo -e "${BLUE}Recent Logs:${NC}"
if [ -f log/rails.log ]; then
    RAILS_LOG_SIZE=$(du -h log/rails.log | cut -f1)
    RAILS_LOG_LINES=$(wc -l < log/rails.log)
    echo -e "  Rails Log: $RAILS_LOG_SIZE ($RAILS_LOG_LINES lines)"
    
    # Show last error if any
    LAST_ERROR=$(grep -i "error\|fatal" log/rails.log | tail -1)
    if [ ! -z "$LAST_ERROR" ]; then
        echo -e "  ${YELLOW}Last Error: $(echo $LAST_ERROR | cut -c1-60)...${NC}"
    fi
else
    echo -e "  Rails Log: Not found"
fi

if [ -f log/python_api.log ]; then
    PYTHON_LOG_SIZE=$(du -h log/python_api.log | cut -f1)
    PYTHON_LOG_LINES=$(wc -l < log/python_api.log)
    echo -e "  Python Log: $PYTHON_LOG_SIZE ($PYTHON_LOG_LINES lines)"
else
    echo -e "  Python Log: Not found"
fi
echo ""

# Summary
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
RAILS_RUNNING=$(lsof -ti:3000 2>/dev/null)
PYTHON_RUNNING=$(lsof -ti:8000 2>/dev/null)

if [ ! -z "$RAILS_RUNNING" ] && [ ! -z "$PYTHON_RUNNING" ]; then
    echo -e "${GREEN}✅ All services are running!${NC}"
    echo ""
    echo -e "${BLUE}Access the application at:${NC}"
    echo -e "  ${CYAN}http://localhost:3000/playground${NC}"
elif [ ! -z "$RAILS_RUNNING" ] || [ ! -z "$PYTHON_RUNNING" ]; then
    echo -e "${YELLOW}⚠️  Some services are running${NC}"
    echo ""
    echo -e "To start all services, run:"
    echo -e "  ${CYAN}./start.sh${NC}"
else
    echo -e "${RED}❌ No services are running${NC}"
    echo ""
    echo -e "To start services, run:"
    echo -e "  ${CYAN}./start.sh${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"