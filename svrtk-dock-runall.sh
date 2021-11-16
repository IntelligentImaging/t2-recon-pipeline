#!/bin/bash

if [ $# -ne 1 ] ; then
	echo "Incorrect argument"
	echo "usage: sh $0 [Directory]"
	echo "fins all SVRTK run.sh's in [Directory] and runs them"
	echo "This version of the run script is for the Docker container installation"
	exit 1
fi

begin=`pwd`
DIR=$1

runs="`find $DIR -mindepth 2 -maxdepth 4 -type f -name run-svrtk\*.sh`"

echo "Process cases"
for f in $runs ; do
    base=`basename $f`
	dname=`dirname $f`
	idtmp="${dname%/nii*}"
	id="${idtmp##*/}"
    # get name of output file from run script
    output=`grep SVRTK $f | sed 's,.*\(SVRTK.*z\).*,\1,'`
	if [ -f "${dname}/${output}" ] ; then
		echo $f already ran
	else
		echo "Run $f"
        cd $dname
		sh $base
        cd $begin
	fi
done
