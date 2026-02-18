\echo '-------------------------------------------------------------------------------'
\echo '-- Role'
\echo '-------------------------------------------------------------------------------'

comment on role postgres is 'Superuser.';

\ir administrator.sql
\ir curator.sql
\ir app_user.sql
\ir c_user.sql

\du+
