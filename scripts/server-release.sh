#!/usr/bin/env bash
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
# 1. Issue rsync command
rsync -al ${CANDIDATE_DIR}${PLANET}${DATASET} ${SERVER_DIR}${PLANET}${DATASET}
# 2. Rebuild the gmt_data_server.txt file
# 2a. Make sed script that changes THEDATE to today's dat
date "+%Y-%m-%d" | awk '{printf "s/THEDATE/%s/g\n", $$1}' > /tmp/sed.txt
# 2b. Find all the dataset server files
find ${SERVER_DIR} -name '*_*_server.txt' > /tmp/datasets.lis
# 2c. Count the number of data files or directory entries and start first line of /tmp/gmt_data_server.txt:
cat \$(cat /tmp/datasets.lis) | grep -v '^#' | wc -l | awk '{printf "%d\n", $1}' > /tmp/gmt_data_server.txt
# 2d. Append the header information section after piping via sed to get the date
cat ${TOP_DIR}/gmt_data_server_header.txt | sed -f /tmp/sed.txt >> /tmp/gmt_data_server.txt
# 2e. Append all the data set files to the same file
cat \$(cat /tmp/datasets.lis) >> /tmp/gmt_data_server.txt
# 2f. Copy the old server file to the backup file
cp -f ${TOP_DIR}/${SERVER}/gmt_data_server.txt ${TOP_DIR}/${SERVER}/gmt_data_server_previous.txt
# 2g. Place the new server file
cp -f /tmp/gmt_data_server.txt ${TOP_DIR}/${SERVER}
# 3. Clean up
rm -f tmp/sed.txt /tmp/gmt_data_server.txt /tmp/release.sh
EOF

# Set execute permissions and place on server /tmp
chmod +x /tmp/release.sh
echo server-release.sh: scp /tmp/release.sh ${the_user}@${CANDIDATE_SERVER}:/tmp
scp /tmp/release.sh ${the_user}@${CANDIDATE_SERVER}:/tmp

# Execute the script via ssh on oceania
echo server-release.sh: ssh ${the_user}@${CANDIDATE_SERVER} "/tmp/release.sh"
