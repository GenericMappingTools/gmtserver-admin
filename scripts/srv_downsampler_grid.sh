#!/bin/bash -e
# srv_downsampler_grid.sh - Filter the highest resolution grid to lower resolution versions
#
# usage: srv_downsampler_grid.sh recipe.
# where
#	recipe:		The name of the recipe file (e.g., earth_relief)
#
# These recipe files contain meta data such as where to get the highest-resolution
# master file from which to derive the lower-resolution versions, information about
# title, radius of the planetary body, desired node registration and resolutions,
# desired output grid format and name prefix, and filter type, etc.  Thus, this
# script should handle data from different planets.

if [ $# -eq 0 ]; then
	echo "usage: srv_downsampler_grid.sh recipefile"
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
	echo "error: Run srv_downsampler_grid.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi
# 1. Move into the staging directory
cd ${TOPDIR}/staging
	
# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_downsampler_grid.sh: Recipe $RECIPE not found"
	exit -1
fi	

# 3. Extract parameters into a shell include file and ingest
grep SRC_FILE $RECIPE   | awk '{print $2}'  > /tmp/par.sh
grep SRC_TITLE $RECIPE  | awk '{print $2}' >> /tmp/par.sh
grep SRC_REMARK $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep SRC_RADIUS $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep SRC_NAME $RECIPE   | awk '{print $2}' >> /tmp/par.sh
grep SRC_UNIT $RECIPE   | awk '{print $2}' >> /tmp/par.sh
grep DST_MODE $RECIPE   | awk '{print $2}' >> /tmp/par.sh
grep DST_NODES $RECIPE  | awk '{print $2}' >> /tmp/par.sh
grep DST_PLANET $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep DST_PREFIX $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep DST_FORMAT $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep DST_SCALE $RECIPE  | awk '{print $2}' >> /tmp/par.sh
grep DST_OFFSET $RECIPE | awk '{print $2}' >> /tmp/par.sh
source /tmp/par.sh

# 4. Get the file name of the source file and output modifiers
SRC_BASENAME=`basename ${SRC_FILE}`
SRC_ORIG=${SRC_BASENAME}
DST_MODIFY=${DST_FORMAT}+s${DST_SCALE}+o${DST_OFFSET}

# 5. Determine if this source is an URL and if we need to download it first
is_url=`echo ${SRC_FILE} | grep -c :`
if [ $is_url ]; then	# Data source is an URL
	if [ ! -f ${SRC_BASENAME} ]; then # Must download first
		curl -k ${SRC_FILE} --output ${SRC_BASENAME}
	fi
	SRC_ORIG=${SRC_FILE}
	SRC_FILE=${SRC_BASENAME}
fi

# 6. Determine if the grid has less than full 180 latitude range.
#    If so we use grdcut to add NaNs in those areas and use that tmp grid instead

y_range=$(gmt grdinfo ${SRC_FILE} -Cn -o2-3 | awk '{print $2 - $1}')
if [ ${y_range} -lt 180 ]; then
	x_range=$(gmt grdinfo ${SRC_FILE} -Cn -o0-1 | awk '{printf "%s/%s\n", $1, $2}')
	gmt grdcut ${SRC_FILE} -R${x_range}/-90/90 -G/tmp/extend.grd -N -V
	SRC_FILE=/tmp/extend.grd
fi

# 7. Extract the requested resolutions and registrations

grep -v '^#' $RECIPE > /tmp/res.lis
DST_NODES=$(echo $DST_NODES | tr ',' ' ')
REG=$(gmt grdinfo ${SRC_FILE} -Cn -o10)
if [ $REG -eq 0 ]; then
	SRC_REG=g
else
	SRC_REG=p
fi

# 8. Replace underscores with spaces in the title and remark
TITLE=`echo ${SRC_TITLE} | tr '_' ' '`
REMARK=`echo ${SRC_REMARK} | tr '_' ' '`

# 9. Determine filter mode
if [ "X${DST_MODE}" = "XCartesian" ]; then
	FMODE=1
elif [ "X${DST_MODE}" = "Xspherical" ]; then
	FMODE=4
else
	echo "Bad filter mode $DST_MODE - aborting"
	exit -1
fi

mkdir -p ${DST_PLANET}/${DST_PREFIX}

# 10. Loop over all the resolutions found
while read RES UNIT DST_TILE_SIZE CHUNK MASTER; do
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
	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${RES}${UNIT}_${REG}.grd
		grdtitle="${TITLE} at ${RES} arc ${UNIT_NAME}"
		# Note: The ${SRC_ORIG/+/\\+} below is to escape any plus-symbols in the file name with a backslash so grdedit -D will work
		if [ -f ${DST_FILE} ]; then	# Do nothing
			echo "${DST_FILE} exist - skipping"
		elif [ "X${MASTER}" = "Xmaster" ]; then # Just make a copy of the master to a new output file
			if [ ${REG} = ${SRC_REG} ]; then # Only do the matching node registration for master
				echo "Convert ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY}"
				gmt grdconvert ${SRC_FILE} ${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9
				remark="Reformatted from master file ${SRC_ORIG/+/\\+} [${REMARK}]"
				gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
			fi
		else	# Must down-sample to a lower resolution via spherical Gaussian filtering
			# Get suitable Gaussian full-width filter rounded to nearest 0.1 km after adding 50 meters for noise
			echo "Down-filter ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY}"
			FILTER_WIDTH=`gmt math -Q ${SRC_RADIUS} 2 MUL PI MUL 360 DIV $INC MUL 0.05 ADD 10 MUL RINT 10 DIV =`
			gmt grdfilter ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} --PROJ_ELLIPSOID=Sphere
			remark="Obtained by Gaussian ${DST_MODE} filtering (${FILTER_WIDTH} km fullwidth) from ${SRC_FILE/+/\\+} [${REMARK}]"
			gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
		fi
	done
done < /tmp/res.lis
# 11. Clean up /tmp
rm -f /tmp/res.lis /tmp/par.sh
if [ -f /tmp/extend.grd ]; then
	rm -f /tmp/extend.grd
fi
# 12. Go back to where we started
cd ${HERE}
