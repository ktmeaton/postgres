#!/bin/bash

set -e

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."

docker compose $compose_args exec -T postgres \
  bash -c "PSQL_PAGER=cat psql -v ON_ERROR_STOP=1 -f /tmp/${test_name}.sql"
exit_code=$?

if [[ "$exit_code" == "0" ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (test_schedule)"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (test_schedule): exit code=$exit_code"
fi
