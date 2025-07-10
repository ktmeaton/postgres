\echo '-------------------------------------------------------------------------------'
\echo '--  Backup Setup'
\echo '-------------------------------------------------------------------------------'

\c postgres;
set role postgres;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating extension: pg_walinspect'

create extension if not exists pg_walinspect;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating schema: backup'

create schema if not exists backup;
comment on schema backup is 'Database backups and logs.';

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: get_json'

-- Get a JSON summary of backup history by executing the pgbackrest CLI command.
-- Returns the JSON data as a table for downstream queries.
CREATE OR REPLACE FUNCTION backup.get_json()
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
\echo '-- Creating function: get_latest'

-- Get last successful backup for each pgBackRest stanza.
CREATE OR REPLACE FUNCTION backup.get_latest()
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
            FROM jsonb_array_elements(backup.get_json()) AS data
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
create or replace function backup.get_log()
returns table(
    cluster text,
    db jsonb,
    status jsonb,
    repo jsonb,
    backup jsonb,
    archive jsonb
)
language plpgsql
as $$
begin
    return query
        with log as (
            select
                data->>'name' as cluster,
                data->'db' as db,
                data->'status' as status,
                data->'repo' as repo,
                jsonb_array_elements( data->'backup') as backup,
                jsonb_array_elements( data->'archive') as archive
            from jsonb_array_elements(backup.get_json()) as data
        )
        select
            log.cluster::text,
            jsonb_array_elements(log.db) as db,
            log.status,
            jsonb_array_elements(log.repo) as repo,
            log.backup,
            log.archive
        from log;
end $$;

\echo '-------------------------------------------------------------------------------'
\echo '-- Creating function: run'


create or replace function backup.run(backup_type text, annotation text default null)
returns text
language plpgsql
as $$
declare
  data text;
  timeline integer;
begin
  raise log 'Creating pgBackRest % backup.', backup_type;
  -- Create a temp table to hold the command output
  execute format('create temp table temp_backup_%s (data text)', backup_type);
  -- Format annotation
  if (annotation is not null and annotation != '' ) then
    annotation := format('--annotation=%s', annotation);
  end if;
  -- Copy data into the table directly from the command
  execute format(
    'COPY temp_backup_%s (data) FROM program ''PGPASSWORD=$POSTGRES_PASSWORD pgbackrest --stanza=main --type %s %s backup'' (format TEXT)',
    backup_type, backup_type, annotation
  );
  -- Concatenate lines into one record.
  execute format(
    'with log as (select ''t'' AS t, string_agg(temp_backup_%s.data, ''\n'') as lines from temp_backup_%s group by t) select replace(lines, ''\n'', E''\n'') from log',
    backup_type, backup_type
  ) into data;
  -- Cleanup and return output
  execute format('drop table temp_backup_%s', backup_type);
  return data;
end
$$;

\df backup.*;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating view: archive'

create or replace view backup.archive
with(security_invoker=true)
as
select
    cluster,
    (db->>'id')::integer as db_id,
    archive->>'min' as wal_min,
    archive->>'max'as wal_max
from backup.get_log()
where archive is not null;

-- comments
comment on view backup.archive is 'Database backup archive from pgbackrest.';

\echo '-------------------------------------------------------------------------------'
\echo '-- creating view: log'

create or replace view backup.log
with(security_invoker=true)
as
select
    cluster,
    (db->>'id')::integer as db_id,
    backup->>'type' as type,
    (backup->'error')::boolean as error,
    to_timestamp((backup->'timestamp'->'start')::numeric)::timestamptz as start,
    to_timestamp((backup->'timestamp'->'stop')::numeric)::timestamptz as stop,
    round((backup->'info'->'size')::numeric / (1024*1024 * 1024), 3) as size,
    'gb'::text as size_units,
    (backup->'info'->'delta')::integer / (1024 * 1024) as delta,
    'mb'::text as delta_units,
    backup->'annotation' as annotation
from backup.get_log();

-- comments
comment on view backup.log is 'Database backup log from pgbackrest.';

\echo '-------------------------------------------------------------------------------'
\echo '-- creating view: log_extended'

create or replace view backup.log_extended
with(security_invoker=true)
as
select
    cluster,
    (db->>'id')::integer as db_id,
    backup->>'type' as type,
    (backup->'error')::boolean as error,
    (status->>'code')::integer as code,
    status->>'message' as message,
    to_timestamp((backup->'timestamp'->'start')::numeric)::timestamptz as start,
    to_timestamp((backup->'timestamp'->'stop')::numeric)::timestamptz as stop,
    backup->>'label' as label,
    backup->>'prior' as prior,
    round((backup->'info'->'size')::numeric / (1024*1024 * 1024), 3) as size,
    'gb'::text as size_units,
    (backup->'info'->'delta')::integer / (1024 * 1024) as delta,
    'mb'::text as delta_units,
    backup->'annotation' as annotation,
    backup->'lsn'->>'start'as lsn_start,
    backup->'lsn'->>'stop' as lsn_stop
from backup.get_log();

\dv backup.*;
