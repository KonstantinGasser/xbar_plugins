#!/bin/bash

# defines how long a single Zen session goes
ZEN_TIME_RANGE=$((10))

COLOR_ORANGE=208
COLOR_PINK=213


current_zen_minutes() {

	# need to use -c since initally no \n is appended to the line (see case "start")
	if [ "$(wc -c < "${ZEN_CONFIGS_PATH}")" -le 0 ]; then 
		echo "-1"
		return
	fi

	local start_ts=$(tail -n1 ${ZEN_CONFIGS_PATH} | awk -F ':' '{print $2}' | awk -F '-' '{print $1}')
	local now_ts=$(date +%s)

	local diff=$((now_ts - start_ts))
	
	echo $(($diff / 60))
}

# -1: no session running
#  1: session running
session_running() {
	
	# need to use -c since initally no \n is appended to the line (see case "start")
	if [ "$(wc -c < "${ZEN_CONFIGS_PATH}")" -le 0 ]; then 
		echo "-1"
		return
	fi

	local nf=$(tail -n1 ${ZEN_CONFIGS_PATH} | awk -F '-' '{print NF}')

	if [ $nf -lt 4 ]; then
		echo "1"
		return
	fi

	echo "-1"
}

# gradient from orange -> pink
color_gradient() {
	local passed_minutes=$(min $1 $ZEN_TIME_RANGE)
	local color_diff=$(($COLOR_PINK-$COLOR_ORANGE))

	# scale ZEN_TIME_RANGE to color diff. Asumption is that ZEN_TIME_RANGE >> color_diff
	local step_increment=$(( (passed_minutes * color_diff) / $ZEN_TIME_RANGE ))

	# \033[38;5;214m
	echo "\033[38;5;$(($COLOR_ORANGE+step_increment))m"
}

min() {
    if [ "$1" -lt "$2" ]; then
        echo "$1"
    else
	    echo "$2"
    fi
}

if [ -z "$1" ]; then
	passed_minutes=$(current_zen_minutes)

	if [ "$passed_minutes" -lt 0 ]; then
	echo "Init state"
	else 
		# local char="①"
		# if [ "$passed_minutes" -ge 60 ]; then
		# 	char="②"
		# fi
		char="⬤"

		color=$(color_gradient $passed_minutes)
		echo -e "${color}${char}"
	fi


else 
	case "$1" in
		"start") # create a new entry in the zen config file with YYYY-MM-DD:unix-timestamp
			echo -n "$(date +%Y-%m-%d):$(date +%s)" >> "${ZEN_CONFIGS_PATH}"
			;;
		"stop") 
			echo "-$(date +%s)" >> ${ZEN_CONFIGS_PATH}
			;;
	esac
fi


echo "---"

if [ $(session_running) -eq -1 ]; then
	echo "Zen On | bash='$0' | param1='start' | terminal=false | refresh=true"
else
	echo "Zen Off | bash='$0' | param1='stop' | terminal=false | refresh=true"
fi


