-- Deploy fontanella:availability_rules to pg
BEGIN;
CREATE TABLE availability_rules (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lawyer_id BIGINT NOT NULL REFERENCES lawyers (id),
    organization_id BIGINT NOT NULL REFERENCES organizations (id),
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    timezone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_time < end_time)
);
COMMIT;
