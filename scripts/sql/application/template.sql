set role postgres;

\echo '-------------------------------------------------------------------------------'
\echo '-- creating database: {name}'

-- Don't stop on errors if database already exist
\set ON_ERROR_STOP off

create database {name};
comment on database {name} is '{name} application database.';
\c {name}

-- from now on, stop on errors
\set on_error_stop on

\echo '-------------------------------------------------------------------------------'
\echo '-- creating role: {name}'

do $do$ begin
   if not exists ( select from pg_catalog.pg_roles where  rolname = '{name}') then
      create role {name} nologin;
   end if;
end $do$;
-- comments
comment on role {name} is 'application: {name} access to connect and create.';

-- permissions
grant create, connect on database {name} to {name};
alter role {name} with createrole;
grant usage, create on schema public to {name};


-- Hide password output from logging
\o /dev/null

\set {name}_password `echo ${NAME}_PASSWORD`
SET {name}.password = '';
SELECT set_config('{name}.password', :'{name}_password', false);
-- Restore output logging
\o

DO $do$
BEGIN
   -- If {name} user cannot login, we need to set that up
   IF EXISTS (SELECT FROM pg_roles WHERE rolname = '{name}' and rolcanlogin = FALSE) THEN
      RAISE NOTICE '{name} role does not have login permissions.';
      -- If a password couldn't be ready from the environment variable, raise exception
      IF (SELECT current_setting('{name}.password') = '') THEN
         RAISE EXCEPTION 'No password could be set for {name}.'
         USING HINT = 'Please set the environment variable: {NAME}_PASSWORD';
      -- Successfully found non-null password, set the password
      ELSE
         RAISE NOTICE 'Giving role {name} login permissions.';
         EXECUTE format('ALTER ROLE {name} WITH LOGIN ENCRYPTED PASSWORD ''%1$s'';', current_setting('{name}.password'));
      END IF;
   ELSE
      RAISE NOTICE '{name} role has login permissions.';
   END IF;
END $do$;
-- Reset to Null
SET {name}.password = '';

\c postgres
