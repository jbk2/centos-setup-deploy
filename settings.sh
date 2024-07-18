#!/usr/bin/env bash
# Server setting
#
set -eo pipefail

# Public IP address of the server
[ -z "$SERVER" ] && SERVER=

# Domain name (e.g. google.com)
[ -z "$SERVER_NAME" ] && SERVER_NAME=

# Email
[ -z "$EMAIL" ] && EMAIL=

# SSH port
[ -z "$PORT" ] && PORT=22

# SSH private key path
[ -z "$SSH_KEY" ] && SSH_KEY=~/Documents/config/new_app_sshkey

# Additional SSH options like a path to key
[ -z "$SSH_OPTIONS" ] && SSH_OPTIONS="-i $SSH_KEY -o StrictHostKeyChecking=no"

# User to replace root
[ -z "$SITE_USER" ] && SITE_USER=deploy

# Do not change the following
SITE_HOME=/srv/$SERVER_NAME

# Basic checks
if [ -z $SERVER ] || [ -z $SERVER_NAME ] || [ -z $EMAIL ] || [ -z $SSH_KEY ]
then
  echo "SERVER, SERVER_NAME, EMAIL or SSH_KEY not set."
  exit 1
fi
