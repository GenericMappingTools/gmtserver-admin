#!/bin/bash -e
# srv_downsampler.sh - Filter the highest resolution grid to lower resolution versions
#
# usage: srv_downsampler.sh recipe.
# where
#	recipe:		The name of the recipe file (e.g., earth_relief.recipe)

HOME=/export/gmtserver/gmt/data/gmtserver-admin
HERE=`pwd`
cd ${HOME}/staging

if [ $# -eq 0 ]; then
	echo "usage: srv_downsampler.sh recipefile"
	exit -1
fi

# Get recipe file path
RECIPE=$HOME/recipes/$1

# Extract parameters into a shell include file and ingest
grep SRC_FILE $RECIPE   | awk '{print $2}'  > /tmp/par.sh
grep ${SRC_NAME} $RECIPE   | awk '{print $2}' >> /tmp/par.sh
grep ${SRC_RADIUS} $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep ${DST_NODES} $RECIPE  | awk '{print $2}' >> /tmp/par.sh
grep ${DST_PREFIX} $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep ${DST_FORMAT} $RECIPE | awk '{print $2}' >> /tmp/par.sh
source /tmp/par.sh
# Get the file name of the source file
SRC_BASENAME=`basename ${SRC_FILE}`
SRC_ORIG=${SRC_BASENAME}
# Determine if this source is an URL and if we need to download it first
is_url=`echo ${SRC_FILE} | grep -c :`
if [ $is_url ]; then	# Data source is an URL
	if [ ! -f ${SRC_BASENAME} ]; then # Must download first
		curl ${SRC_FILE} --output ${SRC_BASENAME}
	fi
	SRC_ORIG=${SRC_FILE}
	SRC_FILE=${SRC_BASENAME}
fi
	 
# Extract the requested resolutions
grep -v '^#' $RECIPE > /tmp/res.lis
# Replace underscores with spaces in the title
TITLE=`echo ${SRC_NAME} | tr '_' ' '`
while read RES UNIT MASTER; do	# For all the resolutions found
	if [ "X$UNIT" = "Xd" ]; then	# Gave increment in degrees
		INC=$RES
		UNIT_NAME=degree
	elif [ "X$UNIT" = "Xm" ]; then	# Gave increment in minutes
		INC=`gmt math -Q $RES 60 DIV =`
		UNIT_NAME=minute
	elif [ "X$UNIT" = "Xs" ]; then	# Gave increment in seconds
		INC=`gmt math -Q $RES 3600 DIV =`
		UNIT_NAME=second
	else
		echo "Bad resolution $RES - aborting"
		exit -1
	fi
	if [ "X${MASTER}" = "Xmaster" ]; then # Just make a copy of the master
		gmt grdconvert ${SRC_FILE} ${DST_PREFIX}_${RES}${UNIT}.grd=${DST_FORMAT} -Vl --IO_NC4_DEFLATION_LEVEL=9
		gmt grdedit ${DST_PREFIX}_${RES}${UNIT}.grd -D+t"${TITLE} at ${RES} arc ${UNIT_NAME}"+r"Reformatted from master file ${SRC_ORIG}"
	else	# Must downsample to a lower resolution via spherical Gaussian filtering
		# Get suitable Gaussian full-width filter rounded to nearest 0.1 km
		FILTER_WIDTH=`gmt math -Q ${SRC_RADIUS} 2 MUL PI MUL 360 DIV $INC MUL 10 MUL RINT 10 DIV =`
		gmt grdfilter ${SRC_FILE} -Fg${FILTER_WIDTH} -D4 -I${RES}${UNIT} -r${DST_NODES} -G${DST_PREFIX}_${RES}${UNIT}.grd=${DST_FORMAT} -Vl --IO_NC4_DEFLATION_LEVEL=9 --PROJ_ELLIPSOID=Sphere
		gmt grdedit ${DST_PREFIX}_${RES}${UNIT}.grd -D+t"${TITLE} at ${RES} arc ${UNIT_NAME}"+r"Obtained by Gaussian spherical filtering (${FILTER_WIDTH} km fullwidth) from ${SRC_FILE}"
	fi
done < /tmp/res.lis
rm -f /tmp/res.lis /tmp/par.sh
cd ${HERE}
