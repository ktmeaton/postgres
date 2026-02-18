\echo '-------------------------------------------------------------------------------'
\echo '-- creating role: curator'

-- database curator, can read and write data, but cannot create/drop tables.
-- row-level security is enforced on the curator role.

do $do$ begin
   if not exists ( select from pg_catalog.pg_roles where  rolname = 'curator') then
      create role curator nologin;
   end if;
end $do$;
-- comments
comment on role curator is 'curator: partial read/write access, cannot create or drop tables.';
