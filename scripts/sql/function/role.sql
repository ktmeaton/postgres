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

\echo '-------------------------------------------------------------------------------'
\echo 'creating function: get_pg_roles'

-- summarize pg roles, membership, and grantors.
create or replace function public.get_pg_roles()
returns table (role text, member text, grantor text)
language sql
as $$
    select
        r1.rolname,
        r2.rolname as member,
            r3.rolname as grantor
    from pg_auth_members m
    left join pg_roles r1 on m.roleid = r1.oid
    left join pg_roles r2 on m.member = r2.oid
    left join pg_roles r3 on m.grantor = r3.oid;
$$;
