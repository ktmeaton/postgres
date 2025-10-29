FROM postgres:17.6-trixie

# Install system packages:
# Unix Tools: pgbackrest, jq, curl, wget
# Unix GIS Tools: postgresql-17-postgis-3 osmium-tool, osm2pgsql
RUN apt update \
  && apt upgrade -y \
  && apt install -y curl jq osmium-tool osm2pgsql pgbackrest postgresql-17-postgis-3 wget

# Install postgres extension: pg_timetable
RUN wget https://github.com/cybertec-postgresql/pg_timetable/releases/download/v5.13.0/pg_timetable_Linux_x86_64.deb \
  && dpkg -i pg_timetable_Linux_x86_64.deb \
  && rm -f pg_timetable_Linux_x86_64.deb

# Transfer custom configuration files
COPY config/postgresql.conf /etc/postgresql/postgresql.conf
COPY config/pg_hba.conf /etc/postgresql/pg_hba.conf
COPY config/pgbackrest.conf /etc/pgbackrest/pgbackrest.conf

# Transfer essential startup scripts
COPY scripts/docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN rm -f /docker-entrypoint-initdb.d/entrypoint.sh
COPY scripts/docker/01_entrypoint.sh /docker-entrypoint-initdb.d/01_entrypoint.sh
COPY scripts/docker/02_applications.sh /docker-entrypoint-initdb.d/02_applications.sh
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
    && chmod +r /etc/pgbackrest/pgbackrest.conf \
    && mkdir -p /var/lib/pgbackrest \
    && chmod 750 /var/lib/pgbackrest \
    && chown postgres:postgres /var/lib/pgbackrest \
    && mkdir -p /data/postgresql \
    && chown -R postgres:postgres /data/postgresql \
    && chmod +r /etc/postgresql/*

# TLS Certificates (Development)
RUN wget -O /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64 \
  && chmod 755 /usr/local/bin/mkcert \
  && mkcert -install

# Final cleanup
RUN apt autoremove -y

# Use less with no line wrapping for nicer query results
ENV PSQL_PAGER='less -S'
ENV TZ='America/Edmonton'

# Start in the entrypoint directory
WORKDIR /docker-entrypoint-initdb.d

# Run as a non-root user
USER postgres

# Use the custom server config file
CMD ["-c","config_file=/etc/postgresql/postgresql.conf"]
