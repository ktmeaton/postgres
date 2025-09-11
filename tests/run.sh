#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# CLI Arguments

num_args=$#
positional_args=()
tests_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
postgres_dir=$(dirname $tests_dir)

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      help="true"
      shift # past argument
      ;;
    --no-cleanup)
      no_cleanup=true
      shift # past argument
      ;;
    --network)
      network=$2
      shift # past argument
      shift # past value
      ;;
    -|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      positional_args+=("$1")
      shift # past argument
      ;;
  esac
done

network_default="bff-afirms"

usage="
Run postgresql tests.\n\n
-h,--help     \t    Print help and usage\n
--no-cleanup  \t    Don't remove test database after completion.\n
--network     \t    Name of the network to create (default: ${network_default})\n
-t,--test     \t    Name of the test to run.
"

if [[ "$help" == "true" ]]; then
  echo -e $usage
  exit 0
fi

# -----------------------------------------------------------------------------
# Arguments

test_name="test_$test"
env_file=".env"
no_cleanup=${no_cleanup:-false}
network=${network:-${network_default}}

# -----------------------------------------------------------------------------
# Functions

wait_for_healthy_container () {
  container=$1
  max_checks=10
  curr_check=1

  status=unknown
  while [[ $status != "healthy" ]]; do
    status=$(docker container inspect -f '{{.State.Health.Status}}' $container)
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tContainer status check [$curr_check/$max_checks]: $status"
    if [[ $status == "restarting" || $status == "unhealthy" ]]; then
      echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tERROR: Container is unhealthy. Exiting."
      exit 1
    fi
    if [[ $status == "healthy" || $curr_check -ge $max_checks ]]; then
      break
    fi
    sleep 3
    curr_check=$(expr $curr_check + 1)
  done

  return 0
}

# -----------------------------------------------------------------------------
# Test Check

test_names=()
for name in ${positional_args[@]}; do

  if [[ $name == "all" ]]; then
    for test_path in $(ls -d ${tests_dir}/test-*); do
      test_names+=($(basename $test_path))
    done
  else
    test_name="test-$name"
    test_dir=${tests_dir}/${test_name}
    if [[ ! -e $test_dir ]]; then
      echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tERROR: Test directory does not exist: ${test_dir}"
      exit 1
    fi
    test_names+=(test-$name)
  fi
done

# -----------------------------------------------------------------------------
# Container Setup

for test_name in ${test_names[@]}; do
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\t--------------------------------------------------------------------------------------"
  test_dir=${tests_dir}/${test_name}
  output_dir="$(pwd)/tests/${test_name}"
  mkdir -p $output_dir
  compose_file="$(pwd)/tests/${test_name}/docker-compose.yml"
  container="${test_name}-db"

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tChecking if docker network exists: $network"
  network_exists=$(docker network ls  | grep -w $network || echo false)
  if [[ $network_exists == "false" ]]; then
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCreating docker network: $network"
    docker network create $network
  else
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tDocker network exists: $network"
  fi

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tSetting up container: ${container}"

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tPreparing docker-compose file: ${compose_file}"
  db_name=$(echo "$test_name" | sed 's/-/_/g')
  sed "s/{DB}/${db_name}/g" ${test_dir}/script.template.sql > ${output_dir}/script.sql
  sed -E \
    -e "s/\{NETWORK\}/$network/g" \
    -e "s/\{NAME\}/$test_name/g" \
    -e "s/\"$network\"/$network/g" \
    -e "s/\"$test_name\"/$test_name/g" \
    -e "/volumes:/a \      - ${output_dir}/script.sql:/tmp/${test_name}.sql" \
    -e "s|- \./data|- ${output_dir}/data|g" \
    -e "s|- \./|- $(pwd)/|g" \
    -e "s|- \../|- $(pwd)/../|g" \
    -e "s|build: .*|build: ${postgres_dir}|" \
    config/docker-compose.template.yml > ${compose_file}

  # Make sure it is down
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStopping container if running: ${container}"
  docker compose --env-file ${env_file} -f ${compose_file} down ${container} 1>/dev/null 2>&1

  if [[ -e ${output_dir}/data ]]; then
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up old test data: ${output_dir}/data"
    rm -rf ${output_dir}/data;
  fi

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCopying data files into test directory: ${output_dir}"
  cp -r $(pwd)/data ${output_dir}
  # We will need to regenerate certs with new container/host name
  rm -rf ${output_dir}/data/certs/*

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStarting container: ${container}"
  docker compose --env-file ${env_file} -f ${compose_file} up -d ${container}

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tWaiting for container status: healthy"
  wait_for_healthy_container "$container"

  # -----------------------------------------------------------------------------
  # Custom code

  source ${test_dir}/run.sh

  # -----------------------------------------------------------------------------
  # Cleanup

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up."
  docker compose --env-file .env -f $compose_file down ${container} 2> /dev/null
  if [[ ! $no_cleanup == 'true' ]]; then
    rm -rf ${output_dir}/data
		image=$(grep -E "image:.*${network}" ${compose_file} | sed -E 's/.*image:|"|\s//g')
   	docker image rm $image
  fi

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest complete: ${test_name}"

done
