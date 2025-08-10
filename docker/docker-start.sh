#!/bin/bash

echo "🚀 Starting LLM Play application..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "Please create .env file from .env.example and configure your settings"
    exit 1
fi

# Start all services
echo "🔄 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service status
echo "📊 Service status:"
docker-compose ps

# Run database migrations
echo "🗄️ Running database migrations..."
docker-compose exec rails bundle exec rails db:create 2>/dev/null
docker-compose exec rails bundle exec rails db:migrate

echo ""
echo "✅ Application started successfully!"
echo "🌐 Access the application at:"
echo "   - Main App: http://localhost"
echo "   - Rails Direct: http://localhost:3000"
echo "   - Python API: http://localhost:8000"
echo ""
echo "📋 View logs with: docker-compose logs -f"
echo "🛑 Stop with: ./docker-stop.sh"