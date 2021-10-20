#!/bin/bash -e
# srv_srtm_coverage.sh - Create the srtm_tiles.nc coverage file for @earth_relief
#
# This 1x1 pixel grid helps us know if SRTM tiles are present and if so if it is
# a partial-ocean tile requiring the filler from @earth_relief_15s.  We want a
# 1x1 degree pixel grid with: 0 = no SRTM tile, 1 = SRTM tile  with partial ocean,
# 2 = SRTM tile entirely on land.  Since there are no SRTM tiles outside the
# 60S/60N latitude band we only need to build the grid for that range.
# Note 1: For 6.0-6.2 this was simply a 0 or 1 grid. For 6.3 we have upgraded
#	that to use 1 (partial) or 2 (full) SRTM coverage, as described above.
# Note 2: The GMT source code in gmt_remote.c ASSUMES the coverage region is 0/360 so we
#	are stuck with that even though all the data are -180/180...  This ensures
#	backwards compatibility so when GMT 6.2 reads the same coverage file it works.
# Note 3: While the logic here is to use pixel-registration to keep track of the
#	tiles, backwards compatibility dictates we use gridline-registration and then
#	use the lower-left corner node to check status for this tile. This creates
#	a lat = north row with NaNs that we reset to 0 (since outside range anyway).
#
# usage: srv_srtm_coverage.sh
# 
# 1. Use the LL coordinates of the SRTM tiles to build a tile/no-tile grid
#    Since the srtm_tiles.txt file contains N00E006 we need to extract the
#	lon, lat and add 0.5 for the center of the 1x1 degree pixel
awk '{ printf "%s%s\t%s\%s\n", substr ($1, 5, 3), substr ($1, 4, 1), substr ($1, 2, 2), substr ($1, 1, 1)}' information/srtm_tiles.txt > /tmp/xy.txt
gmt xyz2grd -R0/360/-60/60 -I1 -rp -fg -G/tmp/srtm.nc=nb /tmp/xy.txt -i0-1o0.5 -An -V -di0
# 2. Use the @earth_mask_15s_g grid to determine which tiles have at least some ocean in them
gmt grdmath -R0/360/-60/60 @earth_mask_15s_p 0 EQ = /tmp/ocean_mask.nc=nb
# Find highest value per 1x1 tile. If 1 then it is partially ocean, else land
gmt grd2xyz /tmp/ocean_mask.nc -bo3d | gmt xyz2grd -R0/360/-60/60 -I1 -rp -Au -G/tmp/ocean.nc=ns -V -fg -bi3d
# 3. Combine the tile and ocean files to yield the 0,1,2 final grid as (ocean & srtm) + srtm:
gmt grdmath /tmp/srtm.nc 2 MUL /tmp/ocean.nc SUB DUP 0 GE MUL = /tmp/srtm_tiles_p.nc=nb
# Then convert to final grid-line registration which will place a row at north with NaNs
gmt grd2xyz /tmp/srtm_tiles_p.nc | gmt xyz2grd -R0/360/-60/60 -I1 -rg -fg -G/tmp/tmp.nc=nb -i0-1o-0.5,2
# Replace the NaNs with 0 since no tiles start at 60N
gmt grdmath /tmp/tmp.nc=nb 0 DENAN = srtm_tiles.nc=nb --IO_NC4_DEFLATION_LEVEL=9
# Update the remark and make a test plot of the flags
gmt grdedit srtm_tiles.nc=nb -D+t"Availability of SRTM tiles"+r"0 means empty, 1 means land tile, 2 means partial land tile"
gmt grdimage srtm_tiles.nc -Cblue,red,lightbrown -B -B+t"SRTM mask ocean (blue), land (brown) and mixed (red)" -png /tmp/t
echo "srtm_tiles.nc: You must manually add it to the cache and commit the change there"
