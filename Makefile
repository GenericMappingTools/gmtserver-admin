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
#!-------------------- MAKE HELP FOR DCW --------------------
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