#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-h] [-d study DWI folder] -- [RAW CASE DIR] [GENERAL PROC DIR]
    Sets up processing directory for fetal reconstruction pipeline
    [RAW CASE DIR] should be the the case directory with the subject ID (eg. f1234s1/)
    [PROC DIR] should be a folder with many cases (eg. /fileserver/fetal/reconstruction/)

    -h      Display this help and exit
    -d      Set up diffusion processing directory in the specified location. Do not put subject ID here.
    -c	    Use specified converter ( -c dcm2niix )
    -e      Take series number from END of folder names, instead of start (default=start)
    -a      Also create an Anonymized DICOM folder. VALIDATE ANONYMIZATION. 
    [DEPRECIATED] --dense  Setup 2D Densenet dir
    [DEPRECIATED] --mask   Start 2D Densenet brain extraction
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
        -d)
            dwi="Y"
            dwipath="$2"
            shift
            ;;
        -c|--converter)
            if [[ $2 == dcm2niix ]] ; then
		    CONV="$2"
	    fi
            shift
            ;;
        -e)
            let end=1
            ;;
        -a|--anonymize)
            let anon=1
            ;;
        # --dense)
        #     dense="Y"
            # ;;
        # -m|--mask)
        #     mask="Y"
            # ;;
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
ID=`basename "$RAW"`
DCMDIR=`find ${RAW} -type d -name DICOM | head -n1`
IMAGEDIR=`dirname $DCMDIR`
NIIDIR="${IMAGEDIR}/nii"
NET="/fileserver/fetal/software/2Ddensenet"
SHDIR=`dirname $0`

if [[ ! -d $RAW ]] ; then
	die "error: Raw case directory $RAW doesn't exist"
elif [[ ! -d $DCMDIR ]] ; then
    die "error: DICOM directory named DICOM not found in $RAW"
	fi

function convert () {
	BASE=`basename "$DCM"`
	OUT=`echo ${NIIDIR}/${BASE} | sed -e 's, ,_,g'`
	mkdir -pv "${OUT}"
	if [[ ! -z `find ${OUT} -type f` ]] ; then
		echo "Skipping: Files already exist in ${OUT}"
	else
		echo "Converting $DCM"
		if [[ $CONV == "dcm2niix" ]] ; then
			dcm2niix -z y -i y -f %d_%s -o "${OUT}/" "$DCM"
		else
			echo 1 | mrconvert -clear_property comments $DCM ${OUT}/${BASE}.nii.gz
		fi
	fi
	}

# Detox DICOM dir
echo "Removing special characters from DICOM folder names"
detox ${DCMDIR}

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

if [[ $anon = 1 ]] ; then
    echo "Deidentify images:"
    sh $SHDIR/deidentify.sh $DCMDIR ${IMAGEDIR}/deid xxx
fi


# Copy T2 stacks to reconstruction folder
echo "COPY TO RECON FOLDER # # #"
RECON="${PROC}/${ID}/svrtk"
mkdir -pv ${RECON}/../notgood
for TERM in SSh T2_HASTE CERVIX SSFSE DL_HASTE iTSE_haste_dnf ; do # Search terms
    ARRAY=`find ${NIIDIR}/ -type f -name \*$TERM\*.nii\* -a ! -iname \*LOC -a ! -iname \*DTI\* -a ! -iname \*CINCI\* -a ! -iname \*T1W\*` # -and ! -iname \*DLonur\* -and ! -iname \*_DL` # Make an array of found images
    if [[ -n $ARRAY ]] ; then # exlcude empty arrays
        for IM in $ARRAY ; do
            base=`basename "$IM"`
            if [[ $end = 1 ]] ; then
                num=`echo ${base##*_} | sed -e 's,\.nii.*,,g'`
		text=`echo ${base%_*} | sed -e 's,\(........\).*,\1,' -e 's,_,,g'`
            else
                num=`echo ${base%%_*}`
		text=`echo ${base#*_} | sed -e 's,\(........\).*,\1,' -e 's,_,,g'`
            fi
            #text=`echo $base | sed -e 's,[0-9]*_,,' -e 's,\(........\).*,\1,' -e 's,_,,g'`
		if [[ $text == "DLHASTE" ]] ; then
			text="VFA"
		elif [[ $text == "wip1062" ]] ; then
			text="dnf"
		elif [[ $text == "T2HASTE" ]] ; then
			text="prod"
		fi
            new="fetus-${text}_${num}.nii.gz"
            chk=`find ${PROC}/${ID} -type f -name $new`
            if [[ -z $chk ]] ; then
            cp ${IM} -v ${RECON}/${new} # copy to recon dir
        else echo "$new already in recon dir"
        fi
        done
    fi
done

# Set up niftymic folder
mkdir -pv ${RECON}/../niftymic/{t2,mask}
cp ${RECON}/fetus*z -vup ${RECON}/../niftymic/t2/

# Set up diffusion processing directory
DCMPATH=`readlink -f $DCMDIR`
if [[ $dwi == "Y" ]] ; then
    echo "Create directory tree for DWI processing"
    sh ${FETALDTI}/dtiTemplate.sh ${dwipath}/${ID} ${DCMPATH}
fi

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
