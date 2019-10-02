# GMT Data Server Administration

Cache data and scripts for managing the GMT data server

Current master server is: **gmtserver.soest.hawaii.edu**

Master data server URL: **oceania.generic-mapping-tools.org**

To clone this repo you can run

git clone https://github.com/GenericMappingTools/gmtserver-admin

## Cache files

GMT Core developers can add, modify or remove cache files from their working copy
of the gmtserver-admin repo, and after merging the gmtserver will automatically
update its working copy via the crontab script, and if there are changes the key
gmt_hash_server.txt file will be rebuilt as needed.

## Global grids

For now, the earth_relief_xxy.grd files are maintained and updated manually.
Changes to these need to be followed by a manual run of update_file_hash.sh.

## Crontab

The working directory on the gmtserver is updated once an hour via a
crontab script running under local account pwessel with this crontab entry:

```
0 * * * *      /export/gmtserver/gmt/data/gmtserver-admin/git_update.sh > /export/gmtserver/gmt/LOGS/git_update.cron.log 2>&1
```
