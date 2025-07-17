#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# Test Script

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."

docker compose --env-file ${env_file} -f ${compose_file} exec -T $container \
  bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U \$POSTGRES_USER -f /tmp/${test_name}.sql" 1> /dev/null 2>&1

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tIdentifying restore points."
cmd="select label,lsn_stop from backup.log_extended where annotation->>'source' = 'test-backup' and annotation->>'comment' = '{comment}' order by stop desc limit 1;"
comments=("after_create" "after_insert" "after_delete" "after_final")
declare -A targets
for comment in ${comments[@]}; do
  comment_cmd=$(echo $cmd | sed "s/{comment}/${comment}/g")
  target=$(docker compose --env-file ${env_file} -f ${compose_file} exec -T ${container} bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U \$POSTGRES_USER -t --csv -c \"$comment_cmd\"" | sed -e "s/\r//g")
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

  docker compose --env-file .env -f ${test_dir}/docker-compose.yml down $container 2> /dev/null
  run_pgbackrest "--stanza=main --target-action=promote --type=lsn --target=$lsn --target-timeline=current restore"
  docker compose --env-file .env -f ${test_dir}/docker-compose.yml up -d $container 2> /dev/null
  wait_for_healthy_container $container

  observed=${test_dir}/observed.txt
  expected=${test_dir}/expected.txt
  if [[ -e $observed ]]; then rm -f $observed; fi
  if [[ -e $expected ]]; then rm -f $expected; fi

  docker compose --env-file ${env_file} -f ${compose_file} exec -T $container \
    bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U \$POSTGRES_USER test_backup -t --csv -c 'select * from test' " | \
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

if [[ $no_cleanup == 'true' ]]; then
  docker compose --env-file ${env_file} -f ${compose_file} exec -T ${container} bash -c "PSQL_PAGER=cat PGPASSWORD=\$POSTGRES_PASSWORD psql -U \$POSTGRES_USER -c \"drop database test_backup\"" 1> /dev/null
fi
