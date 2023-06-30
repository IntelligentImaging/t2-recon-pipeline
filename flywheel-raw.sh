#!/bin/bash

# fw sync --include dicom fw://rollins/P8836-RollinsFetal flywheel
# fw sync --include dicom fw://crl/P41916-fetalbrain flywheel

CRL=/fileserver/fetal/raw
FCB=/fileserver/fetal/FCB/raw
fwCRL=/fileserver/fetal/flywheel/P41916-fetalbrain/SUBJECTS
fwFCB=/fileserver/fetal/flywheel/P8836-RollinsFetal/SUBJECTS

for f in ${fwCRL}/f???? ${fwFCB}/FCB??? ; do
    if [[ -d $f ]] ; then
        subj=`basename $f`
        for ses in ${f}/SESSIONS/s? ; do
            # infer full scan id from path
            scan=`basename $ses`
            id="${subj}${scan}"
            # determine whether this is a CRL or FCB scan
            if [[ $id == *FCB* ]] ; then
                echo $id :  fcb subject
                odir=$FCB
            elif [[ $id == f* ]] ; then
                echo $id : crl subject
                odir=$CRL
            fi
        # copy of the data for pipeline will go here
        osub="${odir}/${id}"
        mkdir -pv $osub
        odcm=`find $osub -maxdepth 2 -type d -name DICOM`
        # check if there's already a DICOM folder
        # if there is, we don't copy the files over
        if [[ -d $odcm ]] ; then 
            echo found existing local subject dicom directory: $odcm
        else
            echo no local subject directory found. copying to fileserver raw dirs.
            odcm="${osub}/anon/DICOM"
            # for each sequence, pull the number and name
            # copied data will be named NUM_SEQUENCENAME
            for acq in ${ses}/ACQUISITIONS/* ; do
                echo Series: "$acq"
                ex=`find "$acq" -type f -name \*.dcm | head -n1`
                # Get seq name and number
                name=`dcmdump +L +P "0008,103e" "$ex" | sed -e 's,.*\[\(.*\)\].*,\1,g' -e 's, ,_,g'`
                num=`dcmdump +L +P "0020,0011" "$ex" | sed 's,.*\[\(.*\)\].*,\1,g'`
                seriesout="${odcm}/${num}_${name}"
                mkdir -pv ${seriesout}
                # actually copy the data
                rsync -a "${acq}"/FILES/* ${seriesout}/
            done
        fi
        done
    fi
done


