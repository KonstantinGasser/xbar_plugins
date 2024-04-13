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
STEP_CHARS=("➊" "➋" "➌" "◰") # index 3 not needed since range of quarters is [0,4)

QUARTER_COLORS=($COLOR_ONE $COLOR_TWO $COLOR_THREE)

HOUR_IN_MINUTES=60
QUARTER_IN_MINUTES=15
QUARTERS_IN_HOUR=4


print_menu() {
	echo "---"

	if [ $(session_running) -eq -1 ]; then
		echo "Let's Focus | bash='$0' | param1='start' | terminal=false | refresh=true"
	else
		echo "Coffee break | bash='$0' | param1='stop' | terminal=false | refresh=true"
	fi
}

# UNUSED START
# gradient_by_step() {
#
# 	local max_quarters=$(($ZEN_RANGE / $QUARTER_IN_MINUTES))
# 	# maximum consecutive sequence of ansi colors in increasing/decreasing color shades
# 	# 202->203->204->205->206->207
# 	# 208 begin of new color shade
# 	local max_steps=6 
#
# 	local step=$1
# 	if [ $COLOR_START -ge $COLOR_END ]; then
# 		step=$((-1*step))
# 	fi
#
# 	# step=$(((step * max_steps) / max_quarters))
# 	step=$(scale $max_quarters $max_steps $step)
#
# 	# \033[38;5;#m
# 	echo -e "\x1B[38;5;$((${COLOR_START}+step))m"
# }
#
# scale() {
# 	local maxima=$1
# 	local nominal=$2
# 	local value=$3
# 	echo "$(((value * nominal) / maxima))"
# }
#
# UNUSED END

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


	if [ "$passed_minutes" -lt 0 ]; then
		echo -e "\x1B[48;5;208mz\x1B[48;5;211me\x1B[48;5;213mn"
		echo -e "\x1B[0m"
	else 

		# prefix:
		# 1) either shows number of passed hours
		# 2) or if hours eq 0 static text
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

		# remaining quarters can be zero at which point we do not want to
		# include a divider between the message prefix and suffix
		if [ $remaining_quarters -gt 0 ]; then
			message+=" "
		fi

		# for each passed quarter append a color shifted STEP_CHAR.
		for ((i = 1; i <= $remaining_quarters; i++)); do
			message+=" \x1B[38;5;${QUARTER_COLORS[$(($i-1))]}m${STEP_CHAR}"
			
		done

		# NOTE: not sure what to do which this info?
		#
		# compute the trailing minutes last uncompleted quarter.
		# values in range [0,14).
		left_minutes=$(($remaining_minutes % $QUARTER_IN_MINUTES))

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
			echo -n "$(date +%Y-%m-%d):$(date +%s)" >> "${ZEN_FILE}"
			;;
		"stop") 
			if [ $(session_running) -eq -1 ]; then
				echo "Stopping of session only while a session is running"
				print_menu	
				exit 0
			fi
			echo "-$(date +%s)" >> "$ZEN_FILE"
			;;
	esac
fi

print_menu
