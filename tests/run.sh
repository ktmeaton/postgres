#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# CLI Arguments

num_args=$#
positional_args=()
tests_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
project_dir=$(dirname $tests_dir)

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

usage="
Run postgresql tests.\n\n
-h,--help \t Print help and usage\n
--no-cleanup \t Don't remove test database after completion.
-t,--test \t Name of the test to run.
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

run_pgbackrest () {
  args=$1

  docker run \
      --rm \
      --entrypoint pgbackrest  \
      --user $(id -u):$(id -g) \
      -v ${test_dir}/data/postgres:/data/postgresql \
      -v ${test_dir}/data/pgbackrest:/data/pgbackrest \
      -v ${test_dir}/data/spool:/var/spool/pgbackrest/ \
      -v ${test_dir}/data/certs:/data/certs \
      -v ${project_dir}/config/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf \
      -v ${project_dir}/config/pg_hba.conf:/etc/postgresql/pg_hba.conf \
      bff-afirms/postgres:17.5 \
      $args

  return 0
}

# -----------------------------------------------------------------------------
# Test Check

test_names=()
for name in ${positional_args[@]}; do

  if [[ $name == "all" ]]; then
    for test_path in $(ls -d ${tests_dir}/test_*); do
      test_names+=($(basename $test_path))
    done
  else
    test_name="test_$name"
    test_dir=${tests_dir}/${test_name}
    if [[ ! -e $test_dir ]]; then
      echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tERROR: Test directory does not exist: ${test_dir}"
      exit 1
    fi
    test_names+=(test_$name)
  fi
done

# -----------------------------------------------------------------------------
# Container Setup

for test_name in ${test_names[@]}; do
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\t--------------------------------------------------------------------------------------"
  test_dir=${tests_dir}/${test_name}
  db=${db:-$test_name}
  compose_file="${test_dir}/docker-compose.yml"

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tSetting up container: ${test_name}"

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tPreparing docker-compose file: ${compose_file}"
  sed "s/{DB}/${db}/g" ${test_dir}/script.template.sql > ${test_dir}/script.sql
  sed -E \
    -e "/volumes:/a \      - ${test_dir}/script.sql:/tmp/${test_name}.sql" \
    -e "s/container_name: postgres/container_name: $test_name/" \
    -e "s/^\ + postgres:/\  ${test_name}:/" \
    -e "s/:-postgres/:-${test_name}/" \
    -e "s|- \./data|- ${test_dir}/data|g" \
    -e "s|- \./|- ${project_dir}/|g" \
    -e "s|build: \.|build: ../../|" \
    docker-compose.yml > ${compose_file}
  # Make sure it is down
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStopping container if running: ${test_name}"
  docker compose --env-file ${env_file} -f ${compose_file} down 2>/dev/null

  if [[ -e ${test_dir}/data ]]; then
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up old test data."
    rm -rf ${test_dir}/data;
  fi

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCopying data files into test directory."
  cp -r ${project_dir}/data ${test_dir}
  # We will need to regenerate certs with new container/host name
  rm -rf ${test_dir}/data/certs/*

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStarting container: ${test_name}"
  docker compose --env-file ${env_file} -f ${compose_file} up -d 2>/dev/null

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tWaiting for container status: healthy"
  wait_for_healthy_container "$test_name"

  # -----------------------------------------------------------------------------
  # Custom code

  source ${test_dir}/run.sh

  # -----------------------------------------------------------------------------
  # Cleanup

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up."
  if [[ $no_cleanup == 'true' ]]; then
    rm -rf ${test_dir}/data
  fi

  docker compose --env-file .env -f ${test_dir}/docker-compose.yml down 2> /dev/null

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest complete: ${test_name}"

done
