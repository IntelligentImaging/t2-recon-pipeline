#!/bin/bash

edir=/lab-share/Rad-Gholipour-e2/Public/fetalmri/segmentation/GEPZ/edits

for seg in ${edir}/GEPZ/*-edit.nii.gz ; do
    
    base=`basename $seg`
    id=`echo $base | sed -e 's,_MAS.*,,g' -e 's,atlas_niftymic_,,g' -e 's,atlas_t2final_,,g' -e 's,_30cc,,g'`
    subj=`echo $id | sed -e 's,\(.*\)s[0-9],\1,g'`
    scan=`echo $id | sed -e 's,.*\(s[0-9]\),\1,g'`
    echo $id $subj $scan

    let WMZ=0 ; if [[ $base == *"WMZ"* ]] ; then let WMZ=1 ; fi
    if [[ $base == *"t2final"* ]] ; then 
        METHOD="SVRTK"
    elif [[ $base == *"niftymic"* ]] ; then
        METHOD="niftymic"
    else
        echo couldnt figure out METHOD
        continue
    fi

    odir="/lab-share/Rad-Gholipour-e2/Public/fetalmri/dwi2023/protocols/processed/sub-${subj}/${scan}/anat"
    mkdir -pv ${odir}

    if [[ $WMZ = 0 ]] ; then 
        out="${odir}/sub-${subj}_${scan}_rec-${METHOD}_desc-MAS-edit_t2w.nii.gz"
    else
        out="${odir}/sub-${subj}_${scan}_rec-${METHOD}_desc-MAS-WMZ-edit_t2w.nii.gz"
    fi

    cp $seg -vup $out 

done
