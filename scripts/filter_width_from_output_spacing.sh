#!/bin/bash
#
# Filter-width function for grid or image down-sampling.

FW_OFFSET=0.0	# Intercept in km at 0 increment
FW_ROUND=0.1	# Round final filter width to multiples of this (in km)

function filter_width_from_output_spacing () {	# Accepts one argument only
	# $1 is increment in degrees. Computes km_2_deg, scales by sqrt(2) to get to diagonal,
	# scale, by 2 to get diameter of filter, then rounds to multiple of FW_ROUND
	K2D=$(gmt math -Q 2 ${SRC_RADIUS} MUL PI MUL 360 DIV =)		# Converts km this planet to degrees
	FW_RAW=$(gmt math -Q ${1} ${K2D} MUL 2 MUL 2 SQRT MUL =)	# Filter width given by our equation
	FW=$(gmt math -Q ${FW_RAW} ${FW_OFFSET} ADD ${FW_ROUND} DIV RINT ${FW_ROUND} MUL =)	# Final rounded filter width
	echo ${FW}
}
