\echo '-------------------------------------------------------------------------------'
\echo '--  CRON Setup'
\echo '-------------------------------------------------------------------------------'

\c postgres;
set role postgres;

-- setup cron extension, it must be located in the postgres database.
create extension if not exists pg_cron;
comment on schema cron is 'job scheduler using extension pg_cron.';
comment on table cron.job is 'jobs scheduled with pg_cron.';
comment on table cron.job_run_details is 'job run details scheduled with pg_cron.';

-- to unschedule is: select cron.unschedule(1);
-- to schedule is: select cron.schedule_in_database('<name of the scheduled job>', '<schedule>', '<job content>', '<database>', '<database account>', '<enable the job>');

\echo 'scheduling job: name=backup_full, frequency=midnight on sundays'
select cron.schedule_in_database('backup_full', '0 0 * * sun', 'select backup.run(''full'', ''source="cron"''); select backup.run(''diff'', ''source="cron"'');', 'postgres', 'postgres', true);

\echo 'scheduling job: name=backup_diff, frequency=midnight on sunday to friday'
select cron.schedule_in_database('backup_diff', '0 0 * * sun-fri', 'select backup.run(''diff'', ''source="cron"'')', 'postgres', 'postgres', true);

\echo 'scheduling job: name=backup_diff, frequency=every 6 hours'
select cron.schedule_in_database('backup_incremental', '0 */6 * * *', 'select backup.run(''incr'', ''source="cron"'')', 'postgres', 'postgres', true);

select * from cron.job;
