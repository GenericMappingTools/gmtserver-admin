#	Makefile for gmtserver-admin
#
#
#	Author:	Paul Wessel, SOEST, U. of Hawaii.
#
#	Update Date:	02-FEB-2023
#
#-------------------------------------------------------------------------------
#	!! STOP EDITING HERE, THE REST IS FIXED !!
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------

help::
		@grep '^#!' Makefile | cut -c3-
#!-------------------- MAKE HELP FOR GMTSERVER-ADMIN --------------------
#!
#!make <target>, where <target> can be:
#!
#!server-release     : rsync ALL data from candidate server to public server oceania
#!server-info        : Rebuild the gmt_data_server.txt file on server oceania
#!candidate-delete   : Remove ALL data sets from the server candidate
#!candidate-release  : rsync all data from staging directory to server candidate
#!candidate-info     : Rebuild the gmt_data_server.txt file server candidate
#!

candidate-delete:
		ssh candidate.generic-mapping-tools.org "rm -rf /export/gmtserver/gmt/candidate/server; mkdir /export/gmtserver/gmt/candidate/server"

candidate-release:
		candidate-release.sh
		srv_candidate_server.sh

candidate-info:
		srv_candidate_server.sh

server-release:
		scripts/server-release.sh

server-info:
		date "+%Y-%m-%d" | awk '{printf "s/THEDATE/%s/g\n", $$1}' > /tmp/sed.txt
		rm information/gmt_data_server.txt
		cat information/*_*_server.txt | grep -v '^#' | wc -l | awk '{printf "%d\n", $$1}' > /tmp/gmt_data_server.txt
		sed -f /tmp/sed.txt < information/gmt_data_server_header.txt >> /tmp/gmt_data_server.txt
		cat information/*_*_server.txt >> /tmp/gmt_data_server.txt
		mv /tmp/gmt_data_server.txt information/gmt_data_server.txt  

make-earth:
	make earth-topo
	make earth-grav
	make earth-mag
	make earth-masks

make-planets:
	make mars-relief
	make moon-relief
	make mercury-relief
	make pluto-relief
	make venus-relief

#----------------------------------
earth-topo:
		make earth-topo
		make earth-grav
		make earth-relief
		make earth-synbath
		make earth-gebco
		make earth-gebcosi
		make earth-faa
		make earth-vgg

earth-grav:
		make earth-faa
		make earth-vgg

earth-mag:
		make earth-emag
		make earth-emag4k
		make earth-wdmam

earth-relief:
		scripts/srv_downsampler_grid.sh earth_relief
		scripts/srv_tiler.sh earth_relief

earth-synbath:
		scripts/srv_downsampler_grid.sh earth_synbath
		scripts/srv_tiler.sh earth_synbath

earth-gebco:
		scripts/srv_downsampler_grid.sh earth_gebco
		scripts/srv_tiler.sh earth_gebco

earth-gebcosi:
		scripts/srv_downsampler_grid.sh earth_gebcosi
		scripts/srv_tiler.sh earth_gebcosi

earth-faa:
		scripts/srv_downsampler_grid.sh earth_faa
		scripts/srv_tiler.sh earth_faa

earth-vgg:
		scripts/srv_downsampler_grid.sh earth_vgg
		scripts/srv_tiler.sh earth_vgg

earth-wdmam:
		scripts/srv_downsampler_grid.sh earth_wdmam
		scripts/srv_tiler.sh earth_wdmam

earth-emag:
		scripts/srv_downsampler_grid.sh earth_mag
		scripts/srv_tiler.sh earth_mag

earth-emag4km:
		scripts/srv_downsampler_grid.sh earth_mag4km
		scripts/srv_tiler.sh earth_mag4km

earth-masks:
	scripts/srv_earthmasks.sh earth_mask

mars-relief:
		scripts/srv_downsampler_grid.sh mars_relief
		scripts/srv_tiler.sh mars_relief

mercury-relief:
		scripts/srv_downsampler_grid.sh mercury_relief
		scripts/srv_tiler.sh mercury_relief

moon-relief:
		scripts/srv_downsampler_grid.sh moon_relief
		scripts/srv_tiler.sh moon_relief

pluto-relief:
		scripts/srv_downsampler_grid.sh pluto_relief
		scripts/srv_tiler.sh pluto_relief

venus-relief:
		scripts/srv_downsampler_grid.sh venus_relief
		scripts/srv_tiler.sh venus_relief

# Upload new data to candidate server

place-synbath:
		scripts/place_candidate.sh earth_synbath

place-venus_relief:
		scripts/place_candidate.sh venus_relief
