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
# 1e Duplicate to the MD5 file for backwardness
cp -f ../data/gmt_hash_server.txt ../data/gmt_md5_server.txt
# 1f Also do rsync of files than may have changed to {candidate,static,test}, including cache dir
for ghost_server in candidate static test; do
	rsync -a --delete cache ../${ghost_server}
	cp -f ../data/gmt_hash_server.txt ../${ghost_server}
done
