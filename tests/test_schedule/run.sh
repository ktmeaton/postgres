#!/bin/bash

set -e

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."

docker compose --env-file ${env_file} -f ${compose_file} exec -T ${test_name} \
  bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -U \$POSTGRES_USER -f /tmp/${test_name}.sql"
exit_code=$?

if [[ "$exit_code" == "0" ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (test_schedule)"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (test_schedule): exit code=$exit_code"
fi
