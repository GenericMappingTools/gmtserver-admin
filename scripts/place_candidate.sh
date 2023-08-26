#!/bin/bash -e
# Place a complete dataset for given planet on the candidate server space.
# This script assumes that srv_downloader_grid.sh and srv_tiler.sh have
# been run on an update data set.  To try it out from the cloud service
# we must replace what is in the candidate server directory with this new
# version. For instance, if earth_relief has been updated and the new version
# lives in your staging directory (under earth/earth_relief), you refresh the
# version on the candidate server by running it via the make command:
#
#	make place-relief
#
# Similar processes for other data by replacing "-relief" with "-faa", etc.
# The new directory will also contain the relevant data_server information file
# secrtion for this data set, e.g., earth/earth_relief/earth_relief_server.txt.
# These are combined into an update server file.

# 1. Give usage message if not getting one argument
if [ $# -ne 1 ]; then
	cat <<- EOF  >&2
	place_candidate.sh: Place a candidate data set on the upcoming release server

	Usage: place_candidate.sh <dataset>
		E.g.: place_candidate.sh earth_synbath
	EOF
	exit 1
fi

# 2. Set name of the candidate server, its directory, and URL
CANDIDATE=candidate
CANDIDATE_DIR=/export/gmtserver/gmt/${CANDIDATE}/server
CANDIDATE_SERVER=${CANDIDATE}.generic-mapping-tools.org:${CANDIDATE_DIR}

# 3. Make sure we are in the top directory with staging beneath us
if [ ! -d staging ]; then	# Not run from top dir
	echo "place_candidate.sh: Must be run from the top directory that contains staging"
	exit 1
fi

# 4. Get the planet and dataset names in separate variables
dataset=$1	# Full name of data set, e.g., venus_relief
planet=$(echo ${dataset} | awk -F_ '{print $1}')		# This is either earth, venus, etc

# 5. Check that this dataset exists in staging dir
if [ ! -d staging/${planet}/${dataset} ]; then
	echo "place_candidate.sh: staging/${planet}/${dataset} not found"
	exit 1
fi
# 6. Good to go but require a yes to do the replacing on the server
echo -n "Are you sure you want to replace ${planet}/${dataset} on the ${CANDIDATE} server [y/N]? : "
read answer
if [ "X${answer}" == "X" ]; then	# Default of no answer is N for no
		answer=N
fi
# 7. Do the work if got an affirmative answer
if [ $answer = "Y" ] || [ "${answer}" == "y" ]; then
	echo "Deleting previous ${planet}/${dataset} on the ${CANDIDATE} server"
	ssh ${CANDIDATE}.generic-mapping-tools.org "rm -rf ${CANDIDATE_DIR}/${planet}/${dataset}"
	echo "Copying over the new ${planet}/${dataset} from staging to the ${CANDIDATE} server"
	scp -r staging/${planet}/${dataset} ${CANDIDATE_SERVER}/${planet}
	echo "Setting permissions on ${planet}/${dataset}"
	ssh ${CANDIDATE}.generic-mapping-tools.org "chmod -R g+rw,o+r ${CANDIDATE_DIR}/${planet}/${dataset}"
	echo "Refreshing of ${planet}/${dataset} completed"
fi
