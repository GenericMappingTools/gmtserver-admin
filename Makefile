#	Makefile for gmtserver-admin
#
#
#	Author:	Paul Wessel, SOEST, U. of Hawaii
#
#	Update Date:	15-JAN-2022
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
#!server-info        : Make the gmt_data_server.txt file
#!

server-info:
		date "+%Y-%m-%d" | awk '{printf "s/THEDATE/%s/g\n", $$1}' > /tmp/sed.txt
		cat information/earth_*_server.txt | grep -v '^#' | wc -l | awk '{printf "%d\n", $$1}' > information/gmt_data_server.txt
		sed -f /tmp/sed.txt < information/gmt_data_server_header.txt >> information/gmt_data_server.txt
		cat information/earth_*_server.txt >> information/gmt_data_server.txt

earth-topo:
		make earth-relief
		make earth-synbath
		make earth-gebco
		make earth-gebcosi
		make earth-faa
		make earth-vgg

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
