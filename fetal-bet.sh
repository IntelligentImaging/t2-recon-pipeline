#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-p PREFIX] [-s] [-d] -- [input directory]
    Incorrect input supplied

	Runs FETAL-BET for the input directory

    -p      Set input stack file prefix (default=fetus)
	-s	SINGLE MODE: chooses only the middle (alphabetical) image to mask
	-d	Dilate result by 2
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
        -p|--prefix)
            if [[ -n "$2" ]] ; then
                PREF="$2" # Specify prefix for input images
                shift
            else die 'error: no prefix supplied'
            fi
            ;;
        -s|--single)
	    let SINGLEMODE=1
            ;;
        -d|--dilate)
            if [[ $2 -gt 0 ]] ; then
                let DILATE=$2
            else die 'error: provide dilation factor (usually 1-4)'
            fi
            shift
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

if [[ ! -n $PREF ]] ; then
    PREF="fetus"
fi


inpath=$1
segin=${inpath}/FETALBET
mkdir -pv ${segin}

if [[ $SINGLEMODE = 1 ]] ; then
	ims=`find ${inpath} -maxdepth 1 -type f -name ${PREF}\*z -a ! -name \*mask\*`
	count=`find ${inpath} -maxdepth 1 -type f -name ${PREF}\*z -a ! -name \*mask\* | wc -w`
	half=`echo "$count / 2" | bc`
	chosen=`ls ${inpath}/${PREF}*z | sed -n "${half}p"`
	cp $chosen -v ${segin}
else
	cp ${inpath}/${PREF}* -v ${segin}/
fi

singularity exec docker://arfentul/fetalbet-model:first /bin/bash -c "python /app/src/codes/inference.py --data_path ${segin}/ --save_path ${inpath} --saved_model_path /app/src/model/AttUNet.pth"

for mask in ${inpath}/*_predicted_mask.nii.gz ; do
	if [[ -f $mask ]] ; then
		if [[ $DILATE > 0 ]] ; then
			# crlBinaryMorphology ${mask} dilate 1 ${DILATE} ${mask} # grow mask by DILATE factor
            maskfilter ${mask} dilate -npass ${DILATE} ${mask} -force
            maskfilter -largest ${mask} connect ${mask} -force # mask out all but the largest body of voxels
		fi

		base=`basename $mask`
		want=`echo $base | sed -e 's,\(.*\)_predicted_mask,mask_\1,g'`

		mrconvert ${mask} ${mask} -datatype int16 -force # SVRTK doesn't take int32, which fetal-bet seems to produce sometimes...
        mv -v ${mask} ${inpath}/${want}
	fi
done
