# postgres

A opinionated PostgreSQL docker deployment for primary research data and web applications.

## Features

- **Rootless**: Runs the `postgres` container as the host user.
  - Stores persistent data under the local (`data/`) directory.
  - See the [Best Practices](https://www.docker.com/blog/understanding-the-docker-user-instruction/) about running containers as non-root.
- **Non-Superuser**: Creates a custom database and user who is not a superuser.
  - Avoids running as the default superuser (`postgres`).
  - Useful when creating a single database for a web application.
- **Security**: Enforces SSl/TLS and encrypted password authenication (scram-sha-256).
  - Blocks login attempts from the superuser unless they are coming from directly within the docker container.
- **Backups**: Database backups scheduled with [`pgBackRest`](https://pgbackrest.org/) and [`pg_timetable`](https://github.com/cybertec-postgresql/pg_timetable).
  - Allows [Point-in-Time Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html).

## Usage

Clone the repository, run the setup script, and start the container.

```bash
git clone https://github.com/ktmeaton/postgres.git
cd postgres
./setup.sh
docker compose build
docker compose up -d
docker compose logs postgres
```

## Database

- Database files are located under `data/postgres`
- Logs are located under `data/postgres/main/log`

## Backup

- Database backups can be found under `data/pgbackrest`
- Backup scheduling is specified in `scripts/sql/extension/timetable.sql`

### Restore

1. Get the latest successful backup.

    ```bash
    docker compose exec db psql -c 'select stop,label,lsn_stop from backup.log_extended order by stop desc limit 1';
    ```

    ```text
              stop          |               label               |  lsn_stop
    ------------------------+-----------------------------------+------------
    2025-10-14 11:19:50-06  | 20251012-000013F_20251014-111947I | 0/C4000168
    ```

1. Shutdown the database.

    ```bash
    docker compose down
    ```

1. Backup the database.

    ```bash
    cp -r data data-bak
    ```

1. Restore backup point.

  ```bash
  scripts/utils/restore --lsn 0/C4000168 --label 20251012-000013F_20251014-111947I --image bff-afirms/postgres:17.6 --data-dir data
  ```

1. Restart database to complete restore.

  ```bash
  docker compose up -d
  ```

## Tests

| name            | description                                           | command                   |
| --------------- | ----------------------------------------------------- | ------------------------- |
| auth            | Test authentication, security, and tls/ssl.           | `tests/run.sh auth`       |
| backup          | Check backup and restore functionality of pgBackRest. | `tests/run.sh backup`     |
| schedule        | Check job scheduling with pg_timetable.               | `tests/run.sh schedule`   |

To run all the tests, stop the original container first:

```bash
docker compose down postgres
tests/run.sh all
```

### Utilities

- Display the backup schedule:

    ```bash
    docker compose exec postgres get_backup_schedule

        chain_name     |      run_at       |                                                command
    --------------------+-------------------+--------------------------------------------------------------------------------------------------------
    backup_full        | 0 0 * * 0         | select backup.run('full', 'source="pg_timetable"'); select backup.run('diff', 'source="pg_timetable"')
    backup_diff        | 0 1,13 * * *      | select backup.run('diff', 'source="pg_timetable"')
    backup_incr        | 0 2,8,14,20 * * * | select backup.run('incr', 'source="pg_timetable"')
     ```

- Run manual backups.

    ```bash
    docker compose exec postgres run_backup full
    docker compose exec postgres run_backup diff
    docker compose exec postgres run_backup incr

    ```

- Get information about the latest backup:

    ```bash
    docker compose exec postgres get_backup_latest

     cluster | last_successful_backup |    last_archived_wal     | last_backup_type
    ---------+------------------------+--------------------------+------------------
     "main"  | 2025-06-19 14:35:08-06 | 00000001000000000000000E | "incr"
    ```

- Get extended backup log:

    ```bash
    docker compose exec postgres utils/get_backup_log_extended | less -S
    ```

- Apply updates from a single script (ex. roles).

    ```bash
    docker compose exec postgres bash -c "psql f sql/role/_all.sql"
    ```

- Apply updates from all sql scripts.

    ```bash
    docker compose exec postgres bash -c "PSQL_PAGER=cat psql -f sql/_all.sql" | less -S
    ```
