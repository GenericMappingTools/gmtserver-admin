#!/bin/bash -e
# Find all data subdirs in staging and place them into the dev S3 candidate bucket.
# This is the AWS-native equivalent of candidate-release.sh.

set -u

if [ ! -d staging ]; then
	echo "candidate-release_aws.sh: Must be run from the top directory that contains staging" >&2
	exit 1
fi

find staging -name '*_*_server.txt' | grep -v gmt_data | awk -F'/' '{print $3}' > /tmp/datasets.lis

while read -r dataset; do
	if [ -n "${dataset}" ]; then
		echo "Placing ${dataset} on the AWS candidate bucket"
		scripts/place_candidate_aws.sh "${dataset}"
	fi
done < /tmp/datasets.lis

rm -rf /tmp/datasets.lis
