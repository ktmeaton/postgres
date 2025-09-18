\echo '-------------------------------------------------------------------------------'
\echo '-- creating procedure: create_user'

create or replace procedure create_user(custom_user text, custom_password text)
language plpgsql
as $$
declare
    debug text;
begin

   if (custom_user != 'postgres') then

      -- create role
      if not exists ( select from pg_catalog.pg_roles where  rolname = custom_user ) then
         execute format('create role %s nologin', custom_user);
      end if;

      -- if user cannot login, we need to set that up
      if exists (select from pg_roles where rolname = custom_user and rolcanlogin = false) then
         raise notice '% role does not have login permissions.', custom_user;
         -- if a password couldn't be ready from the environment variable, raise exception
         if (custom_password = '') then
            raise exception 'no password could be set for role %.', custom_user
               using hint = 'please set the environment variable: POSTGRES_PASSWORD';
         -- successfully found non-null password, set the password
         else
            raise notice 'giving role % login permissions.', custom_user;
            execute format('alter role %s with login encrypted password ''%2$s'';', custom_user, custom_password);
         end if;
      else
         raise notice '% role has login permissions.', custom_user;
      end if;

   end if;
end $$;
