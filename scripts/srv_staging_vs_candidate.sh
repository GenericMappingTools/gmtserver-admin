#!/bin/bash
# This checks if all the files in the given directory
# made it to the candidate server. Compare what you get
# by running this script one the candidate server and your staging dir

if [ $# -eq 0 ]; then
	cat <<- EOF >&2
	usage: srv_staging_vs_candidate.sh <dir>
		<dir> is the top server directory with planets and earth within it
	EOF
	exit -1
fi

DIR=$1

rm -f ${HOME}/dataset.log

# 1. Move into the dir with the planets
cd ${DIR}
find . -name '*_*_server.txt' | grep -v gmt_data_server.txt | awk -F/ '{print $3}' > /tmp/datasets.lis
while read dataset; do
	planet=$(echo $dataset | awk -F_ '{print $1}')
	find ${planet}/${dataset} -name '*.jp2' >> ${HOME}/dataset.log
	find ${planet}/${dataset} -name '*.grd' >> ${HOME}/dataset.log
	find ${planet}/${dataset} -name '*.tif' >> ${HOME}/dataset.log
done < /tmp/datasets.lis
n_datasets=$(wc -l /tmp/datasets.lis | awk '{printf "%d\n", $1}')
n_files=$(wc -l ${HOME}/dataset.log | awk '{printf "%d\n", $1}')
echo "Found a total of ${n_files} files for ${n_datasets} data sets"
echo "Log file is ${HOME}/dataset.log"
