# Diseño del modelo de datos — Sistema de citas legales

## Contexto

Sistema de gestión de citas legales que opera en múltiples países y husos horarios.
Los abogados pertenecen a estudios jurídicos (organizaciones), tienen calendarios propios,
y las citas pueden ser presenciales, por videollamada o telefónicas.

Este documento refleja el proceso de diseño iterativo del modelo de datos,
detallando cada decisión, sus alternativas, y el razonamiento detrás de la elección.

---

## Características arquitectónicas priorizadas

| Prioridad | Característica | Justificación |
|-----------|---------------|---------------|
| Alta | Reliability | Dos turnos que se pisan, o un turno mal registrado, implica pérdida de dinero y reputación para los estudios. |
| Alta | Rendimiento y disponibilidad | Problemas en la toma de turnos desincentivan el uso de la plataforma. |
| Alta | Simplicidad | El dominio no justifica una arquitectura compleja. Se priorizan bajos costos de infraestructura y desarrollo. |
| Baja | Agilidad e interoperabilidad | Se prefiere una solución robusta y simple. La extensibilidad no es prioritaria en la primera iteración. |

---

## Decisiones de diseño

### 1. Estrategia de zonas horarias

**Decisión**: Usar `TIMESTAMPTZ` (UTC) para instantes absolutos y `TIME` + identificador IANA para horarios recurrentes.

#### Problema

El sistema opera en múltiples países con distintos husos horarios y reglas de horario de verano (DST).
Una cita entre un abogado en Buenos Aires y un cliente en Madrid involucra dos timezones distintas
que pueden cambiar independientemente por DST.

#### Alternativas evaluadas

| Enfoque | Descripción | Problema |
|---------|-------------|----------|
| Guardar offset fijo (ej: `-03:00`) | Almacenar la hora con un desplazamiento numérico | El offset es una foto estática. No se adapta a cambios de DST. |
| Guardar todo en UTC | Convertir todo a UTC al guardar | Funciona para citas, pero para disponibilidades recurrentes ("lunes 9-17") pierde el significado local. Si cambia el DST, la hora UTC equivalente cambia, pero el registro no. |
| **Instantes en UTC + horarios locales con IANA tz** | Citas como `TIMESTAMPTZ`, disponibilidades como `TIME` + `TEXT` (IANA timezone name) | Elegido. |

#### Razonamiento

Existen dos tipos de dato temporal fundamentalmente distintos en el sistema:

- **Citas (instantes absolutos)**: Una vez agendada, una cita representa un momento fijo en el tiempo.
  No cambia si un país modifica sus reglas de DST. Se almacena como `TIMESTAMPTZ`, que internamente
  guarda UTC y convierte al leer.

- **Disponibilidades recurrentes (hora local)**: Cuando un abogado dice "trabajo de 9 a 17",
  se refiere a su hora local. Si cambia el DST, el abogado sigue trabajando de 9 a 17 hora local,
  pero el equivalente UTC cambió. Se almacena como `TIME` + identificador IANA (ej: `America/Buenos_Aires`).

El identificador IANA (no el offset numérico) es clave porque encapsula las reglas de transición
de DST. Las librerías y bases de datos lo usan para calcular el offset correcto según la fecha específica.

**Consideración operativa**: La base de datos IANA se actualiza periódicamente porque los gobiernos
modifican reglas de DST. Mantener actualizados el SO, la DB y las dependencias del runtime es
parte de que esta estrategia funcione correctamente.

---

### 2. Modelo de disponibilidad: Whitelist

**Decisión**: Los abogados definen explícitamente cuándo están disponibles (whitelist). Todo lo no definido se considera no disponible.

#### Alternativas evaluadas

| Enfoque | Descripción | Riesgo |
|---------|-------------|--------|
| **Whitelist (disponibilidad explícita)** | El abogado define cuándo SÍ está disponible. | Si algo no se cargó, simplemente no se ofrece. Seguro. **Elegido.** |
| Blacklist (indisponibilidad sobre default) | Se asume un horario base y el abogado marca cuándo NO está. | Si se olvida de cargar un bloqueo, se ofrece un turno incorrecto. |

#### Razonamiento

En un sistema legal, ofrecer un turno incorrecto tiene un costo alto (reputación del estudio,
potencial impacto legal). El modelo whitelist es inherentemente más seguro: el peor caso es
no ofrecer un horario que sí estaba disponible, lo cual es preferible a ofrecer uno que no lo estaba.

---

### 3. Cálculo de slots: Lazy (reglas en runtime)

**Decisión**: Almacenar reglas de disponibilidad y calcular los slots libres en tiempo de consulta, en lugar de pre-generar slots individuales.

#### Alternativas evaluadas

| Enfoque | Descripción | Ventajas | Desventajas |
|---------|-------------|----------|-------------|
| **Lazy (reglas)** | Se guardan reglas ("lunes 9-17") y al consultar se calculan los huecos libres restando las citas existentes. | Poco storage. Flexible con duraciones variables. La fuente de verdad es la regla. **Elegido.** | Query más compleja; la lógica de negocio está en el cálculo. |
| Eager (slots pre-generados) | Se generan registros individuales por cada slot futuro con estado (available/booked/blocked). | Query trivial (`WHERE status = 'available'`). Concurrencia simple (lock por fila). | Mucho volumen de datos. Requiere job de generación periódica. Cambiar la regla implica regenerar. Duración variable es compleja (combinar slots contiguos). |

#### Razonamiento

El factor determinante fue la **duración variable de turnos**. En un sistema legal, una consulta
inicial puede durar 60 minutos, un seguimiento 30 minutos, y una llamada rápida 15 minutos.

Con slots pre-generados de granularidad fija, un turno de 60 minutos requiere encontrar y lockear
atómicamente múltiples slots consecutivos. Si se cambia la duración, hay que regenerar.

Con el modelo lazy, la duración es propiedad del tipo de cita. El sistema simplemente verifica
si el hueco libre es >= la duración requerida. No se asume granularidad fija.

---

### 4. Concurrencia: Exclusion constraint en PostgreSQL

**Decisión**: Usar un exclusion constraint con `tstzrange` para prevenir solapamientos a nivel de base de datos.

```sql
EXCLUDE USING GIST (
    lawyer_id WITH =,
    tstzrange(starts_at, ends_at) WITH &&
)
```

#### Razonamiento

Dos clientes podrían ver el mismo hueco libre y querer reservarlo simultáneamente.
En lugar de manejar esto en la capa de aplicación (propenso a race conditions),
se delega a PostgreSQL con un exclusion constraint.

Este constraint usa un índice GiST y opera a nivel de fila. Dos citas para distintos
abogados no compiten entre sí. Solo hay contención si dos citas para el mismo abogado
se solapan en el tiempo, lo cual es el caso exacto que queremos prevenir.

Es la solución más simple y robusta: la base de datos garantiza la integridad,
sin necesidad de locks explícitos, transacciones SERIALIZABLE, ni lógica de aplicación.

---

### 5. Datos de clientes: Perfil por organización

**Decisión**: Modelo híbrido — autenticación global, perfil de cliente por organización.

#### Alternativas evaluadas

| Enfoque | Ventaja | Desventaja |
|---------|---------|------------|
| Datos globales compartidos | Onboarding rápido, el cliente carga una vez. | Un estudio puede ver que el cliente se atiende con otro. En derecho, esto puede ser un problema ético (conflicto de interés). |
| Datos completamente por organización | Aislamiento total. | El cliente recarga todos sus datos cada vez. |
| **Híbrido: auth global + perfil por org** | Un solo login (buen onboarding), datos profesionales aislados por estudio. | Leve duplicación de datos de perfil. **Elegido.** |

#### Razonamiento

En el dominio legal, la confidencialidad entre estudios es especialmente sensible.
El modelo híbrido resuelve ambos problemas: el usuario se loguea una vez (`users` global),
pero cada organización mantiene su propia ficha del cliente (`client_profiles`) con datos
de contacto, notas, e historial independientes.

---

### 6. Citas como entidad separada (no "evento" genérico)

**Decisión**: La cita tiene su propia tabla dedicada, separada de disponibilidades y bloqueos.

#### Razonamiento

Se evaluó inicialmente un modelo unificado donde todo (cita, disponibilidad, bloqueo) fuera un
"evento" en una sola tabla. Si bien conceptualmente todo "ocupa tiempo en un calendario",
las reglas de negocio y las queries son muy distintas:

- Una cita tiene: cliente, tipo, estado, modalidad.
- Una disponibilidad no tiene nada de eso.

`SELECT * FROM appointments` es una de las queries más comunes del sistema.
Cuando una query es central para el negocio, merece su propia tabla.

A nivel de dominio, el concepto de "evento" puede existir como abstracción.
A nivel de persistencia, las queries y reglas de negocio justifican la separación.

---

## Modelo de entidades

### Diagrama de relaciones

```
users ─────┬──── lawyers ──────┬── availability_rules
           │         │         ├── availability_overrides
           │         │         ├── lawyer_appointment_types ── appointment_types
           │         │         │                                     │
           │         │         └── appointments ◄────────────────────┘
           │         │                 ▲
           ├──── client_profiles ──────┘
           │         │
           └──── organization_members
                     │
              organizations
```

### DDL

```sql
-- ============================================
-- Identidad y autenticación
-- ============================================

CREATE TABLE users (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email           TEXT NOT NULL UNIQUE,
    password_hash   TEXT,               -- nullable: no aplica si usa OAuth
    auth_provider   TEXT NOT NULL DEFAULT 'local',  -- 'local', 'firebase', 'google'
    auth_provider_id TEXT,              -- UID del proveedor externo
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- Organizaciones
-- ============================================

CREATE TABLE organizations (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL,
    country     TEXT NOT NULL,
    timezone    TEXT NOT NULL,           -- IANA, default para la org
    address     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- Membresía y roles
-- ============================================

CREATE TABLE organization_members (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id),
    organization_id BIGINT NOT NULL REFERENCES organizations(id),
    role            TEXT NOT NULL,       -- 'admin', 'lawyer', 'secretary', 'intern'
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, organization_id)
);

-- ============================================
-- Perfiles
-- ============================================

-- Global: datos profesionales del abogado
CREATE TABLE lawyers (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         BIGINT NOT NULL UNIQUE REFERENCES users(id),
    license_number  TEXT,
    specialty       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Por organización: datos del cliente para ese estudio
CREATE TABLE client_profiles (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id),
    organization_id BIGINT NOT NULL REFERENCES organizations(id),
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    phone           TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, organization_id)
);

-- ============================================
-- Tipos de cita
-- ============================================

CREATE TABLE appointment_types (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations(id),
    name            TEXT NOT NULL,
    duration_minutes INT NOT NULL,
    modality        TEXT NOT NULL,       -- 'presencial', 'video', 'telefonica'
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Qué tipos ofrece cada abogado
CREATE TABLE lawyer_appointment_types (
    lawyer_id           BIGINT NOT NULL REFERENCES lawyers(id),
    appointment_type_id BIGINT NOT NULL REFERENCES appointment_types(id),
    PRIMARY KEY (lawyer_id, appointment_type_id)
);

-- ============================================
-- Disponibilidad
-- ============================================

-- Reglas recurrentes semanales
CREATE TABLE availability_rules (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lawyer_id       BIGINT NOT NULL REFERENCES lawyers(id),
    organization_id BIGINT NOT NULL REFERENCES organizations(id),
    day_of_week     SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    timezone        TEXT NOT NULL,       -- IANA timezone identifier
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);

-- Excepciones puntuales (bloqueos o disponibilidad extra)
CREATE TABLE availability_overrides (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lawyer_id       BIGINT NOT NULL REFERENCES lawyers(id),
    organization_id BIGINT NOT NULL REFERENCES organizations(id),
    date            DATE NOT NULL,
    start_time      TIME,               -- NULL si es bloqueo de día completo
    end_time        TIME,
    is_available    BOOLEAN NOT NULL,    -- true = disponibilidad extra, false = bloqueo
    reason          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- Citas (entidad transaccional central)
-- ============================================

CREATE TABLE appointments (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_id     BIGINT NOT NULL REFERENCES organizations(id),
    lawyer_id           BIGINT NOT NULL REFERENCES lawyers(id),
    client_profile_id   BIGINT NOT NULL REFERENCES client_profiles(id),
    appointment_type_id BIGINT NOT NULL REFERENCES appointment_types(id),
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    status              TEXT NOT NULL DEFAULT 'pending',
                        -- 'pending', 'confirmed', 'cancelled', 'completed', 'no_show'
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (starts_at < ends_at),

    -- Anti-solapamiento a nivel de base de datos
    EXCLUDE USING GIST (
        lawyer_id WITH =,
        tstzrange(starts_at, ends_at) WITH &&
    )
);

-- Índice principal para queries de disponibilidad
CREATE INDEX idx_appointments_lawyer_date
    ON appointments (lawyer_id, starts_at);
```

---

## Extensibilidad futura

### Extensiones al modelo

| Escenario | Cómo se extiende |
|-----------|-----------------|
| Tipos de cita variables por horario ("video solo los viernes") | Agregar relación N:N entre `availability_rules` y `appointment_types`. Las reglas pasan a definir no solo cuándo, sino qué se ofrece en cada ventana. |
| Notificaciones y recordatorios | Nueva tabla `notifications` vinculada a `appointments`. No impacta el modelo existente. |
| Pagos y facturación | Tablas `invoices` e `invoice_items` vinculadas a `organizations` y `appointments`. |
| Historial de cambios (auditoría) | Tabla de auditoría genérica o triggers que registren cambios en `appointments`. |
| Recurrencia de citas | Campo `recurrence_rule` en `appointments` (formato iCal RRULE) o tabla separada de series. |

### Estrategia de escalamiento

El modelo está diseñado para escalar progresivamente:

1. **Día 1**: Índices compuestos + exclusion constraint. Suficiente para miles de organizaciones.

2. **Crecimiento medio**: Particionado por rango temporal en `appointments` (trimestral o mensual).
   PostgreSQL (10+) soporta particionado nativo transparente: las queries se ejecutan contra la tabla
   padre y el query planner automáticamente escanea solo las particiones relevantes (partition pruning).
   Se puede automatizar con `pg_partman`.

3. **Crecimiento alto**: Particionado adicional por `organization_id` si se requiere aislamiento
   fuerte entre tenants o distribución geográfica de datos.

El principio es **no sobre-diseñar anticipadamente**: cada nivel de optimización se agrega cuando
las métricas lo justifican, no antes. El modelo base es lo suficientemente limpio como para
evolucionar sin refactors destructivos.
