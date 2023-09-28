#!/usr/bin/env bash
# srv_downsampler_image.sh - Filter the highest resolution image to lower resolution versions
#
# usage: srv_downsampler_image.sh recipe [-f] [-n] [-x]
# where
#	recipe:		The name of the recipe file (e.g., earth_night)
#
# These recipe files contain meta data such as where to get the highest-resolution
# master file from which to derive the lower-resolution versions, information about
# format, radius of the planetary body, desired node registration and resolutions,
# name prefix, and filter type, etc.  Thus, this script should handle images from
# different planets.
# Note: If the highest resolution image is not an integer unit then some exploration
# needs to be done to determine what increment and tile size give an integer number
# of tiles over 360 and 180 ranges (see srv_downsampler_grid.sh for discussion).

# Constants related to filtering are defined here
# Note: On Earth, 15 arc sec ~ 462 m

source scripts/filter_width_from_output_spacing.sh

# Hardwired settings for images
DST_OFFSET=0
DST_SCALE=1
DST_TILE_SIZE=0
DST_CPT=-
MARK=""

if [ $# -eq 0 ]; then
	cat <<- EOF >&2
	usage: srv_downsampler_image.sh <recipefile> [-f] [-n] [-x]"
		<recipefile> is one of several in the recipes directory, e.g., earth_day

		Optional arguments:
			-f	Force removal if data set directory already exists [abort]
			-n	Do not make any lower resolution files yet, just report
			-x	Run grdfilter with -x-1 option (i.e., use all but one core)
	EOF
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
	echo "error: Run srv_downsampler_image.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi

# 1. Move into the staging directory
cd ${TOPDIR}/staging

# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_downsampler_image.sh: Recipe $RECIPE not found"
	exit -1
fi	

TMP=/tmp/$$
mkdir -p ${TMP}

# 3. Extract parameters into a shell include file and ingest
grep SRC_FILE $RECIPE   | awk '{print $2}'  > ${TMP}/par.sh
grep SRC_RADIUS $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_TITLE $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REF $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REG $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_MODE $RECIPE   | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PLANET $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PREFIX $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
grep DST_FORMAT $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
source ${TMP}/par.sh
CITE=$(echo ${SRC_REF} | tr '_' ' ')
TITLE=$(echo ${SRC_TITLE} | tr '_' ' ')
# 4. Get the file name of the source file and output modifiers
SRC_BASENAME=$(basename ${SRC_FILE})
SRC_ORIG=${SRC_BASENAME}

# 5. Determine if this source is an URL and if we need to download it first
is_url=$(echo ${SRC_FILE} | grep -c :)
if [ $is_url ]; then	# Data source is an URL
	if [ ! -f ${SRC_BASENAME} ]; then # Must download first
		echo "srv_downsampler_grid.sh: Must download original source ${SRC_FILE}"
		curl -k ${SRC_FILE} --output ${SRC_BASENAME}
	fi
	SRC_ORIG=${SRC_FILE}
	SRC_FILE=${SRC_BASENAME}
fi

# 6. Extract the requested resolutions

grep -v '^#' $RECIPE > ${TMP}/res.lis

# 7. Determine filter mode
if [ "X${DST_MODE}" = "XCartesian" ]; then
	FMODE=1
elif [ "X${DST_MODE}" = "Xspherical" ]; then
	FMODE=4
else
	echo "Bad filter mode $DST_MODE - aborting"
	exit -1
fi

# 8 See if user gave the -f, -n, -x or split cutoff in seconds to save on memory

DST_SPLIT=0	# Do it all in one go
DST_FORCE=0	# Abort if dataset dir exists
DST_BUILD=1	# By default we do the processing
shift	# Go to first argument after recipe (if there is any)
while [ ! "X$1" == "X" ]; do
	if [ "${1}" = "-n" ]; then	# Just report, no build
		DST_BUILD=0
	elif [ "${1}" = "-f" ]; then	# Delete existing dataset dir
		DST_FORCE=1
	elif [ "${1}" = "-x" ]; then	# Filter in parallel
		threads="-x-1"
	else
		DST_SPLIT=${1}
		echo "For output resolutions <= ${DST_SPLIT} seconds we filter N + S hemispheres separately"
	fi
	shift		# So that $2 now is next arg or blank
done

# 9.0 Set info file here since no image tiling yet
INFOFILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_server.txt

# 9.1 Check if just reporting

if [ ${DST_BUILD} -eq 1 ]; then	# Start building info file
	if [ -d ${DST_PLANET}/${DST_PREFIX} ]; then
		if [ ${DST_FORCE} -eq 1 ]; then
			rm -rf ${DST_PLANET}/${DST_PREFIX}
		else
			echo "Data set directory ${DST_PLANET}/${DST_PREFIX} already exists - aborting. Use -f to force removal instead."
			exit -1
		fi
	fi
	mkdir -p ${DST_PLANET}/${DST_PREFIX}
	cat <<- EOF > ${INFOFILE}
	#
	# ${TITLE}
	#
	EOF
else	# Just report parameters and tasks
	cat <<- EOF
	# Final parameters after processing ${RECIPE}:

	SRC_ORIG	${SRC_ORIG}
	SRC_FILE	${SRC_FILE}
	SRC_REG		${SRC_REG}
	DST_SPLIT	${DST_SPLIT}
	INFOFILE	${INFOFILE}
	TITLE		${TITLE}
	CITE		${CITE}

	# Processing steps to be taken if -n was not given:

	EOF
fi

# 9.2 Get the right projection ellipsoid/spheroid for this planetary body
if [ "X${DST_PLANET}" = "Xearth" ]; then
	DST_SPHERE=Sphere
else
	DST_SPHERE=${DST_PLANET}
fi

# 9.4 Get creation date
creation_date=$(date +%Y-%m-%d)

# 10. Loop over all the resolutions found

while read RES UNIT TILE MASTER; do
	if [ "X${UNIT}" = "Xd" ]; then	# Gave increment in degrees
		INC=${RES}
		UNIT_NAME=degree
	elif [ "X${UNIT}" = "Xm" ]; then	# Gave increment in minutes
		INC=$(gmt math -Q ${RES} 60 DIV =)
		UNIT_NAME=minute
	elif [ "X${UNIT}" = "Xs" ]; then	# Gave increment in seconds
		INC=$(gmt math -Q ${RES} 3600 DIV =)
		UNIT_NAME=second
	elif [ "X${UNIT}" = "X" ]; then	# Blank line? Skip
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
	DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${IRES}${UNIT}.tif
	if [ -f ${DST_FILE} ]; then	# Do nothing
		echo "${DST_FILE} exist - skipping"
	elif [ "X${MASTER}" = "Xmaster" ]; then # Just make a copy of the master to a new output file
		echo "Convert ${SRC_FILE} to ${DST_FILE}"
		SIZE=$(ls -lh ${SRC_FILE} | awk '{print $5}')
		MSG="${TITLE} original at ${RES}x${RES} arc ${UNIT_NAME}"
		if [ ${DST_BUILD} -eq 1 ]; then
			cp ${SRC_FILE} ${DST_FILE}
			printf "%s/server/%s/%s/\t%s_%s_%s\t%s\t%s\t%s\t%s\t%4s\t%s\t%s\t-\t-\t\t%s [%s]\n" \
				"${MARK}" ${DST_PLANET} ${DST_PREFIX} ${DST_PREFIX} ${FTAG} ${SRC_REG} ${TAG} ${SRC_REG} ${DST_SCALE} ${DST_OFFSET} ${SIZE} ${DST_TILE_SIZE} ${creation_date} "${MSG}" "${CITE}" >> ${INFOFILE}
		fi
	else	# Must down-sample to a lower resolution via spherical Gaussian filtering
		# Get suitable Gaussian full-width filter rounded to nearest 0.1 km after adding 50 meters for noise
		FILTER_WIDTH=$(filter_width_from_output_spacing ${INC})
		FWR_SEC=$(gmt math -Q 2 2 SQRT MUL ${INC} MUL 3600 MUL RINT =)
		FTAG="${IRES}${UNIT}"
		MSG="${TITLE} at ${RES}x${RES} arc ${UNIT_NAME} reduced by Gaussian ${DST_MODE} r/g/b filtering (${FILTER_WIDTH} km fullwidth)"
		if [ ${DST_BUILD} -eq 1 ]; then
			printf "Down-filter ${SRC_FILE} to ${DST_FILE} FW = ${FILTER_WIDTH} km [${FWR_SEC}s] via layers "
			gmt grdmix ${SRC_FILE} -D -G/tmp/tmp_%c.nc=ns
			for code in r g b; do
				printf "${code}"
				gmt grdfilter /tmp/tmp_${code}.nc -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -rp -G/tmp/tmp_filt_${code}.nc=ns ${threads} --PROJ_ELLIPSOID=${DST_SPHERE}
			done
			printf " > ${DST_FORMAT}\n"
			gmt grdmix -C /tmp/tmp_filt_r.nc /tmp/tmp_filt_g.nc /tmp/tmp_filt_b.nc -G${DST_FILE} -Ni
			SIZE=$(ls -lh ${DST_FILE} | awk '{print $5}')
			printf "%s/server/%s/%s/\t%s_%s_%s\t%s\t%s\t%s\t%s\t%4s\t%s\t%s\t-\t-\t\t%s [%s]\n" \
				"${MARK}" ${DST_PLANET} ${DST_PREFIX} ${DST_PREFIX} ${FTAG} ${SRC_REG} ${TAG} ${SRC_REG} ${DST_SCALE} ${DST_OFFSET} ${SIZE} ${DST_TILE_SIZE} ${creation_date} $"${MSG}" "${CITE}" >> ${INFOFILE}
		else
			echo "Down-filter ${SRC_FILE} to ${DST_FILE} via R, G, and B layers. FW = ${FILTER_WIDTH} km [${FWR_SEC}s]"
		fi
	fi
done < ${TMP}/res.lis

# 9. Clean up /tmp
rm -rf ${TMP}
# 11. Go back to where we started
cd ${HERE}
