#!/bin/sh
# Run git pull on gmtserver and determine if any file was updated.
# If so, run the update_file_hash.sh script as well
# P. Wessel, Sept. 26. 2019

# Change directory to top dir of working directory
cd /export/gmtserver/gmt/data/gmtserver-admin
# Check changes and update file hash
git fetch origin master
count=`git rev-list HEAD..origin/master --count`
if [ "$count" -ne "0" ]; then
    git pull origin master
    bash update_file_hash.sh
fi
