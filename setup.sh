#!/bin/bash

# -----------------------------------------------------------------------------
#CLI Arguments

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      network="$2"
      shift # past argument
      shift # past value
      ;;
    --name)
      name="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      help="true"
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

network_default="bff-afirms"
name_default="postgres"

usage="Docker deployment setup.\n\n
--network\tName of the network to create (default: ${network_default})\n
--name\t\tName of the container to create (default: ${name_default})\n
-h, --help\tPrint help and usage."

# -----------------------------------------------------------------------------
# Argument Parsing


if [[ $help == "true" ]]; then
  echo -e $usage
  exit 0
fi

network=${network:-${network_default}}
name=${name:-${name_default}}

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tBeginning ${name} setup."

# -----------------------------------------------------------------------------
# Create the docker network

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tChecking if docker network exists: $network"
network_exists=$(docker network ls  | grep $network || echo false)
if [[ $network_exists == "false" ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCreating docker network: $network"
  docker network create $network
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tDocker network exists: $network"
fi

# -----------------------------------------------------------------------------
# Create secure credentials

if [[ ! -e .env ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tGenerating credentials: ${name}"
  scripts/utils/generate_credentials.sh > .env
  if [[ ! -e .env.bak ]]; then
    cp .env .env.bak
  fi
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCredentials located: ${name}"
fi

# -----------------------------------------------------------------------------
# Create data directories for mounting with host permissions

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCreating data directories"
mkdir -p data
cd data
mkdir -p certs postgres pgbackrest/archive pgbackrest/backup pgbackrest/log spool
cd ..

# -----------------------------------------------------------------------------
# Create docker-compose file from template

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCreating file: docker-compose.yml"
sed \
  -e "s/{NETWORK}/$network/g" \
  -e "s/{NAME}/$name/g" \
  -e "s/\"$network\"/$network/g" \
  -e "s/\"$name\"/$name/g" \
  config/docker-compose.template.yml > docker-compose.yml

# -----------------------------------------------------------------------------
# Finish

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCompleted ${name} setup."
