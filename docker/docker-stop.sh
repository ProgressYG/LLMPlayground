#!/bin/bash

echo "🛑 Stopping LLM Play application..."

# Stop all services
docker-compose down

echo "✅ All services stopped"
echo ""
echo "💡 To remove volumes (database data), run:"
echo "   docker-compose down -v"
echo ""
echo "🔄 To restart, run:"
echo "   ./docker-start.sh"