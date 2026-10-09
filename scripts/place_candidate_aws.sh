#!/bin/bash -eux
# Place a complete dataset for a given planet into the candidate area in the
# AWS S3 dev bucket, overwriting any earlier copy of the same dataset.
#
# This is the AWS-native equivalent of place_candidate.sh.  It avoids ssh/scp
# and instead uses the AWS CLI to copy the full staging tree into the candidate
# dataset area on the dev bucket.  This is more robust for large data sets than
# writing through the FUSE mount.
#
# Intended workflow:
#   1. Build the dataset in staging/<planet>/<dataset>
#   2. Run: scripts/place_candidate_aws.sh <dataset>
#   3. Validate from the dev bucket candidate area
#   4. When verified, promote to the stage/production workflow later
#
# Example:
#   scripts/place_candidate_aws.sh earth_gebco
#
# Environment:
#   GMT_S3_BUCKET          Bucket name to use (default: gmt-s3-data-dev-us-east-2)
#   GMT_S3_PREFIX          Prefix under the bucket (default: gmt-data/candidate/server)
#   AWS_REGION             AWS region used by the CLI (default: us-east-2)
#   AWS_PROFILE            Optional AWS profile to use
#

if [ $# -ne 1 ]; then
	cat <<- EOF >&2
	place_candidate_aws.sh: Place a candidate data set into the dev S3 bucket

	Usage: place_candidate_aws.sh <dataset>
		Example: place_candidate_aws.sh earth_gebco
	EOF
	exit 1
fi

set -u

DATASET=$1
PLANET=$(echo "${DATASET}" | awk -F_ '{print $1}')

# Use the dev bucket by default, but allow override for testing or future variants.
GMT_S3_BUCKET=${GMT_S3_BUCKET:-gmt-s3-data-dev-us-east-2}
GMT_S3_PREFIX=${GMT_S3_PREFIX:-gmt-data/candidate/server}
AWS_REGION=${AWS_REGION:-us-east-2}

# Keep the S3 path compatible with the repo's "candidate/server/<planet>/<dataset>" layout.
TARGET_S3_URI="s3://${GMT_S3_BUCKET}/${GMT_S3_PREFIX}/${PLANET}/${DATASET}"
TARGET_S3_URI_PARENT="s3://${GMT_S3_BUCKET}/${GMT_S3_PREFIX}/${PLANET}"

# Require a local staging tree before doing the copy.
if [ ! -d staging ]; then
	echo "place_candidate_aws.sh: Must be run from the top directory that contains staging" >&2
	exit 1
fi

if [ ! -d "staging/${PLANET}/${DATASET}" ]; then
	echo "place_candidate_aws.sh: staging/${PLANET}/${DATASET} not found" >&2
	exit 1
fi

# The candidate directory is in the dev bucket, not on a remote SSH host.
# Keep the target layout consistent with the repo's candidate server structure.
if [ -n "${AWS_PROFILE:-}" ]; then
	AWS_PROFILE_FLAG=(--profile "${AWS_PROFILE}")
else
	AWS_PROFILE_FLAG=()
fi

# Set a default region if not already configured, but do not override a user-specified AWS config.
if [ -n "${AWS_REGION:-}" ]; then
	AWS_REGION_FLAG=(--region "${AWS_REGION}")
else
	AWS_REGION_FLAG=()
fi

# Non-interactive mode: if stdin is not a tty or as a nohup process, default to yes.
if [ -t 0 ]; then
	echo -n "Are you sure you want to replace ${PLANET}/${DATASET} in the ${GMT_S3_BUCKET} candidate area [y/N]? : "
	read answer
	if [ "X${answer}" == "X" ]; then
		answer=N
	fi
else
	answer=Y
fi

if [ "${answer}" != "Y" ] && [ "${answer}" != "y" ]; then
	echo "place_candidate_aws.sh: Aborting"
	exit 0
fi

# Remove any existing copy of this candidate dataset before syncing the new one.
# This mirrors the old remote behaviour where rm -rf was used on the candidate target.
aws s3 rm "${TARGET_S3_URI}" \
	"${AWS_PROFILE_FLAG[@]}" \
	"${AWS_REGION_FLAG[@]}" \
	--recursive \
	--only-show-errors || true

# Sync the built staging tree into the candidate area on S3.
# --delete ensures the target reflects the staging tree exactly.
aws s3 sync "staging/${PLANET}/${DATASET}" "${TARGET_S3_URI}" \
	"${AWS_PROFILE_FLAG[@]}" \
	"${AWS_REGION_FLAG[@]}" \
	--delete \
	--only-show-errors

# Ensure the candidate parent path exists; aws sync creates the needed prefix.
# Final check: list the target to confirm the dataset landed in the expected place.
# Avoid piping to head so the AWS CLI is not cut off mid-write.
aws s3 ls "${TARGET_S3_URI_PARENT}" \
	"${AWS_PROFILE_FLAG[@]}" \
	"${AWS_REGION_FLAG[@]}" \
	--recursive \
	--summarize

echo "place_candidate_aws.sh: Candidate copy completed for ${PLANET}/${DATASET} at ${TARGET_S3_URI}"
