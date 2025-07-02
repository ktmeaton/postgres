\out

\echo '-------------------------------------------------------------------------------'
\echo '-- database initialization begins'
\echo '-------------------------------------------------------------------------------'

\set custom_db `echo $CUSTOM_DB`
set custom.db = '';
select set_config('custom.db', :'custom_db', false);


-- perform initial setup
-- \ir setup/_all.sql;
-- create database schema
\ir schema/_all.sql;
-- create extensions
\ir extension/_all.sql;
-- define commonly-used functions
\ir function/_all.sql;
-- create tables
\ir table/_all.sql;
-- create roles
\ir role/_all.sql
-- perform application setup
\ir application/_all.sql

-- reconnect to refresh changes.
\c

-- create full backup if one doesn't already exist.
set role postgres;
do $do$ begin
    if not exists ( select from backup.log where type = 'full' ) then
        perform backup.run_backup_full();
    end if;
end $do$;

\echo '-------------------------------------------------------------------------------'
\echo 'backup log:'
select * from backup.log;

-- final location and role setting
\c

\echo '-------------------------------------------------------------------------------'
\echo '-- database initialization complete'
\echo '-------------------------------------------------------------------------------'
