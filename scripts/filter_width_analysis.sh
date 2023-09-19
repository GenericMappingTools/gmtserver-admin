#!/bin/bash
# Script used to illustrate the effect o the filter width with increasing output node spacing
# P.Wessel, Sept. 19, 2023

SRC_RADIUS=6371.0087714
source filter_width_from_output_spacing.sh
LAT=60

function filter_width_array_from_output_spacing () {	# Accepts 1-2 argument only: -Tmin/max/dx in arc minutes [R]
	# $1 is arg to -T. Computes km_2_deg, scales by sqrt(2) to get to diagonal,
	# scale, by 2 to get diameter of filter, then rounds to multiple of FW_ROUND
	echo $1 $2 $3 > shit
	SCL=${2}
	K2D=$(gmt math -Q 2 ${SRC_RADIUS} MUL PI MUL 360 DIV =)		# Converts km on this planet to degrees
	if [ "X${3}" = "X" ]; then	# No rounding
		gmt math -T${1} T 60 DIV ${K2D} MUL 2 MUL 2 SQRT MUL ${SCL} MUL ${FW_OFFSET} ADD =	# Filter width given by our equation (in km)
	else	# Rounding
		gmt math -T${1} T 60 DIV ${K2D} MUL 2 MUL 2 SQRT MUL ${SCL} MUL ${FW_OFFSET} ADD ${FW_ROUND} DIV RINT ${FW_ROUND} MUL =	# Final rounded filter width
	fi
}

ARG="@[F_w = 2 \sqrt{2} \frac{2 \pi R_p}{360}\Delta@["
for FW_SCL in 1 0.707106781187; do
gmt begin filter_circles_${FW_SCL} png
	gmt grdmath -R-1/1/-1/1 -I30m X = x30s.grd
	gmt grdmath -R-1/1/-1/1 -I15m X = x15s.grd
	gmt grdmath -R-1/1/-1/1 -I1 X = x01m.grd
	gmt grdmath -R-1.01224061334/1.01224061334/-1.01224061334/1.01224061334 -I12.1468873601m X = x12.14.grd
	gmt basemap -R-1.25/1.25/-1.25/1.25 -JX6i -Bafg15m+u"'"
	gmt grd2xyz x01m.grd   | gmt plot -Ss15p -Gblue -l"01\042 filtered"+HLEGEND+f12p
	gmt grd2xyz x30s.grd   | gmt plot -Ss10p -Gred  -l"30\047 filtered"
	gmt grd2xyz x15s.grd |   gmt plot -Sc4p -Gorange -l"15\047 data"
	gmt grd2xyz x12.14.grd | gmt plot -Sc4p -Gdarkgreen -l"12.14...\047 data"
	r30=$(gmt math -Q 0.25 2 MUL 2 SQRT MUL 6 MUL 2.5 DIV 2.54 MUL ${FW_SCL} MUL =)
	echo 0 0 | gmt plot -Sc${r30} -W1p -l"Filter for 30\047"+S5p
	echo 0 -0.5 | gmt plot -Sc${r30} -W1p,gray -l"Filter for 30\047"+S5p
	echo -0.5 -0.5 | gmt plot -Sc${r30} -W1p,gray
	echo -0.5 0 | gmt plot -Sc${r30} -W1p,gray
	r00=$(gmt math -Q 0.5 2 MUL 2 SQRT MUL 6 MUL 2.5 DIV 2.54 MUL 4 PI DIV MUL =)
	r01=$(gmt math -Q 0.5 2 MUL 2 SQRT MUL 6 MUL 2.5 DIV 2.54 MUL ${FW_SCL} MUL =)
	echo 0 0 | gmt plot -Sc${r01} -W1p -l"Filter for 01\042"+S10p
	echo 0 0 | gmt plot -Sc${r00} -W0.25p,- -l"Filter for same area"+S10p
	y30=$(gmt math -Q 0.25 2 MUL 2 SQRT MUL 6 MUL 2.5 DIV 2.54 MUL ${FW_SCL} MUL =)
	x30=$(gmt math -Q 0.25 2 MUL 2 SQRT MUL 6 MUL 2.5 DIV 2.54 MUL ${FW_SCL} MUL ${LAT} COSD DIV =)
	echo 0 0 0 $x30 $y30 | gmt plot -Se -W1p -l"Filter for 30\047 at ${LAT}@."+S10p
	echo 0 1.14 |gmt plot -Sr5.8i/0.3i -Gwhite
	echo ${ARG} | gmt text -F+cTL+f14p -Dj9p
	ARG="@[F_w = 2 \frac{2 \pi R_p}{360}\Delta@["
gmt end
done
rm -f x01m.grd x30s.grd x15s.grd x12.14.grd
ARG="@[F_w = 2 \sqrt{2} \frac{2 \pi R_p}{360}\Delta@["
#for FW_SCL in 1 0.707106781187; do
for FW_SCL in 1; do
gmt begin filter_widths_${FW_SCL} png
	gmt basemap -R0/6.25/0/11.50 -Baf -JX9i/6i
	x15s=$(gmt math -Q 0.25 60 DIV =)
	x30s=$(gmt math -Q 0.50 60 DIV =)
	y15=$(filter_width_from_output_spacing ${x15s})
	y30=$(filter_width_from_output_spacing ${x30s})

	gmt plot -Wfaint <<- EOF
	> x 15s
	0.25	0
	0.25	20
	> x 30s
	0.5	0
	0.5	20
	> y 15s
	0	${y15}
	60	${y15}
	> y 30s
	0	${y30}
	60	${y30}
	EOF
	gmt math -T0/60/0.01 T 60 DIV 2 MUL 6371.0087714 MUL PI MUL 360 DIV = | gmt plot -Wfaint,red -l'Old filterwidth (FW)'+jTL
	filter_width_array_from_output_spacing 0/60/0.01 ${FW_SCL}   | gmt plot -W4p,orange -l"New unrounded FW"
	filter_width_array_from_output_spacing 0/60/0.01 ${FW_SCL} R | gmt plot -W1p -l"Rounded FW"
	cat <<- EOF | gmt plot -St8p -Gblue -l"Previous FW at 6'"
	60	111.2
	30	55.6
	20	37.1
	15	27.8
	10	18.6
	6	11.2
	EOF
	gmt plot -Sc6p -Gred <<- EOF -l"Empirical knots"
	0.25	0.75
	0.5	1.5
	EOF
	echo ${ARG} | gmt text -F+cTC+f14p -Dj0/10p
	ARG="@[F_w = 2 \frac{2 \pi R_p}{360}\Delta@["
	gmt inset begin -DjBR+o16p+w3i/2i -F+p0.5p+gwhite -C0.3i/0.1i/0.2i/0.1i
		gmt basemap -Bxaf+u"'" -Byaf -BWS -R0/60/0/350
		gmt math -T0/60/0.01 T 60 DIV 2 MUL 6371.0087714 MUL PI MUL 360 DIV = | gmt plot -Wfaint,red 
		filter_width_array_from_output_spacing 0/60/0.01 ${FW_SCL} R | gmt plot -W1p
		cat <<- EOF | gmt plot -St4p -Gblue -N
		60	111.2
		30	55.6
		20	37.1
		15	27.8
		10	18.6
		6	11.2
		EOF
	gmt inset end
gmt end
done
gmt begin filter-weights png
gmt set MAP_GRID_PEN 0.25p,-
	gmt subplot begin 1x2 -Fs3i/1i -R-1/2/0/0.5 -Bxa0.5g1 -Byaf
	gmt math -T-1/2/0.01 T 2 POW 18 MUL NEG EXP 2 PI MUL SQRT DIV = | gmt plot -W1p -c
	gmt math -T-1/2/0.01 T 1 SUB 2 POW 18 MUL NEG EXP 2 PI MUL SQRT DIV = | gmt plot -W1p
	gmt math -T-1/2/0.01 T 2 POW 9 MUL NEG EXP 2 PI MUL SQRT DIV = | gmt plot -W1p -c
	gmt math -T-1/2/0.01 T 1 SUB 2 POW 9 MUL NEG EXP 2 PI MUL SQRT DIV = | gmt plot -W1p
	gmt subplot end
gmt end show
