#!/bin/bash
# Fetal registration using example case brains
shopt -s extglob


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-h] [-m|--mask mask.nii.gz] [-n|--normalize n] [-t|--target] [-c|--metric] [-ga|--ga GA] [-w|--wide] -- [input]

        Fetal pipeline register to atlas space script

          REQUIRED ARGUMENTS
        [input] Input image which gets registered to atlas space
          OPTIONAL ARGUMENTS
        -h      display help
        -m      supply a binary mask to crop the image (default: no mask)
        -n      run N4 bias correction (after masking) for "n" iterations, usually 3 (default: n=3)
        -t      specify registration target, must be either "ATLAS", "CASES", "EARLY",
                OR specify a single target image for registration.
                "EARLY" should be used for very small brains (~20 weeks and below)
                (default: ATLAS)
        -c      FLIRT registration metric {mutualinfo,corratio,normcorr,normmi,leastsq,labeldiff,bbr} (default is corratio)
        -ga     specify gestational age for atlas matching (default: estimate based on total volume)
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
            fi
            ;;
        -n|--normalize)
            if [[ "$2" ]] ; then
                ITER=$2
                if [[ $ITER -gt 0 ]] ; then
                    echo ITER is $ITER
                    shift
                else die "-n ITER should be a number greater than 0"
                fi
            fi
            ;;
        -t|--target)
            if [[ "$2" ]] ; then
                TARGET=$2
                shift
            else die 'no registration target specified'
            fi
            ;;
        -c|--metric)
            if [[ "$2" ]] ; then
                METRIC=$2
                shift
            else die 'no target specified'
            fi
            ;;
        -ga|--ga)
            if [[ "$2" ]] ; then
                GA=$2
                shift
            else die 'no GA specified'
            fi
            ;;
        -w|--wide)
            WIDE="YES"
            ;;
        -?*)
            printf 'warning: unknown option (ignored): %s\n' "$1" >&2
            ;;
        *) # default case, no options
            break
    esac
    shift
done

if [ $# -ne 1 ] ; then
    show_help
    exit
fi

if [ ! -e $1 ] ; then
    echo "error: Could not find $1 ... exiting"
    exit 1
fi

# Required arguments
INPUT=`readlink -f $1`
DIR=`dirname $INPUT`
BASE=`basename $INPUT`
SCRIPT="${DIR}/run-reg.sh"
if [[ ! -n $METRIC ]] ; then METRIC="corratio" ; fi

# registration command to be called later
function register {
                baseT="`basename ${template%%.*}`"
                output=${basebrain}_FLIRTto_${baseT}
                echo "input is $BASE"
                echo "template image is $template"
        		echo "template GA is $tga"
                echo "output files are ${output##*/}"
                echo "reg metric is $METRIC"
                echo "Running FLIRT!"
                cmd="flirt -dof 6 -cost $METRIC -in $INPUT -ref ${template} -omat ${output}.mat -out ${output}"
		echo $cmd >> $SCRIPT
		$cmd
                }

# If optional mask is supplied, mask input image and set masked image as image which gets registered
CCMASK="${DIR}/mask_r3Drecon_registration.nii.gz"
if [ $MASK ] ; then
    echo "Finalize mask (crlMaskConnectedComponents)"
    $FETALBIN/crlMaskConnectedComponents ${MASK} ${CCMASK} 1 500
    echo Masking image
    MASKED="${DIR}/m${BASE}"
  #  $FETALBIN/crlMaskImage $INPUT $CCMASK $MASKED
    fslmaths $INPUT -mul $CCMASK $MASKED
    INPUT=$MASKED
fi

# If optional N4 bias is supplied, do N4 bias correction n times
if [ $ITER ] ; then
    echo Performing bias correction
    let count=0
    OUT="${DIR}/BIASTEMP.nii.gz"
    CORR="${DIR}/bm${BASE}"
    MAX="${DIR}/tmp_bm${BASE}"
    NEG="${DIR}/tmp_bm${BASE}"
    while [[ $count -lt ${ITER} ]] ; do
        $FETALBIN/crlN4biasfieldcorrection $INPUT $OUT $CCMASK
        INPUT="${OUT}"
        ((count++))
    done
    mv $OUT -v $CORR
    $FETALBIN/crlMatchMaxImageIntensity ${FETALREF}/STA_GEPZ/STA35.nii.gz $CORR $MAX 
    $FETALBIN/crlNoNegativeValues ${MAX} ${NEG}
    mv -v ${NEG} ${CORR}
    INPUT=${CORR} 
fi

# used to name output files
basebrain="${INPUT%%.*}"

# AUTO-DETECT GA if no GA supplied 
if [[ ! -n $GA  && ! -f $TARGET ]] ; then
    # Compare mask volume to each STA mask volume and pick the closest
    echo "Estimating input GA"
    choose="${FETALREF}/STA_GEPZ/masks/choose.txt"
    while read line ; do
        atlasGA=`echo $line | cut -d' ' -f1`
        avol=`echo $line | cut -d ' ' -f2`
        invol=`$FETALBIN/crlComputeVolume $CCMASK 1`
        diff=`echo "($avol-$invol)/1" | bc`
        abs=${diff#-}
        # list all comparison results
        # echo AtlasGA $atlasGA Diff $abs
        # if no comparison values yet, set it using first line
        if [[ -z $pick ]] ; then
            pick="$atlasGA"
            pickvol="$abs"
            # if a line's diff is less than comparison, replace the saved values
        elif [[ $abs -lt $pickvol ]] ; then
            pick="$atlasGA"
            pickvol="$abs"
        fi
    done < $choose
    echo "Estimated GA is: $pick"
    GA=$pick
fi

# If a single target was given, use it
if [[ ! -n $TARGET && ${GA} -lt 22 ]] ; then
    TARGET="EARLY"
    echo "Small brain ROI so we will register to early-GA templates"
elif [[ ! -n $TARGET ]] ; then
    TARGET="ATLAS"
    echo "Reg target will be $TARGET"
fi

# Else, we use a list with registration templates
if   [[ $TARGET == "CASES" ]] ; then
	echo "*** Registering $INPUT to same-age cases ***"
    tlist="${FETALREF}/regtemplates/cases.csv"
elif [[ $TARGET == "ATLAS" ]] ; then
	echo "*** Registering $INPUT to same-age STA images ***"
    tlist="${FETALREF}/regtemplates/STA.csv"
elif [[ $TARGET == "EARLY" ]] ; then
    echo "*** Registering $INPUT to EARLY-ga cases ***"
    tlist="${FETALREF}/regtemplates/early.csv"
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
			register &
			warning="n"
			echo
		fi
	done < ${tlist}
    wait
fi

if [[ ! "$warning" = "n" ]] ; then
	echo "No templates of correct GA were found for ${input}"
fi
