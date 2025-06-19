FROM postgres:17.5-bookworm

# Unix Tools: pgbackrest, jq, curl
RUN apt update \
  && apt install -y \
     curl pgbackrest jq postgresql-17-cron

# Transfer custom configuration files
COPY config/postgresql.conf /etc/postgresql/postgresql.conf
COPY config/pg_hba.conf /etc/postgresql/pg_hba.conf

# Transfer essential startup scripts
# COPY scripts/docker/entrypoint.sql /docker-entrypoint-initdb.d/entrypoint.sql
COPY scripts/docker/entrypoint.sh /docker-entrypoint-initdb.d/entrypoint.sh
COPY scripts/sql /docker-entrypoint-initdb.d/sql

# Transfer ownership (root->postgres) for directories 
# that will become mounted volumes from container -> host
RUN chown -R postgres:postgres /docker-entrypoint-initdb.d \
    && chown postgres:postgres /var/log/postgresql \
    && chown postgres:postgres /var/log/pgbackrest \
    && mkdir -p /etc/pgbackrest /etc/pgbackrest/conf.d \
    && touch /etc/pgbackrest/pgbackrest.conf \
    && chmod 640 /etc/pgbackrest/pgbackrest.conf \
    && chown postgres:postgres /etc/pgbackrest/pgbackrest.conf \
    && mkdir -p /var/lib/pgbackrest \
    && chmod 750 /var/lib/pgbackrest \
    && chown postgres:postgres /var/lib/pgbackrest

# Use less with no line wrapping for nicer query results
ENV PSQL_PAGER='less -S'

# Start in the entrypoint directory
WORKDIR /docker-entrypoint-initdb.d