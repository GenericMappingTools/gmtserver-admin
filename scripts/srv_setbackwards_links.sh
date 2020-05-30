#!/bin/bash -e
# srv_setbackwards_links.sh [root]
#
# When the @remotefiles was first introduced in GMT 5.x and continued
# in GMT 6.0.0, we looked for the earth_relief_xxy.grd files in the
# top of the gmtserver directory (/export/gmtserver/gmt/data). This
# has to continue to work as we make changes for 6.1.  The solution
# is to create symbolic links from where 6.x/6.0.0 expects the files
# to where the files will be.  For the earth_relief files, this is
# now in server/earth/earth_relief.
#
# Creates two sets of symbolic links to:
#	 -> server/earth/earth_reliefearth_relief_xxy.grd
#
# 1) For older GMT versions we need symbolic links in the root.
# 2) For GMT 6.1 we need links in the same directory as the files.
#
# This script creates both sets of links

# 0. Make the list of the resolutions and the registrations
cat << EOF > /tmp/tmp.lis
01d	p
30m	p
20m	p
15m	p
10m	p
06m	p
05m	p
04m	p
03m	p
02m	p
01m	p
30s	p
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

# 3a. Make the backwards compatible 6.0.0 links in the root dir
while read xxy registration; do
	ln -s server/earth/earth_relief/earth_relief_${xxy}_${registration}.grd earth_relief_${xxy}.grd
done < /tmp/tmp.lis
# 3b. Manually do the 60m -> 01d link since there is no 60m source anymore
ln -s server/earth/earth_relief/earth_relief_01d_p.grd earth_relief_60m.grd

# 4a. Make the links in the earth_relief dir
cd /export/gmtserver/gmt/${dir}/server/earth/earth_relief
while read xxy registration; do
	ln -s earth_relief_${xxy}_${registration}.grd earth_relief_${xxy}.grd
done < /tmp/tmp.lis
# 4b. Manually do the 60m -> 01d link since there is no 60m source anymore
ln -s earth_relief_01d_p.grd earth_relief_60m.grd
# 5. Remote tempfile
rm -f /tmp/tmp.lis
