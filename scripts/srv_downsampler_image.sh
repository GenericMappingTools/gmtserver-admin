#!/bin/bash -e
# srv_downsampler_image.sh - Filter the highest resolution image to lower resolution versions
#
# usage: srv_downsampler_image.sh recipe [-n]
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

if [ $# -eq 0 ]; then
	echo "usage: srv_downsampler_image.sh recipefile"
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
grep DST_MODE $RECIPE   | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PLANET $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PREFIX $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
grep DST_FORMAT $RECIPE | awk '{print $2}' >> ${TMP}/par.sh
source ${TMP}/par.sh

# 4. Get the file name of the source file and output modifiers
SRC_BASENAME=$(basename ${SRC_FILE})
SRC_ORIG=${SRC_BASENAME}
DST_MODIFY=${FORMAT}

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

# 8. Build a -x<cores> argument for this computer

n_cores=$(gmt --show-cores)
if [ ${n_cores} -gt 1 ]; then
	threads="- x${n_cores}"
fi

# 9.1 See if user gave the split cutoff in seconds to save on memory, and/or -n

DST_SPLIT=0	# Do it all in one go
DST_BUILD=1	# By default we do the processing
shift	# Go to first argument after recipe (if there is any)
while [ ! "X$1" == "X" ]; do
	if [ "${1}" = "-n" ]; then	# Just report, no build
		DST_BUILD=0
	else
		DST_SPLIT=${1}
		echo "For output resolutions <= ${DST_SPLIT} seconds we filter N + S hemispheres separately"
	fi
	shift		# So that $2 now is next arg or blank
done

if [ ${DST_BUILD} -eq 0 ]; then	# Report variables
	cat <<- EOF
	# Final parameters after processing ${RECIPE}:

	SRC_ORIG	${SRC_ORIG}
	SRC_FILE	${SRC_FILE}
	SRC_REG		${SRC_REG}
	DST_MODIFY	${DST_MODIFY}
	DST_SPLIT	${DST_SPLIT}
	TITLE		${TITLE}
	REMARK		${REMARK}

	# Processing steps to be taken if -n was not given:

	EOF
else
	mkdir -p ${DST_PLANET}/${DST_PREFIX}
fi

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
	DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${IRES}${UNIT}.tif
	if [ -f ${DST_FILE} ]; then	# Do nothing
		echo "${DST_FILE} exist - skipping"
	elif [ "X${MASTER}" = "Xmaster" ]; then # Just make a copy of the master to a new output file
		echo "Convert ${SRC_FILE} to ${DST_FILE}"
		cp ${SRC_FILE} ${DST_FILE}
	else	# Must down-sample to a lower resolution via spherical Gaussian filtering
		# Get suitable Gaussian full-width filter rounded to nearest 0.1 km after adding 50 meters for noise
		FILTER_WIDTH=$(filter_width_from_output_spacing ${INC})
		if [ ${DST_BUILD} -eq 1 ]; then
			printf "Down-filter ${SRC_FILE} to ${DST_FILE} via layers "
			gmt grdmix ${SRC_FILE} -D -Gtmp_%c.nc=ns
			for code in r g b; do
				printf "${code}"
				gmt grdfilter tmp_${code}.nc -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -rp -Gtmp_filt_${code}.nc=ns ${threads}
			done
			printf " > ${DST_FORMAT}\n"
			gmt grdmix -C tmp_filt_r.nc tmp_filt_g.nc tmp_filt_b.nc -G${DST_FILE} -Ni
		else
			echo "Down-filter ${SRC_FILE} to ${DST_FILE} via R, G, and B layers. FW = ${FILTER_WIDTH}"
		fi
	fi
done < ${TMP}/res.lis

# 9. Clean up /tmp
rm -rf ${TMP}
# 11. Go back to where we started
cd ${HERE}
