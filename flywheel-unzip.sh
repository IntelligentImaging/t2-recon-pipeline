#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input fw scan] [output folder copy]
    Incorrect input supplied
    output should probably be SUBJECTS/id/SESSIONS/sx/ACQUISITIONS/
EOF
}

if [ $# -ne 2 ]; then
    show_help
    exit
fi

input=$1
output=$2

detox $input
for series in ${input}/* ; do
    if [[ -d $series ]] ; then
        detox $series
        # Unzip the zips
        find $series -type f -name \*dicom.zip -execdir unzip -n {} \;
        ex=`find $series -type f -name \*dcm | head -n1`
        # Get seq name and number
        name=`dcmdump +L +P "0008,103e" $ex | sed -e 's,.*\[\(.*\)\].*,\1,g' -e 's, ,_,g'`
        num=`dcmdump +L +P "0020,0011" $ex | sed 's,.*\[\(.*\)\].*,\1,g'`
        # echo ${num}_${name} 
        seriesout="${output}/${num}_${name}"
        mkdir -pv ${seriesout}
        rsync -a ${series}/* ${seriesout}/
    fi
done
