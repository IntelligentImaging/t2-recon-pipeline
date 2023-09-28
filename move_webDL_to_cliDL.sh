#!/bin/bash

cli=/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel/fetalbrain-P00041916
web=/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel/webdownloads/flywheel/crl/fetalbrain-P00041916

for dl in webdownloads/flywheel/*/*-P000*/*/s? ; do
	scan=`basename $dl`
	dir=`dirname $dl`
	subj=`basename $dir`
	dir2=`dirname $dir`
	study=`basename $dir2`
	dir3=`dirname $dir2`
	group=`basename $dir3`
	dest="${study}/SUBJECTS/${subj}/SESSIONS/${scan}/ACQUISITIONS"
	if [[ ! -d $dest ]] ; then
		mkdir -pv $dest
		rsync -av $dl/* $dest/
	else echo "$dest already there"
	fi
done


