#!/bin/bash

echo "Beginning postgres setup."

echo "Generating secret credentials: .env"
if [[ ! -e .env ]]; then
    {
        echo -e "# Host user and group information for non-root container usage"
        echo USER_GROUP_ID=$(id -u):$(id -g)

        echo -e "\n# Database Credentials"
        echo POSTGRES_PASSWORD=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 50)
        echo CUSTOM_PASSWORD=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 50)

        echo -e "\n# Caddy"
        echo DOMAIN_NAME=localhost

    } > .env

    cp .env .env.bak
fi

# postgres
echo "Creating data directories: data/postgres"
mkdir -p data/postgres
cd data/postgres
mkdir -p certs db pgbackrest/archive pgbackrest/backup pgbackrest/log spool
cd ../..

echo "Completed postgres setup."
