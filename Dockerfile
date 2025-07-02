FROM postgres:17.5-bookworm

# Unix Tools: pgbackrest, jq, curl
RUN apt update \
  && apt install -y \
     curl pgbackrest jq postgresql-17-cron wget

# Transfer custom configuration files
COPY config/postgresql.conf /etc/postgresql/postgresql.conf
COPY config/pg_hba.conf /etc/postgresql/pg_hba.conf

# Transfer essential startup scripts
COPY scripts/docker/primary-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/docker/secondary-entrypoint.sh /docker-entrypoint-initdb.d/entrypoint.sh
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

# TLS Certificates (Development)
RUN wget -O /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64 \
  && chmod 755 /usr/local/bin/mkcert \
  && mkcert -install

# Use less with no line wrapping for nicer query results
ENV PSQL_PAGER='less -S'

# Start in the entrypoint directory
WORKDIR /docker-entrypoint-initdb.d

# Use the custom server config file
CMD ["-c","config_file=/etc/postgresql/postgresql.conf"]
