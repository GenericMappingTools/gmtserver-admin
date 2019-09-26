# gmtserver-admin

Cache data and scripts for managing the GMT data server

The working directory on the gmtserver is updated every one hour
from crontab running under account pwessel with the crontab entry

0 * * * *      /export/gmtserver/gmt/data/gmtserver-admin/git_update.sh > /export/gmtserver/gmt/LOGS/git_update.cron.log 2>&1

Core developers can add, modify or remove cache files form their working copy
of the gmtserver-admin repo, and after merging the server will automatically
update its working copy, and if there are changes the gmt_hash_server.txt file
will be rebuilt.
