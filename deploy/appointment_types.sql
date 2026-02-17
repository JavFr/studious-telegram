-- Deploy fontanella:appointment_types to pg
BEGIN;
CREATE TABLE appointment_types (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations (id),
    name TEXT NOT NULL,
    duration_minutes INT NOT NULL,
    modality TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMIT;
