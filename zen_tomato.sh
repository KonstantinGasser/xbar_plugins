#!/bin/bash

#  <xbar.title>Tiny Zen</xbar.title>
#  <xbar.version>v2.1.7-beta</xbar.version>
#  <xbar.author>Konstantin Gasser</xbar.author>
#  <xbar.author.github>KonstantinGasser</xbar.author.github>
#  <xbar.desc>Silently show a time window of 2h pass without getting distract by it</xbar.desc>
#  <xbar.dependencies>bash</xbar.dependencies>
#
#  <xbar.var>number(COLOR_ONE=213): First quarter color</xbar.var>
#  <xbar.var>number(COLOR_TWO=213): Second quarter color</xbar.var>
#  <xbar.var>number(COLOR_THREE=213): Third quarter color</xbar.var>
#  <xbar.var>number(ZEN_RANGE=120): Focus time you want to set (in minutes)</xbar.var>
#  <xbar.var>string(ZEN_FILE="/path/to/zen-file"): Path to zen config</xbar.var>
#  
#  IDEAS:
#  - make ZEN_RANGE soft limit with a visual reminder to take a break :)

STEP_CHAR="⬤"
BREAK_PREFIX="b"

QUARTER_COLORS=($COLOR_ONE $COLOR_TWO $COLOR_THREE)

HOUR_IN_MINUTES=60
QUARTER_IN_MINUTES=15
QUARTERS_IN_HOUR=4


print_menu() {
	echo "---"
	
	# show: session must not be running
	if [ $(session_running) -eq -1 ]; then
		echo "Let's Focus | bash='$0' | param1='start' | terminal=false | refresh=true"
	fi

	# show: session must be running and no current break started
	if [ $(session_running) -eq 1 ] && [ $(break_running) -eq -1 ]; then
		echo "Coffee break | bash='$0' | param1='break' | terminal=false | refresh=true"
	fi

	# show: session must be running and break started
	if [ $(session_running) -eq 1 ] && [ $(break_running) -eq 1 ]; then
		echo "Back to work | bash='$0' | param1='continue' | terminal=false | refresh=true"
	fi

	# show: session must be running. If break or not does not matter
	if [ $(session_running) -eq 1 ]; then
		echo "Wind down | bash='$0' | param1='stop' | terminal=false | refresh=true"
	fi
}

add_break_prefix() {
	local line_number=1

	if [ $(wc -l < "${ZEN_FILE}") -gt 0 ]; then
		line_number=$(wc -l < "${ZEN_FILE}")
	fi

	sed -i '' "${line_number} s/^/${BREAK_PREFIX}/" "${ZEN_FILE}"

}


remove_break_prefix() {
	local line_number=1


	if [ $(wc -l < "${ZEN_FILE}") -gt 0 ]; then
		line_number=$(wc -l < "${ZEN_FILE}")
	fi

	sed -i '' "${line_number} s/^${BREAK_PREFIX}//" "${ZEN_FILE}"
}

# after a break we want to reset the timer
update_break_continue_time() {
	local line_number=1

	if [ $(wc -l < "${ZEN_FILE}") -gt 0 ]; then
		line_number=$(wc -l < "${ZEN_FILE}")
	fi

	local current_ts=$(tail -n1 ${ZEN_FILE} | awk -F ':' '{print $2}' | awk -F '-' '{print $1}')
	local now_ts=$(date +%s)

	sed -i '' "${line_number} s/${current_ts}/${now_ts}/" "${ZEN_FILE}"
}

# appends -unix_timestamp to the last line of the zen config
close_session() {
	
	local line_number=$(wc -l < "${ZEN_FILE}")
	local now_ts=$(date +%s)

	sed -i '' "${line_number} s/$/-${now_ts}/" "${ZEN_FILE}"
}

passed_zen_minutes() {

	# need to use -c since initally no \n is appended to the line (see case "start")
	if [ "$(wc -c < "${ZEN_FILE}")" -le 0 ]; then 
		echo "-1"
		return
	fi

	local start_ts=$(tail -n1 ${ZEN_FILE} | awk -F ':' '{print $2}' | awk -F '-' '{print $1}')
	local now_ts=$(date +%s)

	local diff=$((now_ts - start_ts))
	
	echo $(($diff / $HOUR_IN_MINUTES))
}

# -1: no break running
#  1: break running
break_running() {

	# need to use -c since initally no \n is appended to the line (see case "start")
	if [ "$(wc -c < "${ZEN_FILE}")" -le 0 ]; then 
		echo "-1"
		return
	fi

	# if the current session (last line in file) has the prefix b
	# the session is paused.
	local prefix=$(tail -n1 ${ZEN_FILE} | head -c1)

	if [ "$prefix" != "$BREAK_PREFIX" ]; then
		echo "-1"
		return
	fi

	echo "1"
}

# -1: no session running
#  1: session running
session_running() {
	
	# need to use -c since initally no \n is appended to the line (see case "start")
	if [ "$(wc -c < "${ZEN_FILE}")" -le 0 ]; then 
		echo "-1"
		return
	fi

	local nf=$(tail -n1 ${ZEN_FILE} | awk -F '-' '{print NF}')

	if [ $nf -lt 4 ]; then
		echo "1"
		return
	fi

	echo "-1"
}


if [ -z "$1" ]; then
	passed_minutes=$(passed_zen_minutes)


	if [ $(break_running) -eq 1 ]; then
		echo "☕️"
		print_menu
		exit 0
	fi

	if [ $(session_running) -eq -1 ]; then
		echo -e "\x1B[48;5;208mz\x1B[48;5;211me\x1B[48;5;213mn"
		echo -e "\x1B[0m"
	else 

		# prefix:
		# 1) either shows number of passed hours
		# 2) or if hours eq 0 static text
		#
		# divider:
		# 1) " - "
		#
		# suffix:
		# 1) shows uncompleted hour segements colors
		# 2) unclear what to show when 0 quarters (in the first 14min 59sec)??
		message=""

		# compute how many hours have passed so far.	
		hours=$((passed_minutes / $HOUR_IN_MINUTES))
		if [ $hours -gt 0 ]; then
			message+="${hours} hours: "
		else
			message+="Keep going.."
		fi

		# append divider between prefix and suffix
		message+=" - "
		
		# compute minutes of new started hour (range [0,60)).
		#
		# example:
		# 104 passed minutes implies 1 hour has passed and 44
		# minutes into the new hour have been counted
		remaining_minutes=$(($passed_minutes % $HOUR_IN_MINUTES))
		
		# compute based on the remaining minutes how many quarters
		# within that time have passed.
		#
		# example:
		# 44 minutes of the uncompleted hour have passed and
		# in total floor(44 / 15) full quarters have passed
		# which are 2
		remaining_quarters=$(($remaining_minutes / $QUARTER_IN_MINUTES))


		# for each passed quarter append a color shifted STEP_CHAR.
		for ((i = 1; i <= $remaining_quarters; i++)); do
			message+=" \x1B[38;5;${QUARTER_COLORS[$(($i-1))]}m${STEP_CHAR}"
		done

		# compute the trailing minutes last uncompleted quarter.
		# values in range [0,14).
		left_minutes=$(($remaining_minutes % $QUARTER_IN_MINUTES))
	
		# in order to not show nothing when a new hour started
		# and a quarter has not passed yet show a dot
		if [ $remaining_quarters -eq 0 ] && [ $left_minutes -ge 0 ]; then
			message+=" \x1B[38;5;${QUARTER_COLORS[0]}m${STEP_CHAR}"
		fi

		echo -e "${message}"
	fi


else 
	case "$1" in
		"start") # create a new entry in the zen config file with YYYY-MM-DD:unix-timestamp
			if [ $(session_running) -eq 1 ]; then
				echo "Starting of session only while no session is running"
				print_menu	
				exit 0
			fi
			
			echo "$(date +%Y-%m-%d):$(date +%s)" >> "${ZEN_FILE}"
			;;
		"break")
			if [ $(session_running) -eq -1 ]; then
				echo "Break of session only while session is running"
				print_menu
				exit 0
			fi
			
			if [ $(break_running) -eq 1 ]; then
				echo "Break of session only while no break is running"
				print_menu
				exit 0
			fi

			# prepend BREAK_PREFIX to current session
			if [ "$(wc -c < "${ZEN_FILE}")" -le 0 ]; then 
				echo "Break of session only when session exists"
				print_menu
				exit 0
			fi

			add_break_prefix
			;;
		"continue")

			if [ $(session_running) -eq -1 ]; then
				echo "Continue of break only when session exists"
				print_menu
				exit 0
			fi

			if [ $(break_running) -eq -1 ]; then
				echo "Continue of break only when break started"
				print_menu
				exit 0
			fi


			if [ "$(wc -c < "${ZEN_FILE}")" -le 0 ]; then 
				echo "Continue of break only when session exists"
				print_menu
				exit 0
			fi

			remove_break_prefix
			update_break_continue_time
			;;
		"stop") 
			if [ $(session_running) -eq -1 ]; then
				echo "Stopping of session only while a session is running"
				print_menu	
				exit 0
			fi

			close_session
			;;
	esac
fi

print_menu
