#!/bin/bash -e
# srv_tiler.sh - Split a large grid into suitable square tiles
#
# usage: srv_tiler.sh recipe [-n].
# where
#	recipe:		The name of the recipe file (e.g., earth_relief)
#		-n Optional switch that only reports and makes no tiles
#
# These recipe files contain meta data for this data set.  Here, we only
# need to get the resolution and file names since the global files already
# exist.  The script will processes all the global resolutions and if tiling
# occurs we create sub-directories with the tiled files inside.
# We convert all tiles to JP2 format for minimized sizes for transmission.
# The global grids that ended up being tiled are placed in <recipe>_tiled dir.
#
# Along the way we build the section needed for inclusion in gmt_data_server.txt
# This file is called xxxxxx_server.txt, e.g., mars_relief_server.txt and will be
# placed in the dataset directory
#
# NOTE: We will ONLY look for the global files on this local machine.  We first
# look in the staging/<planet> directory, and if not there then we look in the
# users server directory.
#
# Note: If the highest resolution grid is not an integer unit then some exploration
# needs to be done to determine what increment and tile size give an integer number
# of tiles over 360 and 180 ranges.  E.g., below is the master line for mars_relief
# (which had 200 m pixels on Mars spheroid) and earth_relief (which as 15s exactly):
#	12.1468873601	s		25.7142857143		4096	master
#	15				s		10					4096	master
# Easiest to work with number of rows and find suitable common factors.

export LC_NUMERIC=C		# Temporary change the rules and symbols for formatting non-monetary numeric information

if [ $# -eq 0 ]; then
	echo "usage: srv_tiler.sh recipe [-n]"
	echo "	-n Makes no tiles but reports which one would be built"
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
	echo "error: Run srv_tiler.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi

# Load in prefix function
. ${TOPDIR}/scripts/get_prefix_func.sh

# 1. Move into the staging directory
cd ${TOPDIR}/staging
	
# 2. Get recipe full file path and check for -f
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_tiler.sh: Recipe $RECIPE not found"
	exit -1
fi

# 9.3 See if user gave the split cutoff in seconds to save on memory
DST_BUILD=1	# By default we do the processing
if [ "${2}" = "-n" ]; then	# Just report, no build
	DST_BUILD=0
fi

TMP=/tmp/$$
mkdir -p ${TMP}

# 3. Extract parameters into a shell include file and ingest
grep SRC_TITLE $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REF $RECIPE       | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_RADIUS $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PLANET $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PREFIX $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_TILE_SIZE $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
grep DST_FORMAT $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_SCALE $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep DST_OFFSET $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_MODE $RECIPE      | awk '{print $2}' >> ${TMP}/par.sh
grep DST_NODES $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep DST_CPT $RECIPE       | awk '{print $2}' >> ${TMP}/par.sh
grep DST_SRTM $RECIPE      | awk '{print $2}' >> ${TMP}/par.sh
source ${TMP}/par.sh
	 
# 4. Extract the requested resolutions and inverse scale
grep -v '^#' $RECIPE > ${TMP}/res.lis
DATADIR=${DST_PLANET}/${DST_PREFIX}
DST_NODES=$(echo $DST_NODES | tr ',' ' ')
# INV_SCL is needed to convert data to the integers we wish to store in the JP2 file
INV_SCL=$(gmt math -Q ${DST_SCALE} INV =)

# 8. Replace underscores with spaces in the title and reference
TITLE=$(echo ${SRC_TITLE} | tr '_' ' ')
CITE=$(echo ${SRC_REF} | tr '_' ' ')

export GDAL_PAM_ENABLED=NO	# We do not want XML files in the directories

INFOFILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_server.txt
TILED_DIR=${TOPDIR}/staging/${DST_PLANET}/${DST_PREFIX}_tiled
creation_date=$(date +%Y-%m-%d)
if [ ${DST_BUILD} -eq 1 ]; then	# Start building info file
	cat <<- EOF > ${INFOFILE}
	#
	# ${TITLE}
	#
	EOF
else	# Just report parameters and tasks
	cat <<- EOF
	# Final parameters after processing ${RECIPE}:

	DATADIR		${DATADIR}
	INFOFILE	${INFOFILE}
	TILED_DIR	${TILED_DIR}
	DST_NODES	${DST_NODES}
	INV_SCL		${INV_SCL}
	TITLE		${TITLE}
	CITE		${CITE}

	# Processing steps to be taken if -n was not given:

	EOF
fi

# 5. Loop over all the resolutions found
while read RES UNIT DST_TILE_SIZE CHUNK MASTER ; do
	if [ "X$UNIT" = "Xd" ]; then	# Gave increment in degrees
		INC=$RES
		UNAME=degrees
	elif [ "X$UNIT" = "Xm" ]; then	# Gave increment in minutes
		INC=$(gmt math -Q $RES 60 DIV =)
		UNAME=minutes
	elif [ "X$UNIT" = "Xs" ]; then	# Gave increment in seconds
		INC=$(gmt math -Q $RES 3600 DIV =)
		UNAME=seconds
	else
		echo "Bad resolution $RES - aborting"
		exit -1
	fi
	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		# Name and path of grid we wish to tile
		IRES=$(gmt math -Q ${RES} FLOOR = --FORMAT_FLOAT_OUT=%02.0f)
		DST_TILE_TAG=${DST_PREFIX}_${IRES}${UNIT}_${REG}
		DST_FILE=${DST_TILE_TAG}.grd
		if [ -f ${DATADIR}/${DST_FILE} ]; then # found locally
			DATAGRID=${DATADIR}/${DST_FILE}
		else 	# Get it via local server files
			DATAGRID=~/.gmt/server/${DST_PREFIX}_${IRES}${UNIT}_${REG}.grd
		fi
		if [ ! -f ${DATAGRID} ]; then # No
			echo "No such file to tile: ${DATAGRID}"
			continue
		fi
		TAG="${RES}${UNIT}"
		FTAG="${IRES}${UNIT}"
		SIZE=$(ls -lh ${DATAGRID} | awk '{print $5}')
		FILTER_WIDTH=$(gmt math -Q ${SRC_RADIUS} 2 MUL PI MUL 360 DIV $INC MUL 0.05 ADD 10 MUL RINT 10 DIV =)
		# Compute number of tiles required for this grid given nominal tile size.
		# We enforce square tiles by only solving for ny and doubling it for nx
		IDST_TILE_SIZE=$(gmt math -Q ${DST_TILE_SIZE} RINT =)
		if [ ${IDST_TILE_SIZE} -gt 0 ]; then	# OK, we need to split the file into separate tiles
			ny=$(gmt math -Q 180 ${DST_TILE_SIZE} DIV =)
			nx=$(gmt math -Q ${ny} 2 MUL =)
			n_tiles=$(gmt math -Q $nx $ny MUL =)
			echo "Tiling: ${DATAGRID} split into ${n_tiles} tiles"
			# Get dimension of tiles in degrees
			# Build the list of w/e/s/n for the tiles
			gmt grdinfo ${DATAGRID} -I${DST_TILE_SIZE} -D -C > ${TMP}/wesn.txt
			# Determine local temporary tile directory for this product
			TILEDIR=./${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${IRES}${UNIT}_${REG}
			rm -rf ${TILEDIR}
			mkdir -p ${TILEDIR}
			while read w e s n; do
				# Get the {N|S}yy{W|E}xxx prefix
				prefix=$(get_prefix $w $s)
				# Create name for this tile (without extension)
				TILEFILE=${TILEDIR}/${prefix}.${DST_TILE_TAG}.jp2
				printf "Convert subset %s from %s to %s\n" $prefix ${DST_FILE} ${TILEFILE}
				if [ ${DST_BUILD} -eq 1 ]; then
					# Extract the tile from the global grid and write after making the integers; no compression since a tmpfile
					gmt grdconvert ${DATAGRID} -R$w/$e/$s/$n -G${TMP}/subset.nc=${DST_FORMAT} -Z+s${INV_SCL}+o${DST_OFFSET}
					# Compress this grid to a lossless JP2000 file
					gdal_translate -q -of JP2OpenJPEG -co "QUALITY=100" -co "REVERSIBLE=YES" -co "YCBCR420=NO" ${TMP}/subset.nc ${TILEFILE}
				fi
			done < ${TMP}/wesn.txt
			# Write reference record for gmt_data_server.txt for these tiles
			if [ "X${MASTER}" = "Xmaster" ]; then # No filtering was done
				MSG="${TITLE} original at ${RES}x${RES} arc ${UNAME}"
			else
				MSG="${TITLE} at ${RES}x${RES} arc ${UNAME} reduced by Gaussian ${DST_MODE} filtering (${FILTER_WIDTH} km fullwidth)"
			fi
			if [ ${DST_BUILD} -eq 1 ]; then
				printf "/server/%s/%s/\t%s_%s_%s/\t%s\t%s\t%s\t%s\t%4s\t%s\t%s\t-\t-\t%s\t%s [%s]\n" \
					${DST_PLANET} ${DST_PREFIX} ${DST_PREFIX} ${FTAG} ${REG} ${TAG} ${REG} ${DST_SCALE} ${DST_OFFSET} ${SIZE} ${DST_TILE_SIZE} ${creation_date} ${DST_CPT} "${MSG}" "${CITE}" >> ${INFOFILE}
				# Move the tiled grid away from this tree
				mkdir -p ${TILED_DIR}
				mv -f ${DATAGRID} ${TILED_DIR}
				printf "%s: Moved to %s\n" ${DST_FILE} ${TILED_DIR}
			fi
		else
			if [ ${DST_BUILD} -eq 1 ]; then
				# Write reference record for gmt_data_server.txt for this complete grid
				printf "No tiling requested for %s\n" ${DST_FILE}
				printf "/server/%s/%s/\t%s\t%s\t%s\t%s\t%s\t%4s\t0\t%s\t-\t-\t%s\t%s at %dx%d arc %s reduced by Gaussian %s filtering (%g km fullwidth) [%s]\n" \
					${DST_PLANET} ${DST_PREFIX} ${DST_FILE} ${FTAG} ${REG} ${DST_SCALE} ${DST_OFFSET} ${SIZE} ${creation_date} ${DST_CPT} "${TITLE}" ${RES} ${RES} ${UNAME} ${DST_MODE} ${FILTER_WIDTH} "${CITE}" >> ${INFOFILE}
			fi
		fi
	done
done < ${TMP}/res.lis
if [ ${DST_BUILD} -eq 1 ]; then
	if [ ${DST_SRTM} = "yes" ]; then	# Must add the two records for SRTM via filler and coverage
		printf "/server/%s/%s/\t%s_03s_g/\t03s\tg\t1\t0\t6.8G\t1\t2020-06-01\tsrtm_tiles.nc\tearth_relief_15s_p\t%s\tEarth Relief at 3x3 arc seconds tiles provided by SRTMGL3 (land only) [NASA/USGS]\n" ${DST_PLANET} ${DST_PREFIX} ${DST_PREFIX} ${DST_CPT} >> ${INFOFILE}
		printf "/server/%s/%s/\t%s_01s_g/\t01s\tg\t1\t0\t 41G\t1\t2020-06-01\tsrtm_tiles.nc\tearth_relief_15s_p\t%s\tEarth Relief at 1x1 arc seconds tiles provided by SRTMGL1 (land only) [NASA/USGS]\n" ${DST_PLANET} ${DST_PREFIX} ${DST_PREFIX} ${DST_CPT} >> ${INFOFILE}
	fi
	echo "File with gmt_data_server.txt section: ${DST_PREFIX}_server.txt left in ${DATADIR} folder"
fi

# 6. Clean up /tmp
rm -rf ${TMP}
# 7. Go back to where we started
cd ${HERE}
