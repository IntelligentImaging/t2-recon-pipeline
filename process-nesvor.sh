#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-s] [-r] [-a||--all] -- [case nesvor directory]
    Incorrect input supplied

	Must select at least one step to run. Each step requires the output from the previous:
	-s	Reconstruction using the images in the input directory
	-r	Run additional rigid registration to atlas space (refine alignment) 
    	--all   Do all 
 
    You should inspect the input stacks first and remove those you don't need. ~6-9 stacks is plenty.
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

let STEPsvr=0
let STEPreg=0

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -s)
            let STEPsvr=1
            ;;
        -r)
            let STEPreg=1
            ;;
        -a|--all)
            let STEPsvr=1 ; let STEPreg=1 
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

if (( ${STEPsvr} + ${STEPreg} == 0 )) ; then die 'Need to specify at least one step to run' ; fi

shdir=`dirname $0`

recon=`readlink -f $1`
dir=`dirname $recon`
subj=`basename $dir`

echo
echo "input directory: ${recon}"
date

# # # SVR RECONSTRUCTION # # #
if [[ ${STEPsvr}=1 ]] ; then

    echo "# # # SVR RECONSTRUCTION # # #"
    fetuses=`find ${recon} -maxdepth 1 -type f -name fetus\*.nii.gz`

    if [[ ! -n $fetuses ]] ; then die "t2 stacks (fetus*nii.gz) not found, can't run reconstruction" ; fi

    bash ${shdir}/nesvor.sh ${recon} # runs nesvor container

    echo "++ SVR recon step done ++"
fi

# # # REFINE REGISTRATION # # #
if [[ ${STEPreg}=1 ]] ; then

    echo "# # # REFINE REGISTRATION # # #"

    if [[ ! -f ${recon}/nesvor.nii.gz ]] ; then die "could not find nesvor reconstruction" ; fi 

    bash ${shdir}/reg-fetal-recon.sh ${recon}/nesvor.nii.gz

    echo "++ Registration step done ++"
    echo "Now run sh ${shdir}/choosereg.sh on ${recon}/nesvor_FLIRTto_STA[ga].nii.gz if you are happy with the result"

fi
