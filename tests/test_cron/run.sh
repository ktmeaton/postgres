#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# Test Script

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."

docker compose --env-file ${env_file} -f ${compose_file} exec -T ${test_name} \
  bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -f /tmp/${test_name}.sql"
