\echo '-------------------------------------------------------------------------------'
\echo '-- creating custom role'

-- Hide password output from logging
\o /dev/null

\set custom_user `echo $CUSTOM_USER`
set custom.username = '';
select set_config('custom.username', :'custom_user', false);

\set custom_password `echo $CUSTOM_PASSWORD`
SET custom.password = '';
select set_config('custom.password', :'custom_password', false);

-- Restore output logging
\o

\ir ../function/role.sql
call create_user(current_setting('custom.username'), current_setting('custom.password'));

-- Reset password to null;
set custom.password = '';
