#!/usr/bin/bash
# Provision the server based on settings.sh
#
# Run as:
#  `./setup.sh
#
set -eo pipefail

USAGE="
Usage:

	$0
	$0 -u UNIT -s STEP

Options:

	-u UNIT    run only a given unit
	-s STEP    run only a given step
	-v         run in the verbose mode"

#
# Process script arguments
#
while getopts ":u:s:h" opt; do
	case $opt in
		u)
			RUN_UNIT=$OPTARG
			;;
		s)
			RUN_STEP=$OPTARG
			;;
		v)
			VERBOSE=true
			;;
		h)
			echo "$USAGE"
			exit 0
			;;
		\?)
			echo "$OPTARG is not a valid option."
			echo "$USAGE"
			exit 1
			;;
	esac
done

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh
source $DIR/src/functions.sh

echo "--- CONFIGURING $SERVER_NAME on $SERVER ---"

#
# Unit definitions
#
start_unit "base"

step "create_user" "Creating $SITE_USER"
ssh_as root 'bash -s' <<-STDIN
	set -euo pipefail

	useradd $SITE_USER || echo "Already exists"

	# Reuse key
	rm -rf /home/$SITE_USER/.ssh
	su - $SITE_USER -c 'mkdir ~/.ssh'
	su - $SITE_USER -c 'touch ~/.ssh/authorized_keys'
	cat /root/.ssh/authorized_keys >> /home/$SITE_USER/.ssh/authorized_keys
	chmod 700 /home/$SITE_USER/.ssh
	chmod 600 /home/$SITE_USER/.ssh/authorized_keys

	# Add password-less sudo=
	echo '$SITE_USER  ALL=(ALL)  NOPASSWD: ALL' | tee /etc/sudoers.d/$SITE_USER
	chmod 0440 /etc/sudoers.d/$SITE_USER
	visudo -c -f /etc/sudoers.d/$SITE_USER
	passwd -l root
STDIN

step "system_deps" "Installing system dependencies"
ssh_as root 'bash -s' <<-STDIN
	set -euo pipefail
	dnf install epel-release -y
	dnf install -y nginx firewalld certbot cronie-anacron logrotate
STDIN

step "auto_updates" "Setting up weekly system updates"
ssh_as root 'bash -s' <<-STDIN
	set -eo pipefail

	cat <<-EOF > /etc/cron.weekly/system_update
		#!/bin/sh
		dnf update -y && systemctl restart nginx.service
	EOF

	systemctl enable crond.service
	systemctl restart crond.service
STDIN

step "journal" "Limiting the size of system log"
ssh_as root 'bash -s' <<-STDIN
	set -eo pipefail
	sed -i 's@#SystemMaxUse=@SystemMaxUse=50M@g' /etc/systemd/journald.conf
STDIN

finish_unit

start_unit "lets_encrypt"

step "upload" "Uploading NGINX config for Let's Encrypt"
scp_config_as root cert.conf site.conf

step "run" "Run NGINX for Let's Encrypt"
ssh_as root 'bash -s' <<-STDIN
	set -euo pipefail

	sed -i 's@SERVER_NAME_PLACEHOLDER@$SERVER_NAME@g' ~/site.conf
	sed -i 's@SITE_HOME_PLACEHOLDER@$SITE_HOME@g' ~/site.conf

	mv ~/site.conf /etc/nginx/conf.d/site.conf
	chown root:root /etc/nginx/conf.d/site.conf
	restorecon -RFvv /etc/nginx/conf.d
	nginx -t
	systemctl start nginx.service
STDIN

step "certbot" "Run certbot"
ssh_as root 'bash -s' <<-STDIN
	set -eo pipefail
	rm -rf /etc/letsencrypt/live/$SERVER_NAME*/
	rm -rf $SITE_HOME/certbot/.well-known
	mkdir -p $SITE_HOME/certbot/.well-known
	semanage fcontext -a -t httpd_sys_content_t '$SITE_HOME/certbot(/.*)?' || echo "Already exists"
	restorecon -RFvv $SITE_HOME/certbot
	certbot certonly --webroot --webroot-path $SITE_HOME/certbot -d $SERVER_NAME -m $EMAIL --agree-tos -n
STDIN

finish_unit

start_unit "nginx"

step "upload" "Uploading final NGINX config"
scp_config_as root site.conf

step "config" "Configure NGINX"
CERT_DIR=$(capture_ssh_as root "
	array=(\$(ls -d /etc/letsencrypt/live/$SERVER_NAME*)) && echo \${array[-1]}
")
ssh_as root 'bash -s' <<-STDIN
	set -euo pipefail

	sed -i 's@SERVER_PLACEHOLDER@$SERVER@g' ~/site.conf
	sed -i 's@SERVER_NAME_PLACEHOLDER@$SERVER_NAME@g' ~/site.conf
	sed -i 's@SITE_HOME_PLACEHOLDER@$SITE_HOME@g' ~/site.conf
	sed -i 's@CERT_DIR_PLACEHOLDER@$CERT_DIR@g' ~/site.conf

	mv ~/site.conf /etc/nginx/conf.d/site.conf
	chown root:root /etc/nginx/conf.d/site.conf
	restorecon -RFvv /etc/nginx/conf.d
	nginx -t
STDIN

step "prepare_dir" "Prepare directory for static files"
ssh_as root 'bash -s' <<-STDIN
	set -euo pipefail
	rm -rf /srv/$SERVER_NAME/html
	mkdir -p /srv/$SERVER_NAME/html
	chown :$SITE_USER /srv/$SERVER_NAME/html
	chmod g+w /srv/$SERVER_NAME/html
	semanage fcontext -a -t httpd_sys_content_t '$SITE_HOME/html(/.*)?' ||
		semanage fcontext -m -t httpd_sys_content_t '$SITE_HOME/html(/.*)?'
	restorecon -RFvv $SITE_HOME/html
STDIN

step "restart" "Restart NGINX"
ssh_as root 'bash -s' <<-STDIN
	systemctl enable nginx.service
	systemctl start nginx.service
STDIN

finish_unit

start_unit "cron"

step "setup" "Set up cron tasks"
ssh_as root 'bash -s' <<-STDIN
	set -eo pipefail

	bash -c 'cat > /etc/cron.daily/certbot <<-EOF
		#!/bin/sh
		/usr/bin/certbot renew --pre-hook "systemctl stop nginx.service" --post-hook "systemctl start nginx.service"
	EOF'

	systemctl enable crond
	systemctl restart crond
STDIN

finish_unit

start_unit "firewall" "Setting up firewall"

step "upload" "Uploading firewalld public zone config"
scp_config_as root public.xml /etc/firewalld/zones/public.xml

step "restart" "Enabling and starting firewalld"
ssh_as root 'bash -s' <<-STDIN
	systemctl enable firewalld.service
	systemctl restart firewalld.service
STDIN

finish_unit
