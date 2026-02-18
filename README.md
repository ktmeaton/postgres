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

- Database files are located under `data/postgres/db`
- Logs are located under `data/postgres/db/main/log`

## Backup

- Database backups can be found under `data/postgres/pgbackrest`
- Backup scheduling is specified in `scripts/sql/extension/timetable.sql`

### Restore

1. Get the latest successful backup.

    ```bash
    docker compose exec postgres psql -c 'select stop,label,lsn_stop from backup.log_extended order by stop desc limit 1';
    ```

    ```text
              stop          |               label               | lsn_stop  
    ------------------------+-----------------------------------+-----------
    2025-12-12 13:55:03-07 | 20251212-135455F_20251212-135502D | 0/5000218
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
    scripts/utils/restore \
      --lsn 0/5000218 \
      --label 20251212-135455F_20251212-135502D \
      --image ktmeaton/postgres:18.1 \
      --data-dir data
    ```

    <details>

    <summary>Show output</summary>

    ```text
    docker run --rm --entrypoint pgbackrest --user 1000:1000 -v /home/username/projects/postgres/data/postgres/db:/data/postgresql -v /home/username/projects/postgres/data/postgres/pgbackrest:/data/pgbackrest -v /home/username/projects/postgres/data/postgres/spool:/var/spool/pgbackrest -v /home/username/projects/postgres/data/postgres/certs:/data/certs ktmeaton/postgres:18.1 --stanza=main --target-action=promote --type=lsn --set=20251212-135455F_20251212-135502D --target=0/5000218 --target-timeline=current restore

    2025-12-12 14:03:44.080 P00   INFO: restore command begin 2.57.0: --delta --exec-id=1-90846eb4 --log-level-console=info --log-level-file=info --log-path=/data/pgbackrest/log --pg1-path=/data/postgresql/main --repo1-path=/data/pgbackrest --set=20251212-135455F_20251212-135502D --stanza=main --target=0/5000218 --target-action=promote --target-timeline=current --type=lsn

    2025-12-12 14:03:44.096 P00   INFO: repo1: restore backup set 20251212-135455F_20251212-135502D, recovery will start at 2025-12-12 13:55:02
    2025-12-12 14:03:44.096 P00   WARN: unknown user in backup manifest mapped to current user
    2025-12-12 14:03:44.096 P00   WARN: unknown group in backup manifest mapped to current group
    2025-12-12 14:03:44.098 P00   INFO: remove invalid files/links/paths from '/data/postgresql/main'
    2025-12-12 14:03:45.018 P00   INFO: write updated /data/postgresql/main/postgresql.auto.conf
    2025-12-12 14:03:45.032 P00   INFO: restore global/pg_control (performed last to ensure aborted restores cannot be started)
    2025-12-12 14:03:45.035 P00   INFO: restore size = 30.6MB, file total = 1304
    2025-12-12 14:03:45.036 P00   INFO: restore command end: completed successfully (959ms)
    ```

    </details>

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

To run tests, stop the original container first:

```bash
docker compose down postgres
tests/run.sh auth
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
     main    | 2025-12-12 13:55:03-07 | 000000020000000000000006 | diff
    ```

- Get extended backup log:

    ```bash
    docker compose exec postgres utils/get_backup_log_extended | less -S
    ```

- Apply updates from a single script (ex. roles).

    ```bash
    docker compose exec postgres bash -c "psql -f sql/role/_all.sql"
    ```

- Apply updates from all sql scripts.

    ```bash
    docker compose exec postgres bash -c "PSQL_PAGER=cat psql -f sql/_all.sql" | less -S
    ```
