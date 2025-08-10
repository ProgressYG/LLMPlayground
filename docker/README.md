# 🐳 LLM Play Docker Deployment Guide

## 📋 Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 8GB+ RAM available
- 10GB+ disk space

## 🚀 Quick Start

### 1. Prepare Environment

```bash
cd docker
cp .env.example .env
```

Edit `.env` file with your configuration:
- Add your LLM API keys (OpenAI, Anthropic, Google)
- Set database password
- Add Rails master key

### 2. Generate Rails Master Key (if needed)

```bash
cd ..
rails secret > docker/rails/master.key
```

### 3. Build and Start

```bash
cd docker
chmod +x *.sh
./docker-build.sh
./docker-start.sh
```

### 4. Access Application

- **Main Application**: http://localhost
- **Rails Direct**: http://localhost:3000
- **Python API**: http://localhost:8000
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

## 🏗️ Architecture

```
┌─────────────┐
│    Nginx    │ Port 80/443
│(Reverse Proxy)│
└──────┬──────┘
       │
   ┌───┴────┐
   │        │
┌──▼───┐ ┌─▼──────┐
│Rails │ │Python  │
│ App  │ │FastAPI │
└──┬───┘ └────────┘
   │
┌──▼───────────┐
│  PostgreSQL  │
│   + Redis    │
└──────────────┘
```

## 📦 Container Services

| Service | Port | Description |
|---------|------|-------------|
| nginx | 80, 443 | Reverse proxy & load balancer |
| rails | 3000 | Main Rails application |
| python_api | 8000 | LLM API service |
| postgres | 5432 | PostgreSQL database |
| redis | 6379 | Cache & ActionCable |

## 🔧 Management Commands

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rails
docker-compose logs -f python_api
```

### Execute Commands
```bash
# Rails console
docker-compose exec rails bundle exec rails console

# Database console
docker-compose exec postgres psql -U llmplay -d llm_play_production

# Python shell
docker-compose exec python_api python
```

### Restart Services
```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart rails
```

### Stop Application
```bash
./docker-stop.sh
```

### Remove Everything
```bash
# Stop and remove containers
docker-compose down

# Also remove volumes (data)
docker-compose down -v
```

## 📊 Resource Usage

### Recommended Minimum
- CPU: 2 cores
- RAM: 4GB
- Disk: 10GB

### Optimal Performance
- CPU: 4 cores
- RAM: 8GB
- Disk: 20GB

## 🔍 Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres pg_isready
```

### Rails Not Starting
```bash
# Check Rails logs
docker-compose logs rails

# Rebuild Rails container
docker-compose build --no-cache rails
```

### Python API Issues
```bash
# Check Python logs
docker-compose logs python_api

# Test health endpoint
curl http://localhost:8000/health
```

### Port Conflicts
```bash
# Check port usage
lsof -i :80
lsof -i :3000
lsof -i :8000

# Change ports in docker-compose.yml if needed
```

## 🔒 Security Notes

1. **Change default passwords** in `.env`
2. **Keep API keys secure** - never commit `.env` to git
3. **Use HTTPS in production** - configure SSL certificates in nginx
4. **Regular updates** - keep Docker images updated
5. **Firewall rules** - restrict ports in production

## 📈 Scaling

### Horizontal Scaling
```yaml
# In docker-compose.yml, add replicas
services:
  rails:
    deploy:
      replicas: 3
```

### Resource Limits
```yaml
# Add resource constraints
services:
  rails:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## 🆘 Support

For issues or questions:
1. Check logs: `docker-compose logs`
2. Verify environment: `docker-compose config`
3. Test health: `docker-compose ps`
4. Review this guide

## 📝 Notes

- Data persists in Docker volumes
- Logs are stored in volumes
- Configuration via environment variables
- Auto-restart on failure enabled

---

**Version**: 1.0.0
**Last Updated**: 2025-08-10