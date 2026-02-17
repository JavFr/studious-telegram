-- Deploy fontanella:organization_members to pg
BEGIN;
CREATE TABLE organization_members (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    organization_id BIGINT NOT NULL REFERENCES organizations (id),
    role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, organization_id)
);
COMMIT;
