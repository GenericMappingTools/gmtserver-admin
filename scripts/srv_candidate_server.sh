#!/bin/bash
# Determine all the datasets of the candidate server,
# then find all the planet_dataset_server.txt snippets
# and cat into a final gmt_data_server.txt for this server.

# 2. Set name of the candidate server, its directory, and URL
CANDIDATE=candidate
CANDIDATE_DIR=/export/gmtserver/gmt/${CANDIDATE}/server
CANDIDATE_SERVER=${CANDIDATE}.generic-mapping-tools.org:${CANDIDATE_DIR}

# testing locally first
CANDIDATE_DIR=/Users/pwessel/UH/RESEARCH/CVSPROJECTS/GMTdev/gmtserver-admin/staging
cd ${CANDIDATE_DIR}

# Write/save last file
if [ -f gmt_data_server.txt ]; then
	mv gmt_data_server.txt gmt_data_server.txt.prev
fi

# Start new file with the header server section
cp -f ../information/gmt_data_server_header.txt /tmp/gmt_data_server.txt

# List of all server snippets
find . -name '*_*_server.txt' > /tmp/s.lis
while read file; do
	cat ${file} >> /tmp/gmt_data_server.txt
done < /tmp/s.lis

# Count them:
grep -v '^#' /tmp/gmt_data_server.txt | wc -l | awk '{print $1}' > ${CANDIDATE_DIR}/gmt_data_server.txt
cat /tmp/gmt_data_server.txt >> ${CANDIDATE_DIR}/gmt_data_server.txt
