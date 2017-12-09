#!/bin/sh

## This should be run (at least once) as root before the script

mkdir -p $1/raw
chown -R angell $1
@SUDO/bin/sudo -u postgres @POSTGRESQL/bin/createuser angell || true
@SUDO/bin/sudo -u postgres @POSTGRESQL/bin/createdb angell -O angell || true
@SUDO/bin/sudo -u angell @POSTGRESQL/bin/psql angell < @OUT/etc/angell.sql || true
