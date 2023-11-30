#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [study] [subj] [session]
    This is used to download a flywheel scan
    study = "crl" or "fcb"
EOF
}

if [ $# -ne 3 ]; then
    show_help
    exit
fi 

study=$1
subj=$2
sess=$3

if [[ $study == "crl" ]] ; then
    FWproj="crl"
    FWstudy="fetalbrain-P00041916"
elif [[ $study == "fcb" ]] ; then
    FWproj="rollins"
    FWstudy="rollinsfetal-P00008836"
else echo you need to enter 'crl' or 'fcb'
    exit
fi

echo fw://${FWproj}/${FWstudy}/${subj}/${sess}
fw download -y --include dicom --output ${study}-${subj}-${sess}.tar "fw://${FWproj}/${FWstudy}/${subj}/${sess}"
