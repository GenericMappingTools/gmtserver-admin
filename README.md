# gmtserver-admin
Cache data and script for managing the GMT data server

The working directory on the gmtserver is updated every one hour
from crontab under pwessel with the crontab entry

0 * * * *      git -C /export/gmtserver/gmt/data/gmtserver-admin pull -q > /export/gmtserver/gmt/LOGS/git.cron.log 2>&1
