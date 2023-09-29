#!/usr/bin/env bash
# srv_earthmasks.sh - Filter the highest resolution grid to lower resolution versions
#
# usage: srv_earthmasks.sh recipe.
# where
#	recipe:		The name of the recipe file (e.g., earth_relief)
#
# This script is simply creating a land/sea mask based on the GSHHG full resolution
# data set.  We skip features smaller than a grid cell via -A.

# Hardwired settings for masks
DST_OFFSET=0
DST_SCALE=1
MARK=""

if [ $# -eq 0 ]; then
	cat <<- EOF >&2
	usage: srv_earthmasks.sh <recipefile> [-n] [-f]"
		<recipefile> is one of several in the recipes directory, but typically earth_mask

		Optional arguments (must be in the indicated order):
			-f	Force removal if data set directory already exists [abort]
			-n	Do not make any resolution files yet, just report
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
	echo "error: Run srv_earthmasks.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi

# 1. Move into the staging directory
cd ${TOPDIR}/staging
	
# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/${1}.recipe
if [ ! -f ${RECIPE} ]; then
	echo "error: srv_earthmasks.sh: Recipe ${RECIPE} not found"
	exit -1
fi	

TMP=/tmp/$$
mkdir -p ${TMP}

# 3. Extract parameters into a shell include file and ingest
grep SRC_TITLE ${RECIPE}  | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REMARK ${RECIPE} | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_RADIUS ${RECIPE} | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_NAME ${RECIPE}   | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REF ${RECIPE}    | awk '{print $2}' >> ${TMP}/par.sh
grep DST_NODES ${RECIPE}  | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PLANET ${RECIPE} | awk '{print $2}' >> ${TMP}/par.sh
grep DST_PREFIX ${RECIPE} | awk '{print $2}' >> ${TMP}/par.sh
grep DST_FORMAT ${RECIPE} | awk '{print $2}' >> ${TMP}/par.sh
grep DST_CPT ${RECIPE}    | awk '{print $2}' >> ${TMP}/par.sh
source ${TMP}/par.sh

# 4. Extract the requested resolutions and registrations

grep -v '^#' ${RECIPE} > ${TMP}/res.lis
DST_NODES=$(echo $DST_NODES | tr ',' ' ')

# 5. Replace underscores with spaces in the title and remark
TITLE=$(echo ${SRC_TITLE} | tr '_' ' ')
REMARK=$(echo ${SRC_REMARK} | tr '_' ' ')
CITE=$(echo ${SRC_REF} | tr '_' ' ')

# 6. See if user gave the -f or -n

DST_FORCE=0	# Abort if dataset dir exists
DST_BUILD=1	# By default we do the processing
shift	# Go to first argument after recipe (if there is any)
while [ ! "X$1" == "X" ]; do
	if [ "${1}" = "-n" ]; then	# Just report, no build
		DST_BUILD=0
	elif [ "${1}" = "-f" ]; then	# Delete existing dataset dir
		DST_FORCE=1
	fi
	shift		# So that $2 now is next arg or blank
done

# 7. Get creation date
creation_date=$(date +%Y-%m-%d)

# 8. Set info file here since no image tiling yet
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

# 9.2 Loop over all the resolutions found
while read RES UNIT TILE CHUNK; do
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
		echo "Bad resolution ${RES} - aborting"
		exit -1
	fi
	if [ ! ${RES} = "01" ]; then	# Use plural unit
		UNIT_NAME="${UNIT_NAME}s"
	fi
	# Get area of a grid cell at Equator in km^2 as cutoff for -A
	MIN_AREA=$(gmt math -Q ${SRC_RADIUS} PI MUL 180 DIV ${INC} MUL 2 POW RINT =)
	if [ ${MIN_AREA} -eq 0 ]; then
		remark="All features included [${REMARK}]"
	else
		remark="Features < ${MIN_AREA} km^2 skipped [${REMARK}]"
	fi
	IRES=$(gmt math -Q ${RES} FLOOR = --FORMAT_FLOAT_OUT=%02.0f)
	FTAG="${IRES}${UNIT}"

	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${RES}${UNIT}_${REG}.grd
		grdtitle="${TITLE} at ${RES} arc ${UNIT_NAME}"

		if [ -f ${DST_FILE} ]; then	# Do nothing
			echo "${DST_FILE} exist - skipping"
		else	# Must run grdlandmask with these settings
			echo "Creating ${DST_FILE}"
			if [ ${DST_BUILD} -eq 1 ]; then
				gmt grdlandmask -Rd -I${RES}${UNIT} -r${REG} -Df -N0/1/2/3/4 -A${MIN_AREA} -G${DST_FILE}=${DST_FORMAT} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} --PROJ_ELLIPSOID=Sphere
				gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"
				SIZE=$(ls -lh ${DST_FILE} | awk '{print $5}')
				printf "%s/server/%s/%s/\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t-\t-\t%s\t%s at %dx%d arc %s (GSHHG features < %s km^2 in area are skipped) [%s]\n" \
					"${MARK}" ${DST_PLANET} ${DST_PREFIX} ${DST_FILE} ${FTAG} ${REG} ${DST_SCALE} ${DST_OFFSET} ${SIZE} ${creation_date} ${DST_CPT} "${TITLE}" ${RES} ${RES} ${UNIT_NAME} ${MIN_AREA} "${CITE}" >> ${INFOFILE}
			else
				SIZE="N/A"
				printf "%s/server/%s/%s/\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t-\t-\t%s\t%s at %dx%d arc %s (GSHHG features < %s km^2 in area are skipped) [%s]\n" \
					"${MARK}" ${DST_PLANET} ${DST_PREFIX} ${DST_FILE} ${FTAG} ${REG} ${DST_SCALE} ${DST_OFFSET} ${SIZE} ${creation_date} ${DST_CPT} "${TITLE}" ${RES} ${RES} ${UNIT_NAME} ${MIN_AREA} "${CITE}"
			fi
		fi
	done
done < ${TMP}/res.lis
# 10. Clean up /tmp
rm -rf ${TMP}
# 11. Go back to where we started
cd ${HERE}
