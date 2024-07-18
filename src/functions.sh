# Define a new unit block
#
#   unit "postgresql"
#
start_unit () {
	UNIT=$1

	if [ -z "$UNIT" ]
	then
		fail "A unit name has to be provided"
		return
	fi

	if run_unit
	then
		echo "==> CONFIGURING $1"
	fi
}

# Define a new step block within a unit
#
#   step "install" "Install a new package"
#
step () {
	STEP=$1
	DESC=$2

	if [ -z "$STEP" ]
	then
		fail "A step name has to be provided"
		return
	fi

	if run_step
	then
		if [ -z "$DESC" ]
		then
			echo "[$UNIT] [$STEP] Running step..."
		else
			echo "[$UNIT] [$STEP] $DESC..."
		fi
	fi
}

# Print a successful message
#
#   command && success
#
success () {
	if run_step
	then
		print_result "Ok."
	fi
}

# Print an error message
#
#   command || fail
#
fail () {
	if run_step
	then
		if [ -z "$1" ]
		then
			print_result "^^^ Failed."
		else
			print_result "Failed: $1"
		fi
		exit 1
	fi
}

# Print a message as part of a step or standalone
#
#   print_result "Print me"
#
print_result () {
	if [ -z "$UNIT" ] || [ -z "$STEP" ]
	then
		echo $1
	else
		echo "[$UNIT] [$STEP] $1"
	fi
}

# Finish a unit block
#
#   finish_unit
#
finish_unit () {
	if run_unit
	then
		echo "[$UNIT] Configured."
	fi
}

# Evaluate if a current unit should run
run_unit () {
	[ -z "$RUN_UNIT" ] || [ "$RUN_UNIT" == "$UNIT" ]
}

# Evaluate if a current step should run
run_step () {
	run_unit && ([ -z "$RUN_STEP" ] || [ "$RUN_STEP" == "$STEP" ])
}

# Run an SSH command as a given user and keep the output
# if VERBOSE is set to true
#
#   ssh_as root "command"
#
ssh_as () {
	if run_step
	then
		local args="$1@$SERVER -p $PORT $SSH_OPTIONS"
		shift
		if [ "$VERBOSE" = "true" ]
		then
			ssh $args $@ && success || fail
		else
			ssh $args $@ > /dev/null && success || fail
		fi
	else
		return 0
	fi
}

# Run an SSH command as a given user and capture the output
#
#   capture_ssh_as root "command"
#
capture_ssh_as () {
	if run_step
	then
		local args="$1@$SERVER -p $PORT $SSH_OPTIONS"
		shift
		ssh $args $@ 2>&1
	else
		return 0
	fi
}

# Run scp a given user
#
#   scp_as $ADMIN config/cert.crt /home/db_admin
#
scp_as () {
	if run_step
	then
		local args="-P $PORT $SSH_OPTIONS"

		if [ "$VERBOSE" = "true" ]
		then
			scp $args $2 $1@$SERVER:$3 \
				&& success || fail
		else
			scp $args $2 $1@$SERVER:$3 \
				> /dev/null && success || fail
		fi
	else
		return 0
	fi
}

# Copy a config file as a given user to the provided
# destination or the user home
#
# scp_config_as root postgresql.conf /root
#
scp_config_as () {
	local dest=$3

	if [ -z "$dest" ]
	then
		dest=$2
	fi

	scp_as $1 $DIR/config/$2 $dest
}

# Ask for a password for a given user and save it
# to the given variable
#
#  ask_password $DB_USER DB_PASSWORD
#
ask_password () {
	if run_step
	then
		read -sp "Enter passcode for $1: " $2
		echo
	else
		return 0
	fi
}