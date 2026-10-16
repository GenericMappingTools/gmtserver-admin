#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE_SERVER=${CANDIDATE_SERVER:-candidate}
GMT_USERDIR=${GMT_USERDIR:-"${REPO_DIR}/gmt_candidate_test"}
VALIDATION_DIR=${VALIDATION_DIR:-"${GMT_USERDIR}/earth_gebco/validation"}
WESN=${WESN:--156/-154/18/20}
DATASETS=(
	earth_gebco_01m_g
	earth_gebco_01m_p
	earth_gebco_30s_g
	earth_gebco_30s_p
)

mkdir -p "${VALIDATION_DIR}"
export GMT_USERDIR

echo "validate_earth_gebco_candidate.sh: Writing artifacts to ${VALIDATION_DIR}"

for dataset in "${DATASETS[@]}"; do
	echo "validate_earth_gebco_candidate.sh: Checking ${dataset} on ${CANDIDATE_SERVER}"
	gridded_source="@${dataset}"
	candidate_info="${VALIDATION_DIR}/${dataset}.candidate.grdinfo.txt"
	candidate_cut="${VALIDATION_DIR}/${dataset}.candidate.cut.nc"
	candidate_cut_info="${VALIDATION_DIR}/${dataset}.candidate.cut.grdinfo.txt"

	gmt grdinfo "${gridded_source}" --GMT_DATA_SERVER="${CANDIDATE_SERVER}" -Vi > "${candidate_info}"
	gmt grdcut "${gridded_source}" -R"${WESN}" -G"${candidate_cut}" --GMT_DATA_SERVER="${CANDIDATE_SERVER}" -Vi
	gmt grdinfo "${candidate_cut}" > "${candidate_cut_info}"
done

find "${VALIDATION_DIR}" -maxdepth 1 -type f | sort > "${VALIDATION_DIR}/manifest.txt"

echo "validate_earth_gebco_candidate.sh: Validation artifacts are ready"