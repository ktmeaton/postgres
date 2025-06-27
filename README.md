# postgres

A PostgreSQL docker deployment for primary research data and web applications.

## Features

- **Rootless**: Runs the `postgres` container as the host user.
    - See the [Best Practices](https://www.docker.com/blog/understanding-the-docker-user-instruction/) about running containers as non-root.
- **Non-Superuser**: Creates a custom database and user who is not a superuser.
    - Avoids running as the default `postgres` superuser.
    - Useful when creating a single database for a web application.
- **Security**: Enforces encrypted password authenication (scram-sha-256).
    - Blocks login attempts from the `postgres` user unless they are coming from directly within the docker container.
- **Backups**: Database backups scheduled with [`pgBackRest`](https://pgbackrest.org/) and [`pg_cron`](https://github.com/citusdata/pg_cron).
    - Allows [Point-in-Time Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html).


## Usage

1. Clone the repository.

    ```bash
    git clone https://github.com/BFF-AFIRMS/postgres.git
    cd postgres
    ```

1. Generate secure credentials.

    ```bash
    scripts/generate_credentials.sh >.env >.env.bak
    ```

1. Start the database container.

    ```bash
    docker compose up -d
    ```

1. Save the db init logs once the container is in a health state.

    ```bash
    docker logs postgres > data/postgres/main/log/init.log 2>&1
    ```

## Database

- Database files are located under `data/postgres`
- Logs are located under `/data/postgres/main/log`

### Utilities

- Apply updates from a single script (ex. cron configuration).

    ```bash
    docker exec postgres psql -U postgres postgres -f sql/extension/cron.sql
    ```

- Apply updates from all sql scripts.

    ```bash
    docker exec postgres psql -U postgres postgres -f sql/_all.sql
    ```

## Backup

- Database backups can be found under `data/pgbackrest`
- Backup scheduling is specified in `scripts/sql/extension/cron.sql`

### Utilities

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
