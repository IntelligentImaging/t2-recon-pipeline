#!/bin/bash

# fw sync --include dicom fw://rollins/P8836-RollinsFetal flywheel
# fw sync --include dicom fw://crl/P41916-fetalbrain flywheel

raw=/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/dicom
fwCRL=/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel/fetalbrain-P00041916
fwFCB=/lab-share/Rad-Warfield-e2/Groups/fetalmri/scans/flywheel/RollinsFetal-P00008836

for f in ${fwCRL}/SUBJECTS/f???? ${fwFCB}/SUBJECTS/FCB??? ; do
    if [[ -d $f ]] ; then
        subj=`basename $f`
        for ses in ${f}/SESSIONS/s? ; do
            # infer full scan id from path
            scan=`basename $ses`
            id="${subj}${scan}"
        # copy of the data for pipeline will go here
        osub="${raw}/${id}"
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
		if [[ -d ${acq}/FILES ]] ; then
            detox ${acq}/FILES
			rsync -a "${acq}"/FILES/* ${seriesout}/
		else
            detox ${acq}
            rsync -a "${acq}"/* ${seriesout}/
		fi
            done
        fi
        done
    fi
done


