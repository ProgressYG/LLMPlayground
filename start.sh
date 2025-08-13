#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting LLM API Playground...${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if services are already running
RAILS_PID=$(lsof -ti:3000 2>/dev/null)
PYTHON_PID=$(lsof -ti:8000 2>/dev/null)

if [ ! -z "$RAILS_PID" ] || [ ! -z "$PYTHON_PID" ]; then
    echo -e "${YELLOW}⚠️  Some services are already running${NC}"
    if [ ! -z "$RAILS_PID" ]; then
        echo "   Rails server is running on port 3000 (PID: $RAILS_PID)"
    fi
    if [ ! -z "$PYTHON_PID" ]; then
        echo "   Python API is running on port 8000 (PID: $PYTHON_PID)"
    fi
    echo ""
    read -p "Do you want to stop them and restart? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./stop.sh
        echo ""
    else
        echo "Exiting..."
        exit 1
    fi
fi

# Check if PostgreSQL is running
#if ! pg_isready -q 2>/dev/null; then
#    echo -e "${YELLOW}⚠️  PostgreSQL is not running. Attempting to start...${NC}"
#    if command -v brew &> /dev/null; then
#        brew services start postgresql@16 2>/dev/null || brew services start postgresql 2>/dev/null
#        sleep 2
#        if ! pg_isready -q 2>/dev/null; then
#            echo -e "${RED}❌ Failed to start PostgreSQL${NC}"
#            echo "   Please start it manually and try again"
#            exit 1
#        fi
#    else
#        echo -e "${RED}❌ PostgreSQL is not running and brew is not available${NC}"
#        echo "   Please start PostgreSQL manually"
#        exit 1
#    fi
#fi
#echo -e "${GREEN}✅ PostgreSQL is running${NC}"

# Check for .env file
#if [ ! -f .env ]; then
#    echo -e "${YELLOW}⚠️  .env file not found${NC}"
#    if [ -f .env.example ]; then
#        cp .env.example .env
#        echo -e "${GREEN}✅ Created .env file from template${NC}"
#        echo -e "${YELLOW}   Please add your API keys to .env file${NC}"
#    else
#        echo -e "${RED}❌ No .env.example file found${NC}"
#        echo "   Please create .env file with your API keys"
#        exit 1
#    fi
#fi

# Check Python virtual environment
if [ ! -d "venv" ]; then
    echo -e "${BLUE}📦 Creating Python virtual environment...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    pip install -q -r requirements.txt
    echo -e "${GREEN}✅ Python environment ready${NC}"
else
    source venv/bin/activate
fi

# Install Ruby dependencies if needed
if ! bundle check > /dev/null 2>&1; then
    echo -e "${BLUE}📦 Installing Ruby dependencies...${NC}"
    bundle install --quiet
    echo -e "${GREEN}✅ Ruby dependencies installed${NC}"
fi

# Install Node dependencies if needed
if [ ! -d "node_modules" ] || ! npm list > /dev/null 2>&1; then
    echo -e "${BLUE}📦 Installing Node dependencies...${NC}"
    npm install --silent
    echo -e "${GREEN}✅ Node dependencies installed${NC}"
fi

# Setup database if needed
if ! rails db:version > /dev/null 2>&1; then
    echo -e "${BLUE}🗄️  Setting up database...${NC}"
    rails db:create > /dev/null 2>&1
    rails db:migrate > /dev/null 2>&1
    echo -e "${GREEN}✅ Database ready${NC}"
else
    # Run pending migrations if any
    if rails db:migrate:status 2>/dev/null | grep -q "down"; then
        echo -e "${BLUE}🗄️  Running pending migrations...${NC}"
        rails db:migrate > /dev/null 2>&1
        echo -e "${GREEN}✅ Migrations completed${NC}"
    fi
fi

# Clean up old PID files
rm -f tmp/pids/server.pid 2>/dev/null

# Compile assets
echo -e "${BLUE}🎨 Compiling assets...${NC}"
rails tailwindcss:build > /dev/null 2>&1
echo -e "${GREEN}✅ Assets compiled${NC}"

# Create log directory if it doesn't exist
mkdir -p log

# Start services
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All checks passed! Starting services...${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📍 Rails Server:${NC} http://localhost:3000/playground"
echo -e "${BLUE}📍 Python API:${NC}   http://localhost:8000"
echo -e "${BLUE}📍 API Docs:${NC}      http://localhost:8000/docs"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down services...${NC}"
    ./stop.sh
    exit 0
}

# Trap Ctrl+C
trap cleanup INT

# Start Rails server in background
echo -e "${BLUE}Starting Rails server...${NC}"
rails server -b 0.0.0.0 > log/rails.log 2>&1 &
RAILS_PID=$!

# Wait for Rails to start
sleep 3

# Start Python API server in background
echo -e "${BLUE}Starting Python API server...${NC}"
source venv/bin/activate
python lib/llm_api_server.py > log/python_api.log 2>&1 &
PYTHON_PID=$!

# Wait for Python API to start
sleep 2

# Check if services started successfully
if kill -0 $RAILS_PID 2>/dev/null && kill -0 $PYTHON_PID 2>/dev/null; then
    echo ""
    echo -e "${GREEN}✅ All services started successfully!${NC}"
    echo ""
    echo -e "${BLUE}Logs:${NC}"
    echo "  Rails: tail -f log/rails.log"
    echo "  Python: tail -f log/python_api.log"
    echo ""

    # Keep the script running
    while true; do
        if ! kill -0 $RAILS_PID 2>/dev/null; then
            echo -e "${RED}Rails server stopped unexpectedly${NC}"
            cleanup
        fi
        if ! kill -0 $PYTHON_PID 2>/dev/null; then
            echo -e "${RED}Python API server stopped unexpectedly${NC}"
            cleanup
        fi
        sleep 5
    done
else
    echo -e "${RED}❌ Failed to start services${NC}"
    echo "Check the logs for more information:"
    echo "  log/rails.log"
    echo "  log/python_api.log"
    cleanup
fi
