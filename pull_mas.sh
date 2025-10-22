#!/bin/bash

segdir=/lab-share/Rad-Gholipour-e2/Public/fetalmri/segmentation/GEPZ/proc

# Look through the segmentation processing directory, which is our final step
# for t2 images. Therefore, anything here is a finished scan.
# "t2final" are the SVRTK recons, "msrr" are the NiftyMIC recons
for fold in ${segdir}/atlas_t2final_f*  ; do
#for fold in ${segdir}/*t2final* ${segdir}/*msrr* ; do
    base=`basename $fold`
    # check if SVRTK or niftymic reconstruction was used
    if [[ $base == *"t2final"* ]] ; then METHOD="SVRTK" ; elif [[ $base == *"msrr"* ]] ; then METHOD="niftymic" ; else echo "idk which method $base is" ; continue ; fi
    
    # get the subj/scan id based on filename
    if [[ $METHOD == "SVRTK" ]] ; then
        id=`echo ${base#atlas_t2final_}`
        subj=`echo $id | sed -e 's,\(.*\)s[0-9],\1,g'`
        scan=`echo $id | sed -e 's,.*\(s[0-9]\),\1,g'`
    else
        id=`echo ${base%-msrr_template}`
        subj=`echo $id | sed -e 's,\(.*\)s[0-9],\1,g'`
        scan=`echo $id | sed -e 's,.*\(s[0-9]\),\1,g'`
    fi
    echo $id $subj $scan $METHOD
    t2w="${fold}/${base}.nii.gz"

    # categorize and copy segmentation based on naming in the segmentation directory
    for seg in ${fold}/PVC/*MAS*z ; do
        if [[ -f $seg ]] ; then
            segbase=`basename $seg`
            let WMZ=0
            if [[ $segbase == *"WMZ"* ]] ; then let WMZ=1 ; fi
            pdir="/lab-share/Rad-Gholipour-e2/Public/fetalmri/dwi2023/protocols/processed/sub-${subj}/${scan}/"
            odir="${pdir}/anat"
            mkdir -pv ${odir}

            if [[ $WMZ = 0 ]] ; then 
                out="${odir}/sub-${subj}_${scan}_rec-${METHOD}_desc-MAS_t2w.nii.gz"
            else
                out="${odir}/sub-${subj}_${scan}_rec-${METHOD}_desc-MAS-WMZ_t2w.nii.gz"
            fi

            cp $t2w -vnp ${odir}/sub-${subj}_${scan}_rec-${METHOD}_t2w.nii.gz
            cp $seg -vnp $out 
        fi
    done

    xdir="${pdir}/xfm"
    # This section finds the t2-to-atlas transform from the recon folder and copies it
    if [[ $METHOD == "SVRTK" ]] ; then
        reconfold="/lab-share/Rad-Gholipour-e2/Public/fetalmri/reconstruction/${subj}${scan}/svrtk"
        t2space="${reconfold}/t2_t2_${subj}${scan}.nii.gz"
        transform="${reconfold}/t2-atlas_${subj}${scan}.tfm"
        mkdir -pv ${xdir}
        if [[ -f $t2space ]] ; then cp $t2space -vnp ${xdir}/sub-${subj}_${scan}_rec-${METHOD}_t2w-t2space.nii.gz ; fi
        if [[ -f $transform ]] ; then cp $t2space -vnp ${xdir}/sub-${subj}_${scan}_rec-${METHOD}_from-t2space_to-atlas.tfm ; fi
    fi

done
