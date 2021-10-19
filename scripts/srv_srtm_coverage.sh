#!/bin/bash -e
# srv_srtm_coverage.sh - Create the srtm_tiles.nc coverage file for @earth_relief
# This 1x1 pixel grid helps us know if SRTM tiles are present and if so if it is
# a partial-ocean tile requiring the filler from @earth_relief_15s.  We want a
# 1x1 degree pixel grid with: 0 = no SRTM tile, 1 = SRTM tile entirely on land,
# 2 = SRTM tile with partial ocean.  Since there are no SRTM tiles outside the
# 60S/60N latitude band we only need to build the grid for that range.
# Note: For 6.0-6.2 this was simply a 0 or 1 grid (not 2) and it was a gridline-
#	registered grid which I think was wrong.  We take the requested w/e/s/n and
#	round outward to nearest integer degree, so then we should just look at the
#	tiles inside that region.
#
# usage: srv_srtm_coverage.sh
# 
# 1. Use the LL coordinates of the SRTM tiles to build a tile/no-tile grid
#    Since the srtm_tiles.txt file contains N00E006 we need to extract the
#	lon, lat and add 0.5 for the center of the 1x1 degree pixel
awk '{ printf "%s%s\t%s\%s\n", substr ($1, 5, 3), substr ($1, 4, 1), substr ($1, 2, 2), substr ($1, 1, 1)}' information/srtm_tiles.txt > /tmp/xy.txt
gmt xyz2grd -R-180/180/-60/60 -I1 -r -fg -G/tmp/srtm.nc=nb /tmp/xy.txt -i0-1o0.5 -An -V -di0
# 2. Use the @earth_mask_15s_g grid to determine which tiles have at least some ocean in them
gmt grdmath -R0/360/-60/60 @earth_mask_15s_p 0 EQ = /tmp/ocean_mask.nc=nb
gmt grd2xyz /tmp/ocean_mask.nc | gmt xyz2grd -R-180/180/-60/60 -I1 -r -Au -G/tmp/ocean.nc=ns -V -fg
# 3. Combine the tile and ocean files to yield the 0,1,2 final grid as (ocean & srtm) + srtm:
gmt grdmath /tmp/ocean.nc /tmp/srtm.nc BITAND /tmp/srtm.nc ADD  = srtm_tiles.nc=nb --IO_NC4_DEFLATION_LEVEL=9
gmt grdedit srtm_tiles.nc -D+t"Availability of SRTM tiles"+r"0 means empty, 1 means land tile, 2 means partial land tile"
echo "srtm_tiles.nc: You must manually add it to the cache and commit the change there"
