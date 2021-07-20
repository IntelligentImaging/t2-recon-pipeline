#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-h] [-d|--dense] [-m|--mask] -- [RAW CASE DIR] [GENERAL PROC DIR]
    Sets up processing directory for fetal reconstruction pipeline
    [RAW CASE DIR] should be the the case directory with the subject ID (eg. f1234s1/)
    [PROC DIR] should be a folder with many cases (eg. /fileserver/fetal/reconstruction/)

    -h      Display this help and exit
    -dense  Setup 2D Densenet dir
    -mask   Start 2D Densenet brain extraction
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

# Optional arguments
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        -d|--dense)
            dense="Y"
            ;;
        -m|--mask)
            mask="Y"
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'warning: unknown option (ignored): %s\n' "$1" >&2
            ;;
        *) # default, no options
            break
    esac
    shift
done

# verify any argument
if [ $# -eq 0 ] ; then
        show_help
            exit
        fi
        
RAW="$1"
PROC="$2"
ID=`basename $RAW`
DCMDIR=`find ${RAW} -type d -name DICOM`
NIIDIR="`dirname $DCMDIR`/nii"
NET="/home/ch162835/Software/2Ddensenet"

if [[ ! -d $RAW ]] ; then
	die "Raw case directory $RAW doesn't exist. Exiting."
	fi

function convert () {
	BASE=`basename $DCM`
	OUT="${NIIDIR}/${BASE}"
	mkdir -pv ${OUT}
	if [[ ! -z `find ${OUT} -type f` ]] ; then
		echo "Skipping: Files already exist in ${OUT}"
	else
		echo "Converting $DCM"
		dcm2niix -z y -f %d_%s -o "${OUT}/" $DCM
		fi
	}

# Convert to NIFTI with dcm2niix
mkdir -pv ${NIIDIR}
if [[ ! -z `find ${DCMDIR} -mindepth 2 -type f` ]] ; then
	for DCM in ${DCMDIR}/* ; do
		if [[ -d ${DCM} ]] ; then
			convert		
			fi
		done
else
	echo Conversion step error: DICOM files were not found
	fi

# Copy T2 stacks to reconstruction folder
RECON="${PROC}/${ID}/nii"
mkdir -pv ${RECON}/../notgood
for TERM in T2_HASTE CERVIX SSFSE_T2 ; do # Search terms
    ARRAY=`find ${NIIDIR}/ -type f -name \*$TERM\*.nii\*` # Make an array of found images
    if [[ -n $ARRAY ]] ; then # exlcude empty arrays
        for IM in $ARRAY ; do
            base=`basename $IM`
            end="${base##*_}"
            new="fetus_${end}"
            chk=`find ${PROC}/${ID} -type f -name $new`
            if [[ -z $chk ]] ; then
            cp ${IM} -v ${RECON}/${new} # copy to recon dir
        else echo "$new already in recon dir"
        fi
        done
    fi
done

# Install 2D Densenet to recon directory
if [[ $dense == "Y" || $mask == "Y" ]] ; then
    echo "--dense or --mask option is set: installing 2D densenet"
    cp ${NET} -urv ${RECON}
    cp ${RECON}/fetus*z -uv ${RECON}/2Ddensenet/InputData/
    echo "Recon Dir: ${RECON}"
    echo "Densenet Code Dir: ${RECON}/2Ddensenet/InputData/"
fi

# Run 2D Densenet
if [[ $mask = "Y" ]] ; then
	echo "Starting python 2D densenet brain mask"
	python ${RECON}/2Ddensenet/Code/FC-Dense-2D.py
fi

# Open directory and file permissions
find ${RECON} -type d -exec chmod -c --preserve-root 777 {} \;
find ${RECON} -type f -exec chmod -c --preserve-root 664 {} \;
