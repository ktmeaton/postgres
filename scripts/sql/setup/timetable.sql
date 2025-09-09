\echo '-------------------------------------------------------------------------------'
\echo '--  Application: pg_timetable'

\c postgres;

-- setup cron extension, it must be located in the postgres database.
comment on schema timetable is 'Job scheduling with pg_timetable.';

do $$
declare
    backups   text[] := '{
        full,
        diff,
        incr
    }';
    -- Every sunday at midnight
    -- Every 2 hours at 1am (01:00) and 1pm (13:00)
    -- Every 6 hours, at 2am, 8am, 2pm, 8pm
    schedules text[] := '{
        "0 0 * * 0",
        "0 1,13 * * *",
        "0 2,8,14,20 * * *"
    }';
    commands  text[] := '{
        "select backup.run(''full'', ''source=\"pg_timetable\"'')",
        "select backup.run(''diff'', ''source=\"pg_timetable\"'')",
        "select backup.run(''incr'', ''source=\"pg_timetable\"'')"
    }';
    backup    text;
    name      text;
    schedule  text;
    command   text;
begin

    FOR i IN 1 .. array_length(backups, 1) loop
        backup := backups[i];
        name := 'backup_' || backup;
        schedule := schedules[i];
        command  := commands[i];

        if not exists (select from timetable.chain where chain_name = name and run_at = schedule) then
            raise notice 'scheduling job: name=%, schedule=%', name, schedule;
            delete from timetable.chain where chain_name = name;
            PERFORM timetable.add_job(
                job_name            => name,
                job_schedule        => schedule,
                job_command         => command,
                job_max_instances   => 1
            );
        else
            raise notice 'job is already scheduled: name=%, schedule=%', name, schedule;
        end if;
    end loop;
end $$;

select * from timetable.chain;
