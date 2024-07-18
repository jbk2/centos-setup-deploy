#!/usr/bin/bash
# Lock root account
#
# Run as:
#  `./lock.sh
#
set -eo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh
source $DIR/src/functions.sh

ssh_as $SITE_USER 'bash -s' <<-STDIN
	sudo chage -E 0 root
STDIN