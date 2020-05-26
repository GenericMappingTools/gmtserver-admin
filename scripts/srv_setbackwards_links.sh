#!/bin/bash -e
# srv_setbackwards_links.sh
#
# Creates symbolic links to the earth_relief/earth_relief_xxy.grd files
# that were known prior to GMT 6.1.  For older GMT versions we need
# symbolic links in the root (/export/gmtserver/gmt/data) directory,
# while for GMT 6.1 we need links in the server directory instead.
# This script creates both sets of links

# 1. Make the list of the resolutions and the registrations
cat << EOF > /tmp/tmp.lis
01d	g
30m	g
20m	g
15m	g
10m	g
06m	g
05m	g
04m	g
03m	g
02m	g
01m	g
30s	g
15s	p
EOF

# 2a. Make the links in the root dir
cd /export/gmtserver/gmt/data
while read xxy registration; do
	ln -s server/earth_relief/earth_relief_${xxy}_${registration}.grd earth_relief_${xxy}.grd
done < /tmp/tmp.lis
# Manually do the 60m -> lis link
ln -s server/earth_relief/earth_relief_01d_g.grd earth_relief_60m.grd

# 2b. Make the links in the server dir
cd /export/gmtserver/gmt/data/server
while read xxy registration; do
	ln -s earth_relief/earth_relief_${xxy}_${registration}.grd earth_relief_${xxy}.grd
done < /tmp/tmp.lis
# Manually do the 60m -> lis link
ln -s earth_relief/earth_relief_01d_g.grd earth_relief_60m.grd
rm -f /tmp/tmp.lis
