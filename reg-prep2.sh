#!/bin/bash
shopt -s extglob

if [[ $# -lt 1 || $# -gt 3 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [Best Recon Orientation] [opt: #iterations] [opt: --temp]"
    echo
    echo "Sets up recon registration to atlas space including"
    echo "directory tree and N4 bias correction"
    echo 
    echo " [#iterations] (default 3) number of N4 b0-inhomogeneity"
    echo "                           correction recursive loops"
    echo " [--temp] if set, temporary recurions will be preserved"
    echo "                           (biastemp0, biastemp1, etc)"
	exit
	fi

# N4 binary
n4="crlN4biasfieldcorrection"

# Verify arguments
# Input stack
if [ ! -e $1 ] ; then
    echo "Could not find "$1". Exiting"
    exit 1
fi

# Number of N4 iterations
re='^[0-9]+$'
if ! [[ $2 =~ $re && $2 -ne 0 ]] ; then
    echo "error: 2nd argument #iterations was not a natural number."
    echo "sh $0 for full instructions"
    exit 1
fi

# Select whether to retain intermediary N4 corrections
if [[ ! $3 == "-t" && ! $3 == "" ]] ; then
    echo "error: 3rd argument should be '--temp' or be omitted."
    echo "sh $0 for full instructions"
    exit 1
fi

# Set naming conventions
RECON=`readlink -f $1`
echo "Try compress"
gzip -v $RECON
RECONDIR=`dirname $RECON`
REGDIR="${RECONDIR}/registration"
BASE=`basename $RECON`
ITS="$2"
TEMP="$3"
LOG="${REGDIR}/run-reg-prep.txt"
# The chosen orientation is renamed to "best"
if [[ ! $RECON = *"best"* ]] ; then
	BEST=`echo $RECON | sed 's,fetus_,fetus_best_,g'`
else
	BEST=$RECON
fi
mv -v ${RECON} ${BEST}
mkdir -pv ${REGDIR}

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
cmd="crlBinaryThreshold ${inN4} ${tempmask} 0.5 40000 1 0"
$cmd
echo $cmd > $LOG
while [ $i -lt $ITS ] ; do
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
mv -v $inN4 $biascorr
rm -v $tempmask
if [[ ! $TEMP == "--temp" ]] ; then
    rm -v ${REGDIR}/*(biastemp*_${BASE})
fi
echo "N4 bias correction done"

# Intensity correction (N4 changes intensity range)
REF="/fileserver/fetal/FCB/reference/T30template.nii"
echo "Match image intensities to reference image"
cmd="crlMatchMaxImageIntensity $REF $biascorr $maxcorr"
$cmd
echo $cmd >> $LOG
cmd="crlNoNegativeValues $maxcorr $finalcorr"
$cmd
echo $cmd >> $LOG

# Open permissions for group to write
find ${REGDIR} -type d -exec chmod -c --preserve-root 770 {} \;
chmod 660 ${REGDIR}/mask.nii.gz
