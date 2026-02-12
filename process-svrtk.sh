#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-s] [-m] [-r] [-a||--all] -- [case svrtk directory]
    Incorrect input supplied 

	Must select at least one step to run. Each step requires the output from the previous:
	-s	SVRTK reconstruction using the images in the input directory
	-m 	T2 recon mask segmentation for the SVRTK recon
	-r	Normalize intensity and register masked recon to atlas
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
        -r)
            let STEPreg=1
            ;;
        -a|--all)
            let STEPsvr=1 ; let STEPmask=1 ; let STEPreg=1
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

if [[ ${STEPsvr}+${STEPmask}+${STEPreg} = 0 ]] ; then die 'Need to specify at least one step to run' ; fi

shdir=`dirname $0`

svrtk=`readlink -f $1`
dir=`dirname $svrtk`
subj=`basename $dir`

echo
echo "input directory: ${svrtk}"
date

# # # SVR RECONSTRUCTION # # #
if [[ ${STEPsvr}=1 ]] ; then

    echo "# # # SVR RECONSTRUCTION # # #"
    fetuses=`find $1 -maxdepth 1 -type f -name fetus\*.nii.gz`
    svrmask=`find $1 -maxdepth 1 -type f -name mask_\*.nii.gz`

    if [[ ! -n $fetuses || ! -f $svrmask ]] ; then die "t2 stacks (fetus*nii.gz) or mask (mask_*.nii.gz) not found, can't run SVRTK" ; fi

    bash ${shdir}/svrtk-gen.sh ${svrtk} # creates the run script

    if [[ -f ${svrtk}/run-svrtk.sh ]] ; then
        bash ${shdir}/svrtk-exec.sh -s ${svrtk} # -s runs the container with apptainer
    else die "Run script for SVRTK not found"
    fi

    echo "++ SVR recon step done ++"
fi

# # # SVR MASKING and REGISTRATION # # #
if [[ ${STEPmask}=1 ]] ; then

    echo "# # # SVR MASKING and REGISTRATION # # #"
    svrrecon="${svrtk}/SVRTK_${subj}.nii.gz"

    if [[ ! -f $svrrecon ]] ; then die "SVRTK reconstruction not found" ; fi
    
    # -n 1 runs one iteration or N4 bias correction
    # -s Tells the script to run brian mask segmentation, DK code, with apptainer
    bash ${shdir}/reg-prep.sh -n 1 -s ${svrrecon} 
    # This step also does intesity normalization

    echo "++ subject-space recon masking done ++"
fi

# # # ATLAS REGISTRATION # # #
if [[ ${STEPreg}=1 ]] ; then

    echo "# # # ATLAS REGISTRATION # # #"
    subjrecon="${svrtk}/registration/nxbSVRTK_${subj}.nii.gz"
    subjmask="${svrtk}/registration/mask.nii.gz"

    if [[ ! -f $subjrecon || ! -f $subjmask ]] ; then die "Recon or Mask from step 2 (masking) not found" ; fi

    # -n 2 runs two more iterations of N4 bias correction
    # -m takes the mask from step 2
    # -w Widens the registration template selection to plus and minus one week GA
    bash ${shdir}/reg-fetal-recon.sh -n 2 -m ${subjmask} -w ${subjrecon}
    # This script once again matches intensities to template range.

    echo "++ atlas registration done ++"
fi