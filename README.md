# Fontanella — Sistema de Citas Legales

Sistema de gestión de citas legales que opera en múltiples países y husos horarios.

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) / [Podman](https://podman.io/) y Compose
- [Make](https://www.gnu.org/software/make/)
- [Sqitch](https://sqitch.org/download/) — gestor de migraciones SQL
- (Opcional) [SQLFluff](https://docs.sqlfluff.com/) — `pip install sqlfluff`
- (Opcional) [pgFormatter](https://github.com/darold/pgFormatter) — `brew install pgformatter` / `apt install pgformatter`

### Instalar Sqitch

| OS | Comando |
|----|---------|
| Fedora/RHEL | `sudo dnf install sqitch` o `cpanm App::Sqitch DBD::Pg` |
| macOS | `brew install sqitch_pg` |
| Debian/Ubuntu | `sudo apt install sqitch` |

## Inicio rápido

```bash
make build    # Construir imagen PG17 con pgTAP
make up       # Levantar PostgreSQL
make deploy   # Desplegar todas las migraciones
make test     # Ejecutar ciclo completo de tests
```

## Comandos disponibles

Ejecutar `make help` para ver todos los targets. Los principales:

| Comando          | Descripción |
|------------------|-------------|
| `make up`        | Iniciar PostgreSQL |
| `make down`      | Detener PostgreSQL |
| `make deploy`    | Desplegar migraciones |
| `make revert`    | Revertir migraciones |
| `make verify`    | Verificar migraciones |
| `make status`    | Estado actual de migraciones |
| `make test`      | Ejecutar tests pgTAP |
| `make psql`      | Consola psql interactiva |
| `make lint`      | Lint SQL con SQLFluff |
| `make format`    | Formatear SQL con pgFormatter |
| `make clean`     | Eliminar volumen de datos (destructivo) |

## Por qué Sqitch

Este proyecto usa [Sqitch](https://sqitch.org/) para gestionar migraciones de base de datos.
A diferencia de herramientas como Flyway o Liquibase:

- **SQL puro**: Los scripts son SQL nativo de PostgreSQL. No hay abstracción XML/YAML/JSON.
  Usás las mismas sentencias que ejecutarías manualmente.

- **Grafo de dependencias**: El orden de ejecución se define por dependencias explícitas
  entre cambios, no por convenciones de nombre de archivo. Esto hace imposible desplegar
  una tabla antes que su dependencia.

- **Rework**: Después de un release, se pueden modificar cambios existentes con `sqitch rework`
  sin crear migraciones parche. Sqitch mantiene el historial de ambas versiones.

- **Verificación integrada**: Cada cambio incluye un script de verificación que se ejecuta
  automáticamente en cada deploy. Si algo no está como se espera, el deploy falla.

- **Plan file como fuente de verdad**: El archivo `sqitch.plan` contiene todo el historial
  de cambios con sus dependencias, legible por humanos y versionable con git.

## Workflow de desarrollo

### Día a día

1. Editar scripts en `deploy/`, `verify/`, `revert/`
2. `make deploy` para probar los cambios
3. `make test` para verificar el ciclo completo
4. `make lint` para verificar estilo

### Agregar un cambio nuevo

```bash
sqitch add nombre_cambio \
    --requires dependencia1 \
    --requires dependencia2 \
    -n 'Descripción del cambio'
```

Esto crea los tres archivos (`deploy/`, `verify/`, `revert/`) y agrega la entrada al plan.

### Modificar un cambio ya tagueado

```bash
sqitch rework nombre_cambio -n 'Descripción de la modificación'
```

Importante: solo usar `rework` después de un tag. Antes del tag, editar los archivos directamente.

## Referencia rápida de Sqitch

| Comando | Descripción |
|---------|-------------|
| `sqitch add` | Crear un nuevo cambio |
| `sqitch deploy` | Desplegar cambios pendientes |
| `sqitch verify` | Verificar cambios desplegados |
| `sqitch revert` | Revertir cambios |
| `sqitch rework` | Modificar un cambio post-release |
| `sqitch tag` | Crear un tag (punto de rollback) |
| `sqitch status` | Ver estado actual |
| `sqitch log` | Ver historial de deploys |

## Ambientes

| Ambiente    | Base de datos    | Estrategia |
|-------------|-----------------|-------------|
| local       | `fontanella_dev` (localhost:5432) | Deploy incremental. Revert libre. Tests pgTAP. |
| staging     | PostgreSQL externo (CI/CD) | Deploy a latest. Espejo del flujo de producción. |
| producción  | PostgreSQL externo (CI/CD) | Deploy con tag checkpoint. Rollback: `sqitch revert --to @TAG`. |

Para apuntar a un ambiente externo:

```bash
SQITCH_TARGET="db:pg://user:pass@host:5432/dbname" make deploy
```

O definir targets adicionales en `sqitch.conf`.

### Estrategia de versionado

- Tags de Sqitch alineados con semver: `v0.1.0`, `v0.2.0`, etc.
- Crear tag **antes** de cada deploy a producción: `sqitch tag v0.1.0 -n 'Descripción'`
- El tag es el punto de rollback seguro. Si un deploy falla, Sqitch revierte al último tag.
- Tags de git en `main` alineados con los tags de Sqitch.

### Pipeline CI/CD

```
lint (SQLFluff) → test (revert + deploy + verify + pgTAP) → deploy staging → deploy producción
```

## Herramientas de calidad SQL

### SQLFluff (linting)

Configurado en `.sqlfluff`. Verifica estilo y convenciones:
- Keywords y tipos en UPPER CASE
- Indentación de 4 espacios
- Líneas de hasta 120 caracteres

```bash
make lint                          # Verificar
sqlfluff fix deploy/ verify/       # Auto-corregir
```

### pgFormatter (formateo)

Configurado en `.pg_format`. Formatea SQL específico de PostgreSQL:

```bash
make format    # Formatear todos los scripts
```

### pgTAP (testing)

Framework de testing unitario para PostgreSQL. Los tests están en `test/pgtap/`.
Se ejecutan dentro del contenedor de PostgreSQL (no requiere instalación local).

```bash
make test    # Ejecutar tests pgTAP (requiere migraciones desplegadas)
```

## Estructura del proyecto

```
fontanella/
├── docker/                    # Infraestructura Docker/Podman
│   ├── docker-compose.yml
│   └── postgres/
│       └── Dockerfile         # PG17 + pgTAP
├── sqitch.conf                # Configuración de Sqitch
├── sqitch.plan                # Plan de migraciones
├── deploy/                    # Scripts de despliegue
├── revert/                    # Scripts de reversión
├── verify/                    # Scripts de verificación
├── test/pgtap/                # Tests pgTAP
├── Makefile                   # Task runner
├── CLAUDE.md                  # Instrucciones para LLMs
├── DECISIONES.md              # Diseño y decisiones técnicas
└── README.md                  # Este archivo
```
