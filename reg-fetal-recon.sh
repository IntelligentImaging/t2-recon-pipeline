#!/bin/bash
# Fetal registration using example case brains
shopt -s extglob


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-h] [-m|--mask mask.nii.gz] [-n|--normalize n] [-t|--target] [-w|--wide] -- [input] [ga]

        Fetal pipeline register to atlas space script

        -h      display help
        -m      supply a binary mask to crop the image (default: no mask)
        -n      run N4 bias correction (after masking) for "n" iterations, usually 3 (default: n=3)
        -t      specify registration target, must be either "ATLAS", "CASES", "EARLY",
                OR specify a single target image for registration.
                "EARLY" should be used for very small brains (~20 weeks and below)
                (default: ATLAS)
        -w      Widens selection of targets to +/- one week GA (default: off)

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
            show_help # help message
            exit
            ;;
        -m|--mask)
            if [[ "$2" ]] ; then
                MASK=$2
                echo mask is $MASK
                shift
            else
                die 'error: "--mask" requires a mask image'
                exit
            fi
            echo ARGS $#
            ;;
        -n|--normalize)
            if [[ "$2" ]] ; then
                ITER=$2
                if [[ $ITER -gt 0 ]] ; then
                    echo ITER is $ITER
                    shift
                else echo "-n ITER should be a number greater than 0"
                    exit
                fi
            fi
            echo ARGS $#
            ;;
        -t|--target)
            if [[ "$2" ]] ; then
                TARGET=$2
                shift
            fi
            echo ARGS $#
            ;;
        -w|--wide)
            WIDE="YES"
            echo $ARGS $#
            ;;
        -?*)
            printf 'warning: unknown option (ignored: %s\n' "$1" >&2
            ;;
        *) # default case, no options
            break
    esac
    shift
done

# Required arguments
INPUT=`readlink -f $1`
GA="$2"
DIR=`dirname $INPUT`
BASE=`basename $INPUT`
SCRIPT="${DIR}/run-reg.sh"

if [ $# -ne 2 ] ; then
    show_help
    exit
fi

if [ ! -e $1 ] ; then
    echo "error: Could not find $1 ... exiting"
    exit 1
fi

# registration command to be called later
function register {
                baseT="`basename ${template%%.*}`"
                output=${basebrain}_FLIRTto_${baseT}
                echo "input is $INPUT"
                echo "base name is $basebrain" 
                echo "template image is $template"
		echo "template GA is $tga"
                echo "output files are $output"
                echo "Running FLIRT!"
                cmd="flirt -dof 6 -cost corratio -in $INPUT -ref ${template} -omat ${output}.mat -out ${output}"
		echo $cmd >> $SCRIPT
		$cmd
                }

if [ $MASK ] ; then
    echo "Finalize mask (crlMaskConnectedComponents)"
    CCMASK="${DIR}/mask_r3Drecon_registration.nii.gz"
    crlMaskConnectedComponents ${MASK} ${CCMASK} 1 500
    echo Masking image
    MASKED="${DIR}/m${BASE}"
    crlMaskImage $INPUT $CCMASK $MASKED
    INPUT=$MASKED
fi

if [ $ITER ] ; then
    echo Performing bias correction
    let count=0
    OUT="${DIR}/BIASTEMP.nii.gz"
    CORR="${DIR}/bm${BASE}"
    MAX="${DIR}/tmp_bm${BASE}"
    NEG="${DIR}/tmp_bm${BASE}"
    while [[ $count -lt ${ITER} ]] ; do
        crlN4biasfieldcorrection $INPUT $OUT $CCMASK
        INPUT="${OUT}"
        ((count++))
    done
    mv $OUT -v $CORR
    crlMatchMaxImageIntensity /fileserver/fetal/segmentation/templates/STA_GEPZ/STA35.nii.gz $CORR $MAX 
    crlNoNegativeValues ${MAX} ${NEG}
    mv -v ${NEG} ${CORR}
    INPUT=${CORR} 
fi

# for naming output files
basebrain="${INPUT%%.*}"

if [[ ! -n $TARGET ]] ; then
    TARGET="ATLAS"
    echo "Reg target will be $TARGET"
fi

# lists with registration templates
if   [[ $TARGET == "CASES" ]] ; then
	echo "*** Registering $INPUT to same-age cases ***"
    tlist="/fileserver/fetal/segmentation/templates/regtemplates/cases.csv"
elif [[ $TARGET == "ATLAS" ]] ; then
	echo "*** Registering $INPUT to same-age STA images ***"
    tlist="/fileserver/fetal/segmentation/templates/regtemplates/STA.csv"
elif [[ $TARGET == "EARLY" ]] ; then
    echo "*** Registering $INPUT to EARLY-ga cases ***"
    tlist="/fileserver/fetal/segmentation/templates/regtemplates/early.csv"
    GA="21"
elif [[ -f $TARGET ]] ; then
    echo "Registering to file"
	template=`readlink -f $TARGET`
	tga="NA"
	basebrain="${INPUT%%.*}"
	register
	warning="n"
else
        echo "Supplied argument for reference invalid"
        exit
        fi

if [[ $TARGET == "ATLAS" || $TARGET == "CASES" || $TARGET == "EARLY" ]] ; then 
	# inspect list of possible registration templates
	while read line ; do 
		# name of template
		template=`readlink -f $(echo $line | awk -F' ' '{ print $1 }')`
		# GA of template
		tga=`echo $line | awk -F' ' '{ print $2 }'`
		# check if template GA is match for our input GA, if so run command
		# if -w is set it will check for +/-1 GA templates
		if [[ $GA -eq $tga ]] || [[ -n $WIDE && ( ${GA}-${tga} -eq 1 || ${GA}-${tga} -eq -1 ) ]] ; then
			register
			warning="n"
			echo
		fi
	done < ${tlist}
	fi

if [[ ! "$warning" = "n" ]] ; then
	echo "No templates of correct GA were found for ${input}"
fi
