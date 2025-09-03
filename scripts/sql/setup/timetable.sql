\echo '-------------------------------------------------------------------------------'
\echo '--  Application: pg_timetable'

\c postgres;

-- setup cron extension, it must be located in the postgres database.
comment on schema timetable is 'Job scheduling with pg_timetable.';

\echo 'scheduling job: name=backup_full, frequency=midnight on sundays'
SELECT timetable.add_job(
    job_name            => 'backup_full',
    job_schedule        => '0 0 * * 0',
    job_command         => 'select backup.run(''full'', ''source="pg_timetable"''); select backup.run(''diff'', ''source="pg_timetable"'')',
    job_max_instances   => 1
);

-- Every 2 hours at 1am (01:00) and 1pm (13:00)
\echo 'scheduling job: name=backup_diff, frequency=every 12 hours'
SELECT timetable.add_job(
    job_name            => 'backup_diff',
    job_schedule        => '0 1,13 * * *',
    job_command         => 'select backup.run(''diff'', ''source="pg_timetable"'')',
    job_max_instances   => 1
);

-- Every 6 hours, at 2am, 8am, 2pm, 8pm
\echo 'scheduling job: name=backup_incr, frequency=every 2 hours'
SELECT timetable.add_job(
    job_name            => 'backup_incr',
    job_schedule        => '0 2,8,14,20 * * *',
    job_command         => 'select backup.run(''incr'', ''source="pg_timetable"'')',
    job_max_instances   => 1
);

select * from timetable.chain;
