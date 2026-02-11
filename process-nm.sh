#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-s] [-m] [-a||--all] -- [case niftymic directory]
    Incorrect input supplied

	Must select at least one step to run. Each step requires the output from the previous:
	-s	NiftyMIC reconstruction using the images in the input directory
	-m 	Mask nm recons with the mask and copy to output directory
    	--all   Do all
 
    You should inspect the input stacks first and remove those you don't need. ~6-9 stacks is plenty.
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
        -s)
            let STEPsvr=1
            ;;
        -m)
            let STEPmask=1
            ;;
        -a|--all)
            let STEPsvr=1 ; let STEPmask=1 
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

if [[ ${STEPsvr}+${STEPmask} = 0 ]] ; then die 'Need to specify at least one step to run' ; fi

shdir=`dirname $0`

nmic=`readlink -f $1`
dir=`dirname $nmic`
subj=`basename $dir`

echo
echo "input directory: ${nmic}"
date

# # # SVR RECONSTRUCTION # # #
if [[ ${STEPsvr}=1 ]] ; then

    echo "# # # SVR RECONSTRUCTION # # #"
    fetuses=`find ${1}/t2 -maxdepth 1 -type f -name fetus\*.nii.gz`

    if [[ ! -n $fetuses ]] ; then die "t2 stacks (fetus*nii.gz) or mask (mask_*.nii.gz) not found, can't run reconstruction" ; fi

    bash ${shdir}/nm-gen.sh ${nmic} # creates the run script

    if [[ -f ${nmic}/run-nm.sh ]] ; then
        bash ${shdir}/nm-exec.sh -s ${nmic} # -s runs the container with apptainer
    else die "Run script for recon not found"
    fi

    echo "++ SVR recon step done ++"
fi

# # # MASK RECONSTRUCTION # # #
if [[ ${STEPmask}=1 ]] ; then

    echo "# # # SVR RECONSTRUCTION # # #"
    #subj_srr=${nmic}/srr/recon_subject_space/srr_subject.nii.gz
    #subj_mask=${nmic}/srr/recon_subject_space/srr_subject_mask.nii.gz
    atlas_srr=${nmic}/srr/recon_template_space/srr_template.nii.gz
    atlas_mask=${nmic}/srr/recon_template_space/srr_template_mask.nii.gz

    if [[ ! -f $atlas_srr || ! -f $atlas_mask ]] ; then die "could not find niftymic output reconstructions" ; fi 

    output=${nmic}/output
    mkdir -pv ${output}

    #mrmath $subj_srr $subj_mask product ${output}/${subj}-msrr_subject.nii.gz
    mrmath $atlas_srr $atlas_mask product ${output}/${subj}-msrr_template.nii.gz -force

fi