-- Deploy fontanella:lawyer_appointment_types to pg
BEGIN;
CREATE TABLE lawyer_appointment_types (
    lawyer_id BIGINT NOT NULL REFERENCES lawyers (id),
    appointment_type_id BIGINT NOT NULL REFERENCES appointment_types (id),
    PRIMARY KEY (lawyer_id, appointment_type_id)
);
COMMIT;
