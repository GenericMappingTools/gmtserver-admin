#!/bin/bash -e
# srv_downsampler_grid.sh - Filter the highest resolution grid to lower resolution versions
#
# usage: srv_downsampler_grid.sh recipe [split]
# where
#	recipe:		The name of the recipe file (e.g., earth_relief)
#
# These recipe files contain meta data such as where to get the highest-resolution
# master file from which to derive the lower-resolution versions, information about
# title, radius of the planetary body, desired node registration and resolutions,
# desired output grid format and name prefix, and filter type, etc.  Thus, this
# script should handle data from different planets.
# Note: If the highest resolution grid is not an integer unit then some exploration
# needs to be done to determine what increment and tile size give an integer number
# of tiles over 360 and 180 ranges.  E.g., below is the master line for mars_relief
# (which had 200 m pixels on Mars spheroid) and earth_relief (which as 15s exactly):
#	12.1468873601	s		25.7142857143		4096	master
#	15				s		10					4096	master
# Easiest to work with number of rows and find suitable common factors.
#
# Note: Because high-resolution global grids requires 16-32 Gb RAM to hold in memory
# you can pass a 2nd argument such as 30 to force 15s and 30s output (anything <= 30)
# resolutions to be filtered per hemisphere (S + N) then assembled to one grid.

if [ $# -eq 0 ]; then
	echo "usage: srv_downsampler_grid.sh recipefile"
	exit -1
fi

if [ $(uname -n) = "gmtserver" ]; then	# Doing official work on the server
	TOPDIR=/export/gmtserver/gmt/gmtserver-admin
	HERE=$(pwd)
elif [ -d ../scripts ]; then	# On your working copy, probably in scripts
	HERE=$(pwd)
	cd ..
	TOPDIR=$(pwd)
elif [ -d scripts ]; then	# On your working copy, probably in top gmtserver-admin
	HERE=$(pwd)
	TOPDIR=$(pwd)
else
	echo "error: Run srv_downsampler_grid.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi
# 1. Move into the staging directory, possibly after creating it
mkdir -p ${TOPDIR}/staging
cd ${TOPDIR}/staging
	
# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_downsampler_grid.sh: Recipe $RECIPE not found"
	exit -1
fi	

# Create a unique temp directory
TMP=/tmp/$$
mkdir -p ${TMP}

# 3. Extract parameters into a shell include file and ingest
grep SRC_FILE $RECIPE    | awk '{print $2}'  > ${TMP}/par.sh
grep SRC_TITLE $RECIPE   | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REF $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_DOI $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_RADIUS $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_NAME $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_UNIT $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_PROCESS $RECIPE | awk -F'#' '{print $2}' >> ${TMP}/par.sh
grep SRC_CUSTOM $RECIPE  | awk -F'#' '{print $2}' >> ${TMP}/par.sh
grep SRC_EXT $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep DST_MODE $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_NODES $RECIPE   | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PLANET $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PREFIX $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep DST_FORMAT $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep DST_SCALE $RECIPE   | awk '{print $2}' >> ${TMP}/par.sh
grep DST_OFFSET $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
source ${TMP}/par.sh

# 4. Get the file name of the source file and output modifiers
SRC_BASENAME=$(basename ${SRC_FILE})
SRC_ORIG=${SRC_BASENAME}
DST_MODIFY=${DST_FORMAT}+s${DST_SCALE}+o${DST_OFFSET}

# 5.1 Determine if this source is an URL and if we need to download it first
is_url=$(echo ${SRC_FILE} | grep -c :)
if [ $is_url ]; then	# Data source is an URL
	if [ ! -f ${SRC_BASENAME} ]; then # Must download first
		echo "srv_downsampler_grid.sh: Must download original source ${SRC_FILE}"
		curl -k ${SRC_FILE} --output ${SRC_BASENAME}
	fi
	SRC_ORIG=${SRC_FILE}
	SRC_FILE=${SRC_BASENAME}
fi
# 5.2 See if given any pre-processing steps for zip files
if [ ! "X${SRC_PROCESS}" = "X" ]; then	# Preprocessing data to get initial grid
	echo "srv_downsampler_grid.sh: Execute pre-processing steps: ${SRC_PROCESS}"
	$(echo ${SRC_PROCESS} | tr '";' ' \n' > ${TMP}/job1.sh)
	bash ${TMP}/job1.sh
	SRC_FILE=$(basename ${SRC_FILE} zip)"${SRC_EXT}"
fi
# 5.3 See if given any custom formatting steps
if [ ! "X${SRC_CUSTOM}" = "X" ]; then	# Preprocessing data to get initial grid
	SRC_FILE=$(basename ${SRC_FILE} ${SRC_EXT})"nc"
	SRC_ORIG=${SRC_FILE}
	if [ ! -f ${SRC_FILE} ]; then	# Run the custom command(s)
		echo "srv_downsampler_grid.sh: Must convert original ${SRC_EXT} source to ${SRC_FILE}"
		$(echo ${SRC_CUSTOM} | tr '";' ' \n' > ${TMP}/job2.sh)
		bash ${TMP}/job2.sh
	fi
fi

# 6. Determine if the grid has less than full 180 latitude range.
#    If so we use grdcut to add NaNs in those areas and use that tmp grid instead

y_range=$(gmt grdinfo ${SRC_FILE} -Cn -o2-3 | awk '{print $2 - $1}')
if [ ${y_range} -lt 180 ]; then
	x_range=$(gmt grdinfo ${SRC_FILE} -Cn -o0-1 | awk '{printf "%s/%s\n", $1, $2}')
	echo "srv_downsampler_grid.sh: Must extend ${SRC_FILE} region to -R${x_range}/-90/90 and fill with NaNs to temp file ${TMP}/${SRC_FILE}"
	gmt grdcut ${SRC_FILE} -R${x_range}/-90/90 -G${TMP}/${SRC_FILE} -N
	SRC_FILE=${TMP}/${SRC_FILE}
fi

# 7. Extract the requested resolutions and registrations

grep -v '^#' $RECIPE > ${TMP}/res.lis
DST_NODES=$(echo $DST_NODES | tr ',' ' ')
REG=$(gmt grdinfo ${SRC_FILE} -Cn -o10)
if [ $REG -eq 0 ]; then
	SRC_REG=g
else
	SRC_REG=p
fi

# 8. Replace underscores with spaces in the title and remark
TITLE=$(echo ${SRC_TITLE} | tr '_' ' ')
REMARK=$(echo "${SRC_REF}; ${SRC_DOI}" | tr '_' ' ')

# 9.1 Determine filter mode
if [ "X${DST_MODE}" = "XCartesian" ]; then
	FMODE=1
elif [ "X${DST_MODE}" = "Xspherical" ]; then
	FMODE=4
else
	echo "Bad filter mode $DST_MODE - aborting"
	exit -1
fi

# 9.2 Get the right projection ellipsoid/spheroid for this planetary body
if [ "X${DST_PLANET}" = "Xearth" ]; then
	DST_SPHERE=Sphere
else
	DST_SPHERE=${DST_PLANET}
fi

# 9.3 See if user gave the split cutoff in seconds to save on memory
if [ "X${2}" = "X" ]; then	# Do it all in one go
	DST_SPLIT=0
else
	DST_SPLIT=${2}
	echo "For output resolutions <= ${DST_SPLIT} seconds we filter N + S hemispheres separately"
fi

mkdir -p ${DST_PLANET}/${DST_PREFIX}

# 10. Loop over all the resolutions found
while read RES UNIT DST_TILE_SIZE CHUNK MASTER; do
	if [ "X$UNIT" = "Xd" ]; then	# Gave increment in degrees
		INC=$RES
		UNIT_NAME=degree
	elif [ "X$UNIT" = "Xm" ]; then	# Gave increment in minutes
		INC=$(gmt math -Q $RES 60 DIV =)
		UNIT_NAME=minute
	elif [ "X$UNIT" = "Xs" ]; then	# Gave increment in seconds
		INC=$(gmt math -Q $RES 3600 DIV =)
		UNIT_NAME=second
	elif [ "X$UNIT" = "X" ]; then	# Blank line? Skip
		echo "Blank line - skipping"
		continue
	else
		echo "Bad resolution $RES - aborting"
		exit -1
	fi
	IRES=$(gmt math -Q ${RES} FLOOR =)
	if [ ${IRES} -gt 1 ]; then	# Use plural unit
		UNIT_NAME="${UNIT_NAME}s"
	fi
	IRES=$(gmt math -Q ${RES} FLOOR = --FORMAT_FLOAT_OUT=%02.0f)
	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${IRES}${UNIT}_${REG}.grd
		grdtitle="${TITLE} at ${RES} arc ${UNIT_NAME}"
		# Note: The ${SRC_ORIG/+/\\+} below is to escape any plus-symbols in the file name with a backslash so grdedit -D will work
		if [ -f ${DST_FILE} ]; then	# Do nothing
			echo "${DST_FILE} exists - skipping"
		elif [ "X${MASTER}" = "Xmaster" ]; then # Just make a copy of the master to a new output file
			if [ ${REG} = ${SRC_REG} ]; then # Only do the matching node registration for master
				echo "Convert ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY}"
				gmt grdconvert ${SRC_FILE} ${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9
				remark="Reformatted from master file ${SRC_ORIG/+/\\+} [${REMARK}]"
				gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
			fi
		elif [ "${UNIT}" = "s" ] && [ ${IRES} -le ${DST_SPLIT} ]; then # Split files <= DST_SPLIT s to avoid excessive memory requirement
			# See https://github.com/GenericMappingTools/remote-datasets/issues/32 - we do south and north hemisphere separately
			# Get suitable Gaussian full-width filter rounded to nearest 0.01 km after adding 50 meters for noise
			echo "Down-filter ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY}"
			FILTER_WIDTH=$(gmt math -Q ${SRC_RADIUS} 2 MUL PI MUL 360 DIV $INC MUL 0.05 ADD 100 MUL RINT 100 DIV =)
			gmt grdfilter -R-180/180/-90/0 ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${TMP}/s.grd --PROJ_ELLIPSOID=${DST_SPHERE}
			gmt grdfilter -R-180/180/0/90  ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${TMP}/n.grd --PROJ_ELLIPSOID=${DST_SPHERE}
			gmt grdpaste ${TMP}/s.grd ${TMP}/n.grd -G${TMP}/both.grd
			remark="Reduced by Gaussian ${DST_MODE} filtering (${FILTER_WIDTH} km fullwidth) from ${SRC_FILE/+/\\+} [${REMARK}]"
			gmt grdconvert ${TMP}/both.grd -G${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} 			
			gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
		else	# Must down-sample to a lower resolution via spherical Gaussian filtering
			# Get suitable Gaussian full-width filter rounded to nearest 0.1 km after adding 50 meters (0.05 km) for noise
			echo "Down-filter ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY}"
			FILTER_WIDTH=$(gmt math -Q ${SRC_RADIUS} 2 MUL PI MUL 360 DIV $INC MUL 0.05 ADD 10 MUL RINT 10 DIV =)
			gmt grdfilter ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} --PROJ_ELLIPSOID=${DST_SPHERE}
			remark="Reduced by Gaussian ${DST_MODE} filtering (${FILTER_WIDTH} km fullwidth) from ${SRC_FILE/+/\\+} [${REMARK}]"
			gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
		fi
	done
done < ${TMP}/res.lis
# 11. Clean up /tmp
rm -rf ${TMP}
# 12. Go back to where we started
cd ${HERE}
