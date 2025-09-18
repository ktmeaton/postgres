#!/bin/bash

set +e

echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tExecuting test script."

observed=${test_output_dir}/observed.txt
expected=${test_output_dir}/expected.txt
if [[ -e $observed ]]; then rm -f $observed; fi
if [[ -e $expected ]]; then rm -f $expected; fi

# ----------------------------------------------------------------------------#
# superuser password

docker exec $container bash -c "PGPASSWORD=\$PGPASSWORD PGUSER=\$PGUSER psql"
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (superuser_password): observed=$exit_code"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (superuser_password): expected=0 observed=$exit_code"
  exit 1
fi

# ----------------------------------------------------------------------------#
# custom password

docker exec ${container} bash -c "PGPASSWORD=\$CUSTOM_PASSWORD PGUSER=custom PGDATABASE=custom psql"
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (custom_password): observed=$exit_code"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (custom_password): expected=0 observed=$exit_code"
  exit 1
fi

# ----------------------------------------------------------------------------#
# No Remote Superuser auth

docker exec ${container} bash -c "PGPASSWORD=\$PGPASSWORD PGUSER=\$PGUSER psql postgres://@${container}" > $observed 2>&1
expected='pg_hba.conf rejects connection for .* user "postgres".* SSL encryption'
observed_debug=$(cat $observed | tr '\n' ';');
if [[ $(grep -E "$expected" $observed) ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (no_remote_superuser_auth): observed=$expected"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (no_remote_superuser_auth): expected=$expected observed=$observed_debug"
  exit 1
fi

# ----------------------------------------------------------------------------#
# No Password

docker exec ${container} bash -c "unset PGPASSWORD && psql -U custom" > $observed 2>&1
expected="fe_sendauth: no password supplied"
observed_debug=$(cat $observed | tr '\n' ';');

if [[ $(grep "$expected" $observed) ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (no_password): observed=$expected"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (no_password): expected=$expected observed=$observed_debug"
  exit 1
fi

# ----------------------------------------------------------------------------#
# Wrong Password

docker exec ${container} bash -c "PGPASSWORD=WRONG_PASSWORD psql -U \$PGUSER" > $observed 2>&1
expected="password authentication failed for user"
observed_debug=$(cat $observed | tr '\n' ';');

if [[ $(grep "$expected" $observed) ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (wrong_password): observed=$expected"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (wrong_supplied): expected=$expected observed=$observed_debug"
  exit 1
fi

# ----------------------------------------------------------------------------#
# No SSL

docker exec ${container} bash -c "PGPASSWORD=\$PGPASSWORD PGUSER=\$PGUSER psql 'postgres://@$container?sslmode=disable'" > $observed 2>&1
expected="pg_hba.conf rejects connection for host .* no encryption"
observed_debug=$(cat $observed | tr '\n' ';');

if [[ $(grep -E "$expected" $observed) ]]; then
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest pass (no_ssl): observed=$expected"
else
  echo -e "$(date '+%Y-%m-%d %H:%m:%S')\tTest fail (no_ssl): expected=$expected observed=$observed_debug"
  exit 1
fi

rm -f $observed

set -e
