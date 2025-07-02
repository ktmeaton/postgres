#!/bin/bash


echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tBeginning PostgreSQL setup."

# Create the docker network
echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tChecking if docker network exists: bff_afirms"
network_exists=$(docker network ls  | grep bff_afirms || echo false)
if [[ $network_exists == "false" ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCreating docker network: bff_afirms"
  docker network create bff_afirms
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tDocker network exists: bff_afirms"
fi

if [[ ! -e .env ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tGenerating credentials: postgres"
  scripts/generate_credentials.sh > .env
  if [[ ! -e .env.bak ]]; then
    cp .env .env.bak
  fi
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCredentials located: postgres"
fi

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCompleted PostgreSQL setup."
