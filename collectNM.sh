#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input list]
    Incorrect input supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 
if [[ ! -f $1 ]] ; then
    echo $1 doesnt exist
    exit
fi

out="collect_niftymics"

# Look through the niftymic folders and pull recons
while read id ; do
	tspace="${id}/niftymic/srr/recon_template_space"

	if [[ -d $tspace ]] ; then 
		srr=${tspace}/srr_template.nii.gz
		mask=${tspace}/srr_template_mask.nii.gz

		outsrr="${out}/${id}-srr_template.nii.gz"
		outmask="${out}/${id}-srr_template_mask.nii.gz"
		cp $srr -vup $outsrr
		cp $mask -vup $outmask
	fi
done < $1

mkdir -pv $out 
# Crop recons with masks
for im in collect_niftymics/*-srr_template.nii.gz ; do
    base=`basename $im`	
    echo $base
    edit=`echo $im | sed -e 's,srr_template,srr_template_maskEDIT,'`

    # Check if an edited mask exists
    # If needed edit a mask and append EDIT before the .nii.gz extension
    if [[ -f $edit ]] ; then
        mask=$edit
    else mask=`echo $im | sed -e 's,srr_template,srr_template_mask,'`
    fi

    crop=`echo $base | sed -e 's,srr,msrr,'`

    if [[ ! -f collect_niftymics/cropped/$crop ]] ; then
        crlMaskImage $im $mask collect_niftymics/cropped/$crop
    fi

done
