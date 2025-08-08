#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}🛑 Stopping LLM API Playground services...${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

STOPPED_SERVICES=0

# Function to stop a service
stop_service() {
    local SERVICE_NAME=$1
    local PORT=$2
    local PIDS=$(lsof -ti:$PORT 2>/dev/null)
    
    if [ ! -z "$PIDS" ]; then
        echo -e "${YELLOW}Stopping $SERVICE_NAME (Port: $PORT)...${NC}"
        for PID in $PIDS; do
            echo "  Killing process $PID..."
            kill -TERM $PID 2>/dev/null
            sleep 1
            # Force kill if still running
            if kill -0 $PID 2>/dev/null; then
                kill -9 $PID 2>/dev/null
            fi
        done
        echo -e "${GREEN}✅ $SERVICE_NAME stopped${NC}"
        STOPPED_SERVICES=$((STOPPED_SERVICES + 1))
    else
        echo -e "${BLUE}ℹ️  $SERVICE_NAME is not running${NC}"
    fi
}

# Stop Rails server
stop_service "Rails server" 3000

# Stop Python API server
stop_service "Python API server" 8000

# Clean up Rails PID file
if [ -f tmp/pids/server.pid ]; then
    echo "Cleaning up Rails PID file..."
    rm -f tmp/pids/server.pid
fi

# Kill any remaining Ruby/Rails processes
RUBY_PIDS=$(pgrep -f "rails server" 2>/dev/null)
if [ ! -z "$RUBY_PIDS" ]; then
    echo -e "${YELLOW}Stopping remaining Rails processes...${NC}"
    kill -9 $RUBY_PIDS 2>/dev/null
    STOPPED_SERVICES=$((STOPPED_SERVICES + 1))
fi

# Kill any remaining Python API processes
PYTHON_PIDS=$(pgrep -f "llm_api_server" 2>/dev/null)
if [ ! -z "$PYTHON_PIDS" ]; then
    echo -e "${YELLOW}Stopping remaining Python processes...${NC}"
    kill -9 $PYTHON_PIDS 2>/dev/null
    STOPPED_SERVICES=$((STOPPED_SERVICES + 1))
fi

# Kill any foreman processes
FOREMAN_PIDS=$(pgrep -f foreman 2>/dev/null)
if [ ! -z "$FOREMAN_PIDS" ]; then
    echo -e "${YELLOW}Stopping foreman processes...${NC}"
    kill -9 $FOREMAN_PIDS 2>/dev/null
fi

# Kill any webpack-dev-server processes
WEBPACK_PIDS=$(pgrep -f webpack-dev-server 2>/dev/null)
if [ ! -z "$WEBPACK_PIDS" ]; then
    echo -e "${YELLOW}Stopping webpack processes...${NC}"
    kill -9 $WEBPACK_PIDS 2>/dev/null
fi

echo ""
if [ $STOPPED_SERVICES -gt 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ All services stopped successfully${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
else
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}ℹ️  No services were running${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
fi
echo ""