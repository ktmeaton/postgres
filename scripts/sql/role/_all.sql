\echo '-------------------------------------------------------------------------------'
\echo '-- Role'
\echo '-------------------------------------------------------------------------------'

comment on role postgres is 'Superuser.';

\ir custom.sql
\ir administrator.sql
\ir curator.sql
\ir app_user.sql

\du+
