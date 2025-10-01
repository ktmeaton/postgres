\echo '-------------------------------------------------------------------------------'
\echo '-- search path'
\echo '-------------------------------------------------------------------------------'

set role postgres;

alter database postgres set search_path to public;
alter role postgres in database postgres set search_path to public,backup,timetable;

-- reconnect to fresh search path
\c postgres

-- display schema
\echo '-------------------------------------------------------------------------------'
\echo '-- schema'
show search_path;
\dn+
