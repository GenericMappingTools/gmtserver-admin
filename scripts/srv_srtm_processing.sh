#!/bin/bash -e
# srv_srtm_processing.sh - STRM Processing
#
# usage: srv_srtm_processing.sh
#
# Download zipped tiles from USGS via wget, then unzip and convert to lossless JPEG2000 grids via GDAL
# This was done, hopefully once, already but the script is here for documentation.  I think I needed
# to create that account on the USGS server so wget would work.
#
# P. Wessel, Sept. 14, 2017

# Convert things like N00E006 to a valid -R region
function get_region  () {	# $1 is the tile tag
	let S=`echo $1 | awk '{printf "%d\n", substr($1,2,2)}'`
	SC=`echo $1 | awk '{printf "%c\n", substr($1,1,1)}'`
	let W=`echo $1 | awk '{printf "%d\n", substr($1,5,3)}'`
	WC=`echo $1 | awk '{printf "%c\n", substr($1,4,1)}'`
	if [ $SC = "S" ]; then
		let N=S-1
	else
		let N=S+1
	fi
	if [ $WC = "W" ]; then
		let E=W-1
	else
		let E=W+1
	fi
	printf "%3.3d%c/%3.3d%c/%2.2d%s/%2.2d%c\n" $W $WC $E $WC $S $SC $N $SC
}
# Set the resolution you are working on (1 or 3)
RES=1
mkdir -p SRTMGL${RES}_ZIP SRTMGL${RES}_HGT SRTMGL${RES}_JP2000
while read tile; do
	if [ ! -f SRTMGL${RES}_ZIP/${tile}.SRTMGL${RES}.hgt.zip ]; then	# Obtain file using wget
		printf "Get %s" $tile
		wget https://e4ftl01.cr.usgs.gov/SRTM/SRTMGL${RES}.003/2000.02.11/${tile}.SRTMGL${RES}.hgt.zip --user=pwessel@hawaii.edu --password=Norge2001 --quiet -O SRTMGL${RES}_ZIP/${tile}.SRTMGL${RES}.hgt.zip
		printf "\n"
	fi
	if [ ! -f SRTMGL${RES}_HGT/${tile}.SRTMGL${RES}.hgt ]; then	# Uncompress zip file to create *.hgt files
		printf "Uncompress %s" $tile
		unzip -q SRTMGL${RES}_ZIP/${tile}.SRTMGL${RES}.hgt.zip -d SRTMGL${RES}_HGT
		printf "\n"
	fi
	if [ ! -f SRTMGL${RES}_NC/${tile}.SRTMGL${RES}.nc ]; then	# Convert hgt file to compressed nc short int file
		printf "Convert %s to NC shorts" $tile
		region=`get_region $tile`
		gmt xyz2grd -ZTLhw -I1s -R$region SRTMGL${RES}_HGT/${tile}.hgt -GSRTMGL${RES}_NC/${tile}.SRTMGL${RES}.nc=ns --IO_NC4_DEFLATION_LEVEL=9
		printf "\n"
	fi
	if [ ! -f SRTMGL${RES}_JP2000/${tile}.SRTMGL${RES}.jp2 ]; then	# Convert netCDF file to even more compressed JPEG2000 files
		printf "Convert %s to JPEG2000" $tile
		gdal_translate -q -of JP2OpenJPEG -co "QUALITY=100" -co "REVERSIBLE=YES" -co "YCBCR420=NO" SRTMGL${RES}_HGT/${tile}.hgt SRTMGL${RES}_JP2000/${tile}.SRTMGL${RES}.jp2
		printf "\n"
	fi
done < srtmgl${RES}.lis
