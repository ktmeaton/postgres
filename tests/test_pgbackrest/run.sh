#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# CLI Arguments

num_args=$#

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      help="true"
      shift # past argument
      ;;
    -d|--db)
      db=$2
      shift # past argument
      shift # past value
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

usage="
$test_name: Test pgBackRest backup and restore functionality.\n\n
-h,--help \t Print help and usage\n
-d,--db   \t Database name to create and run test in.
"

if [[ "$help" == "true" ]]; then
  echo -e $usage
  exit 0
fi

# -----------------------------------------------------------------------------
# Arguments

test_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
test_name=$(basename $test_dir)
project_dir=$(dirname $(dirname $test_dir))
db=${db:-$test_name}
env_file=".env"
compose_file="${test_dir}/docker-compose.yml"

# -----------------------------------------------------------------------------
# Functions

wait_for_healthy_container () {
  container=$1
  max_checks=5
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
    sleep 5
    curr_check=$(expr $curr_check + 1)
  done

  return 0
}

# -----------------------------------------------------------------------------
# Container Setup

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tRunning test: ${test_name}"

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tPreparing docker-compose file: ${compose_file}"
sed "s/{DB}/${db}/g" ${test_dir}/script.template.sql > ${test_dir}/script.sql
sed -E \
  -e "/volumes:/a \      - ${test_dir}/script.sql:/tmp/${test_name}.sql" \
  -e "s/container_name: postgres/container_name: $test_name/" \
  -e "s/^\ + postgres:/\  ${test_name}:/" \
  -e "s/:-postgres/:-${test_name}/" \
  -e "s|- \./|- ${project_dir}/|g" \
  -e "s|build: \.|build: ../../|" \
  docker-compose.yml > ${compose_file}

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tStarting container: ${test_name}"
docker compose --env-file ${env_file} -f ${compose_file} up -d

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tWaiting for container status: healthy"
wait_for_healthy_container $test_name

# -----------------------------------------------------------------------------
# Test Script

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."
docker compose --env-file ${env_file} -f ${compose_file} exec -T test_pgbackrest \
  bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -f /tmp/${test_name}.sql" 1> /dev/null 2>&1

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tIdentifying restore points."
cmd="select label,lsn_stop from backup.log_extended where annotation->>'source' = '${test_name}' and annotation->>'comment' = '{comment}' order by stop desc limit 1;"
comments=("after_create" "after_insert" "after_delete" "after_final")
declare -A targets
for comment in ${comments[@]}; do
  comment_cmd=$(echo $cmd | sed "s/{comment}/${comment}/g")
  target=$(docker compose --env-file ${env_file} -f ${compose_file} exec -T ${test_name} bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -t --csv -c \"$comment_cmd\"" | sed -e "s/\r//g")
  targets[$comment]=$target
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tLocated restore point ($comment): $target"
done

# -----------------------------------------------------------------------------
# pgBackRest checks

for comment in ${comments[@]}; do
  target=${targets[$comment]}
  label=$(echo "$target" | cut -d ',' -f 1)
  lsn=$(echo "$target" | cut -d ',' -f 2)
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\t--------------------------------------------------------------------------"
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tRestoring point ($comment): lsn=$lsn label=$label"
  docker compose --env-file .env -f ${test_dir}/docker-compose.yml down
  scripts/docker/pgbackrest.sh --stanza=main --target-action=promote --type=lsn --target="$lsn" --target-timeline=current restore 1>&2

  docker compose --env-file .env -f ${test_dir}/docker-compose.yml up -d
  wait_for_healthy_container $test_name

  observed=${test_dir}/observed.txt
  expected=${test_dir}/expected.txt
  if [[ -e $observed ]]; then rm -f $observed; fi
  if [[ -e $expected ]]; then rm -f $expected; fi

  docker compose --env-file ${env_file} -f ${compose_file} exec -T $test_name \
    bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres test_pgbackrest -t --csv -c 'select * from test' " | \
    tr -d $'\r' \
    > $observed

  if [[ "$comment" == "after_create" ]]; then
    touch $expected
  elif [[ "$comment" == "after_insert" ]]; then
    echo -e "1,A\n2,B" > $expected
  elif [[ "$comment" == "after_delete" ]]; then
    echo -e "2,B" > $expected
  elif [[ "$comment" == "after_final" ]]; then
    echo -e "2,B\n3,C" > $expected
  fi

  observed_debug=$(cat $observed | tr '\n' ';');
  expected_debug=$(cat $expected | tr '\n' ';');

  if [[ $(cmp $expected $observed) == "" ]]; then
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass ($comment): expected=$expected_debug observed=$observed_debug"
  else
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tERROR: Test failure ($comment): expected=$expected_debug observed=$observed_debug"
    exit 1
  fi

  rm -f $observed $expected
done

# -----------------------------------------------------------------------------
# Cleanup

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tCleaning up."
docker compose --env-file ${env_file} -f ${compose_file} exec -T ${test_name} bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"drop database ${test_name}\""
docker compose --env-file .env -f ${test_dir}/docker-compose.yml down

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest complete: ${test_name}"
