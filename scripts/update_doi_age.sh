#!/bin/bash
# Run this from server dir which has earth beneath it.
# Adding it to the script folder in case we have similar updates later for other data
# Note the DOI is hardwired for this data set.  Also the -F in the awk assumes that this
# is a unique way to pull out the text after that second colon.

ls earth/earth_age/*.grd > /tmp/t.lis
while read file; do
	printf "\n%s:\n" $file
	old_remark=$(gmt grdinfo $file | grep Remark | awk -F': ' '{print $3}')
	new_remark=$(echo ${old_remark} | sed -e 'sXin reviewXhttp://dx.doi.org/10.1029/2020GC009214Xg')
	echo "Old remark: ${old_remark}"
	echo "New remark: ${new_remark}"
	if [ $(echo $new_remark | awk '{print length($0)}') -ge 160 ]; then
		echo "Warning, new remark is too long for the 160 character attribute, shorten manually"
	else
		gmt grdedit $file -D+r"${new_remark}"
	fi
done < /tmp/t.lis
