set role postgres;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating database: custom'

-- Don't stop on errors if database already exist
\set ON_ERROR_STOP off

create database custom;
comment on database custom is 'Custom application database.';
\c custom

-- from now on, stop on errors
\set on_error_stop on

\echo '-------------------------------------------------------------------------------'
\echo '-- creating role: custom'

do $do$ begin
   if not exists ( select from pg_catalog.pg_roles where  rolname = 'custom') then
      create role custom nologin;
   end if;
end $do$;
-- comments
comment on role custom is 'application: custom access to connect and create.';

-- permissions
grant create, connect on database custom to custom;
alter role custom with createrole;
grant usage, create on schema public to custom;


-- Hide password output from logging
\o /dev/null

\set custom_password `echo $CUSTOM_PASSWORD`
SET custom.password = '';
SELECT set_config('custom.password', :'custom_password', false);
-- Restore output logging
\o

DO $do$
BEGIN
   -- If custom user cannot login, we need to set that up
   IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'custom' and rolcanlogin = FALSE) THEN
      RAISE NOTICE 'custom role does not have login permissions.';
      -- If a password couldn't be ready from the environment variable, raise exception
      IF (SELECT current_setting('custom.password') = '') THEN
         RAISE EXCEPTION 'No password could be set for custom.'
         USING HINT = 'Please set the environment variable: CUSTOM_PASSWORD';
      -- Successfully found non-null password, set the password
      ELSE
         RAISE NOTICE 'Giving role custom login permissions.';
         EXECUTE format('ALTER ROLE custom WITH LOGIN ENCRYPTED PASSWORD ''%1$s'';', current_setting('custom.password'));
      END IF;
   ELSE
      RAISE NOTICE 'custom role has login permissions.';
   END IF;
END $do$;
-- Reset to Null
SET custom.password = '';

\c postgres
