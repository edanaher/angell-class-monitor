#!/bin/sh

## This should be run (at least once) as root before the script

mkdir -p $1/raw
mkdir -p $2
chown -R angell $1 $2
@SUDO/bin/sudo -u postgres @POSTGRESQL/bin/createuser angell || true
@SUDO/bin/sudo -u postgres @POSTGRESQL/bin/createdb angell -O angell || true
@SUDO/bin/sudo -u postgres @POSTGRESQL/bin/psql angell -c "ALTER USER angell WITH PASSWORD '@PASSWORD'"
@SUDO/bin/sudo -u angell @OUT/db/run.sh
