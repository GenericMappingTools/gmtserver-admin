#!/bin/bash
# srv_git_update.sh
#
# Run git pull on gmtserver and determine if any file was updated.
# If so, run the srv_update_sha256.sh script as well
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
	# 5a Update the local repo
	git pull -v origin master
	# 5b Do rsync of files than may have changed to data/cache
	rsync -a --delete cache ../data
	# 5c Update the SHA256 hash table
	bash scripts/srv_update_sha256.sh
	# 5d Duplicate to the Md5 file for backwardness
	cp -f ../data/gmt_hash_server.txt ../data/gmt_md5_server.txt
	# 5e Place a copy of the data information table in the data dir
	cp -f information/gmt_data_server.txt ../data
fi

echo "End Time:" $(date)
