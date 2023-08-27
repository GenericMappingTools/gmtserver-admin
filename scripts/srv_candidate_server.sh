#!/bin/bash
# Determine all the datasets on the candidate server,
# then find all the planet_dataset_server.txt snippets
# and cat into a final gmt_data_server.txt for this server.

# 2. Set name of the candidate server, its directory, and URL
INFO_DIR=../gmtserver-admin/information
CANDIDATE=candidate
CANDIDATE_DIR=/export/gmtserver/gmt/${CANDIDATE}
CANDIDATE_SERVER=${CANDIDATE}.generic-mapping-tools.org
CANDIDATE_SERVER_DIR=${CANDIDATE_SERVER}:${CANDIDATE_DIR}

GUNK=_pre
# Create the bash script for the candidate server to execute
cat << EOF > /tmp/candidate.sh
#!/usr/bin/env bash
#
# 1. cd to candidate server
cd ${CANDIDATE_DIR}

# 2. Backup last server file, if any
if [ -f gmt_data_server.txt ]; then
	mv gmt_data_server.txt gmt_data_server.txt.prev
fi

# 3. Start new info file with the fixed header server section
cp -f ${INFO_DIR}/gmt_data_server_header.txt /tmp/gmt_data_server.txt

# 4. Make a list of all server snippets under server
find server -name '*_*_server.txt' > /tmp/s.lis
while read file; do
	cat \${file} >> /tmp/gmt_data_server.txt
done < /tmp/s.lis

# 5. Count the number of data files or directory entries and start gmt_data_server.txt:
grep -v '^#' /tmp/gmt_data_server.txt | wc -l | awk '{print $1}' > ${CANDIDATE_DIR}/gmt_data_server${GUNK}.txt

# 6. Append all snippets once the total was written:
cat /tmp/gmt_data_server.txt >> ${CANDIDATE_DIR}/gmt_data_server${GUNK}.txt

# 7. Cleanup
rm -rf /tmp/gmt_data_server.txt /tmp/candidate.sh
EOF

# Set execute permissions and place on server /tmp
chmod +x /tmp/candidate.sh
scp /tmp/candidate.sh ${CANDIDATE_SERVER}:/tmp
ssh ${CANDIDATE_SERVER} "/tmp/candidate.sh"
