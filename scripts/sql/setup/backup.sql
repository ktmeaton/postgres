\echo '-------------------------------------------------------------------------------'
\echo '--  Backup Setup'
\echo '-------------------------------------------------------------------------------'

\c postgres;
set role postgres;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating schema: backup'

create schema if not exists backup;
comment on schema backup is 'Database backups and logs.';

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: get_backup_json'

-- Get a JSON summary of backup history by executing the pgbackrest CLI command.
-- Returns the JSON data as a table for downstream queries.
CREATE OR REPLACE FUNCTION backup.get_backup_json()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    DATA jsonb;
BEGIN
    -- Create a temp table to hold the JSON data
    create temp table temp_pgbackrest_data (data text);

    -- Copy data into the table directly from the pgBackRest info command
    copy temp_pgbackrest_data (data)
        from program
            'PGPASSWORD=$POSTGRES_PASSWORD pgbackrest --output=json info' (format text);

    select replace(temp_pgbackrest_data.data, E'\n', '\n')::jsonb
      into data
      from temp_pgbackrest_data;

    drop table temp_pgbackrest_data;
    return data;
END
$$;

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: get_backup_latest'

-- Get last successful backup for each pgBackRest stanza.
CREATE OR REPLACE FUNCTION backup.get_backup_latest()
RETURNS TABLE(
    cluster TEXT,
    last_successful_backup TIMESTAMPTZ,
    last_archived_wal TEXT,
    last_backup_type TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
        WITH stanza AS
        (
            SELECT
                replace((data->'name')::text, '"', '') AS name,
                data->'backup'->(jsonb_array_length(data->'backup') - 1) AS last_backup,
                data->'archive'->(jsonb_array_length(data->'archive') - 1) AS current_archive,
                replace((data->'backup'->(jsonb_array_length(data->'backup') - 1)->'type')::text, '"', '') AS backup_type
            FROM jsonb_array_elements(backup.get_backup_json()) AS data
        )
        SELECT name::TEXT,
            to_timestamp((last_backup->'timestamp'->>'stop')::NUMERIC) AS last_successful_backup,
            current_archive->>'max' AS last_archived_wal,
            backup_type::TEXT
        FROM stanza;
END
$$;

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: get_backup_log'

-- Get summary of active pgbackrest backups and history.
CREATE OR REPLACE FUNCTION backup.get_backup_log()
RETURNS TABLE(
    cluster TEXT,
    db JSONB,
    status JSONB,
    repo JSONB,
    backup JSONB,
    archive JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
        WITH log AS (
            SELECT
                data->'name' AS cluster,
                data->'db' AS db,
                data->'status' AS status,
                data->'repo' AS repo,
                jsonb_array_elements( data->'backup') AS backup,
                jsonb_array_elements( data->'archive') AS archive
            FROM jsonb_array_elements(backup.get_backup_json()) AS data
        )
        SELECT
            log.cluster::TEXT,
            jsonb_array_elements(log.db) AS db,
            log.status,
            jsonb_array_elements(log.repo) AS repo,
            log.backup,
            log.archive
        FROM log;
END $$;

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: run_backup_incremental'

-- Create a pgbackrest incremental backup.
CREATE OR REPLACE FUNCTION backup.run_backup_incremental()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    DATA TEXT;
BEGIN
    RAISE LOG 'Creating pgBackRest incremental backup.';
    -- Create a temp table to hold the command output
    CREATE TEMP TABLE temp_backup_incremental (data TEXT);
    -- Copy data into the table directly from the command
    COPY temp_backup_incremental (data)
    FROM program 'PGPASSWORD=$POSTGRES_PASSWORD pgbackrest --stanza=main --type incr backup' (format TEXT);
    -- Concatenate lines into one record.
    WITH log AS (
        SELECT 't' AS t, string_agg(temp_backup_incremental.data, '\n') AS lines
        FROM temp_backup_incremental
        GROUP BY t)
    SELECT replace(lines, '\n', E'\n') INTO data FROM log;
    -- Cleanup and return output
    DROP TABLE temp_backup_incremental;
    RETURN data;
END
$$;

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: run_backup_diff'

-- Create a pgbackrest diff backup.
CREATE OR REPLACE FUNCTION backup.run_backup_diff()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    DATA TEXT;
BEGIN
    RAISE LOG 'Creating pgBackRest diff backup.';
    -- Create a temp table to hold the command output
    CREATE TEMP TABLE temp_backup_diff (data TEXT);
    -- Copy data into the table directly from the command
    COPY temp_backup_diff (data)
    FROM program 'PGPASSWORD=$POSTGRES_PASSWORD pgbackrest --stanza=main --type diff backup' (format TEXT);
    -- Concatenate lines into one record.
    WITH log AS (
        SELECT 't' AS t, string_agg(temp_backup_diff.data, '\n') AS lines
        FROM temp_backup_diff
        GROUP BY t)
    SELECT replace(lines, '\n', E'\n') INTO data FROM log;
    -- Cleanup and return output
    DROP TABLE temp_backup_diff;
    RETURN data;
END $$;

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: run_backup_full'


CREATE OR REPLACE FUNCTION backup.run_backup_full()
    RETURNS TEXT AS $$
DECLARE
    DATA TEXT;
BEGIN
    RAISE LOG 'Creating pgBackRest full backup.';
    -- Create a temp table to hold the command output
    CREATE TEMP TABLE temp_backup_full (data TEXT);
    -- Copy data into the table directly from the command
    COPY temp_backup_full (data)
    FROM program 'PGPASSWORD=$POSTGRES_PASSWORD pgbackrest --stanza=main --type full backup' (format TEXT);
    -- Concatenate lines into one record.
    WITH log AS (
        SELECT 't' AS t, string_agg(temp_backup_full.data, '\n') AS lines
        FROM temp_backup_full
        GROUP BY t)
    SELECT replace(lines, '\n', E'\n') INTO data FROM log;
    -- Cleanup and return output
    DROP TABLE temp_backup_full;
    RETURN data;
END $$ LANGUAGE plpgsql;

-- Display functions
\df+ backup.*;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating view: log'

create or replace view backup.log
with(security_invoker=true)
as
select
    replace(cluster::text, '"', '') as cluster,
    (db->'id')::integer as db_id,
    (status->'code')::integer as code,
    replace((status->'message')::text, '"', '') as message,
    to_timestamp((backup->'timestamp'->'start')::numeric)::timestamptz as start,
    to_timestamp((backup->'timestamp'->'stop')::numeric)::timestamptz as stop,
    replace((backup->'label')::text, '"', '') as label,
    replace((backup->'prior')::text, '"', '') as prior,
    round((backup->'info'->'size')::numeric / (1024*1024 * 1024), 3) as size,
    'gb'::text as size_units,
    (backup->'info'->'delta')::integer as delta,
    replace((backup->'type')::text, '"', '') as type,
    (backup->'error')::boolean as error
from backup.get_backup_log();

-- comments
comment on view backup.log is 'database backup log from pgbackrest.';
