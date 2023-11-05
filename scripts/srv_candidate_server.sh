#!/bin/bash
# srv_candidate_server.sh
#
# Determine all the datasets on the candidate server,
# then find all the planet_dataset_server.txt snippets
# and cat into a final gmt_data_server.txt for this server.
# Higher resolution data only accessible via GMT6.5 or later
# are commented out with "#% " prefix and not counted in the
# first record listing the total number of data sets.
CANDIDATE=candidate

# Require a yes to do the replacing on the candidate
echo -n "srv_candidate_server.sh: Are you sure you want to rebuild gmt_data_server.txt based on data on the ${CANDIDATE} server [y/N]? : "
read answer
if [ "X${answer}" == "X" ]; then	# Default of no answer is N for no
		answer=N
fi
if [ "X${answer}" == "Xn" ]; then	# Gave n for no
		answer=N
fi
if [ "${answer}" == "N" ]; then	# Default of no answer is N for no
	echo "srv_candidate_server.sh: Aborting"
	exit 1
fi

# A. Set name of the candidate server, its directory, and URL
INFO_DIR=../gmtserver-admin/information
CANDIDATE_DIR=/export/gmtserver/gmt/${CANDIDATE}
CANDIDATE_SERVER=${CANDIDATE}.generic-mapping-tools.org
CANDIDATE_SERVER_DIR=${CANDIDATE_SERVER}:${CANDIDATE_DIR}

# B. If you are testing and do not want to overwrite the candidate
# server;s gmt_data_server.txt, use DEBUG to insert text in filename
DEBUG=

# C. See if GMT_USER is set, else use $USER
if [ "X${GMT_USER}" = "X" ]; then
	the_user=${USER}
else
	the_user=${GMT_USER}
fi

# D. Create the bash script for the candidate server to execute
cat << EOF > /tmp/candidate.sh
#!/usr/bin/env bash
#
# 1. cd to candidate server dir
cd ${CANDIDATE_DIR}

# 2. Backup last server file, if any
if [ -f gmt_data_server.txt ]; then
	mv gmt_data_server.txt gmt_data_server.txt.prev
fi

# 3. Start new info file with the fixed header server section
cp -f ${INFO_DIR}/gmt_data_server_header.txt /tmp/gmt_data_server.txt

# 4. Make a list of all server snippets under server
find server -name '*_*_server.txt' > /tmp/datasets.lis
while read file; do
	cat \${file} >> /tmp/gmt_data_server.txt
done < /tmp/datasets.lis

# 5. Count the number of data files or directory entries and start first line of gmt_data_server.txt/
cat \$(cat /tmp/datasets.lis) | grep -v '^#' | wc -l | awk '{printf "%d\n", \$1}' > ${CANDIDATE_DIR}/gmt_data_server${DEBUG}.txt

# 6. Append all snippets once the total was written:
cat /tmp/gmt_data_server.txt >> ${CANDIDATE_DIR}/gmt_data_server${DEBUG}.txt

# 7. Cleanup
rm -rf /tmp/gmt_data_server.txt /tmp/datasets.lis /tmp/candidate.sh
EOF

# Set execute permissions and place on server /tmp
chmod +x /tmp/candidate.sh
scp /tmp/candidate.sh ${the_user}@${CANDIDATE_SERVER}:/tmp
ssh ${the_user}@${CANDIDATE_SERVER} "/tmp/candidate.sh"
