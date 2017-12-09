#!/bin/sh

## This should be run as angell to run the db setup

PSQL="@POSTGRESQL/bin/psql angell"

if ! $PSQL -c '\dt' | grep -q db_setup; then
  $PSQL -c "CREATE TABLE db_setup(name varchar PRIMARY KEY, created timestamp NOT NULL)";
fi

cd $(dirname "${BASH_SOURCE[0]}")
already_run=$($PSQL -c "SELECT name FROM db_setup")
for sql in *.sql; do
  if echo $already_run | grep -q $sql; then
    continue;
  fi
  $PSQL < $sql || true
  $PSQL -c "INSERT INTO db_setup (name, created) VALUES ('${sql##*/}', 'now')"
done
