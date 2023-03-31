#!/bin/bash 

#Set the path to DCMTK 
export DCMTK="/opt/el7/pkgs/dcmtk/dcmtk-3.6.4/bin"

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-m MODALITY] -- [MRN] [DOS] [Output Subject Dir]
    Incorrect input supplied
    -m      Modality (default=MR)
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
        -m|--modality)
            if [[ -n "$2" ]] ; then
                Modality=$2 # Specify modality
                shift
            else
                die 'error: Modality not specified (default=MR)'
            fi
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

if [ $# -ne 3 ]; then
    show_help
    exit
fi 

PatientID=$1 
StudyDate=$2
output_dir=$3
if [[ ! -n $Modality ]] ; then Modality="MR" ; fi

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

