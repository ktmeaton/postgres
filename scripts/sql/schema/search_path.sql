\echo '-------------------------------------------------------------------------------'
\echo '-- search path'
\echo '-------------------------------------------------------------------------------'

set role postgres;

\set custom_user `echo $CUSTOM_USER`
set custom.username = '';
select set_config('custom.username', :'custom_user', false);

do $$
declare
    custom_db text := current_setting('custom.db');
    custom_user text := current_setting('custom.username');
begin
    execute format('alter database %I set search_path to public, extension', custom_db);
    execute format('alter role postgres in database %I set search_path to public, extension, backup', custom_db);
    execute format('alter role %I in database %I set search_path to public, extension, backup', custom_user, custom_db);
end $$;

-- reconnect to fresh search path
\c

-- display schema
\echo '-------------------------------------------------------------------------------'
\echo '-- schema'
show search_path;
\dn+
