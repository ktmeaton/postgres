#!/bin/bash

echo "
-------------------------------------------------------------------------------
-- initializing pg_timetable
-------------------------------------------------------------------------------"

pg_timetable \
  --init \
  --log-file=${PGDATA}/log/timetable_init.log \
  --log-file-format=text \
  --log-file-rotate \
  --dbname=postgres \
  --user=$POSTGRES_USER \
  --password=$POSTGRES_PASSWORD \
  --sslmode=require \
  --clientname=timetable_worker

echo "-------------------------------------------------------------------------------
-- pg_timetable initialization complete
-------------------------------------------------------------------------------"

touch ${PGDATA}/log/init.log

echo "Performing setup in postgres database"
psql -U postgres -f sql/_all.sql postgres | tee -a ${PGDATA}/log/init.log
