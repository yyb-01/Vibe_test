-- Initial durable checkpoint adapter. Run as a migration owner, not per request.
-- Normalized item/placement/cell constraints and outbox consumers are a later migration.
BEGIN;
CREATE SCHEMA IF NOT EXISTS astra;
CREATE TABLE IF NOT EXISTS astra.schema_version (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    version integer NOT NULL CHECK (version = 1)
);
INSERT INTO astra.schema_version VALUES (true, 1) ON CONFLICT DO NOTHING;
CREATE SEQUENCE IF NOT EXISTS astra.origin_seq MINVALUE 1 MAXVALUE 9223372036854775806 NO CYCLE;
CREATE TABLE IF NOT EXISTS astra.world (
    world_id uuid PRIMARY KEY,
    epoch bigint NOT NULL CHECK (epoch > 0),
    origin bigint NOT NULL CHECK (origin > 0),
    version bigint NOT NULL CHECK (version >= 0),
    checkpoint bytea NOT NULL CHECK (octet_length(checkpoint) BETWEEN 76 AND 100663296)
);
CREATE TABLE IF NOT EXISTS astra.request_result (
    world_id uuid NOT NULL REFERENCES astra.world(world_id),
    account_id uuid NOT NULL,
    request_id uuid NOT NULL,
    action_seq bigint NOT NULL CHECK (action_seq > 0),
    payload bytea NOT NULL CHECK (octet_length(payload) BETWEEN 132 AND 748),
    result_code integer NOT NULL CHECK (result_code BETWEEN 0 AND 14),
    state_sequence bigint NOT NULL CHECK (state_sequence >= 0),
    created_id uuid NOT NULL,
    world_version bigint NOT NULL CHECK (world_version > 0),
    PRIMARY KEY (world_id, account_id, request_id),
    UNIQUE (world_id, account_id, action_seq),
    UNIQUE (world_id, world_version)
);
CREATE TABLE IF NOT EXISTS astra.outbox (
    world_id uuid NOT NULL,
    world_version bigint NOT NULL,
    PRIMARY KEY (world_id, world_version),
    FOREIGN KEY (world_id, world_version)
        REFERENCES astra.request_result(world_id, world_version)
);
COMMIT;
