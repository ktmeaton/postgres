\echo '-------------------------------------------------------------------------------'
\echo '-- creating schemaspy role'

-- Hide password output from logging
\o /dev/null

\set schemaspy_user `echo $SCHEMASPY_USER`
set schemaspy.username = '';
select set_config('schemaspy.username', :'schemaspy_user', false);

\set schemaspy_password `echo $SCHEMASPY_PASSWORD`
SET schemaspy.password = '';
select set_config('schemaspy.password', :'schemaspy_password', false);

-- Restore output logging
\o

\ir ../function/role.sql
call create_user(current_setting('schemaspy.username'), current_setting('schemaspy.password'));

do $$
begin
  execute format('comment on role %s is ''SchemaSpy user.'' ', current_setting('schemaspy.username'));
end $$;

grant pg_read_all_data to schemaspy;

-- Reset password to null;
set schemaspy.password = '';
