-- Deploy fontanella:availability_overrides to pg
BEGIN;
CREATE TABLE availability_overrides (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lawyer_id BIGINT NOT NULL REFERENCES lawyers (id),
    organization_id BIGINT NOT NULL REFERENCES organizations (id),
    date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    is_available BOOLEAN NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time IS NULL OR end_time IS NULL OR start_time < end_time)
);
COMMIT;
