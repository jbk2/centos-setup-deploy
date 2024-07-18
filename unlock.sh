#!/usr/bin/bash
# Unlock root account
#
# Run as:
#  `./unlock.sh
#
set -eo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh
source $DIR/src/functions.sh

ssh_as $SITE_USER 'bash -s' <<-STDIN
	sudo chage -E -1 root
STDIN