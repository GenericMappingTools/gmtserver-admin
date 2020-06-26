#!/bin/bash -e
# srv_setbackwards_links.sh [root]
#
# When the @remotefiles was first introduced in GMT 5.x and continued
# in GMT 6.0.0, we looked for the earth_relief_xxy.grd files in the
# top of the gmtserver directory (/export/gmtserver/gmt/data). This
# has to continue to work as we make changes for 6.1.  The solution
# is to create symbolic links from where 6.x/6.0.0 expects the files
# to where the files will be.  For the earth_relief files, this is
# now in server/earth/earth_relief, except for those grid spacings
# that are now served as tiles.
#
# The links are only used by GMT <= 6.0.0 as 6.1 has no need.
#
# Creates two sets of symbolic links in the root directory to:
#	 -> Grids with increments 10m and larger -> server/earth/earth_relief/earth_relief_xxy_g.grd
#	 -> Grids with smaller increments in the root dir -> earth_reliefearth_relief_xxy_g.grd
#
# Thus, even though GMT 6.1 is not using these last single grids, they
# need to be present for GMT <= 6.0.0 to work.
#
# This script creates both sets of links
#
# Registration: We have settled on gridline-registration since 6.0.0 used that and
# PyGMT v0.1 is limited to gridline grids.

# 0a. Make the list of the resolutions and the registrations of physical files in 6.1
cat << EOF > /tmp/files.lis
01d	g
30m	g
20m	g
15m	g
10m	g
06m	g
EOF
# 0b. Make the list of the resolutions and the registrations of virtual files in 6.1
cat << EOF > /tmp/tiles.lis
05m	g
04m	g
03m	g
02m	g
01m	g
30s	g
15s	p
EOF

# 1. Go to the root of the data service, or alternatively another tree
if [ "X${1}" = "X" ]; then
	dir=data
else
	dir=${1}
fi
cd /export/gmtserver/gmt/${dir}

# 2. Delete the old links wherever they are found
find . -name 'earth_relief_???.grd' -exec rm -f {} \; 

# 3a. Make the backwards compatible 6.0.0 links in the root dir to files in earth_relief
while read xxy registration; do
	ln -s server/earth/earth_relief/earth_relief_${xxy}_${registration}.grd earth_relief_${xxy}.grd
done < /tmp/files.lis
# 3b. Manually do the 60m -> 01d link since there is no 60m source anymore
ln -s server/earth/earth_relief/earth_relief_01d_g.grd earth_relief_60m.grd
# 3c. Make the backwards compatible 6.0.0 links in the root dir to files in the root dir
while read xxy registration; do
	ln -s earth_relief_${xxy}_${registration}.grd earth_relief_${xxy}.grd
done < /tmp/tiles.lis

# 4. Remote tempfile
rm -f /tmp/files.lis
