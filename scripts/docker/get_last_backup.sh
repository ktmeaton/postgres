#!/bin/bash

last_backup=$(docker compose exec -T -e PSQL_PAGER=cat -it postgres bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -Atq -c "select last_successful_backup from backup.get_latest()"')
last_backup=$(echo "$last_backup" | tr -d '\r')
last_backup=$(date "+%Y-%m-%d %H:%M:%S%z" --date="$last_backup + 1 second")
echo "$last_backup"
