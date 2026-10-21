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
#   GMT_S3_PREFIX          Data prefix under the bucket (default: gmt-data/candidate/server)
#   GMT_S3_INDEX_PREFIX    Aggregate index prefix under the bucket (default: gmt-data/candidate)
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
GMT_S3_BUCKET=${GMT_S3_BUCKET:-gmt-s3-data-stage-us-east-2}
GMT_S3_PREFIX=${GMT_S3_PREFIX:-gmt-data/candidate/server}
GMT_S3_INDEX_PREFIX=${GMT_S3_INDEX_PREFIX:-gmt-data/candidate}
AWS_REGION=${AWS_REGION:-us-east-2}
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INFO_DIR="${REPO_DIR}/information"

# Keep the data under the server tree, but keep the aggregate catalog at the candidate root.
TARGET_S3_URI="s3://${GMT_S3_BUCKET}/${GMT_S3_PREFIX}/${PLANET}/${DATASET}"
TARGET_S3_URI_PARENT="s3://${GMT_S3_BUCKET}/${GMT_S3_PREFIX}/${PLANET}"
INDEX_S3_URI="s3://${GMT_S3_BUCKET}/${GMT_S3_INDEX_PREFIX}/gmt_data_server.txt"

rebuild_candidate_index() {
	# GMT expects a single aggregate gmt_data_server.txt at the candidate root.
	# Each dataset contributes one *_server.txt snippet under its own folder; this
	# function gathers those snippets, concatenates them, and writes the final catalog.
	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf "${tmpdir}"' RETURN

	# The header file defines the fixed server metadata header that sits above the per-dataset blocks.
	local header_file="${INFO_DIR}/gmt_data_server_header.txt"
	if [ ! -f "${header_file}" ]; then
		echo "place_candidate_aws.sh: Missing metadata header ${header_file}" >&2
		return 1
	fi

	# Build the aggregate file in a temporary workspace, then upload it to the root candidate index.
	local key_list="${tmpdir}/keys.txt"
	local body_file="${tmpdir}/body.txt"
	local index_file="${tmpdir}/gmt_data_server.txt"

	# Find all dataset snippets under the server tree, but exclude the aggregate index itself.
	aws s3api list-objects-v2 \
		--bucket "${GMT_S3_BUCKET}" \
		--prefix "${GMT_S3_PREFIX}/" \
		--query "Contents[?contains(Key, '_server.txt') && !contains(Key, 'gmt_data_server.txt')].[Key]" \
		--output text \
		"${AWS_PROFILE_FLAG[@]}" \
		"${AWS_REGION_FLAG[@]}" \
		> "${key_list}"

	if [ ! -s "${key_list}" ]; then
		echo "place_candidate_aws.sh: No *_server.txt snippets found under ${GMT_S3_PREFIX}; leaving current candidate index unchanged"
		return 0
	fi

	: > "${body_file}"
	while IFS= read -r s3_key; do
		[ -n "${s3_key}" ] || continue
		local tmp_snippet="${tmpdir}/$(basename "${s3_key}")"
		aws s3 cp "s3://${GMT_S3_BUCKET}/${s3_key}" "${tmp_snippet}" \
			"${AWS_PROFILE_FLAG[@]}" \
			"${AWS_REGION_FLAG[@]}" \
			--only-show-errors
		cat "${tmp_snippet}" >> "${body_file}"
	done < "${key_list}"

	local count
	count=$(grep -v '^#' "${body_file}" | wc -l | awk '{print $1}')
	{
		printf '%s\n' "${count}"
		cat "${header_file}"
		cat "${body_file}"
	} > "${index_file}"

	sed "s/THEDATE/$(date '+%Y-%m-%d')/g" -i "${index_file}"
	aws s3 cp "${index_file}" "${INDEX_S3_URI}" \
		"${AWS_PROFILE_FLAG[@]}" \
		"${AWS_REGION_FLAG[@]}" \
		--only-show-errors

	echo "place_candidate_aws.sh: Rebuilt candidate metadata index at ${INDEX_S3_URI}"
}

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

# Rebuild the aggregate candidate metadata index so multiple datasets can coexist on
# the candidate server at the same time and GMT can discover all entries.
rebuild_candidate_index

# Ensure the candidate parent path exists; aws sync creates the needed prefix.
# Final check: list the target to confirm the dataset landed in the expected place.
# Avoid piping to head so the AWS CLI is not cut off mid-write.
aws s3 ls "${TARGET_S3_URI_PARENT}" \
	"${AWS_PROFILE_FLAG[@]}" \
	"${AWS_REGION_FLAG[@]}" \
	--recursive \
	--summarize

echo "place_candidate_aws.sh: Candidate copy completed for ${PLANET}/${DATASET} at ${TARGET_S3_URI}"
