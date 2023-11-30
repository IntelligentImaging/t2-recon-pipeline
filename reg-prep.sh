#!/bin/bash
shopt -s extglob


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input]
    Incorrect input supplied

	Incorrect argument supplied!
	usage: sh $0 [-n] [-t] [-m] -- [Best Recon Orientation] 
    Sets up recon registration to atlas space including directory tree and N4 bias correction

        [-n] number of N4 b0-inhomogeneity correction recursive loops (DEFAULT=3)
        [-t] if set, temporary recurions will be preserved (biastemp0, biastemp1, etc)
        [-m] performs Davood Karimi brain extraction (mask segmentation)
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        -n|--N4iterations)
            re='^[0-9]+$'
            if [[ $2 =~ $re ]] ; then
                ITS=$2
                echo "N4 iterations set to $ITS"
                shift
            else
                die 'error: "-n" requires a (whole) number of iterations'
                exit
            fi
            ;;
        -t|--temp)
            TEMP="YES"
            ;;
        -m|--mask)
            MASK="YES"
            ;;
        -?*)
            printf 'warning: unknown option -- ignored: %s\n' "$1" >&2
            ;;
        *) # default case no options
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


# N4 binary
n4="${FETALBIN}/crlN4biasfieldcorrection"

# Set naming conventions
RECON=`readlink -f $1`
echo "Try compress"
gzip -v $RECON
RECONDIR=`dirname $RECON`
REGDIR="${RECONDIR}/registration"
BASE=`basename $RECON`
LOG="${REGDIR}/run-reg-prep.sh"
# The chosen orientation is renamed to "best"
if [[ ! $RECON = *"best"* ]] ; then
	BEST=`echo $RECON | sed 's,fetus_,fetus_best_,g'`
else
	BEST=$RECON
fi
mv -v ${RECON} ${BEST}
mkdir -pv ${REGDIR}
# Remove un-chosen r3D's
rm -f ${RECONDIR}/r3DreconOfetus_?.nii.gz
rm -f ${RECONDIR}/r3DreconOfetus_??.nii.gz

# N4 bias correction (iterative loops)
i=0
inN4=$BEST
biascorr="${REGDIR}/b${BASE}"
maxcorr="${REGDIR}/xb${BASE}"
finalcorr="${REGDIR}/nxb${BASE}"
finalcorrBASE=`basename $finalcorr`
echo "N4 bias correction"
tempmask="${REGDIR}/TEMPmask_${BASE}"
echo "Creating mask"
# Threshold the entire image to get mask
# cmd="crlBinaryThreshold ${inN4} ${tempmask} 0.5 40000 1 0"
cmd="fslmaths ${inN4} -thr 0.5 -uthr 40000 -bin ${tempmask}"
$cmd
echo $cmd > $LOG
while [[ $i -lt $ITS ]] ; do
    biastemp="${REGDIR}/biastemp${i}_${BASE}"
    echo "Bias correction step ${i} ..."
    # N4 binary
    cmd="$n4 $inN4 $biastemp $tempmask"
    $cmd
    echo $cmd >> $LOG
    echo "Created $biastemp!"
    # Recurse
    inN4="$biastemp"
    ((i++))
done
# Cleanup N4 temp files
cp -v $inN4 $biascorr
rm -v $tempmask
if [[ ! $TEMP == "YES" ]] ; then
    rm -v ${REGDIR}/*(biastemp*_${BASE})
fi
echo "N4 bias correction done"

# Intensity correction (N4 changes intensity range)
REF="${FETALREF}/templates/ref/STA30.nii.gz"
echo "Match image intensities to reference image"
cmd="${FETALBIN}/crlMatchMaxImageIntensity $REF $biascorr $maxcorr"
$cmd
echo $cmd >> $LOG
cmd="${FETALBIN}/crlNoNegativeValues $maxcorr $finalcorr"
$cmd
echo $cmd >> $LOG

# Open permissions for group to write
find ${REGDIR} -type d -exec chmod -c --preserve-root 775 {} \;

# Davood Karimi Brain Extraction
if [[ $MASK == "YES" ]] ; then
    work="${REGDIR}/BE"
    mkdir -pv $work
    cp ${finalcorr} -v ${work}/
    # Open permission for docker
    chmod 777 $work
    echo "Running Davood Karimi brain extraction docker"
    docker run --mount src=$work,target=/src/test_images/,type=bind davoodk/brain_extraction
    seg=`find ${work}/segmentations -type f -name \*segmentation.nii.gz`
    cp ${seg} -v ${REGDIR}/mask.nii.gz
else echo "Brain extraction option not set"
fi
