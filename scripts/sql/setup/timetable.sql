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

\echo 'scheduling job: name=backup_diff, frequency=every 6 hours'
SELECT timetable.add_job(
    job_name            => 'backup_diff',
    job_schedule        => '0 0,6,12,18 * * *',
    job_command         => 'select backup.run(''diff'', ''source="pg_timetable"'')',
    job_max_instances   => 1
);

\echo 'scheduling job: name=backup_incr, frequency=hourly'
SELECT timetable.add_job(
    job_name            => 'backup_incr',
    job_schedule        => '0 * * * *',
    job_command         => 'select backup.run(''incr'', ''source="pg_timetable"'')',
    job_max_instances   => 1
);

select * from timetable.chain;
