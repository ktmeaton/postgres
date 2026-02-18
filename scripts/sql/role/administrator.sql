\echo '-------------------------------------------------------------------------------'
\echo '-- creating role: administrator'

set role postgres;

-- admin user, very powerful, second only to the postgres superuser
-- can read and write all data in the database, and also bypasses
-- row-level security (rls)
do $do$ begin
   if not exists ( select from pg_catalog.pg_roles where  rolname = 'administrator') then
      create role administrator;
   end if;
end $do$;

-- comments
comment on role administrator is 'adminstrator: full read/write access, bypasses row-level security (rls).';

-- privileges
grant pg_read_all_data to administrator with admin option;
grant pg_write_all_data to administrator with admin option;
grant pg_write_server_files to administrator;
grant create on database postgres to administrator;
alter role administrator with bypassrls;
alter role administrator with createrole;
