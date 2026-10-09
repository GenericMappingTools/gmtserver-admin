#!/bin/bash -e
# Sync verified candidate data from the AWS dev bucket into the AWS stage bucket.
# This is the AWS-native equivalent of a stage/public release step.
#
# Default behaviour:
#   source: s3://gmt-s3-data-dev-us-east-2/gmt-data/candidate/server
#   target: s3://gmt-s3-data-stage-us-east-2/gmt-data/stage/server
#
# This script is intentionally conservative: it does not touch the stage bucket
# unless you explicitly confirm the copy.  The stage bucket is expected to be the
# verified/pre-production publication area that mirrors production.

set -u

SOURCE_BUCKET=${GMT_S3_SOURCE_BUCKET:-gmt-s3-data-dev-us-east-2}
SOURCE_PREFIX=${GMT_S3_SOURCE_PREFIX:-gmt-data/candidate/server}
TARGET_BUCKET=${GMT_S3_TARGET_BUCKET:-gmt-s3-data-stage-us-east-2}
TARGET_PREFIX=${GMT_S3_TARGET_PREFIX:-gmt-data/stage/server}
AWS_REGION=${AWS_REGION:-us-east-2}

if [ -n "${AWS_PROFILE:-}" ]; then
	AWS_PROFILE_FLAG=(--profile "${AWS_PROFILE}")
else
	AWS_PROFILE_FLAG=()
fi

AWS_REGION_FLAG=(--region "${AWS_REGION}")

SOURCE_URI="s3://${SOURCE_BUCKET}/${SOURCE_PREFIX}"
TARGET_URI="s3://${TARGET_BUCKET}/${TARGET_PREFIX}"

if [ ! -n "${SOURCE_BUCKET}" ] || [ ! -n "${TARGET_BUCKET}" ]; then
	echo "stage-release_aws.sh: SOURCE and TARGET buckets must be configured" >&2
	exit 1
fi

# Optionally allow a single dataset to be promoted instead of the whole candidate tree.
DATASET="${1:-}"
if [ -n "${DATASET}" ]; then
	SOURCE_URI="s3://${SOURCE_BUCKET}/${SOURCE_PREFIX}/${DATASET}"
	TARGET_URI="s3://${TARGET_BUCKET}/${TARGET_PREFIX}/${DATASET}"
	PROMOTE_MESSAGE="dataset ${DATASET}"
else
	PROMOTE_MESSAGE="all verified candidate datasets"
fi

echo -n "Are you sure you want to promote ${PROMOTE_MESSAGE} from ${SOURCE_BUCKET} to ${TARGET_BUCKET} [y/N]? : "
read answer
if [ "X${answer}" == "X" ]; then
	answer=N
fi
if [ "${answer}" != "Y" ] && [ "${answer}" != "y" ]; then
	echo "stage-release_aws.sh: Aborting"
	exit 0
fi

aws s3 sync "${SOURCE_URI}" "${TARGET_URI}" \
	"${AWS_PROFILE_FLAG[@]}" \
	"${AWS_REGION_FLAG[@]}" \
	--delete \
	--only-show-errors

aws s3 ls "${TARGET_URI}" \
	"${AWS_PROFILE_FLAG[@]}" \
	"${AWS_REGION_FLAG[@]}" \
	--recursive \
	--summarize | head

echo "stage-release_aws.sh: Verified candidate data copied to ${TARGET_URI}"
