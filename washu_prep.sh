#!/bin/bash

if [[ $# -lt 2 || $# -gt 2 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [RAW CASE DIR] [GENERAL PROC DIR]"
	echo "This script assumes that [RAW CASE DIR] is either arranged:"
	echo " CASE/[NUMERICAL INDIV DICOM DIRS] or CASE/scans/[NAMED INDIV DICOM DIRS]"
	exit
	fi

RAW="$1"
PROC="$2"
RUNCHECK="$3"
ID=`basename $RAW`
DCMDIR="${RAW}/scans"
NIIDIR="${RAW}/nii"
# NET="/fileserver/fetal/software/2Ddensenet"

function DCMrename () {
	TAG=`dcmdump \`find ${SERIES}/DICOM/ -type f -iname \*.dcm | head -n1\` | grep SeriesDesc`
	EDIT1=${TAG#*[}
	EDIT2=${EDIT1%]*}
	DESC=`echo $EDIT2 | sed 's/ /_/g'`
	# rename the directory
	mv -v ${SERIES} ${DCMDIR}/${BASESERIES}_${DESC}
	}

function convert () {
	BASE=`basename $DCM`
	OUT="${NIIDIR}/${BASE}"
	mkdir -pv ${OUT}
	if [[ ! -z `find ${OUT} -type f` ]] ; then
		echo "Skipping: Files already exist in ${OUT}"
	else
		echo "Converting $DCM"
		dcm2niix -z y -f %d_%s -o "${OUT}/" $DCM
		fi
	}

# Rename DICOM directories and move them to a subfolder
rename -v secondary DICOM ${RAW}/*/secondary
mkdir -pv ${DCMDIR}
for SERIES in ${RAW}/* ; do
	BASESERIES=`basename $SERIES`
	if [[ $BASESERIES =~ ^[0-9](|[0-9])$ ]] ; then
		DCMrename
		fi
	done

# Convert to NIFTI with dcm2niix
mkdir -pv ${NIIDIR}
if [[ ! -z `find ${DCMDIR} -mindepth 3 -type f -name \*dcm` ]] ; then
	for DCM in ${DCMDIR}/* ; do
		if [[ -d ${DCM} ]] ; then
			convert		
			fi
		done
else
	echo Conversion step error: DICOM files were not found
	fi

# Copy T2 stacks to reconstruction folder
RECON="${PROC}/${ID}/nii"
mkdir -pv ${RECON} ${RECON}/../notgood
find ${RECON}/../ -type d -exec chmod -c --preserve-root 777 {} \;
for IM in ${NIIDIR}/*T2*/*.nii.gz ; do
        base=`basename $IM`
        end="${base##*_}"
        new="fetus_${end}"
        cp ${IM} -v ${RECON}/${new}
        done

# # Install 2D Densenet to recon directory
# cp ${NET} -rv ${RECON}
# cp ${RECON}/fetus*z -v ${RECON}/2Ddensenet/InputData/
# echo "Recon Dir: ${RECON}"
# echo "Densenet Code Dir: ${RECON}/2Ddensenet/InputData/"
#
# if [[ $RUNCHECK = "-m" ]] ; then
#         echo "Starting python 2D densenet brain mask"
#         python ${RECON}/2Ddensenet/Code/FC-Dense-2D.py
# 	fi
