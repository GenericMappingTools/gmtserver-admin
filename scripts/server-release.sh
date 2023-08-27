#!/usr/bin/env bash
#
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

# Sync all files from candidate to server [UNTESTED]
echo "rsync -alz --delete ${CANDIDATE_DIR} ${SERVER_DIR}"
