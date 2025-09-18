\out

\echo '-------------------------------------------------------------------------------'
\echo '-- database initialization begins'
\echo '-------------------------------------------------------------------------------'

\ir extension/_all.sql;
\ir schema/_all.sql;
\ir function/_all.sql;
\ir table/_all.sql;
\ir role/_all.sql
\ir application/_all.sql

-- reconnect to refresh changes.
\c postgres

-- create full backup if one doesn't already exist.
set role postgres;
do $$
begin
    if not exists ( select from backup.log where type = 'full' ) then
        raise notice 'creating backup: full';
        perform backup.run('full', 'source="setup"');
    end if;
    if not exists ( select from backup.log where type = 'diff' ) then
        raise notice 'creating backup: diff';
        perform backup.run('diff', 'source="setup"');
    end if;
end $$;

\echo '-------------------------------------------------------------------------------'
\echo 'backup log:'
select * from backup.log;

\echo '-------------------------------------------------------------------------------'
\echo '-- database initialization complete'
\echo '-------------------------------------------------------------------------------'
