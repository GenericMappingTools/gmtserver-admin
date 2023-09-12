#	Makefile for gmtserver-admin
#
#
#	Author:	Paul Wessel, SOEST, U. of Hawaii.
#
#	Update Date:	27-AUG-2023
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
#!BUILD AND EXPLORE A NEW DATASET (*) OR AN UPDATE TO EXISTING DATA (e.g., neptune_relief)
#!  *1. Design neptune_relief.recipe and place in recipes directory
#!  *2. Examine and run "scripts/srv_downsampler.sh neptune_relief -n"
#!   3. Run "scripts/srv_downsampler.sh neptune_relief" to down-sample the data
#!  *4. Examine and run "scripts/srv_tiler.sh neptune_relief -n"
#!   5. Run "scripts/srv_tiler.sh neptune_relief" to tile the largest files
#!   6. Run "make place-neptune-relief" to place the new data on the candidate server
#!
#!MANAGE DATA ON SERVER CANDIDATE:
#!  candidate-delete   : Remove ALL data sets from the server dir candidate
#!  candidate-release  : rsync ALL data from staging directory to server dir candidate
#!  candidate-info     : Rebuild the gmt_data_server.txt file for server dir candidate
#!
#!UPDATE PUBLIC SERVER OCEANIA:
#!  server-release     : rsync ALL data from candidate server to public server oceania
#!  server-info        : Rebuild the gmt_data_server.txt file on server oceania
#!
#!MANAGE DATA ON SERVER STATIC:
#!  static-delete   : Remove ALL data sets from the server dir static
#!  static-release  : Update all files needed from oceania to the server dir static
#!-----------------------------------------------------------------------

candidate-delete:
		ssh candidate.generic-mapping-tools.org "rm -rf /export/gmtserver/gmt/candidate/server; mkdir /export/gmtserver/gmt/candidate/server"

candidate-release:
		scripts/candidate-release.sh
		scripts/srv_candidate_server.sh

candidate-info:
		scripts/srv_candidate_server.sh

# STATIC

static-delete:
		ssh static.generic-mapping-tools.org "rm -rf /export/gmtserver/gmt/static/server; mkdir /export/gmtserver/gmt/static/server"

candidate-release:
		scripts/static-release.sh
		scripts/srv_candidate_server.sh

# SERVER

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
	make earth-mask

make-planets:
	make mars-relief
	make moon-relief
	make mercury-relief
	make pluto-relief
	make venus-relief

#----------------------------------
earth-topo:
		make earth-relief
		make earth-synbath
		make earth-gebco
		make earth-gebcosi

earth-grav:
		make earth-faa
		make earth-vgg

earth-mag:
		make earth-emag
		make earth-emag4k
		make earth-wdmam

earth-relief:
		scripts/srv_downsampler.sh earth_relief
		scripts/srv_tiler.sh earth_relief

earth-synbath:
		scripts/srv_downsampler.sh earth_synbath
		scripts/srv_tiler.sh earth_synbath

earth-gebco:
		scripts/srv_downsampler.sh earth_gebco
		scripts/srv_tiler.sh earth_gebco

earth-gebcosi:
		scripts/srv_downsampler.sh earth_gebcosi
		scripts/srv_tiler.sh earth_gebcosi

earth-faa:
		scripts/srv_downsampler.sh earth_faa
		scripts/srv_tiler.sh earth_faa

earth-vgg:
		scripts/srv_downsampler.sh earth_vgg
		scripts/srv_tiler.sh earth_vgg

earth-wdmam:
		scripts/srv_downsampler.sh earth_wdmam
		scripts/srv_tiler.sh earth_wdmam

earth-emag:
		scripts/srv_downsampler.sh earth_mag
		scripts/srv_tiler.sh earth_mag

earth-emag4km:
		scripts/srv_downsampler.sh earth_mag4km
		scripts/srv_tiler.sh earth_mag4km

earth-mask:
	scripts/srv_earthmasks.sh earth_mask

mars-relief:
		scripts/srv_downsampler.sh mars_relief
		scripts/srv_tiler.sh mars_relief

mercury-relief:
		scripts/srv_downsampler.sh mercury_relief
		scripts/srv_tiler.sh mercury_relief

moon-relief:
		scripts/srv_downsampler.sh moon_relief
		scripts/srv_tiler.sh moon_relief

pluto-relief:
		scripts/srv_downsampler.sh pluto_relief
		scripts/srv_tiler.sh pluto_relief

venus-relief:
		scripts/srv_downsampler.sh venus_relief
		scripts/srv_tiler.sh venus_relief

# Upload Earth data to candidate server

place-earth-relief:
		scripts/place_candidate.sh earth_relief

place-earth-synbath:
		scripts/place_candidate.sh earth_synbath

place-earth-gebco:
		scripts/place_candidate.sh earth_gebco

place-earth-gebcosi:
		scripts/place_candidate.sh earth_gebcosi

place-earth-mask:
		scripts/place_candidate.sh earth_mask

place-earth-faa:
		scripts/place_candidate.sh earth_faa

place-earth-vgg:
		scripts/place_candidate.sh earth_vgg

place-earth-emag:
		scripts/place_candidate.sh earth_mag

place-earth-emag4k:
		scripts/place_candidate.sh earth_mag4k

place-earth-wdmam:
		scripts/place_candidate.sh earth_wdmam

# Upload planetary data to candidate server

place-mars-relief:
		scripts/place_candidate.sh mars_relief

place-mercury-relief:
		scripts/place_candidate.sh mercury_relief

place-moon-relief:
		scripts/place_candidate.sh moon_relief

place-pluto-relief:
		scripts/place_candidate.sh pluto_relief

place-venus_relief:
		scripts/place_candidate.sh venus_relief
