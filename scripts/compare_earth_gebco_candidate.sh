#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

PUBLIC_SERVER=${PUBLIC_SERVER:-earthscope}
GMT_USERDIR=${GMT_USERDIR:-"${REPO_DIR}/gmt_candidate_test"}
VALIDATION_DIR=${VALIDATION_DIR:-"${GMT_USERDIR}/earth_gebco/validation"}
COMPARISON_DIR=${COMPARISON_DIR:-"${GMT_USERDIR}/earth_gebco/comparison"}
WESN=${WESN:--156/-154/18/20}
DATASETS=(
	earth_gebco_01m_g
	earth_gebco_01m_p
	earth_gebco_30s_g
	earth_gebco_30s_p
)

if [ ! -f "${VALIDATION_DIR}/earth_gebco_01m_g.candidate.cut.nc" ]; then
	echo "compare_earth_gebco_candidate.sh: Candidate artifacts not found, running validation first"
	"${SCRIPT_DIR}/validate_earth_gebco_candidate.sh"
fi

mkdir -p "${COMPARISON_DIR}"
export GMT_USERDIR

echo "compare_earth_gebco_candidate.sh: Writing artifacts to ${COMPARISON_DIR}"

for dataset in "${DATASETS[@]}"; do
	echo "compare_earth_gebco_candidate.sh: Comparing ${dataset} against ${PUBLIC_SERVER}"
	candidate_cut="${VALIDATION_DIR}/${dataset}.candidate.cut.nc"
	candidate_cut_info="${VALIDATION_DIR}/${dataset}.candidate.cut.grdinfo.txt"
	public_cut="${COMPARISON_DIR}/${dataset}.public.cut.nc"
	public_cut_info="${COMPARISON_DIR}/${dataset}.public.cut.grdinfo.txt"
	metadata_diff="${COMPARISON_DIR}/${dataset}.grdinfo.diff"
	diff_grid="${COMPARISON_DIR}/${dataset}.abs_diff.nc"
	diff_info="${COMPARISON_DIR}/${dataset}.abs_diff.grdinfo.txt"

	gmt grdcut "@${dataset}" -R"${WESN}" -G"${public_cut}" --GMT_DATA_SERVER="${PUBLIC_SERVER}" -Vi
	gmt grdinfo "${public_cut}" > "${public_cut_info}"
	diff -u "${candidate_cut_info}" "${public_cut_info}" > "${metadata_diff}" || true
	gmt grdmath "${candidate_cut}" "${public_cut}" SUB ABS = "${diff_grid}"
	gmt grdinfo "${diff_grid}" > "${diff_info}"
done

find "${COMPARISON_DIR}" -maxdepth 1 -type f | sort > "${COMPARISON_DIR}/manifest.txt"

echo "compare_earth_gebco_candidate.sh: Comparison artifacts are ready"