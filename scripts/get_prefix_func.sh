#!/bin/bash
# Function that creates tile label in integer degrees W/S

function get_prefix  () {       # Takes west (in -180/180 or 0/350 range) and south and makes the {N|S}yy{W|E}xxx prefix
	# Get nearest integer degrees
	W=$(gmt math -Q $1 DUP 180 GE 360 MUL SUB RINT =)	# Ensure it is in -180 <= LON < +180
	S=$(gmt math -Q $2 RINT =)
	if [ $W -ge 0 ]; then
		X=$(printf "E%03d" $W)
	else
		t=$(gmt math -Q $W NEG =)
		X=$(printf "W%03d" $t)
	fi
	if [ $S -ge 0 ]; then
		Y=$(printf "N%02d" $S)
	else
		t=$(gmt math -Q $S NEG =)
		Y=$(printf "S%02d" $t)
	fi
	echo ${Y}${X}
}
