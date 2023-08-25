#!/bin/bash -e
# Place a complete dataset for given planet on the candidate server space
CANDIDATE=test	# Name of the candidate server
CANDIDATE_DIR=/export/gmtserver/gmt/${CANDIDATE}/server
CANDIDATE_SERVER=${CANDIDATE}.generic-mapping-tools.org:${CANDIDATE_DIR}

PRE=echo
#
if [ $# -eq 0 ]; then
	echo "place_candidate.sh: Usage: place_candidate.sh <dataset>"
	echo "	E.g.: place_candidate.sh earth_synbath"
	exit 1
fi

# Get the planet and dataset names
dataset=$1
planet=$(echo ${dataset} | awk -F_ '{print $1}')

# Check if this exists in staging dir
if [ ! -d staging/${planet}/${dataset} ]; then
	echo "place_candidate.sh: staging/${planet}/${dataset} not found"
	exit 1
fi
# OK, good to go but require a yes to do it
echo -n "Are you sure you want to replace ${planet}/${dataset} on the ${CANDIDATE} server [y/N]? : "
read answer
if [ "X${answer}" == "X" ]; then
		answer=N
elif [ "${answer}" == "y" ]; then
		answer=Y
fi
echo "You answered $answer"
#exit
if [ $answer = "Y" ]; then
	echo "Deleting ${planet}/${dataset} on the ${CANDIDATE} server and copying over the new version"
	ssh ${CANDIDATE}.generic-mapping-tools.org "ls -l ${CANDIDATE_DIR}/${planet}/${dataset}"
	${PRE} ssh ${CANDIDATE}.generic-mapping-tools.org "rm -rf ${CANDIDATE_DIR}/${planet}/${dataset}"
	${PRE} scp -r staging/${planet}/${dataset} ${CANDIDATE_SERVER}
fi
