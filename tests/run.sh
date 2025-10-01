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
    --data-dir)
      data_dir=$2
      shift # past argument
      shift # past value
      ;;
    --no-cleanup)
      no_cleanup=true
      shift # past argument
      ;;
    --project)
      project=$2
      shift # past argument
      shift # past value
      ;;
    --output-dir)
      output_dir=$2
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

data_dir_default="$(pwd)/data/postgres"
project_default="postgres"
output_dir_default="$(pwd)/tests_output"

usage="
Run postgresql database tests.\n
tests/run.sh [options] [auth,backup,schedule,all]\n\n
-h,--help     \t    Print help and usage\n
--data-dir    \t    Directory where postgres data files live: ${data_dir_default}).\n
--no-cleanup  \t    Don't remove test database after completion.\n
--output-dir  \t    Output directory default: ${output_dir_default}).\n
--project     \t    Name of the project to create isolated container network (default: ${project_default})\n
"

if [[ "$help" == "true" ]]; then
  echo -e $usage
  exit 0
fi

# -----------------------------------------------------------------------------
# Arguments

test_name="test_$test"
env_file="$(pwd)/.env"
no_cleanup=${no_cleanup:-false}
data_dir=${data_dir-${data_dir_default}}
project=${project-${project_default}}
output_dir=${output_dir-${output_dir_default}}

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
    test_names+=("$test_name")
  fi
done

# -----------------------------------------------------------------------------
# Container Setup

for test_name in ${test_names[@]}; do
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\t--------------------------------------------------------------------------------------"
  test_dir=${tests_dir}/${test_name}
  test_output_dir="${output_dir}/${test_name}"
  mkdir -p $test_output_dir
  compose_file="${test_output_dir}/docker-compose.yml"
  container="${project}-${test_name}-db"
  image=$(grep -E "image:.*postgres" ${postgres_dir}/docker-compose.yml | sed -E 's/\s+//g' | cut -d ":" -f 2-3 )

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tSetting up container: ${container}"

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tPreparing docker-compose file: ${compose_file}"
  db_name=$(echo "${test_name}" | sed 's/-/_/g')
  sed "s/{DB}/${db_name}/g" ${test_dir}/script.template.sql > ${test_output_dir}/script.sql

  sed -E \
    -e "/volumes:/a \      - ${test_output_dir}/script.sql:/tmp/${test_name}.sql" \
    -e "s|- \./data|- ${test_output_dir}/data|g" \
    -e "s|- \./|- $(pwd)/|g" \
    -e "s|- \../|- $(pwd)/../|g" \
    -e "s|build: .*|build: ${postgres_dir}|" \
    ${postgres_dir}/docker-compose.yml > ${compose_file}

  compose_args="-p ${project}-${test_name} --env-file ${env_file} -f ${compose_file}"
  # Make sure it is down
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStopping container if running: ${container}"
  docker compose $compose_args down postgres #1>/dev/null 2>&1

  if [[ -e ${test_output_dir}/data ]]; then
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up old test data: ${test_output_dir}/data"
    rm -rf ${test_output_dir}/data;
  fi

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCopying data files into test directory: ${test_output_dir}"
	test_data_dir="${test_output_dir}/data/postgres"

  mkdir -p ${test_data_dir}
  cp -r ${data_dir}/db ${test_data_dir}/db
  cp -r ${data_dir}/pgbackrest ${test_data_dir}/pgbackrest
  # We will need to regenerate certs with new container/host name
  mkdir -p ${test_data_dir}/certs

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStarting container: ${container}"
  docker compose $compose_args up -d postgres

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tWaiting for container status: healthy"
  wait_for_healthy_container "$container"

  # -----------------------------------------------------------------------------
  # Custom code

  source ${test_dir}/run.sh

  # -----------------------------------------------------------------------------
  # Cleanup

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up."
  docker compose $compose_args down postgres 2> /dev/null
  if [[ ! $no_cleanup == 'true' ]]; then
    rm -rf ${test_output_dir}/data
		#image=$(grep -E "image:.*${network}" ${compose_file} | grep -v "#.*image:" | sed -E 's/.*image:|"|\s//g')
   	#docker image rm $image || true
  fi

  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest complete: ${test_name}"

done
