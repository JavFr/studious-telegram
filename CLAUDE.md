# CLAUDE.md — Instrucciones para LLMs

## Proyecto

Sistema de gestión de citas legales. PostgreSQL 17 + Sqitch para migraciones.
El modelo de datos y las decisiones de diseño están documentadas en `DECISIONES.md`.

## Stack

- **Base de datos**: PostgreSQL 17 (Docker/Podman)
- **Migraciones**: Sqitch (instalación local)
- **Testing**: pgTAP (compilado en la imagen Docker de PG)
- **Linting**: SQLFluff (`pip install sqlfluff`)
- **Formateo**: pgFormatter (`pg_format`)
- **Task runner**: Make

## Estructura de archivos SQL

```
deploy/<cambio>.sql    → CREATE/ALTER envuelto en BEGIN...COMMIT
verify/<cambio>.sql    → SELECT que falla si el cambio no existe
revert/<cambio>.sql    → DROP/ALTER inverso envuelto en BEGIN...COMMIT
```

## Sqitch — Reglas obligatorias

### Antes de un release tag

- Los scripts de deploy/revert/verify se pueden editar directamente.
- NO crear migraciones nuevas para corregir una migración existente que aún no fue tagueada.
- Editar el archivo en `deploy/`, `revert/` y `verify/` directamente.

### Después de un release tag

- NUNCA editar scripts que ya fueron tagueados.
- Usar `sqitch rework <nombre_cambio>` para modificar un cambio existente.
- Rework requiere que exista un tag entre la versión anterior y la nueva.

### Regla de los tres scripts

Cada cambio DEBE tener deploy + verify + revert:

- **deploy**: `CREATE`/`ALTER` con `BEGIN;...COMMIT;`
- **verify**: `SELECT` que falla si el cambio no existe (ver patrones abajo)
- **revert**: `DROP`/`ALTER` inverso con `BEGIN;...COMMIT;`

### Patrones de verificación

```sql
-- Verificar que una tabla y sus columnas existen
SELECT col1, col2, col3 FROM mi_tabla WHERE FALSE;

-- Verificar que un constraint/índice/extensión existe
SELECT 1 / COUNT(*) FROM pg_constraint WHERE conname = '...';
SELECT 1 / COUNT(*) FROM pg_indexes WHERE indexname = '...';
SELECT 1 / COUNT(*) FROM pg_extension WHERE extname = '...';
```

### Dependencias

- Declarar TODAS las dependencias explícitamente con `sqitch add --requires`.
- Si la tabla B tiene un FK a la tabla A, B depende de A.
- Si se usa una extensión (btree_gist), el cambio depende de `extensions`.

### Idempotencia

- Los verify scripts DEBEN ser idempotentes (ejecutar N veces = mismo resultado).
- Los deploy/revert NO necesitan ser idempotentes — Sqitch los ejecuta una sola vez.

### Tags y releases

- Antes de cada deploy a producción: `sqitch tag vX.Y.Z -n 'Descripción'`
- El tag marca un punto de retorno seguro ante fallos.
- Sqitch revierte automáticamente al último tag si un deploy falla.

## Errores comunes a evitar

1. **Crear migración nueva para arreglar una no tagueada** → Editar directamente el script existente.
2. **Olvidar dependencias** → Causa fallo en deploy si las tablas se despliegan en orden incorrecto.
3. **Verify no idempotente** → El verify se ejecuta automáticamente en cada deploy. Si no es idempotente, falla.
4. **Revert incompleto** → Si el revert no deshace todo, `sqitch revert` deja la DB inconsistente.
5. **No usar BEGIN/COMMIT** → Sin transacción, un fallo parcial deja la DB en estado inconsistente.
6. **Editar scripts ya tagueados** → Causa schema drift entre ambientes. Usar `sqitch rework`.
7. **No verificar el exclusion constraint** → `appointments` tiene un `EXCLUDE USING GIST`. Verificar que existe.

## Comandos frecuentes

```bash
make up              # Iniciar PostgreSQL
make deploy          # Desplegar migraciones (dev)
make revert          # Revertir migraciones (dev)
make verify          # Verificar migraciones (dev)
make test            # Ciclo completo de test (revert + deploy + verify + pgTAP)
make psql            # Consola psql (dev)
make lint            # Lint SQL con SQLFluff
make format          # Formatear SQL con pgFormatter
make status          # Estado de migraciones
make help            # Ver todos los targets
```

## Modelo de datos — Puntos clave

- `TIMESTAMPTZ` para instantes absolutos (citas agendadas).
- `TIME` + `TEXT` (IANA timezone) para horarios recurrentes (disponibilidad).
- `EXCLUDE USING GIST` para prevenir solapamiento de citas (requiere `btree_gist`).
- Perfil de cliente por organización (aislamiento entre estudios jurídicos).
- Ver `DECISIONES.md` para el DDL completo y las justificaciones.
