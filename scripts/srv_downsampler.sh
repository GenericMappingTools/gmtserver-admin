#!/usr/bin/env bash -e
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

if [ $(uname -n) = "gmtserver" ]; then	# Doing official work on the server
	TOPDIR=/export/gmtserver/gmt/gmtserver-admin
elif [ -d ../scripts ]; then	# On your working copy, probably in scripts
	cd ..
	TOPDIR=$(pwd)
elif [ -d scripts ]; then	# On your working copy, probably in top gmtserver-admin
	TOPDIR=$(pwd)
else
	echo "error: Run srv_downsampler.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi

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
