#!/bin/bash

if [[ $# -lt 2 || $# -gt 2 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [SCAN DICOM DIR] [GENERAL PROC DIR]"
	echo "This script assumes that [RAW CASE DIR] is either arranged:"
	echo " CASE/[NUMERICAL INDIV DICOM DIRS] or CASE/scans/[NAMED INDIV DICOM DIRS]"
	exit
	fi

SHDIR=`dirname $0`
PROC="$2"
DCMDIR="$1"
SUBJDIR=`dirname $DCMDIR`
NIIDIR="${SUBJDIR}/nii"

function depchk () {
	if command -v $1 >/dev/null 2>&1 ; then
	    echo "$1 found"
	    echo "version: $($1 --version)"
	else
	    echo "$1 not found"
	    exit 1
	fi
	}

depchk rename
depchk dcm2niix

# Rename DICOM directories and move them to a subfolder
for SERIES in ${DCMDIR}/* ; do
	if [[ -d $SERIES ]]  ; then
		echo rename $SERIES

		EX=`find ${SERIES} -type f -iname \*.dcm -o -iname \*.DCM | head -n1`
		EXDIR=`dirname $EX`

		TAGdesc=`dcmdump $EX | grep SeriesDesc`
		dEDIT1=${TAGdesc#*[}
		dEDIT2=${dEDIT1%]*}
		DESC=`echo "${dEDIT2}" | detox --inline | sed -e 's,=,,g' -e 's/,//g'`
		
		TAGnum=`dcmdump $EX | grep SeriesNumber`
		nEDIT1=${TAGnum#*[}
		nEDIT2=${nEDIT1%]*}
		NUM=`echo "${nEDIT2}"`


		# rename the directory
		mv -v ${EXDIR} ${DCMDIR}/${NUM}_${DESC}
	fi
done

detox ${DCMDIR}/*

bash ${SHDIR}/prep-fetal.sh ${SUBJDIR} ${PROC}

