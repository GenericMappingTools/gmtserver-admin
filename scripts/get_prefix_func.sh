#!/bin/bash
# Function that creates tile label

function get_prefix  () {       # Takes west (in -180/180 range) and south and makes the {N|S}yy{W|E}xxx prefix
	if [ $1 -ge 0 ]; then
		X=$(printf "E%03d" $1)
	else
		t=$(gmt math -Q $1 NEG =)
		X=$(printf "W%03d" $t)
	fi
	if [ $2 -ge 0 ]; then
		Y=$(printf "N%02d" $2)
	else
		t=$(gmt math -Q $2 NEG =)
		Y=$(printf "S%02d" $t)
	fi
	echo ${Y}${X}
}
