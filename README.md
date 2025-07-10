# postgres

A PostgreSQL docker deployment for primary research data and web applications.

## Features

- **Rootless**: Runs the `postgres` container as the host user.
  - Stores persistent data under the a local (`.data/`) directory.
  - See the [Best Practices](https://www.docker.com/blog/understanding-the-docker-user-instruction/) about running containers as non-root.
- **Non-Superuser**: Creates a custom database and user who is not a superuser.
  - Avoids running as the default superuser (`postgres`).
  - Useful when creating a single database for a web application.
- **Security**: Enforces SSl/TLS and encrypted password authenication (scram-sha-256).
  - Blocks login attempts from the superuser unless they are coming from directly within the docker container.
- **Backups**: Database backups scheduled with [`pgBackRest`](https://pgbackrest.org/) and [`pg_cron`](https://github.com/citusdata/pg_cron).
  - Allows [Point-in-Time Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html).

## Usage

1. Clone the repository.

    ```bash
    git clone https://github.com/BFF-AFIRMS/postgres.git
    cd postgres
    ```

1. Run the setup script.

    ```bash
    ./setup.sh
    ```

1. Start the database container.

    ```bash
    docker compose up -d
    ```

1. (Optional) save the initialization logs once the container is in a healthy state.

    ```bash
    docker logs postgres > data/postgres/main/log/init.log 2>&1
    ```

## Database

- Database files are located under `data/postgres`
- Logs are located under `/data/postgres/main/log`

## Backup

- Database backups can be found under `data/pgbackrest`
- Backup scheduling is specified in `scripts/sql/extension/cron.sql`

### Test

### Test 1

1. Take a snapshot of the backup logs.

    ```bash
    docker exec -e PSQL_PAGER=cat -it postgres bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "select * from backup.log"'

     cluster | db_id | type | error | code | message |         start          |          stop          |               label               |               prior               | size  | size_units |  delta   |                                 annotation                                 | lsn_start | lsn_stop
    ---------+-------+------+-------+------+---------+------------------------+------------------------+-----------------------------------+-----------------------------------+-------+------------+----------+----------------------------------------------------------------------------+-----------+-----------
     main    |     1 | full | f     |    0 | ok      | 2025-07-10 10:35:03-06 | 2025-07-10 10:35:05-06 | 20250710-103503F                  |                                   | 0.029 | gb         | 31053023 | {"source": "setup"}                                                        | 0/3000028 | 0/3000188
     main    |     1 | diff | f     |    0 | ok      | 2025-07-10 10:41:21-06 | 2025-07-10 10:41:22-06 | 20250710-103503F_20250710-104121D | 20250710-103503F                  | 0.029 | gb         |  3902882 | {"source": "manual", "comment": "after create table test"}                 | 0/6000028 | 0/60001E8
     main    |     1 | incr | f     |    0 | ok      | 2025-07-10 10:56:25-06 | 2025-07-10 10:56:26-06 | 20250710-103503F_20250710-105625I | 20250710-103503F_20250710-104121D | 0.030 | gb         |  5308891 | {"source": "manual", "comment": "after insert test 1A and 2B"}             | 0/8000120 | 0/8000260
     main    |     1 | incr | f     |    0 | ok      | 2025-07-10 10:57:37-06 | 2025-07-10 10:57:38-06 | 20250710-103503F_20250710-105737I | 20250710-103503F_20250710-105625I | 0.030 | gb         |  2694463 | {"source": "manual", "comment": "after delete test 1A and insert test 3C"} | 0/A000028 | 0/A000168
    ```

1. Stop the container.

    ```bash
    docker compose down postgres
    ```

1. Make a development copy of the whole directory.

    ```bash
    cd ..
    cp -r postgres postgres_dev
    cd postgres_dev

    # Clear out potentially corrupted data
    find data/postgres/main -mindepth 1 -delete
    ```

1. Consult the logs log to identify an lsn or timepoint to restore to.

    > - In this example, lsn `0/8000120` was the last checkpoint before a critical deletion occurred.
    > - The timestamp `2025-07-10 10:57:04.485-06` is the time at which the deletion actually occurred.

    ```bash
    cat data/postgres/main/log/*.csv | csvtk pretty | less -S

    ...
    2025-07-10 10:56:25.242 MDT   ...           0     LOG     00000   checkpoint complete: wrote 7 buffers  ... lsn=0/80001C0, redo lsn=0/8000120;
    ...
    2025-07-10 10:57:04.485 MDT   ...   37/4    0     LOG     00000   statement: delete from test where id = 1;
    ...
    ```

1. Configure the restore.

    ```bash
    # Option 1: LSN Restore
    scripts/docker/pgbackrest.sh --stanza=main --target-action=promote --type=lsn --target="0/8000120" --target-timeline=current restore

    # Option 2: Timepoint Restore
    scripts/docker/pgbackrest.sh --stanza=main --target-action=promote --type=time --target="2025-07-10 10:57:04.485-06" --target-timeline=current restore
    ```

1. Restart the container to begin the restoration.

    ```bash
    docker compose up -d

    # Wait for the recovery to be complete
    ls -tr data/postgres/main/log/*.log | tail -n 1 | xargs grep "archive recovery complete"
    ```

### Utilities

- Apply updates from a single script (ex. cron configuration).

    ```bash
    docker exec postgres psql -U postgres postgres -f sql/extension/cron.sql
    ```

- Apply updates from all sql scripts.

    ```bash
    docker exec postgres psql -U postgres postgres -f sql/_all.sql
    ```

- Check current backup schedule:

    ```bash
    docker exec -e PSQL_PAGER=cat postgres psql -U postgres postgres -c 'select * from cron.job;'

     jobid |     schedule     |             command             | nodename | nodeport | database | username | active |      jobname
    -------+------------------+---------------------------------+----------+----------+----------+----------+--------+--------------------
         1 | 0 23 * * sat     | select run_backup_full()        |          |     5432 | postgres | postgres | t      | backup_full
         2 | 0 23 * * sun-fri | select run_backup_diff()        |          |     5432 | postgres | postgres | t      | backup_diff
         3 | 0 * * * *        | select run_backup_incremental() |          |     5432 | postgres | postgres | t      | backup_incremental
     ```

- Run manual backups.

    ```bash
    docker exec -e PSQL_PAGER=cat postgres psql -U postgres postgres -c 'select backup.run_backup_full();' | tee backup_full.log
    docker exec -e PSQL_PAGER=cat postgres psql -U postgres postgres -c 'select backup.run_backup_diff();' | tee backup_diff.log
    docker exec -e PSQL_PAGER=cat postgres psql -U postgres postgres -c 'select backup.run_backup_incremental();' | tee backup_incremental.log
    ```

- Get information about the latest backup:

    ```bash
    docker exec -e PSQL_PAGER=cat postgres psql -U postgres postgres -c 'select * from backup.get_backup_latest();'

     cluster | last_successful_backup |    last_archived_wal     | last_backup_type
    ---------+------------------------+--------------------------+------------------
     "main"  | 2025-06-19 14:35:08-06 | 00000001000000000000000E | "incr"
    ```

- Get full backup log:

    ```bash
    docker exec -e PSQL_PAGER=cat postgres psql -U postgres postgres -c 'select * from backup.get_backup_log();' | less -S
    ```
