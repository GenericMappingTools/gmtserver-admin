#!/bin/bash
# srv_git_update.sh
#
# Runs git pull on gmtserver and determines if any file was updated.
# If so, runs the srv_do_updates.sh script as well
# P. Wessel, Oct. 3, 2019
# Revised PW, May 22, 2020

echo "Start Time:" $(date)

# 1. Change directory to top dir of working directory
cd /export/gmtserver/gmt/gmtserver-admin
# Check changes and update file hash
# 2. Make sure we are on the master branch
git checkout master
# 3. Fetch from the remote repository
git fetch -v origin
# 4. Check if the local master branch is behind the remote one
count=`git rev-list master...origin/master --count`
if [ "$count" -ne "0" ]; then	# 5. There will be updates
	bash scripts/srv_do_updates.sh
fi

echo "End Time:" $(date)
