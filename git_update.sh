#!/bin/sh
# Run git pull on gmtserver and determine if any file was updated.
# If so, run the update_file_hash.sh script as well
# P. Wessel, Sept. 26. 2019

# Change directory to top dir of working directory
cd /export/gmtserver/gmt/data/gmtserver-admin
# Fun git pull and save the output
git pull > /tmp/status
if [ `grep -c "Already up-to-date" /tmp/status` -eq 0 ]; then	# Some files were refreshed, update hash
	update_file_hash.sh
fi
