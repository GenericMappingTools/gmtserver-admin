#	Makefile for gmtserver-admin
#
#
#	Author:	Paul Wessel, SOEST, U. of Hawaii.
#
#	Update Date:	29-SEPT-2023
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
#!      Note: for updates, steps 3 and 5 can be done via make neptune-relief
#!
#! REBUILD DATA SETS LOCALLY IN STAGING DIRECTORY
#!   1. To make all the planets, run "make planets"
#!   2. To make all Earth data set, run "make earth"
#!   3. To make just all Earth topography, run "make earth-topo"
#!   4. To make just the GEBCO Earth topography, run "make earth-gebco"
#!
#!MANAGE DATA ON SERVER CANDIDATE:
#!  candidate-delete   : Remove ALL data sets from the server dir candidate
#!  candidate-release  : rsync ALL data from staging directory to server dir candidate
#!  candidate-info     : Rebuild the gmt_data_server.txt file for server dir candidate
#!
#!UPDATE PUBLIC SERVER OCEANIA:
#!  server-release     : rsync ALL data and gmt_data_server.txt from candidate server to public server oceania
#!
#!MANAGE DATA ON SERVER STATIC:
#!  static-delete   : Remove ALL data sets from the server dir static
#!  static-release  : Update all files needed from oceania to the server dir static
#!-----------------------------------------------------------------------

####################
# SERVER (candidate)
####################

# Completely wipe the candidate/server directory on the candidate server
candidate-delete:
		ssh candidate.generic-mapping-tools.org "rm -rf /export/gmtserver/gmt/candidate/server; mkdir /export/gmtserver/gmt/candidate/server"

candidate-release:
		scripts/candidate-release.sh
		scripts/srv_candidate_server.sh

candidate-info:
		scripts/srv_candidate_server.sh

####################
# SERVER (static)
####################

static-delete:
		ssh static.generic-mapping-tools.org "rm -rf /export/gmtserver/gmt/static/server; mkdir /export/gmtserver/gmt/static/server"

static-release:
		scripts/static-release.sh
		scripts/srv_candidate_server.sh

####################
# SERVER (test)
####################

test-delete:
		ssh test.generic-mapping-tools.org "rm -rf /export/gmtserver/gmt/test/server; mkdir /export/gmtserver/gmt/test/server"

####################
# SERVER (oceania)
####################

server-release:
		scripts/server-release.sh

earth:
	make earth-age
	make earth-grav
	make earth-mag
	make earth-mask
	make earth-topo

planets:
	make mars-relief
	make moon-relief
	make mercury-relief
	make pluto-relief
	make venus-relief

#----------------------------------
earth-topo:
		make earth-gebco
		make earth-gebcosi
		make earth-relief
		make earth-synbath

earth-grav:
		make earth-faa
		make earth-faaerror
		make earth-geoid
		make earth-edefl
		make earth-ndefl
		make earth-vgg

earth-mag:
		make earth-emag
		make earth-emag4km
		make earth-wdmam

earth-age:
		scripts/srv_downsampler.sh earth_age
		scripts/srv_tiler.sh earth_age

earth-images:
		make earth-day
		make earth-night

earth-day:
		scripts/srv_downsampler.sh earth_day

earth-night:
		scripts/srv_downsampler.sh earth_night

earth-gebco:
		scripts/srv_downsampler.sh earth_gebco
		scripts/srv_tiler.sh earth_gebco

earth-gebcosi:
		scripts/srv_downsampler.sh earth_gebcosi
		scripts/srv_tiler.sh earth_gebcosi

earth-relief:
		scripts/srv_downsampler.sh earth_relief
		scripts/srv_tiler.sh earth_relief

earth-synbath:
		scripts/srv_downsampler.sh earth_synbath
		scripts/srv_tiler.sh earth_synbath

earth-faa:
		scripts/srv_downsampler.sh earth_faa
		scripts/srv_tiler.sh earth_faa

earth-faaerror:
		scripts/srv_downsampler.sh earth_faaerror
		scripts/srv_tiler.sh earth_faaerror

earth-geoid:
		scripts/srv_downsampler.sh earth_geoid
		scripts/srv_tiler.sh earth_geoid

earth-edefl:
		scripts/srv_downsampler.sh earth_edefl
		scripts/srv_tiler.sh earth_edefl

earth-ndefl:
		scripts/srv_downsampler.sh earth_ndefl
		scripts/srv_tiler.sh earth_ndefl

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

#####################################################
# Upload Earth and planetary data to candidate server
#####################################################

# Uploads everything
place-all:
	make place-earth
	make place-planets

# Uploads everything about Earth
place-earth:
	make place-earth-age
	make place-earth-topo
	make place-earth-grav
	make place-earth-mag
	make place-earth-mask

# Uploads all Earth age datasets
place-earth-age:
	scripts/place_candidate.sh earth_age

# Uploads all Earth image datasets
place-earth-images:
	make place-earth-day
	make place-earth-night

place-earth-day:
	scripts/place_candidate.sh earth_day

place-earth-night:
	scripts/place_candidate.sh earth_night

# Uploads all Earth gravity/geodesy datasets
place-earth-grav:
	make place-earth-edefl
	make place-earth-faa
	make place-earth-faaerror
	make place-earth-geoid
	make place-earth-ndefl
	make place-earth-vgg

# Uploads all Earth magnetics datasets
place-earth-mag:
	make place-earth-emag
	make place-earth-emag4km
	make place-earth-wdmam

# Uploads all Earth relief datasets
place-earth-topo:
	make place-earth-gebco
	make place-earth-gebcosi
	make place-earth-relief
	make place-earth-synbath

place-earth-edefl:
		scripts/place_candidate.sh earth_edefl

place-earth-emag:
		scripts/place_candidate.sh earth_mag

place-earth-emag4km:
		scripts/place_candidate.sh earth_mag4km

place-earth-faa:
		scripts/place_candidate.sh earth_faa

place-earth-faaerror:
		scripts/place_candidate.sh earth_faaerror

place-earth-geoid:
		scripts/place_candidate.sh earth_geoid

place-earth-gebco:
		scripts/place_candidate.sh earth_gebco

place-earth-gebcosi:
		scripts/place_candidate.sh earth_gebcosi

place-earth-mask:
		scripts/place_candidate.sh earth_mask

place-earth-ndefl:
		scripts/place_candidate.sh earth_ndefl

place-earth-relief:
		scripts/place_candidate.sh earth_relief

place-earth-synbath:
		scripts/place_candidate.sh earth_synbath

place-earth-vgg:
		scripts/place_candidate.sh earth_vgg

place-earth-wdmam:
		scripts/place_candidate.sh earth_wdmam

# Upload planetary data to candidate server

place-planets:
	make place-mars-relief
	make place-mercury-relief
	make place-moon-relief
	make place-pluto-relief
	make place-venus-relief

place-mars-relief:
		scripts/place_candidate.sh mars_relief

place-mercury-relief:
		scripts/place_candidate.sh mercury_relief

place-moon-relief:
		scripts/place_candidate.sh moon_relief

place-pluto-relief:
		scripts/place_candidate.sh pluto_relief

place-venus-relief:
		scripts/place_candidate.sh venus_relief
