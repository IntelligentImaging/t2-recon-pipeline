#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input dicom dir] [output converted dir]
    Incorrect input supplied

	Uses Simon's CRL-dicom-tools docker to convert images
	Container utilizes dcmdjpeg for decompression, pydicom for naming, dcm2niix for conversion
	Apptainer sif built from git lab CRL docker
EOF
}

if [ $# -ne 2 ]; then
    show_help
    exit
fi 

if [[ ! -d $1 ]] ; then show_help ; exit ; fi

mkdir -pv $2

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/uncompress_dicoms.py ${1} ${2}/dicomdir-uncompressed"

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/sort_dicoms.py ${2}/dicomdir-uncompressed ${2}/dicomdir-sorted"

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/dicom_tree_to_nifti.py  ${2}/dicomdir-sorted  ${2}/dicomdir-converted"

