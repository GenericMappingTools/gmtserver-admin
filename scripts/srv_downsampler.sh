#!/usr/bin/env -S bash -e
# Temporary debugging trace: show each command in the log to help diagnose failures.
set -x
# srv_downsampler.sh - Filter the highest resolution image or grids to lower resolution versions
#
# usage: srv_downsampler.sh <recipefile> [-n] [split].
# where
#	<recipefile>:		The name of the recipe file (e.g., earth_relief, earth_night)
#

if [ $# -eq 0 ]; then
	echo "usage: srv_downsampler.sh <recipefile>"
	exit -1
fi

# Determine the repo root from the current directory or script location.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_DIR=$(pwd)
TOPDIR=
CANDIDATE=${START_DIR}
while [ "${CANDIDATE}" != "/" ]; do
	if [ -d "${CANDIDATE}/.git" ] || { [ -d "${CANDIDATE}/scripts" ] && [ -d "${CANDIDATE}/recipes" ]; }; then
		TOPDIR=${CANDIDATE}
		break
	fi
	CANDIDATE=$(dirname "${CANDIDATE}")
done
if [ -z "${TOPDIR}" ]; then
	TOPDIR=${SCRIPT_DIR}/..
fi
if [ ! -d "${TOPDIR}/scripts" ] || [ ! -d "${TOPDIR}/recipes" ]; then
	echo "error: Could not locate the gmtserver-admin repository root from ${START_DIR}" >&2
	exit -1
fi
cd "${TOPDIR}"

# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_downsampler_image.sh: Recipe ${RECIPE} not found"
	exit -1
fi	

type=grid	# The default type is grid, but recipes for images will have SRC_TYPE set
if [ $(grep -c SRC_TYPE ${RECIPE}) -eq 1 ]; then	# Image format
	type=image
fi

# Run the right script
scripts/srv_downsampler_${type}.sh $*
