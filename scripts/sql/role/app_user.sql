\echo '-------------------------------------------------------------------------------'
\echo '-- creating role: app_user'

-- database user, can only read data.
-- row-level security is enforced on the user role.

do $do$ begin
   if not exists ( select from pg_catalog.pg_roles where  rolname = 'app_user') then
      create role app_user nologin;
   end if;
end $do$;
-- comments
comment on role app_user is 'application user: read-only access from applications.';
