#!/bin/bash 
# This version of the script does not put PID in the directory names

if [[ $# -lt 4 ]]; then echo $0 [MRN] [YYYYMMDD] [MODALITY] [OUTPUT DIRECTORY] ; exit; fi

# set arguments and binaries
mrn="$1"
studydate="$2"
modality="$3"
outdir="$4"
dcm4che="/opt/el7/pkgs/dcm4che/dcm4che-5.11.0/bin/"
dcmtk="/opt/el7/pkgs/dcmtk/3.6.1-20161102/bin/"
export outdir dcm4che dcmtk modality

# function: get DICOM tag, search for term, translate spaces to underscore
get_tag() { $dcmtk/dcmdump "$1" | grep "$2" | head -1 | awk '$0=$2' FS=[ RS=] | tr " " "_"; } 

# function: multiple search terms -- use get_tag() multiple times
sortd() { 
patient=`get_tag "$1" 'PatientID'`
study=`get_tag "$1" 'AccessionNumber'`
series=`get_tag "$1" 'SeriesDescription'`
seriesnum=`get_tag "$1" 'SeriesNumber'`

# output directory tree
dpath="$outdir"/anon/DICOM/"$seriesnum"_"$series"

# check to see target is DICOM
if [[ ! "$patient" == "" ]] && [[ ! "$study" == "" ]] && [[ ! "$seriesnum" == "" ]] && [[ ! "$series" == "" ]] ; then 
	# make directory tree
	if [[ ! -d "$dpath" ]] ; then 
		mkdir -vp "$dpath"
		mv -v --backup=t "$1" "$dpath"
	else
		mv -v --backup=t "$1" "$dpath"
	fi 
else 
	echo missing dicom 'info', doing nothing 
fi  
}

export -f get_tag sortd

StudyUIDs=("${StudyUIDs[@]}" `$dcm4che/findscu -c PACSDCM@pacsstor.tch.harvard.edu:104 -b RESEARCHPACS -L STUDY -M StudyRoot -mPatientID="$mrn" -mStudyDate="$studydate" -mModalitiesInStudy=$modality -rStudyInstanceUID | grep 0020,000D | awk '$0=$2' FS=[ RS=]`)

# actually get the data
for s in  ${StudyUIDs[@]}; do 
 $dcm4che/movescu -c PACSDCM@pacsstor.tch.harvard.edu:104 -b RESEARCHPACS --dest RESEARCHPACS -L STUDY -M StudyRoot -mStudyInstanceUID="$s" -mModalitiesInStudy=$modality
 $dcm4che/getscu -c RESEARCHPACS@researchpacs:11112 -L STUDY -M StudyRoot -mStudyInstanceUID="$s" -mModalitiesInStudy=$modality --directory "$outdir"
done

# run function sortd in parallel
if [[ -d "$outdir" ]] ; then 
	find "$outdir" -maxdepth 1 -type f -print | /home/ch163210/bin/parallel -j `nproc` -k sortd 
	rm -v "$outdir"/1.*
else
	echo "$outdir not created. It's likely the data was not pulled"
	echo "Either the MRN/date/modality was wrong, or there were no images"
	exit
fi
