.PHONY: help build up down restart logs clean db-shell redis-shell test health

# Default target
help:
	@echo "MyApp - Docker Development Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build      - Build all Docker images"
	@echo "  up         - Start all services"
	@echo "  down       - Stop all services"
	@echo "  restart    - Restart all services"
	@echo "  logs       - View logs from all services"
	@echo "  logs-f     - Follow logs from all services"
	@echo "  clean      - Remove all containers, volumes, and images"
	@echo "  db-shell   - Open PostgreSQL shell"
	@echo "  redis-shell - Open Redis CLI"
	@echo "  test       - Run API tests"
	@echo "  health     - Check health of all services"
	@echo "  backup-db  - Backup database"
	@echo "  restore-db - Restore database from backup"

# Build all images
build:
	docker-compose build

# Start all services
up:
	docker-compose up -d
	@echo "Services started!"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend:  http://localhost:8080"
	@echo "Run 'make logs-f' to see logs"

# Start with build
up-build:
	docker-compose up -d --build
	@echo "Services built and started!"

# Stop all services
down:
	docker-compose down

# Restart all services
restart:
	docker-compose restart

# View logs
logs:
	docker-compose logs

# Follow logs
logs-f:
	docker-compose logs -f

# View specific service logs
logs-backend:
	docker-compose logs -f backend

logs-frontend:
	docker-compose logs -f frontend

logs-db:
	docker-compose logs -f db

logs-redis:
	docker-compose logs -f redis

# Clean everything
clean:
	docker-compose down -v
	docker system prune -f

# Deep clean (including images)
clean-all:
	docker-compose down -v --rmi all
	docker system prune -af

# PostgreSQL shell
db-shell:
	docker exec -it myapp_db psql -U myapp -d myapp_db

# Redis CLI
redis-shell:
	docker exec -it myapp_redis redis-cli -a redis_password

# Run tests
test:
	@echo "Running API tests..."
	@curl -s http://localhost:8080/health | jq .
	@curl -s http://localhost:8080/api/items | jq .

# Health check
health:
	@echo "Checking service health..."
	@echo "\n=== Backend Health ==="
	@curl -s http://localhost:8080/health | jq . || echo "Backend is down"
	@echo "\n=== Database Status ==="
	@docker exec myapp_db pg_isready -U myapp || echo "Database is down"
	@echo "\n=== Redis Status ==="
	@docker exec myapp_redis redis-cli -a redis_password ping || echo "Redis is down"
	@echo "\n=== Frontend Status ==="
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || echo "Frontend is down"

# Backup database
backup-db:
	@mkdir -p backups
	docker exec myapp_db pg_dump -U myapp myapp_db > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Database backed up to backups/"

# Restore database (usage: make restore-db FILE=backups/backup_20240101_120000.sql)
restore-db:
	@if [ -z "$(FILE)" ]; then echo "Usage: make restore-db FILE=backups/backup_XXXXXX.sql"; exit 1; fi
	docker exec -i myapp_db psql -U myapp myapp_db < $(FILE)
	@echo "Database restored from $(FILE)"

# Reset database
reset-db:
	docker-compose down -v
	docker-compose up -d db
	@echo "Waiting for database to be ready..."
	@sleep 5
	docker-compose up -d
	@echo "Database reset complete!"

# Development mode
dev:
	docker-compose up

# Production mode
prod:
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Install dependencies (for local development)
install:
	@echo "Installing backend dependencies..."
	cd backend && zig build
	@echo "Installing frontend dependencies..."
	cd frontend && cargo build

# Format code
format:
	@echo "Formatting Zig code..."
	find backend/src -name "*.zig" -exec zig fmt {} \;
	@echo "Formatting Rust code..."
	cd frontend && cargo fmt

# Lint code
lint:
	@echo "Linting Rust code..."
	cd frontend && cargo clippy

# Show container status
ps:
	docker-compose ps

# Show container resource usage
stats:
	docker stats

# Update images
update:
	docker-compose pull
	docker-compose up -d --build