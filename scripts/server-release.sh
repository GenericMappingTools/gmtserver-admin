#!/usr/bin/env bash
#
# DANGEROUS script (not tested yet) that synchronizes the files
# in the candidate directory over to the server oceania. It
# also copies over gmt_data_server.txt.

TOP_DIR=/export/gmtserver/gmt		# The gmt account home dir

CANDIDATE_DIR=${TOP_DIR}/candidate	# Place with updated files
SERVER_DIR=${TOP_DIR}/data			# Public oceania server dir

# 1. Check we are on the right computer!
SERVER=$(uname -n)
if [ ! "${SERVER}" = "gmtserver" ]; then
	cat <<- EOF  >&2
	server-release.sh: You must be logged onto the gmtserver, not ${SERVER} to make this target
	EOF
	exit 1
fi

# Here we are logged onto the server and placed ourselves in the candidate server dir

# Sync all data files from candidate to server [UNTESTED]
echo "rsync -al ${CANDIDATE_DIR} ${SERVER_DIR}"
# Update the server table on oceania
cp -f ${CANDIDATE_DIR}/gmt_data_server.txt ${SERVER_DIR}
