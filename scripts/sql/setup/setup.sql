-- print all query results to stdout
\out

\echo '-------------------------------------------------------------------------------'
\echo '-- creating extension: cron'

-- connect to the postgres user db
\c postgres

set role postgres;

-- don't stop on errors, until after db creation
\set on_error_stop off

\echo '-------------------------------------------------------------------------------'
\echo '-- creating extension: pg_stat_statements'

create extension if not exists pg_stat_statements;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating extension: pg_walinspect'

create extension if not exists pg_walinspect;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating temporary database: tmpdb'

create database tmpdb;
comment on database tmpdb is 'Temporary custom database.';

-- environment variables
\set custom_db `echo $CUSTOM_DB`
set custom.db = '';
select set_config('custom.db', :'custom_db', false);

do $$
declare
    custom_db text := current_setting('custom.db');
begin
    -- if a db couldn't be ready from the environment variable, raise exception
    if (custom_db = '') then
        raise exception 'no custom db could be created' using hint = 'please set the environment variable: CUSTOM_DB';
    end if;
    -- check if custom db already exists
    if not exists (select from pg_database where datname = custom_db) then

        raise notice 'creating database: %', custom_db;
        -- rename to temporary to desired custom database name
        execute format('alter database tmpdb rename to %s', custom_db);
        execute format('alter database %s set custom.db = %s', custom_db, custom_db);
    end if;
end $$;

\set on_error_stop on

\echo '-------------------------------------------------------------------------------'
\echo '-- creating custom user'

\ir ../function/role.sql

\set custom_user `echo $CUSTOM_USER`
set custom.username = '';
select set_config('custom.username', :'custom_user', false);

-- Hide password output from logging
\o /dev/null
\set custom_password `echo $CUSTOM_PASSWORD`
SET custom.password = '';
SELECT set_config('custom.password', :'custom_password', false);
-- Restore output logging
\o

do $$
declare
    custom_db text := current_setting('custom.db');
    custom_user text := current_setting('custom.username');
    custom_password text := current_setting('custom.password');
begin
    if not exists (select * from pg_roles where rolname = custom_user) then
        raise notice 'creating user: %', custom_user;
        call create_user(custom_user, custom_password);
    end if;
    execute format('alter database %I set custom.db = %s', custom_db, custom_db);
    execute format('alter database %I set custom.username = %s', custom_db, custom_user);
    execute format('alter database %I owner to %s', custom_db, custom_user);
end $$;

-- display databases
\l+

-- initialize pgbackrest stanzas as superuser
set role postgres;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating pgbackrest stanza: main'

\set output `pgbackrest --stanza=main stanza-create`;
select :'output' as pgbackrest_create_output;

\echo '-------------------------------------------------------------------------------'
\echo '-- checking pgbackrest stanza: main'

\set output `pgbackrest --stanza=main check`;
select :'output' as pgbackrest_check_output;
