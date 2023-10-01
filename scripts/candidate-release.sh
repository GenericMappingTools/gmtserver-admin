#!/usr/bin/env bash
#
# Find all data subdirs in staging and place them on candidate server

# 1. Get list all the subdirs in staging that has a *server.txt snippet
find staging -name '*_*_server.txt' | grep -v gmt_data | awk -F'/' '{print $3}' > /tmp/datasets.lis

# 2. Loop over these data sets and place them
while read dataset; do
	echo "Placing ${dataset} on candidate server"
	scripts/place_candidate.sh ${dataset}
done < /tmp/datasets.lis

# 3. Clean up
rm -rf /tmp/datasets.lis
