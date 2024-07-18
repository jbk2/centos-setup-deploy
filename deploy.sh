#!/usr/bin/bash
# Deploy new content from ./public
#
# Run as:
#  `./deploy.sh
#
set -eo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh
source $DIR/src/functions.sh

echo "--- DEPLOYING ./public ON $SERVER_NAME ---"

if ! [ -d $DIR/public ]
then
	echo "./public directory does not exist!"
	exit 1
fi

start_unit "deploy"

step "upload_files" "Uploading files from ./public"
scp_as $SITE_USER $DIR/public/* /srv/$SERVER_NAME/html

step "nginx_restart" "Restarting webserver"
ssh_as $SITE_USER 'bash -s' <<-STDIN
	sudo systemctl restart nginx.service
STDIN

finish_unit