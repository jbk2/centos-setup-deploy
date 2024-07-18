#!/bin/bash
# Open remote shell
#
# Run as:
#  `./ssh.sh
#
set -eo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh
source $DIR/src/functions.sh

ssh $SITE_USER@$SERVER -p $PORT $SSH_OPTIONS
