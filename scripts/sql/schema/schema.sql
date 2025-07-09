\echo '-------------------------------------------------------------------------------'
\echo '-- schema'
\echo '-------------------------------------------------------------------------------'

set role postgres;
comment on schema public is 'Default public schema.';

\echo '-------------------------------------------------------------------------------'
\echo '-- creating schema: extension'
create schema if not exists extension;
comment on schema extension is 'Third party extensions and tools.';
-- Extensions makes the most sense to belong to postgres superuser
