\echo '-------------------------------------------------------------------------------'
\echo '-- creating role: c_user'

-- allows creation of C Language functions

do $do$ begin
   if not exists ( select from pg_catalog.pg_roles where  rolname = 'c_user') then
      create role c_user with nologin superuser noinherit;
   end if;
end $do$;
-- comments
comment on role c_user is 'superuser: create C language functions.';
