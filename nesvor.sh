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
    USAGE: sh ${0##*/} [-r resolution default=0.5] -- [input directory]
    Incorrect input supplied
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

output=${indir}/nesvor.nii.gz

echo Running NeSVoR reconstruction: $indir
if [[ ! -f $output ]] ; then
    singularity exec --nv docker://junshenxu/nesvor nesvor reconstruct --input-stacks ${indir}/fetus*z --output-volume ${indir}/nesvor.nii.gz --segmentation --bias-field-correction --output-resolution ${RESO}
echo recon done!
else
    echo $output already exists
fi
