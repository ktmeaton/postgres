\echo '-------------------------------------------------------------------------------'
\echo '-- schema'
\echo '-------------------------------------------------------------------------------'

set role postgres;
comment on schema public is 'default public schema.';

\echo '-------------------------------------------------------------------------------'
\echo '-- creating schema: backup'
create schema if not exists backup;
comment on schema backup is 'Database backups and logs.';

\echo '-------------------------------------------------------------------------------'
\echo '-- creating schema: extension'
create schema if not exists extension;
comment on schema extension is 'Third party extensions and tools.';
-- Extensions makes the most sense to belong to postgres superuser
