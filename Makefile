# Makefile - Todos los comandos se ejecutan dentro de Docker
# Asegúrate de que los servicios estén corriendo: make docker-up

.PHONY: help setup server test format seed admin migrate reset-db docker-up docker-down docker-build docker-dev

SHELL := /bin/bash

# Variables para Docker Compose
COMPOSE := docker compose
APP_SERVICE := app
DB_SERVICE := db

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# Docker commands
docker-up: ## Inicia los servicios de producción (app + PostgreSQL)
	$(COMPOSE) up -d

docker-down: ## Detiene los servicios de Docker
	$(COMPOSE) down

docker-build: ## Reconstruye la imagen Docker
	$(COMPOSE) build --no-cache

docker-logs: ## Muestra los logs de la aplicación
	$(COMPOSE) logs -f $(APP_SERVICE)

docker-shell: ## Abre una shell dentro del contenedor app
	$(COMPOSE) exec $(APP_SERVICE) /bin/sh

# Development commands usando el contenedor de producción con bin/claude_mock eval
dev-exec = $(COMPOSE) exec $(APP_SERVICE) /app/bin/claude_mock eval

server: ## Muestra logs del servidor (el servidor ya corre con docker-up)
	@echo "El servidor de producción ya debería estar corriendo con 'make docker-up'"
	@echo "Accede en: http://localhost:4004"
	$(COMPOSE) logs -f $(APP_SERVICE)

migrate: ## Ejecuta las migraciones de la base de datos
	$(COMPOSE) exec $(APP_SERVICE) /app/bin/migrate

reset-db: ## Resetea completamente la base de datos (cuidado: borra todo)
	@echo "⚠️  Esto borrará TODOS los datos de la base de datos"
	@bash -c 'read -p "¿Estás seguro? (escribe yes para confirmar): " confirm && [ "$$confirm" = "yes" ] || exit 1'
	$(COMPOSE) exec $(APP_SERVICE) /app/bin/claude_mock eval 'ClaudeMock.Release.reset_db()'

seed: ## Importa conversaciones desde priv/conversations/
	$(COMPOSE) exec $(APP_SERVICE) /app/bin/seed

# Admin creation (interactivo)
admin: ## Crea un usuario administrador (interactivo)
	@echo ""
	@echo "--- Crear usuario admin ---"
	@echo ""
	@bash -c 'read -p "Email del admin: " email; echo; read -s -p "Password del admin (mín. 12 caracteres): " password; echo; echo; $(COMPOSE) exec -T $(APP_SERVICE) /app/bin/claude_mock eval "ClaudeMock.Release.create_admin(\"$$email\", \"$$password\")"'

# Status
status: ## Muestra el estado de los servicios Docker
	@echo "=== Servicios de Docker ==="
	$(COMPOSE) ps
