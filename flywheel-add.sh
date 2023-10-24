#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input]
    Incorrect input supplied
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        --noZ)
            noUNZIP=1 # will skip unzip steps
            ;;
        --noC)
            noCOPY=1 # will skip copy to raw
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -)?*
            printf 'warning: unknown option (ignored: %s\m' "$1" >&2
            ;;
        *) # default case, no optionals
            break
    esac
    shift
done

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

scripts=`dirname $0`
INPUT=$1
scan=`basename $1`
dir=`dirname $INPUT`
subj=`basename $dir`
dir2=`dirname $dir`
study=`basename $dir2`

out="/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel/${study}/SUBJECTS/${subj}/SESSIONS/${scan}/ACQUISITIONS/"
out2="/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel/${study}/SUBJECTS/${subj}/SESSIONS/${scan}"
mkdir -pv ${out}

if [[ $noUNZIP -ne 1 ]] ; then 
    echo flywheel unzip
    sh $scripts/flywheel-unzip.sh $INPUT $out
fi

if [[ $noCOPY -ne 1 ]] then
    echo flywheel copy to raw
    sh $scripts/flywheel-raw.sh $out2
fi
