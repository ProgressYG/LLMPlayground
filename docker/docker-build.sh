#!/bin/bash

echo "🐳 Building LLM Play Docker containers..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "📝 Creating .env from .env.example..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your API keys and configuration"
    exit 1
fi

# Build all containers
echo "🔨 Building containers..."
docker-compose build --no-cache

echo "✅ Build complete!"
echo "📦 Images created:"
docker images | grep llm_

echo ""
echo "🚀 To start the application, run:"
echo "   ./docker-start.sh"