#!/bin/bash 

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-m MODALITY] [-a] -- [MRN] [DOS] [Output Dir]
    Incorrect input supplied
    -m      Modality (default=MR)
    -a      Anonymize patient ID that goes into folder path (MRN replaced with "anon")
    -n      No separate study folder. All DICOMs will go into a single folder named "DICOM", not separated by StudyID. This is OK if you are manually separating scan sessions into different directories.
    -p      Number of parallel processes for sorting DICOM files (default=24). Greatly speeds up sort step.
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
        -a|--anon)
            let anon=1
            ;;
        -n|--nostudy)
            let nostudy=1
            ;;
        -p|--threads)
            if [[ -n $2 ]] ; then
                let threads=$2 # Set number of threads
                shift
            else
                die 'error: number of threads not set'
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

if [[ ! -n $threads ]] ; then
    let threads=24
fi

PatientID=$1 
StudyDate=$2
output_dir=$3
if [[ ! -n $Modality ]] ; then Modality="MR" ; fi

export PatientID StudyDate output_dir 
mkdir -vp $output_dir

# Searches dcmdump for value of specific tag
get_tag() { dcmdump +P "$1" "$2" | grep -o -P '(?<=\[)(.*?)(?=\])'; }

# Sorts DICOMs by PatientID, Accession Number, and Series 
sortd() { 
patient=`get_tag PatientID $1`
study=`get_tag StudyID $1` 
series=`get_tag SeriesDescription $1` 
seriesnum=`get_tag SeriesNumber $1`
if [[ $anon -eq 1 ]] ; then
    dpatient="${output_dir}/anon"
else
    dpatient="${output_dir}"/"${patient}"
fi
if [[ $nostudy -eq 1 ]] ; then
    ddicom="${dpatient}/DICOM"
else
    ddicom="${dpatient}/${study}/DICOM"
fi
dpath="${ddicom}/${seriesnum}_${series}"

if [[ ! "$patient" == "" ]] && [[ ! "$study" == "" ]] && [[ ! "$seriesnum" == "" ]] && [[ ! "$series" == "" ]] ; then 
    mkdir -vp "$dpath"
    mv --backup=t "$1" "$dpath"
else 
    echo item == $dcm == missing dicom 'info', doing nothing
fi
} # End of sort function

# export -f get_tag sortd

#Return StudyInstanceUID for all studies with given PatientID, StudyDate, and Modality
findscu -od $output_dir -X +sr -aet RESEARCHPACS -aec PACSDCM -S -k "QueryRetrieveLevel=STUDY" -k "PatientID=$PatientID" -k "StudyDate=$StudyDate" -k "Modality=$Modality" -k StudyInstanceUID  pacsstor.tch.harvard.edu 104

#Retrieve all matching studies for given DICOM query files
for d in $output_dir/rsp*.dcm; do 
	echo
	getscu -od $output_dir -aet RESEARCHPACS -aec PACSDCM -S pacsstor.tch.harvard.edu 104 $d
done 

echo Sort DICOMs
let npr=0
for mr in ${output_dir}/MR* ; do
    fout=`file $mr | grep DICOM`
    if [[ -n $fout ]] ; then # check if it's a DICOM
        # Do the sorting as background processes (multi-threaded) up to the number specified in the threads variable
        # echo dcm=$mr npr=$npr threads=$threads # uncomment to get verbose about multi-threading
        sortd $mr &
        ((npr++))
        if [[ ! $npr -lt $threads ]] ; then
            wait
            let npr=0
        fi
    fi
done
wait

echo Remove rsp and report files
rm -fv ${output_dir}/rsp*dcm ${output_dir}/SR* ${output_dir}/PS* ${output_dir}/RAW.*
 
echo Detox DICOM folder
find $output_dir -type d -name DICOM -exec detox {} \;
#detox ${output_dir}/*/DICOM ${output_dir}/*/*/DICOM
