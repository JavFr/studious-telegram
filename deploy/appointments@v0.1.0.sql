-- Deploy fontanella:appointments to pg
BEGIN;
CREATE TABLE appointments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations (id),
    lawyer_id BIGINT NOT NULL REFERENCES lawyers (id),
    client_profile_id BIGINT NOT NULL REFERENCES client_profiles (id),
    appointment_type_id BIGINT NOT NULL REFERENCES appointment_types (id),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (starts_at < ends_at),
    EXCLUDE USING GIST (lawyer_id WITH =, tstzrange(starts_at, ends_at
) WITH &&)
);
CREATE INDEX idx_appointments_lawyer_date ON appointments (lawyer_id, starts_at);
COMMIT;
