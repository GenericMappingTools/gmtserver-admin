#!/bin/sh
# Run git pull on gmtserver and determine if any file was updated.
# If so, run the update_file_hash.sh script as well
# P. Wessel, Sept. 26. 2019

# 1. Change directory to top dir of working directory
cd /export/gmtserver/gmt/data/gmtserver-admin
# Check changes and update file hash
# 2. Make sure we are on the master branch
git fetch origin master
# 3. Do a dry run to determine if files will be updated
count=`git rev-list master ^origin/master --count`
if [ "$count" -ne "0" ]; then	# 4. There will be updates
	# 4a Update the local repo
	git pull origin master
	# 4a Update the hash table
	bash update_file_hash.sh
fi
