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
