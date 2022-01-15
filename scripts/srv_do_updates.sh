#!/bin/bash
# srv_do_updates.sh
#
# Called by srv_git_update.sh when there are changes in the repo.
# Can also be called stand-alone to initialize hash and data server tables
# when checking out the repo for the first time.
#
# P. Wessel, March. 18, 2021

# 1a. Change directory to top dir of working directory
cd /export/gmtserver/gmt/gmtserver-admin
# 1b Update the local repo
git pull -v origin master
# 1c Do rsync of files than may have changed to data/cache
rsync -a --delete cache ../data
# 1d Update the SHA256 hash table
bash scripts/srv_update_sha256.sh
# 1e Duplicate to the Md5 file for backwardness
cp -f ../data/gmt_hash_server.txt ../data/gmt_md5_server.txt
# 1f Place a copy of the data information table in the data dir with leading record indicating number of item
cp -f information/gmt_data_server.txt  ../data
