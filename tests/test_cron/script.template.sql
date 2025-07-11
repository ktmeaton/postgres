\c postgres

do $$
declare
  job_id bigint;
  job_ran boolean;
begin
  raise info 'scheduling cron job: test_cron';
  select
    cron.schedule_in_database('test_cron', '* * * * *', 'select from cron.job', 'postgres', 'postgres', true)
    into job_id;
  raise info 'created cron jobid: %', job_id;
  raise info 'waiting 90 seconds';
  perform pg_sleep(90);
  select exists (select from cron.job_run_details where jobid = job_id and status = 'succeeded') into job_ran;
  perform cron.unschedule(job_id);

  if (job_ran is true) then
    raise info 'cron job test_cron executed successfully';
  else
    raise info 'cron job test_cron did not execute successfully';
  end if;
end $$;
