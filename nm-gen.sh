#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [niftymic case directory]
    Incorrect input supplied
    Required: In CASEFOLDER, create a directory
    named 't2' and copy all input T2
    stacks there, then run this script

    Optional argument:
	[ -a || --alpha ]   Set regularization for recon (default is 0.04) 
	[ -r || --resolution ]	Output resolution (default is .8)

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
        -a|--alpha)
            if [[ "$2" ]] ; then
                alpha=$2
                echo Alpha set to $alpha
                shift
            else
                die 'error: --alpha requires a number'
            fi
            ;;
	 -r|--resolution)
	    if [[ "$2" ]] ; then
		    reso=$2
		    echo resolution set to $reso
		    shift
	    else
	       die 'error: --resolution requires a number'
	    fi
	    ;;
         -?*)
             printf 'warning: unknown option -- ignored: %s\n' "$1" >&2
             ;;
         *) # Default case, no options
             break
     esac
     shift
done

if [ $# -ne 1 ]; then
    show_help
    exit
fi 

# Set variables
nmic=`readlink -f $1`
t2dir="${nmic}/t2"
if [ ! -d "${t2dir}" ]; then  
    echo "$t2dir directory not present"
    echo "Create this directory and copy T2 stacks there first"
    exit
fi
maskdir="${nmic}/mask"
mkdir -pv ${maskdir}
srrdir="${nmic}/srr"
if [[ ! -n $alpha ]] ; then alpha="0.04" ; fi
if [[ ! -n $reso ]] ; then reso=".8" ; fi

# Run scripts
shsfb="${nmic}/run-sfb.sh"
shpipe="${nmic}/run-nm.sh"
if [ -f $shsfb ] ; then rm -v $shsfb ; fi
if [ -f $shpipe ] ; then rm -v $shpipe ; fi

# get list of stacks
t2s=`find ${t2dir} -type f -name fetus\*z`
# write segment fetal brains script
echo "#!/bin/bash" >> $shsfb
echo "niftymic_segment_fetal_brains --filenames \\" >> $shsfb
for stack in $t2s ; do
    t2base=`basename $stack`
	echo "t2/${t2base} \\" >> $shsfb
done
echo "--filenames-masks \\" >> $shsfb
for stack in $t2s ; do
    maskbase=`basename $stack` 
	echo "mask/${maskbase} \\" >> $shsfb
done

# write reconstruction pipeline script including
#   bias field correction
#   subject space recon (niftymic_reconstruct_volume)
#   template space alignment (niftymic_register_image)
#   template space recon (niftymic_reconstruct_volume_from_slices)
echo "#!/bin/bash" >> $shpipe
echo "niftymic_run_reconstruction_pipeline --filenames \\" >> $shpipe
for stack in $t2s ; do
    t2base=`basename $stack`
	echo "t2/${t2base} \\" >> $shpipe
done
echo "--filenames-masks \\" >> $shpipe
for stack in $t2s ; do
    maskbase=`basename $stack`
	echo "mask/${maskbase} \\" >> $shpipe
done
echo "--dir-output srr/ \\" >> $shpipe
echo "--alpha $alpha \\" >> $shpipe
echo "--isotropic-resolution $reso \\" >> $shpipe

# Open permissions so docker sudo can access
echo "Opening permissions for Docker"
find ${nmic} -type d -exec chmod -c --preserve-root 777 {} \;
