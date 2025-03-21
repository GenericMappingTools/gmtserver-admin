#!/bin/bash -e
# srv_downsampler_grid.sh - Filter the highest resolution grid to lower resolution versions
#
# usage: srv_downsampler_grid.sh <recipefile> [-f] [-n] [-x] [split]
# where
#	<recipefile>:		The name of the recipe file (e.g., earth_relief)
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

# Constants related to filtering are defined here
# Note: On Earth, 15 arc sec ~ 462 m

source scripts/filter_width_from_output_spacing.sh

if [ $# -eq 0 ]; then
	cat <<- EOF >&2
	usage: srv_downsampler_grid.sh <recipefile> [-f] [-n] [-x] [<split>]"
		<recipefile> is one of several in the recipes directory, e.g., mars_relief

		Optional arguments (must be in the indicated order):
			-f	Force removal if data set directory already exists [abort]
			-n	Do not make any resolution files yet, just report
			-x	Run grdfilter with -x-1 option (i.e., use all but one core)
			<split>	Force processing of global files at this grid resolution in seconds
					or smaller vi a S and N hemispheres due to memory limitations.
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
grep SRC_RENAME $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_TITLE $RECIPE   | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_REF $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_DOI $RECIPE     | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_RADIUS $RECIPE  | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_NAME $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_UNIT $RECIPE    | awk '{print $2}' >> ${TMP}/par.sh
grep SRC_PROCESS $RECIPE | awk -F'#' '{print $2}' >> ${TMP}/par.sh
grep SRC_RUN $RECIPE  | awk -F'#' '{print $2}' >> ${TMP}/par.sh
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
	if [ ! "X${SRC_RENAME}" = "X" ]; then	# Rename immediately after file lands
		mv -f ${SRC_BASENAME} ${SRC_RENAME}
		SRC_ORIG=${SRC_BASENAME}
		SRC_FILE=${SRC_RENAME}
		SRC_BASENAME=${SRC_RENAME}
	else
		SRC_ORIG=${SRC_FILE}
		SRC_FILE=${SRC_BASENAME}
	fi
fi
# 5.2 See if given any pre-processing steps (1 or more) for zip files via SRC_PROCESS
if [ ! "X${SRC_PROCESS}" = "X" ]; then	# Pre-processing data to get initial grid
	echo "srv_downsampler_grid.sh: Execute pre-processing steps: ${SRC_PROCESS}"
	# Split possibly many commands separated by semi-colons and make a script to run
	$(echo ${SRC_PROCESS} | tr '";' ' \n' > ${TMP}/job1.sh)
	bash ${TMP}/job1.sh
	# Replace the source file name to reflect the extraction from zip to whatever extension
	SRC_FILE=$(basename ${SRC_FILE} zip)"${SRC_EXT}"
fi
# 5.3 See if we must fill the grid to -Rd
if [ ! "X${SRC_RUN}" = "X" ]; then	# Specified commands only
	# Just execute this command
	$(echo ${SRC_RUN} | tr '";' ' \n' > ${TMP}/job2.sh)
	bash ${TMP}/job2.sh
fi
# 5.3 See if given any custom formatting steps
if [ ! "X${SRC_CUSTOM}" = "X" ]; then	# Pre-processing data to get initial grid
	# Similar to SRC_PROCESS but works on the initial source grid
	SRC_FILE=$(basename ${SRC_FILE} ${SRC_EXT})"nc"
	SRC_ORIG=${SRC_FILE}
	if [ ! -f ${SRC_FILE} ]; then	# Run the custom command(s)
		# Split possibly many commands separated by semi-colons and make a script to run
		echo "srv_downsampler_grid.sh: Must convert original ${SRC_EXT} source to ${SRC_FILE}"
		$(echo ${SRC_CUSTOM} | tr '";' ' \n' > ${TMP}/job3.sh)
		bash ${TMP}/job3.sh
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

# 9.3 See if user gave the -f, -n, -x or split cutoff in seconds to save on memory
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
else	# Make files in given directory unless it exists and no -f
	if [ -d ${DST_PLANET}/${DST_PREFIX} ]; then
		if [ ${DST_FORCE} -eq 1 ]; then
			rm -rf ${DST_PLANET}/${DST_PREFIX}
		else
			echo "Data set directory ${DST_PLANET}/${DST_PREFIX} already exists - aborting. Use -f to force removal instead."
			exit -1
		fi
	fi
	mkdir -p ${DST_PLANET}/${DST_PREFIX}
fi

# 10. Loop over all the resolutions found

while read RES UNIT DST_TILE_SIZE CHUNK MASTER; do
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

	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		# Set full name of output grid for this resolution,registration combination:
		DST_FILE=${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${IRES}${UNIT}_${REG}.grd
		grdtitle="${TITLE} at ${RES} arc ${UNIT_NAME}"
		# Note: The ${SRC_ORIG/+/\\+} below is to escape any plus-symbols in the file name with a backslash so grdedit -D will work
		if [ -f ${DST_FILE} ]; then	# Do nothing if the fail already was created earlier [you would need to remove manually first to start fresh]
			echo "${DST_FILE} already exists - skipping"
		elif [ "X${MASTER}" = "Xmaster" ]; then # Just make a reformatted copy of the master to a new output file
			if [ ${REG} = ${SRC_REG} ]; then # Only do the matching node registration for master since it is just repacking the format
				echo "Convert ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY}"
				if [ ${DST_BUILD} -eq 1 ]; then
					gmt grdconvert ${SRC_FILE} ${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9
					remark="Reformatted from master file ${SRC_ORIG/+/\\+} [${REMARK}]"
					gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
					SRC_NANS=$(gmt grdinfo -M ${DST_FILE} -Cn -o14)
					if [ ${SRC_NANS} -gt 0 ]; then
						echo "NaNs in source: Reformatted from master file ${DST_FILE} has ${SRC_NANS} NaNs"
					fi
				fi
			fi
		elif [ "${UNIT}" = "s" ] && [ ${IRES} -le ${DST_SPLIT} ]; then # Split files <= DST_SPLIT s to avoid excessive memory requirement
			# See https://github.com/GenericMappingTools/remote-datasets/issues/32 - we do south and north hemisphere separately
			FWR_SEC=$(gmt math -Q 2 2 SQRT MUL ${INC} MUL 3600 MUL RINT =)
			FILTER_WIDTH=$(filter_width_from_output_spacing ${INC})
			echo "Down-filter ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY} FW = ${FILTER_WIDTH} km [${FWR_SEC}s]"
			if [ ${DST_BUILD} -eq 1 ]; then
				gmt grdfilter -R-180/180/-90/0 ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${TMP}/s.grd ${threads} --PROJ_ELLIPSOID=${DST_SPHERE}
				gmt grdfilter -R-180/180/0/90  ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${TMP}/n.grd ${threads} --PROJ_ELLIPSOID=${DST_SPHERE}
				gmt grdpaste ${TMP}/s.grd ${TMP}/n.grd -G${TMP}/both.grd
				remark="Reduced by Gaussian ${DST_MODE} filtering (${FILTER_WIDTH} km fullwidth) from ${SRC_FILE/+/\\+} [${REMARK}]"
				gmt grdconvert ${TMP}/both.grd -G${DST_FILE}=${DST_MODIFY} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} 			
				gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
			fi
		else	# Must down-sample to a lower resolution via spherical or Cartesian Gaussian filtering
			# Get suitable Gaussian full-width filter rounded to nearest 0.1 km after adding 50 meters (${FW_OFFSET} km) for noise
			FWR_SEC=$(gmt math -Q 2 2 SQRT MUL ${INC} MUL 3600 MUL RINT =)
			FILTER_WIDTH=$(filter_width_from_output_spacing ${INC})
			echo "Down-filter ${SRC_FILE} to ${DST_FILE}=${DST_MODIFY} FW = ${FILTER_WIDTH} km [${FWR_SEC}s]"
			if [ ${DST_BUILD} -eq 1 ]; then
				gmt grdfilter ${SRC_FILE} -Fg${FILTER_WIDTH} -D${FMODE} -I${RES}${UNIT} -r${REG} -G${DST_FILE}=${DST_MODIFY} ${threads} --IO_NC4_DEFLATION_LEVEL=9 --IO_NC4_CHUNK_SIZE=${CHUNK} --PROJ_ELLIPSOID=${DST_SPHERE}
				remark="Reduced by Gaussian ${DST_MODE} filtering (${FILTER_WIDTH} km fullwidth) from ${SRC_FILE/+/\\+} [${REMARK}]"
				gmt grdedit ${DST_FILE} -D+t"${grdtitle}"+r"${remark}"+z"${SRC_NAME} (${SRC_UNIT})"
			fi
		fi
		if [[ -f ${DST_FILE} && ${DST_BUILD} -eq 1 ]]; then
			# Check that filtering covered all nodes, leaving no new NaNs
			n_NaN=$(gmt grdinfo -M ${DST_FILE} -Cn -o14)
			if [[ ${SRC_NANS} -eq 0 && ${n_NaN} -gt 0 ]]; then
				echo "ALERT: File ${DST_FILE} gained ${n_NaN} NaN nodes"
			elif [ ${SRC_NANS} -gt 0 ]; then
				if [ ${SRC_NANS} -gt ${n_NaN} ]; then
					echo "NOTE: File ${DST_FILE} have reduction in NaNs from ${SRC_NANS} to ${n_NaN} nodes"
				else
					echo "NOTE: File ${DST_FILE} have no reduction in NaNs from the original ${SRC_NANS} nodes"
				fi
			fi
		fi
	done
done < ${TMP}/res.lis

# 11. Clean up /tmp
rm -rf ${TMP} gmt.history gmt.conf
# 12. Go back to where we started
cd ${HERE}
