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

