FROM postgres:17.6-bookworm

# PostgreSQL Extensions: postgis
# Unix Tools: pgbackrest, jq, curl
# Unix GIS Tools: osmium, osm2pgsql
RUN apt update \
  && apt upgrade -y \
  && apt install -y curl pgbackrest jq wget postgresql-17-postgis-3 osmium-tool osm2pgsql

# pg_timetable
RUN wget https://github.com/cybertec-postgresql/pg_timetable/releases/download/v5.13.0/pg_timetable_Linux_x86_64.deb \
  && dpkg -i pg_timetable_Linux_x86_64.deb

# Transfer custom configuration files
COPY config/postgresql.conf /etc/postgresql/postgresql.conf
COPY config/pg_hba.conf /etc/postgresql/pg_hba.conf

# Transfer essential startup scripts
COPY scripts/docker/primary-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/docker/secondary-entrypoint.sh /docker-entrypoint-initdb.d/entrypoint.sh
COPY scripts/sql /docker-entrypoint-initdb.d/sql
COPY scripts/utils /docker-entrypoint-initdb.d/utils

RUN cp /docker-entrypoint-initdb.d/utils/* /usr/local/bin

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
ENV TZ='Canada/Mountain'

# Start in the entrypoint directory
WORKDIR /docker-entrypoint-initdb.d

USER postgres

# Use the custom server config file
CMD ["-c","config_file=/etc/postgresql/postgresql.conf"]
