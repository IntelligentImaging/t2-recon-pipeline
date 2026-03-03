#!/bin/bash

if [[ $# -lt 2 || $# -gt 2 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [RAW CASE DIR] [GENERAL PROC DIR]"
	echo "This script assumes that [RAW CASE DIR] is either arranged:"
	echo " CASE/[NUMERICAL INDIV DICOM DIRS] or CASE/scans/[NAMED INDIV DICOM DIRS]"
	exit
	fi

SHDIR=`dirname $0`
RAW="$1"
PROC="$2"
# RUNCHECK="$3"
ID=`basename $RAW`
DCMDIR="${RAW}/scans"
NIIDIR="${RAW}/nii"
# NET="/fileserver/fetal/software/2Ddensenet"

function depchk () {
	if command -v $1 >/dev/null 2>&1 ; then
	    echo "$1 found"
	    echo "version: $($1 --version)"
	else
	    echo "$1 not found"
	    exit 1
	fi
	}

function DCMrename () {
	EX=`find ${SERIES} -type f -iname \*.dcm | head -n1`
	EXDIR=`dirname $EX`
	TAG=`dcmdump $EX | grep SeriesDesc`
	EDIT1=${TAG#*[}
	EDIT2=${EDIT1%]*}
	DESC=`echo "${EDIT2}" | detox --inline | sed -e 's,=,,g'`
	# rename the directory
	mv -v ${EXDIR} ${DCMDIR}/${BASESERIES}_${DESC}
	}

depchk rename
depchk dcm2niix

# Rename DICOM directories and move them to a subfolder
# rename -v secondary DICOM ${RAW}/*/secondary
mkdir -pv ${DCMDIR}
for SERIES in ${RAW}/* ; do
	BASESERIES=`basename $SERIES`
	if [[ $BASESERIES =~ ^[0-9](|[0-9])(|[0-9])(|[0-9])(|[0-9])$ ]] ; then
		echo rename $BASESERIES
		DCMrename
	fi
done

detox ${RAW}/scans

rmdir ${RAW}/*

bash ${SHDIR}/prep-fetal.sh ${RAW} ${PROC}

