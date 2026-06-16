#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [BIDS organized niftymic T2 file]
    Incorrect input supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

image=$1
if [[ ! -f ${image} ]] ; then show_help ; fi


anat=`dirname $image`

tmpdir=${anat}/TMP${RANDOM}
mkdir ${tmpdir}

base=`basename $image`
pt5name=`echo $base | sed -e 's,_t2w.nii.gz,_pt5_t2w.nii.gz,g'`
outname=`echo $base | sed -e 's,rec-\(.*\)_,rec-\1_desc-bounti_,g'`


mrgrid $image regrid -voxel 0.5,0.5,0.5 ${anat}/${pt5name}

apptainer exec --nv docker://fetalsvrtk/svrtk:perinatal_brain_mri_analysis_amd sh -c " bash /home/perinatal-brain-mri-analysis/scripts/run-multi-bounti-fetal-brain-segmentation-2026-general.sh 0 ${anat}/${pt5name} ${tmpdir} ${anat}/${outname}  ; "

rm -rf ${tmpdir}
