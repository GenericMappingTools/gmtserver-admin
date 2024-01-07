#!/usr/bin/env bash
# server-release.sh
#
# Script that copies datasets from the candidate directory over to the 
# server oceania's directory. If no data set is specified then we copy
# all data sets from candidate to server.
# Optional argument is name of a single dataset [Default acts on all]

# A. Set various fixed parameters
CANDIDATE=candidate				# Directory with candidate data
SERVER=data						# Directory with public (oceania) data
TOP_DIR=/export/gmtserver/gmt	# The top dir of the gmt account
#---------------------------------------------------------------------
CANDIDATE_DIR=${TOP_DIR}/${CANDIDATE}/server			# Candidate planets are under here
SERVER_DIR=${TOP_DIR}/${SERVER}/server					# Public planets on oceania are under here
CANDIDATE_SERVER=${CANDIDATE}.generic-mapping-tools.org	# URL of the candidate server
INFO_DIR=${TOP_DIR}/gmtserver-admin/information			# Directory with gmt_data_server header chunk

# Require a yes to do the replacing on the candidate
echo -n "server-release.sh: Are you sure you want to update the oceania server via rsync from the ${CANDIDATE} server [y/N]? : "
read answer
if [ "X${answer}" == "X" ]; then	# Default of no answer is N for no
		answer=N
fi
if [ "X${answer}" == "Xn" ]; then	# Gave n for no
		answer=N
fi
if [ "${answer}" == "N" ]; then	# Default of no answer is N for no
	echo "server-release.sh: Aborting"
	exit 1
fi

# B. Determine if a single data set or everything from candidate shall be synced
echo -n "server-release.sh: Enter a specific data set (e.g., mars_relief) or hit return for all data on the candidate: "
read DATASET
if [ "X${DATASET}" = "X" ]; then
	echo "server-release.sh: Copying all data sets from candidate server to oceania"
else
	echo "server-release.sh: Copying ${DATASET} from candidate server to oceania"
	DATASET="/${DATASET}"
    PLANET=$(echo ${DATASET} | awk -F_ '{print $1}')
fi

# C. See if GMT_USER is set, else use $USER
if [ "X${GMT_USER}" = "X" ]; then
	the_user=${USER}
else
	the_user=${GMT_USER}
fi

# D. Build the script to be copied and executed on the remote server
cat << EOF > /tmp/release.sh
#!/usr/bin/env bash
# Script made by "make server-release" to be run on the gmtserver
#
# 1. Issue rsync command to transfer newer files from candidate to oceania
rsync -al ${CANDIDATE_DIR}${PLANET}${DATASET}/ ${SERVER_DIR}${PLANET}${DATASET}
# 2. Back up previous gmt_data_server.txt
if [ -f ${TOP_DIR}/${SERVER}/gmt_data_server.txt ]; then
	mv ${TOP_DIR}/${SERVER}/gmt_data_server.txt ${TOP_DIR}/${SERVER}/gmt_data_server.txt.prev
fi
# 3. Copy over the gmt_data_server.txt file from candidate
cp -f ${TOP_DIR}/${CANDIDATE}/gmt_data_server.txt ${TOP_DIR}/${SERVER}
EOF

# Set execute permissions and place on server /tmp
chmod +x /tmp/release.sh
echo server-release.sh: scp /tmp/release.sh ${the_user}@${CANDIDATE_SERVER}:/tmp
scp /tmp/release.sh ${the_user}@${CANDIDATE_SERVER}:/tmp

# Execute the script via ssh on oceania
ssh ${the_user}@${CANDIDATE_SERVER} "/tmp/release.sh"
