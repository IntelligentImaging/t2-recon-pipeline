#!/bin/bash


die() {
    printf '%s\n' "$1" >&2
    exit 1
}

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input directory]
    Incorrect input supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi

indir=$1
if [[ ! -d $indir ]] ; then die "input dir doesnt exist" ; fi

output=${indir}/nesvor.nii.gz

echo Running NeSVoR reconstruction: $indir
if [[ ! -f $output ]] ; then
    singularity exec --nv docker://junshenxu/nesvor nesvor reconstruct --input-stacks ${indir}/fetus*z --output-volume ${indir}/nesvor.nii.gz --segmentation --bias-field-correction --output-resolution 0.8
echo recon done!
else
    echo $output already exists
fi
