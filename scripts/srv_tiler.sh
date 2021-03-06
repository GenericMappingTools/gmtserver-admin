#!/bin/bash -e
# srv_tiler.sh - Split a large grid into suitable square tiles
#
# usage: srv_tiler.sh recipe.
# where
#	recipe:		The name of the recipe file (e.g., earth_relief)
#
# These recipe files contain meta data for this data set.  Here, we only
# need to get the resolution and file names since the global files already
# exist.  THe script will processes all the global resolutions and if tiling
# occurs we create subdirectories with the tiled files inside.
# We convert all tiles to JP2 format for minimized sizes for transmission.
#
# NOTE: We will ONLY look for the global files on this local machine.  We first
# look in the staging/<planet> directory, and if not there then we look in the
# users server directory.

function get_prefix  () {       # Takes west south and makes the {N|S}yy{W|E}xxx prefix
	if [ $1 -ge 0 ]; then
		X=`printf "E%03d" $1`
	else
		t=`gmt math -Q $1 NEG =`
		X=`printf "W%03d" $t`
	fi
	if [ $2 -ge 0 ]; then
		Y=`printf "N%02d" $2`
	else
		t=`gmt math -Q $2 NEG =`
		Y=`printf "S%02d" $t`
	fi
	echo ${Y}${X}
}

if [ $# -eq 0 ]; then
	echo "usage: srv_tiler.sh recipe"
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
	echo "error: Run srv_tiler.sh from scripts folder or top gmtserver-admin directory"
	exit -1
fi
# 1. Move into the staging directory
cd ${TOPDIR}/staging
	
# 2. Get recipe full file path
RECIPE=$TOPDIR/recipes/$1.recipe
if [ ! -f $RECIPE ]; then
	echo "error: srv_tiler.sh: Recipe $RECIPE not found"
	exit -1
fi	

# 3. Extract parameters into a shell include file and ingest
grep DST_PLANET $RECIPE    | awk '{print $2}' >  /tmp/par.sh
grep DST_PREFIX $RECIPE    | awk '{print $2}' >> /tmp/par.sh
grep DST_TILE_SIZE $RECIPE | awk '{print $2}' >> /tmp/par.sh
grep DST_FORMAT $RECIPE    | awk '{print $2}' >> /tmp/par.sh
grep DST_SCALE $RECIPE     | awk '{print $2}' >> /tmp/par.sh
grep DST_OFFSET $RECIPE    | awk '{print $2}' >> /tmp/par.sh
grep DST_NODES $RECIPE     | awk '{print $2}' >> /tmp/par.sh
source /tmp/par.sh
	 
# 4. Extract the requested resolutions and inverse scale
grep -v '^#' $RECIPE > /tmp/res.lis
DATADIR=${DST_PLANET}/${DST_PREFIX}
DST_NODES=$(echo $DST_NODES | tr ',' ' ')
# INV_SCL is needed to convert data to the integers we wish to store in the JP2 file
INV_SCL=$(gmt math -Q ${DST_SCALE} INV =)

export GDAL_PAM_ENABLED=NO	# We do not want XML files in the directories

creation_date=`date +%Y-%m-%d`
rm -f ${DST_PREFIX}_dates.txt
# 5. Loop over all the resolutions found
while read RES UNIT DST_TILE_SIZE CHUNK MASTER ; do
	if [ "X$UNIT" = "Xd" ]; then	# Gave increment in degrees
		INC=$RES
	elif [ "X$UNIT" = "Xm" ]; then	# Gave increment in minutes
		INC=`gmt math -Q $RES 60 DIV =`
	elif [ "X$UNIT" = "Xs" ]; then	# Gave increment in seconds
		INC=`gmt math -Q $RES 3600 DIV =`
	else
		echo "Bad resolution $RES - aborting"
		exit -1
	fi
	for REG in ${DST_NODES}; do # Probably doing both pixel and gridline registered output, except for master */
		# Name and path of grid we wish to tile
		DST_TILE_TAG=${DST_PREFIX}_${RES}${UNIT}_${REG}
		DST_FILE=${DST_TILE_TAG}.grd
		if [ -f ${DATADIR}/${DST_FILE} ]; then # found locally
			DATAGRID=${DATADIR}/${DST_FILE}
		else 	# Get it via local server files
			DATAGRID=~/.gmt/server/${DST_PREFIX}_${RES}${UNIT}_${REG}.grd
		fi
		if [ ! -f ${DATAGRID} ]; then # No
			echo "No such file to tile: ${DATAGRID}"
			continue
		fi
		# Compute number of tiles required for this grid given nominal tile size.
		# We enforce square tiles by only solving for ny and doubling it for nx
		if [ $DST_TILE_SIZE -gt 0 ]; then	# OK, we need to split the file into separate tiles
			ny=`gmt math -Q 180 ${DST_TILE_SIZE} DIV =`
			nx=`gmt math -Q ${ny} 2 MUL =`
			n_tiles=`gmt math -Q $nx $ny MUL =`
			echo "Tiling: ${DATAGRID} split into ${n_tiles} tiles"
			# Get dimension of tiles in degrees
			# Build the list of w/e/s/n for the tiles
			gmt grdinfo ${DATAGRID} -I${DST_TILE_SIZE} -D -C > /tmp/wesn.txt
			# Determine local temporary tile directory for this product
			TILEDIR=./${DST_PLANET}/${DST_PREFIX}/${DST_PREFIX}_${RES}${UNIT}_${REG}
			rm -rf ${TILEDIR}
			mkdir -p ${TILEDIR}
			while read w e s n; do
				# Get the {N|S}yy{W|E}xxx prefix
				prefix=`get_prefix $w $s`
				# Create name for this tile (without extension)
				TILEFILE=${TILEDIR}/${prefix}.${DST_TILE_TAG}.jp2
				# Extract the tile from the global grid and write after making the integers; no compression since a tmpfile
				gmt grdconvert ${DATAGRID} -R$w/$e/$s/$n -G/tmp/subset.nc=${DST_FORMAT} -Z+s${INV_SCL}+o${DST_OFFSET}
				# Compress this grid to a lossless JP2000 file
				printf "Convert subset %s from %s to %s\n" $prefix ${DST_FILE} ${TILEFILE}
				gdal_translate -q -of JP2OpenJPEG -co "QUALITY=100" -co "REVERSIBLE=YES" -co "YCBCR420=NO" /tmp/subset.nc ${TILEFILE}
			done < /tmp/wesn.txt
			echo "${DST_TILE_TAG}	$creation_date" >> ${DST_PREFIX}_dates.txt
		else
			printf "No tiling requested for %s\n" ${DST_FILE}
		fi
	done
done < /tmp/res.lis
# 6. Clean up /tmp
#rm -f /tmp/res.lis /tmp/par.sh /tmp/subset.nc
# 7. Go back to where we started
echo "File with tile directory creation dates: ${DST_PREFIX}_dates.txt"
cd ${HERE}
