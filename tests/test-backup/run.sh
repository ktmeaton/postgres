#!/bin/bash

set -e

# The postgres server must not be running when pgbackrest is running.
# This means that we can't use a docker compose container, since
# as soon as we stop postgres, the whole container will stop.
# Instead, we use the postgres image, override the entrypoint,
# and run a one-off command, while never starting the postgres server.
run_pgbackrest () {
  test_data_dir=$1
  postgres_dir=$2
  image=$3
  args=$4

  docker run \
      --rm \
      --entrypoint pgbackrest  \
      --user $(id -u):$(id -g) \
      -v ${test_data_dir}/db:/data/postgresql \
      -v ${test_data_dir}/pgbackrest:/data/pgbackrest \
      -v ${test_data_dir}/spool:/var/spool/pgbackrest/ \
      -v ${test_data_dir}/certs:/data/certs \
      -v ${postgres_dir}/config/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf \
      -v ${postgres_dir}/config/pg_hba.conf:/etc/postgresql/pg_hba.conf \
      $image \
      $args

  return 0
}

# -----------------------------------------------------------------------------
# Test Script

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."

docker compose $compose_args exec -T postgres \
  bash -c "psql -f /tmp/${test_name}.sql" 1>/dev/null 2>&1

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tIdentifying restore points."
cmd="select label,lsn_stop from backup.log_extended where annotation->>'source' = 'test-backup' and annotation->>'comment' = '{comment}' order by stop desc limit 1;"
comments=("after_create" "after_insert" "after_delete" "after_final")
declare -A targets
for comment in ${comments[@]}; do
  comment_cmd=$(echo $cmd | sed "s/{comment}/${comment}/g")
  target=$(docker compose $compose_args exec -T postgres bash -c "PSQL_PAGER=cat psql -t --csv -c \"$comment_cmd\"" | sed -e "s/\r//g")
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

  docker compose $compose_args down postgres
  run_pgbackrest ${test_data_dir} ${postgres_dir} ${image} "--stanza=main --target-action=promote --type=lsn --set=$label --target=$lsn --target-timeline=current restore"
  docker compose $compose_args up -d postgres
  wait_for_healthy_container $container

  observed=${test_output_dir}/observed.txt
  expected=${test_output_dir}/expected.txt
  if [[ -e $observed ]]; then rm -f $observed; fi
  if [[ -e $expected ]]; then rm -f $expected; fi

  docker compose $compose_args exec -T postgres \
    bash -c "PSQL_PAGER=cat psql test_backup -t --csv -c 'select * from test' " | \
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

  result=$(cmp $expected $observed 2> /dev/null || echo "fail")
  exit_code=$?
  if [[ ${result} == "" && $exit_code == 0 ]]; then
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass ($comment): expected=$expected_debug observed=$observed_debug"
  else
    echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tERROR: Test failure ($comment): expected=$expected_debug observed=$observed_debug"
    exit 1
  fi

  rm -f $observed $expected
done

# -----------------------------------------------------------------------------
# Cleanup

if [[ $no_cleanup == 'true' ]]; then
  docker compose $compose_args exec -T ${container} bash -c "PSQL_PAGER=cat psql -c \"drop database test_backup\"" 1> /dev/null
fi
