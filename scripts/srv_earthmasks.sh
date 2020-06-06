#!/bin/bash -e
# srv_earthmasks.sh - Filter the highest resolution grid to lower resolution versions
#
# usage: srv_earthmasks.sh recipe.
# where
#	recipe:		The name of the recipe file (e.g., earth_relief)
#
# This script is simply creating a land/sea mask based on the GSHHG full resoluton
# data set.  We skip features larger than a grid cell via -A.

if [ $# -eq 0 ]; then
	echo "usage: srv_earthmasks.sh recipefile"
	exit -1
fi

if [ `uname -n` = "gmtserver" ]; then	# Doing official work on the server
	TOPDIR=/export/gmtserver/gmt/gmtserver-admin
	HERE=`pwd`
elif [ -d ../scripts ]; then	# On your working copy, probably in scripts
	HERE=`pwd`
	cd ..
	TOPDIR=`pwd`
elif [ -d scripts ]; then	# On your working copy, probably in top gmtserver-admin
	HERE=`pwd`
	TOPDIR=`pwd`
else
	echo "error: Run srv_earthmasks.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi
# 1. Move into the staging directory
cd ${TOPDIR}/staging
	
# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_earthmasks.sh: Recipe $RECIPE not found"
	exit -1
fi	

# 3. Extract parameters into a shell include file and ingest
grep SRC_TITLE $RECIPE  | awk '{print $2}' >> /tmp/par.sh
grep SRC_REMARK $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep SRC_RADIUS $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep SRC_NAME $RECIPE   | awk '{print $2}' >> /tmp/par.sh
grep DST_NODES $RECIPE  | awk '{print $2}' >> /tmp/par.sh
grep DST_PLANET $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep DST_PREFIX $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep DST_FORMAT $RECIPE | awk '{print $2}' >> /tmp/par.sh
source /tmp/par.sh

# 6. Extract the requested resolutions and registrations

grep -v '^#' $RECIPE > /tmp/res.lis
DST_NODES=$(echo $DST_NODES | tr ',' ' ')

# 7. Replace underscores with spaces in the title and remark
TITLE=`echo ${SRC_TITLE} | tr '_' ' '`
REMARK=`echo ${SRC_REMARK} | tr '_' ' '`

mkdir -p ${DST_PLANET}/${DST_PREFIX}

# 9. Loop over all the resolutions found
while read RES UNIT TILE CHUNK; do
	if [ "X$UNIT" = "Xd" ]; then	# Gave increment in degrees
		INC=$RES
		UNIT_NAME=degree
	elif [ "X$UNIT" = "Xm" ]; then	# Gave increment in minutes
		INC=`gmt math -Q $RES 60 DIV =`
		UNIT_NAME=minute
	elif [ "X$UNIT" = "Xs" ]; then	# Gave increment in seconds
		INC=`gmt math -Q $RES 3600 DIV =`
		UNIT_NAME=second
	elif [ "X$UNIT" = "X" ]; then	# Blank line? Skip
		echo "Blank line - skipping"
		continue
	else
		echo "Bad resolution $RES - aborting"
		exit -1
	fi
	if [ ! ${RES} = "01" ]; then	# Use plural unit
		UNIT_NAME="${UNIT_NAME}s"
	fi
	# Get area of a grid cell at Equator in km^2 as cutoff for -A
	MIN_AREA=`gmt math -Q ${SRC_RADIUS} PI MUL 180 DIV $INC MUL 2 POW RINT =`
	if [ $MIN_AREA -eq 0 ]; then
		remark="All features included [${REMARK}]"
	else
		remark="Features < ${MIN_AREA} km^2 skipped [${REMARK}]"
	fi

	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${RES}${UNIT}_${REG}.grd
		grdtitle="${TITLE} at ${RES} arc ${UNIT_NAME}"
		if [ -f ${DST_FILE} ]; then	# Do nothing
			echo "${DST_FILE} exist - skipping"
		else	# Must run grdlandmask with these settings
			echo "Creating ${DST_FILE}"
			gmt grdlandmask -Rd -I${RES}${UNIT} -r${REG} -Df -N0/1/2/3/4 -A${MIN_AREA} -G${DST_FILE}=${DST_FORMAT} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} --PROJ_ELLIPSOID=Sphere
			gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"
		fi
	done
done < /tmp/res.lis
# 10. Clean up /tmp
rm -f /tmp/res.lis /tmp/par.sh
# 11. Go back to where we started
cd ${HERE}
