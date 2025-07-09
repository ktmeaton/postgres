#!/bin/bash

docker run \
    --rm \
    --entrypoint pgbackrest  \
    --user $(id -u):$(id -g) \
    -e TZ='Canada/Mountain' \
    -v $(pwd)/data/postgres:/data/postgresql \
    -v $(pwd)/data/pgbackrest:/data/pgbackrest \
    -v $(pwd)/data/spool:/var/spool/pgbackrest/ \
    -v $(pwd)/data/certs:/data/certs \
    -v $(pwd)/config/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf \
    -v $(pwd)/config/pg_hba.conf:/etc/postgresql/pg_hba.conf \
    bff-afirms/postgres:17.5 \
    "$@"
