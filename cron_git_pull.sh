#!/bin/sh
# P. Wessel, Sept. 25, 2019
# Update the working distribution on the gmtserver
# This script is installed on pwessel crontab on the gmtserver
# and set to run every 1 hour via this entry
# 0 * * * *      /export/gmtserver/gmt/data/gmtserver-admin/cron_git_pull.sh > /export/gmtserver/gmt/data/LOGS/git.cron.log 2>&1
#
# First cd to the top of the gmtserver-admin directory
cd /export/gmtserver/gmt/data/gmtserver-admin
# Refresh the local copy
git pull
