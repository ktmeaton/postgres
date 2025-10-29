#!/bin/bash

set -e

echo "-------------------------------------------------------------------------------"
echo "-- initializing applications begins"
echo "-------------------------------------------------------------------------------"

env | grep -v "POSTGRES_PASSWORD" | grep "_PASSWORD" | cut -d '_' -f 1 | while read name_upper; do
  name="${name_upper,,}"
  log="${PGDATA}/log/${name}.log"
  echo "Creating ${name} database: $log"
  sed -e "s/{name}/${name}/g" -e "s/{NAME}/${name_upper}/g" sql/application/template.sql \
    | psql -U postgres -f - 1>> $log 2>&1
  grep -i error $log || true
done

echo "-------------------------------------------------------------------------------"
echo "-- initializing applications complete"
echo "-------------------------------------------------------------------------------"
