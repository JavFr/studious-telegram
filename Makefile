# ============================================
# Fontanella — Task runner
# ============================================

COMPOSE_FILE := docker/docker-compose.yml
SQITCH       := sqitch
DB           := db:pg://fontanella:fontanella@localhost:5432/fontanella_dev

# ============================================
# Docker
# ============================================

.PHONY: up down build ps logs

up:                    ## Iniciar PostgreSQL
	docker compose -f $(COMPOSE_FILE) up -d

down:                  ## Detener PostgreSQL
	docker compose -f $(COMPOSE_FILE) down

build:                 ## Reconstruir imagen de PostgreSQL
	docker compose -f $(COMPOSE_FILE) build

ps:                    ## Estado de los contenedores
	docker compose -f $(COMPOSE_FILE) ps

logs:                  ## Ver logs de PostgreSQL
	docker compose -f $(COMPOSE_FILE) logs -f postgres

# ============================================
# Sqitch
# ============================================

.PHONY: deploy revert verify status log

deploy:                ## Desplegar migraciones
	$(SQITCH) deploy $(DB)

revert:                ## Revertir migraciones
	$(SQITCH) revert $(DB)

verify:                ## Verificar migraciones
	$(SQITCH) verify $(DB)

status:                ## Estado de migraciones
	$(SQITCH) status $(DB)

log:                   ## Log de migraciones
	$(SQITCH) log $(DB)

# ============================================
# Testing
# ============================================

.PHONY: test

test:                  ## Ejecutar tests pgTAP
	@docker compose -f $(COMPOSE_FILE) exec -T postgres \
		psql -U fontanella -d fontanella_dev -qc "CREATE EXTENSION IF NOT EXISTS pgtap;" 2>/dev/null
	docker cp test/pgtap fontanella-postgres:/tmp/pgtap
	docker compose -f $(COMPOSE_FILE) exec -T postgres \
		bash -c 'pg_prove -U fontanella -d fontanella_dev /tmp/pgtap/*.sql'

# ============================================
# Seed data
# ============================================

CONTAINER := fontanella-postgres

.PHONY: seed seed-volume seed-all seed-reset

seed:                  ## Cargar datos base determinísticos
	docker cp seed/seed.sql $(CONTAINER):/tmp/seed.sql
	docker compose -f $(COMPOSE_FILE) exec -T postgres \
		psql -U fontanella -d fontanella_dev -f /tmp/seed.sql

seed-volume:           ## Generar volumen de datos (requiere seed)
	docker cp seed/seed_volume.sql $(CONTAINER):/tmp/seed_volume.sql
	docker compose -f $(COMPOSE_FILE) exec -T postgres \
		psql -U fontanella -d fontanella_dev -f /tmp/seed_volume.sql

seed-all: seed seed-volume  ## Cargar datos base + volumen

seed-reset:            ## Resetear datos y re-sembrar (DESTRUCTIVO)
	docker compose -f $(COMPOSE_FILE) exec -T postgres \
		psql -U fontanella -d fontanella_dev -c \
		"TRUNCATE appointments, availability_overrides, availability_rules, \
		lawyer_appointment_types, appointment_types, client_profiles, \
		lawyers, organization_members, organizations, users \
		RESTART IDENTITY CASCADE;"
	$(MAKE) seed-all

# ============================================
# Calidad SQL
# ============================================

.PHONY: lint format

lint:                  ## Lint SQL con SQLFluff
	sqlfluff lint deploy/ verify/ revert/

format:                ## Formatear SQL con pgFormatter
	find deploy/ revert/ verify/ -name '*.sql' -exec pg_format -i {} \;

# ============================================
# Utilidades
# ============================================

.PHONY: psql clean help

psql:                  ## Consola psql interactiva
	docker compose -f $(COMPOSE_FILE) exec postgres psql -U fontanella fontanella_dev

clean:                 ## Eliminar volumen de datos (DESTRUCTIVO)
	docker compose -f $(COMPOSE_FILE) down -v

help:                  ## Mostrar esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
