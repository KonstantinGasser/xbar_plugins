#!/bin/bash

#  <xbar.title>Tiny Zen</xbar.title>
#  <xbar.version>v2.1.7-beta</xbar.version>
#  <xbar.author>Konstantin Gasser</xbar.author>
#  <xbar.author.github>KonstantinGasser</xbar.author.github>
#  <xbar.desc>Silently show a time window of 2h pass without getting distract by it</xbar.desc>
#  <xbar.dependencies>bash</xbar.dependencies>
#
#  <xbar.var>number(COLOR_START=208): Gradient color start</xbar.var>
#  <xbar.var>number(COLOR_END=213): Gradient color color</xbar.var>
#  <xbar.var>number(ZEN_RANGE=120): Focus time you want to set (in minutes)</xbar.var>
#  
#  ZEN_FILE also needs to be exported as ENV.
#  Exlcuded here so I don't have to expose my local path on github :)
#  use: export ZEN_FILE="/path/to/zen.txt"

COLOR_START=205
COLOR_END=202
ZEN_RANGE=120
ZEN_FILE="/Users/konstantingasser/.xbar/zen.txt"
STEP_CHAR="■"

current_zen_minutes() {

	# need to use -c since initally no \n is appended to the line (see case "start")
	if [ "$(wc -c < "${ZEN_FILE}")" -le 0 ]; then 
		echo "-1"
		return
	fi

	local start_ts=$(tail -n1 ${ZEN_FILE} | awk -F ':' '{print $2}' | awk -F '-' '{print $1}')
	local now_ts=$(date +%s)

	local diff=$((now_ts - start_ts))
	
	echo $(($diff / 60))
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
	passed_minutes=$(current_zen_minutes)


	if [ "$passed_minutes" -lt 0 ]; then
		echo -e "\x1B[48;5;208mz\x1B[48;5;211me\x1B[48;5;213mn"
	else 
		quarters=$((passed_minutes / 15))

		message=""
		reminder_quarters=$(($quarters % 4)) # catch reminding quarters

		# here each iteration implies 1 hour has passed
		# which we can render
		hours=$quarters
		counter=0
		while [ $hours -gt 3 ]; do
			counter+=1
			hours=$((hours-4))
		done

		message+="Focused ${hours}h | "
		# account for reminding quarters of current hour
		# and somehow render them
		for ((i = 1; i <= reminder_quarters; i++)); do
			message+="$(gradient_by_step $i)$STEP_CHAR"	
		done

			
		echo -e "${message}"
	fi


else 
	case "$1" in
		"start") # create a new entry in the zen config file with YYYY-MM-DD:unix-timestamp
			echo -n "$(date +%Y-%m-%d):$(date +%s)" >> "${ZEN_FILE}"
			;;
		"stop") 

			echo "-$(date +%s)" >> "$ZEN_FILE"
			;;
	esac
fi


echo "---"

if [ $(session_running) -eq -1 ]; then
	echo "Let's Focus | bash='$0' | param1='start' | terminal=false | refresh=true"
else
	echo "Coffee break | bash='$0' | param1='stop' | terminal=false | refresh=true"
fi

# gradient from orange -> pink
color_gradient() {

	local passed_minutes=$(min $1 ${ZEN_RANGE})
	local color_diff=$((${COLOR_END}-${COLOR_START}))

	# scale ZEN_RANGE to color diff. Asumption is that ZEN_RANGE >> color_diff
	local step_increment=$(( (passed_minutes * color_diff) / ${ZEN_RANGE} ))

	# \033[38;5;#m
	echo "/x1B[38;5;$((${COLOR_START}+step_increment))m"

}
