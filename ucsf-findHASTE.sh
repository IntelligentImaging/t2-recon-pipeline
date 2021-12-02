#!/bin/bash
show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input] [study recon dir]
    Incorrect input supplied
EOF
}

if [[ $# -ne 2 || ! -d $1 ]]; then
    show_help
    exit
fi 

id=$1
nii=${id}/nii
recondir=$2
odir="${recondir}/${id}/nii"

echo "# # # Subject $nii # # #"
mkdir -pv $odir
for acq in ${nii}/* ; do
    if [[ -d $acq ]] ; then
        echo
        # Some HASTE have extra Eq image so those are excluded
        im=`find ${acq} -name \*nii.gz -a ! -name \*Eq_1.nii.gz`
        wc=`echo $im | wc -w`
        echo Acquisition: $acq
        echo Number of NIFTIs: $wc
        # Ignore multi-volume series
        if [[ ! $wc -eq 1 ]] ; then
            echo "Multivolume acquisition - not HASTE. Skipping."
            continue
        fi
        echo "NIFTI: $im"
        # Get dimensions (we only want 3D images
        dims=`fslhd $im | grep dim0 | grep -v pix | sed 's,.*\([0-9]\),\1,g'`
        echo Number of dimensions: $dims
        if [[ ! $dims -eq 3 ]] ; then
            echo "Not 3D image - Skipping"
            continue
        fi
        # Get image info
        dim1=`fslhd $im | grep pixdim1 | sed 's,.*dim1\?,,g'`
        dim3=`fslhd $im | grep pixdim3 | sed 's,.*dim3\?,,g'`
        echo "dim1 = $dim1 (we want 0.something here)"
        echo "dim3 = $dim3 (we want 2. or 3.something here)"
        ddim1=`echo $dim1 | sed 's,\..*,,g'`
        ddim3=`echo $dim3 | sed 's,\..*,,g'`
        echo "First digits: $ddim1 and $ddim3"
        if [[ $ddim1 -gt 1 || $ddim3 -gt 3 ]] ; then
            echo "Image spacing isn't right for HASTE - Skipping"
            continue
        else echo "We shall copy $im"
            base=`basename $im`
            fetus="fetus${base}"
            cp $im -vn ${odir}/${fetus}
        fi
    fi
done
