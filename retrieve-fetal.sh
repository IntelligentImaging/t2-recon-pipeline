#!/bin/bash 

#Set the path to DCMTK 
export DCMTK="/opt/el7/pkgs/dcmtk/dcmtk-3.6.4/bin"

if [[ $# -lt 4 ]]; then echo $0 [MRN] [YYYYMMDD] [OUTPUT DIRECTORY] [MODALITY] ; exit ; fi

PatientID=$1 
StudyDate=$2
output_dir=$3
Modality=$4

if [[ ! $Modality == "MR" ]] ; then echo "MODALITY should usually be 'MR'. If not, comment this line." ; exit ; fi

export PatientID StudyDate output_dir 

mkdir -vp $output_dir

#Searches dcmdump for value of specific tag
get_tag() { $DCMTK/dcmdump +P "$1" "$2" | grep -o -P '(?<=\[)(.*?)(?=\])'; }

#Sorts DICOMs by PatientID, Accession Number, and Series 
sortd() { 
patient=`get_tag PatientID $1`
study=`get_tag StudyID $1` 
series=`get_tag SeriesDescription $1` 
seriesnum=`get_tag SeriesNumber $1`
dpath="$output_dir"/"$patient"/"DICOM"/"$seriesnum"_"$series"
if [[ ! "$patient" == "" ]] && [[ ! "$study" == "" ]] && [[ ! "$seriesnum" == "" ]] && [[ ! "$series" == "" ]] ; then 
 if [[ ! -d "$dpath" ]]; then
  mkdir -vp "$dpath"
  mv --backup=t "$1" "$dpath"
 else
  mv --backup=t "$1" "$dpath"
 fi
else 
 echo missing dicom 'info', doing nothing
fi;
}

export -f get_tag sortd

#Return StudyInstanceUID for all studies with given PatientID, StudyDate, and Modality
$DCMTK/findscu -od $output_dir -X +sr -aet RESEARCHPACS -aec PACSDCM -S -k "QueryRetrieveLevel=STUDY" -k "PatientID=$PatientID" -k "StudyDate=$StudyDate" -k "Modality=$Modality" -k StudyInstanceUID  pacsstor.tch.harvard.edu 104

#Retrieve all matching studies for given DICOM query files
for d in $output_dir/rsp*.dcm; do 
	$DCMTK/getscu -od $output_dir -aet RESEARCHPACS -aec PACSDCM -S pacsstor.tch.harvard.edu 104 $d
done 

#Sort the DICOMs in output directory
find "$output_dir" -maxdepth 1 -type f -print | /home/ch163210/bin/parallel -j `nproc` -k sortd

