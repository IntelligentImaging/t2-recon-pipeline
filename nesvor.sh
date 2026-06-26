#!/bin/bash


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
        -r|--resolution)
            if [[ -n "$2" ]] ; then
                RESO=$2 # Specify resolution
                shift
            else
                die 'error: no resolution supplied'
            fi
            ;;
        -b|--bet)
            let FETALBET=1 # activate fetal-bet mode
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


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-r 0.x] [-b|--bet] -- [input directory]
    Incorrect input supplied

    -r      Set output resolution (default=0.5)
    -b      Fetal-BET (brain extraction tool) mode. Can use if NeSVoR stack --segmentation is failing.
            Runs Razieh Fetal-BET on all input masks, dilates result, crops stacks, and uses cropped stacks instead.
            Omits --segmentation argument from NeSVoR command.
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi

if [[ ! -n $RESO ]] ; then
    RESO="0.5"
fi

indir=$1
if [[ ! -d $indir ]] ; then die "input dir doesnt exist" ; fi
pdir=`dirname $indir`
id=`basename $pdir`

output=${indir}/nesvor_${id}.nii.gz

echo Reconstruction: $indir
if [[ -f $output ]] ; then
    echo $output already exists
elif [[ $FETALBET = 1 ]] ; then
    echo FETAL-BET mode
    echo Masking stacks
    sh ${FETALSH}/fetal-bet.sh -d ${indir}

    echo Running NeSVoR reconstruction
    singularity exec --nv docker://junshenxu/nesvor nesvor reconstruct --input-stacks ${indir}/fetus*z --stack-masks ${indir}/mask_fetus*z --output-volume ${output} --bias-field-correction --output-resolution ${RESO}
    echo recon done!

else
    echo Running NeSVoR segmentation and reconstruction
    singularity exec --nv docker://junshenxu/nesvor nesvor reconstruct --input-stacks ${indir}/fetus*z --output-volume ${output} --segmentation --bias-field-correction --output-resolution ${RESO}
    echo recon done!
fi

echo Bias correction
singularity exec --nv docker://junshenxu/nesvor python3 ${FETALSH}/n4biascorrect.py -i ${output} -o ${indir}/bnesvor_${id}.nii.gz
