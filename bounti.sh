#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [BIDS organized niftymic T2 file]
    Incorrect input supplied

    -r  Resample input image to 0.5 (needed for bounti)
    -m  Let bounti do brain masking (for images which have not been brain-extracted)
EOF
}


die() {
    printf '%s\n' "$1" >&2
    exit 1
}
while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -r|--resample) 
            let resam=1 # resample to .5 mm
            ;;
        -m|--mask)
            let domask=1
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

image=$1
if [[ ! -f ${image} ]] ; then show_help ; fi


anat=`dirname $image`

tmpdir=${anat}/TMP${RANDOM}
mkdir ${tmpdir}

base=`basename $image`
pt5name=`echo $base | sed -e 's,_t2w.nii.gz,_pt5_t2w.nii.gz,g'`
outname=`echo $base | sed -e 's,rec-\(.*\)_,rec-\1_desc-bounti_,g'`


if [[ $resam = 1 ]] ; then
    echo Resampling input image to 0.5 mm isotropic
    mrgrid $image regrid -voxel 0.5,0.5,0.5 ${anat}/${pt5name}
    image=${anat}/${pt5name}
fi

if [[ -n ${domask} ]] ; then 
    echo "Brain extraction mode"
    echo Bounti
    apptainer exec --nv docker://fetalsvrtk/svrtk:perinatal_brain_mri_analysis_amd sh -c " bash /home/perinatal-brain-mri-analysis/scripts/run-multi-bounti-fetal-brain-segmentation-2026-general.sh 1 ${image} ${tmpdir} ${anat}/${outname}  ; "

else
    echo "You have already done brain masking"
    mask=${anat}/mask-for-bounti.nii.gz
    echo Creating whole image mask
    crlBinaryThreshold ${image} ${mask} 5 10000 1 0
    echo Bounti
    apptainer exec --nv docker://fetalsvrtk/svrtk:perinatal_brain_mri_analysis_amd sh -c " bash /home/perinatal-brain-mri-analysis/scripts/run-multi-bounti-fetal-brain-segmentation-2026-with-bet-init.sh 0 ${image} ${mask} ${tmpdir} ${anat}/${outname}  ; "
fi

rm -rf ${tmpdir}
