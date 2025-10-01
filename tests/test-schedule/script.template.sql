\c postgres

-- schedule job
do $$ begin raise info 'scheduling job: test_schedule (%)', now(); end $$;
select timetable.add_job(
  job_name            => 'test_schedule',
  job_schedule        => '@every 5 seconds',
  job_command         => 'select from timetable.chain limit 1;',
  job_max_instances   => 1
);
select * from timetable.chain where chain_name = 'test_schedule';

-- wait for job to run
do $$ begin raise info 'sleeping for 60 seconds while job runs'; end $$;
select pg_sleep(60);

-- display log output
select chain_id,chain_name,run_at,ts,message,message_data from
timetable.chain
inner join timetable.log
on chain.chain_id = (log.message_data->>'chain')::bigint
where chain.chain_name = 'test_schedule' and log.message = 'Chain executed successfully';

-- cleanup and error checking
do $$
declare
  chain_id bigint;
  job_success boolean;
begin
  select exists ( select from
    timetable.chain
    left join timetable.log
    on chain.chain_id = (log.message_data->>'chain')::bigint
    where chain_name = 'test_schedule' and message = 'Chain executed successfully') into job_success;

  raise info 'unscheduling job: test_schedule';
  perform timetable.delete_job('test_schedule');

  if job_success then
    raise info 'scheduled job test_schedule executed successfully';
  else
    raise exception 'scheduled job test_schedule did not execute successfully';
  end if;
end $$;
