#!/bin/bash

echo "Starting Rails server..."
rails server -b 0.0.0.0 -p 3000 &
RAILS_PID=$!
echo "Rails server started with PID: $RAILS_PID"

echo "Waiting for Rails to start..."
sleep 5

echo "Starting Python LLM API server..."
source venv/bin/activate
python lib/llm_api_server.py &
PYTHON_PID=$!
echo "Python server started with PID: $PYTHON_PID"

echo ""
echo "================================"
echo "Servers are running!"
echo "Rails: http://localhost:3000/playground"
echo "Python API: http://localhost:8000"
echo "================================"
echo ""
echo "Press Ctrl+C to stop all servers"

wait