#!/bin/bash
# POSIX
shopt -s extglob

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-h] [-m MASK.nii.gz] [-t] -- [input] [#iterations]
    Run [#iterations] of N4 bias correction on [input]

        -h      display this help and exit
        -m MASK.nii.gz  supply a mask image for N4
                [default: all > 0 intensity voxels sampled for mask]
        -t      SAVE temporary iterations [default: no]
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
            if [ "$2" ] ; then
                mask=$2
                shift
            else
                die 'error: "--mask" requires a mask image'
            fi
            ;;
        --mask=?*)
            mask=${1#*=} # delete everything up to the equal sign and use the rest
            ;;
        --mask=) # handle empty mask string
            die 'error: "--mask" requires a mask image'
            ;;
        -t|--temp) # keep temp files
            temp="YES"
            ;;
        --) # end of all options
            shift
            break
            ;;
        -?*)
            printf 'warning: unknown option (ignored): %s\n' "$1" >&2
            ;;
        *) # default case, no options
            break
    esac
    shift
done

# N4 binary
n4="crlN4biasfieldcorrection"

# Verify arguments
if [ $# -eq 0 ] ; then
    show_help
    exit
fi

# Input stack
if [ ! -e $1 ] ; then
	echo "error: Could not find "$1". Exiting"
	show_help
    exit 1
fi

# Number of N4 iterations
re='^[0-9]+$'
if ! [[ $2 =~ $re ]] ; then
    echo "error: $2 (#iterations) was not a whole number"
    show_help
    exit 1
fi

#set variables
input=`readlink -f $1`
base=`basename $input`
dir=`dirname $input`
i=0
log="${dir}/run-n4-${base}.sh"
its="$2"
echo "N4 fix bias input: $input"
echo "Iterations: $its"
if [[ -f $log ]] ; then rm -v $log ; fi

# Select mask
tempmask="${dir}/TEMPmask_${base}"
if [ $mask ] ; then
    finalmask="${dir}/mask_r3Drecon_registration.nii.gz"
    echo "input mask: $mask"
    echo "Masking connected components for mask"
    cmd="crlMaskConnectedComponents $mask $finalmask 1 500"
    $cmd
    echo $cmd >> $log
    cmd="cp $finalmask -v $tempmask"
    $cmd
    echo $cmd >> $log
else
    # Threshold image to get mask
    echo "Binary threshold (temp mask)"
    cmd="crlBinaryThreshold ${input} ${tempmask} 0.5 40000 1 0"
    $cmd
    echo $cmd >> $log
fi

# Recursive N4 executions
while [ $i -lt $its ] ; do
	output="${dir}/biastemp${i}_${base}"
    # N4 binary
	echo "Bias correction step ${i} ..."
	cmd="$n4 $input $output $tempmask"
    $cmd
    echo $cmd >> $log
    # Match original intensity range
    cmd="crlMatchMaxImageIntensity $input $output $output"
    $cmd
    echo $cmd >> $log
    cmd="crlNoNegativeValues $output $output"
    $cmd
    echo $cmd >> $log
	# reset variables
	input="${output}"
    ((i++))
done

if [ $its = 0 ] ; then
    echo "Zero iterations specified. If -mask is set, script will crop the input image"
    output="${dir}/biastemp_${base}"
    cmd="cp $input -v $output"
    $cmd
    echo $cmd >> $log
fi

if [ $mask ] ; then
    echo "Mask supplied- cropping output N4 corrected image"
    cmd="crlMaskImage $output $finalmask ${dir}/mb${base}"
    $cmd
    echo $cmd >> $log
fi

#cleanup
if [[ $its -gt 0 ]] ; then
    mv -v $input ${dir}/b${base}
fi
rm -v ${tempmask}
if [[ ! $temp == "YES" ]] ; then
	rm -v ${dir}/*(biastemp*_${base})
fi
echo "done!"
