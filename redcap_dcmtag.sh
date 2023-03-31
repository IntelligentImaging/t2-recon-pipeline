#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-irb IRB number] -- [input] [output.csv]
    Incorrect input supplied
    Takes [input] raw fetal subject directory and spits out information needed to import to redcap
    Some useful column headers:
    mrn,redcap_event_name,medical_record_number,dob,scan_date,patient_weight,sex,fetal_baby,research_clinical,irb_name
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

# Optional arguments
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        -irb|--irbname)
            irb="$2"
            res="1"
            shift
            ;;
        -f|--fund)
            fund="$2"
            shift
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'warning: unknown option (ignored): %s\n' "$1" >&2
            ;;
        *) # default, no options
            break
    esac
    shift
done

if [ $# -ne 2 ] ; then
    show_help
    exit
fi

# check input
in=$1
if [[ ! -d $in ]] ; then
    echo No directory for $in found
    show_help
    exit 1
fi

# set filepaths
csv="$2"
id=`basename $in`
id2=`echo $in | sed 's,f,,g'`
noscan=`echo $id2 | sed 's,s.*,,g'`
scan=`echo $id2 | sed 's,.*s\(.*\),\1,g'`
arm=`echo $id | sed -e 's,.*s,,g' -e 's,\([0-9]\),scan0\1_arm_1,g'`
di=`find $id -type d -name DICOM | head -n1`
if [[ ! -d $di ]] ; then
    echo "Subject ID ${id2} - no DICOM folder"
    die
fi
cervix=`find $di -type d -name 2_\* -o -iname \*CERVIX\* -o -iname \*localizer\* -o -iname \*PLANE_LOC\* | head -n1`
if [[ ! -d $cervix ]] ; then
    echo "Subject ID ${id2} No CERVIX or localizer scan"
    die
fi
dcm=`find $cervix -type f | head -n1`

# extract DICOM TAGS
fullname="`dcmdump $dcm | grep -i PatientName | head -n1 | sed -e 's,.*\[,,g' -e 's,\].*,,g' -e 's,\^, ,g'`"
mrn=`dcmdump $dcm | grep -i PatientID | head -n1   | sed -e 's,.*\[,,g' -e 's,\].*,,g'`
birth=`dcmdump $dcm | grep -i BirthDate | head -n1 | sed -e 's,.*\[,,g' -e 's,\].*,,g' -e 's/./&-/4' -e 's/./&-/7'`
fetal="1" # this script is for fetals
dos=`dcmdump $dcm | grep -i StudyDate | head -n1   | sed -e 's,.*\[,,g' -e 's,\].*,,g' -e 's/./&-/4' -e 's/./&-/7'`
weight=`dcmdump $dcm | grep -i Weight | head -n1   | sed -e 's,.*\[,,g' -e 's,\].*,,g'`
height=`dcmdump $dcm | grep -i PatientSize | head -n1   | sed -e 's,.*\[,,g' -e 's,\].*,,g'`
sex=`dcmdump $dcm | grep -i PatientSex | head -n1  | sed -e 's,.*\[,,g' -e 's,\].*,,g' -e 's,F,1,g' -e 's,M,2,g'`
acc=`dcmdump $dcm | grep -i AccessionN | head -n1  | sed -e 's,.*\[,,g' -e 's,\].*,,g'`
mri=`dcmdump $dcm | grep -i ModelName | head -n1   | sed -e 's,.*\[,,g' -e 's,\].*,,g'`
loc=`dcmdump $dcm | grep -i StationN | head -n1    | sed -e 's,.*\[,,g' -e 's,\].*,,g'`

# translate scanner name to Redcap code
prisma=`echo $mri | grep -i prisma`
if [[ -n $prisma ]] ; then mri2="5" ; fi
skyra=`echo $mri | grep -i skyra`
if [[ -n $skyra ]] ; then mri2="3" ; fi
vida=`echo $mri | grep -i vida`
if [[ -n $vida ]] ; then mri2="6" ; fi
trio=`echo $mri | grep -i trio`
if [[ -n $trio ]] ; then mri2="4" ; fi
signa=`echo $mri | grep -i signa`
if [[ -n $signa ]] ; then mri2="0" ; fi
avanto=`echo $mri | grep -i avanto`
if [[ -n $avanto ]] ; then mri2="1" ; fi
if [[ ! -n $mri2 ]] ; then mri2="FIXSCRIPT" ; fi

# translate location to Redcap code
if [[ $loc == "2BPMRI_1" ]] ; then
    loc2="5"
    # may need to add more elif statements here in the futre
else loc2="1"
fi

# split name to last and first
last="${fullname%% *}"
first="${fullname#* }"

# clear fields not needed for scan2's
if [[ $scan -ne 1 ]] ; then
    last=""
    first=""
    mrn=""
    birth=""
    fetal=""
    height=""
    weight=""
    sex=""
fi

# if sequences are present in the DICOM folder, we'll add checkmarks to the redcap
f_haste=`find $di -type d -iname \*T2_HASTE\*` ;     if [[ -n $f_haste ]] ;  then haste="1" ; fi # type___0
f_dti=`find $di -type d -iname \*BRAIN\?DTI\*` ;   if [[ -n $f_dti ]] ;    then dti="1" ; fi # type___5
f_dtib=`find $di -type d -iname \*BRAIN\?DTI\*1000 -o -iname \*DTI\*3Shells\* -o -iname \*DTI\*500\*750\* -o -iname \*MultiB\*` ; if [[ -n $f_dtib ]] ;   then dti="1" ; dtib="1" ; fi # brain_dwi_bvalues
f_fmri=`find $di -type d -iname \*rs\?fMRI\*` ;       if [[ -n $f_fmri ]] ;   then fmri="1" ; fi # type___10
f_epi=`find $di -type d -iname \*EPI_highres\*` ;    if [[ -n $f_epi ]] ;    then epi="1" ; fi # type___4
f_zoomit=`find $di -type d -iname \*zoom\*` ;       if [[ -n $f_zoomit ]] ;  then zoomit="1"; fi # type___21
f_hasteDL=`find $di -type d -iname \*DLonur\* -o -iname \*HASTE_WIP\*` ;   if [[ -n $f_hasteDL ]] ;  then hasteDL="1" ; fi # type___32
f_dualecho=`find $di -type d -iname \*dualecho\*` ;   if [[ -n $f_dualecho ]] ;  then dualecho="1" ; fi # type___11 

# If CSV doesn't exist yet, write headers for Redcap
if [[ ! -f $csv ]] ; then
   echo "mrn,redcap_event_name,last_name,first_name,medical_record_number,dob,fetal_baby,normal_abnormal,research_clinical,irb_name,fund,scan_date,accession,scanner,site,patient_height,patient_weight,sex,brain_imagetype___0,brain_imagetype___5,brain_dwi_bvalues,brain_imagetype___10,brain_imagetype___4,brain_imagetype___21,brain_imagetype___23,brain_imagetype___11,pipelines___2,pipelines___5" > $csv
fi

# Write subject rows for Redcap
echo "$noscan,$arm,"$last","$first",$mrn,$birth,$fetal,,$res,$irb,$fund,$dos,$acc,$mri2,$loc2,$height,$weight,$sex,$haste,$dti,$dtib,$fmri,$epi,$zoomit,$hasteDL,$dualecho,1,1" >> $csv
# Echo result
echo "$noscan,$arm,"$last","$first",$mrn,$birth,$fetal,,$res,$irb,$fund,$dos,$acc,$mri2,$loc2,$height,$weight,$sex,$haste,$dti,$dtib,$fmri,$epi,$zoomit,$hasteDL,$dualecho,1,1"
