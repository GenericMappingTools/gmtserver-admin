#!/bin/bash -e
# srv_update_sha256.sh
#
# Find all files on gmtserver and update the hash table in the event files are
# younger than the hash table itself. Files deleted are thus removed from the hash table.
# We only consider the earth_relief_xxy.grd files and the cache dir. SRTM tiles not included
# If an error is detected we quit.

# Name of hash table
GMT_HASH_TABLE="gmt_hash_server"

# 0. Directory with GMT remote data files
DATA=/export/gmtserver/gmt/data

# 1. Make a list of all the earth relief first and then cache files
ls $DATA/earth_relief_???.grd > /tmp/$$.lis
ls $DATA/cache/*  >> /tmp/$$.lis

# 2. Write number of files found to the new hash table header
wc -l < /tmp/$$.lis | awk '{printf "%d\n", $1}' > $DATA/next_${GMT_HASH_TABLE}.txt

# 2. Loop over the files we found and update hash table if needed
while read path; do
	file=`basename $path`
	if [ $path -nt $DATA/${GMT_HASH_TABLE}.txt ]; then	# File was updated after current hash table was made, redo hash
		hash=`sha256sum $path | awk '{print $1}'`
		size=`ls -l $path | awk '{print $5}'`
		printf "%s\t%s\t%s\n" $file $hash $size >> $DATA/next_${GMT_HASH_TABLE}.txt
	else	# Can use the previous hash record
		grep -w $file $DATA/${GMT_HASH_TABLE}.txt >> $DATA/next_${GMT_HASH_TABLE}.txt
	fi
done < /tmp/$$.lis
rm -f /tmp/$$.lis

# 3. Overwrite old file with new hash table if it changed

update=`diff -q $DATA/${GMT_HASH_TABLE}.txt $DATA/next_${GMT_HASH_TABLE}.txt`
if [ "X${update}" == "X" ]; then	# No change
	rm -f $DATA/next_${GMT_HASH_TABLE}.txt
else	# Keep previous and update current
	mv -f $DATA/${GMT_HASH_TABLE}.txt $DATA/${GMT_HASH_TABLE}_previous.txt
	mv -f $DATA/next_${GMT_HASH_TABLE}.txt $DATA/${GMT_HASH_TABLE}.txt
fi
