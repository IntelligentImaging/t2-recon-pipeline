#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [MRN] [DOS]
    Incorrect input supplied

	Uses Simon's CRL-dicom-tools docker to convert images
	Container utilizes dcmdjpeg for decompression, pydicom for naming, dcm2niix for conversion
	Apptainer sif built from git lab CRL docker
EOF
}

if [ $# -ne 2 ]; then
    show_help
    exit
fi 

MRN=$1
StudyDate=$2
odir=${MRN}/${StudyDate}
mkdir -pv ${odir}/Rpacs ${odir}/synR ${odir}/2BP

#singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/retrieve_dicoms.py --outputDir ${odir}/synR --aec SYNAPSERESEARCH --aet PACSDCM --namednode 10.20.2.28 --modality MR --subjectID ${MRN} --studyDate ${StudyDate}"

#singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/retrieve_dicoms.py --outputDir ${odir}/Rpacs --aec PACSDCM --aet RESEARCHPACS --namednode 10.20.2.28 --modality MR --subjectID ${MRN} --studyDate ${StudyDate}"

singularity exec ~/sifs/dicom-tools /bin/bash -c "python3 /usr/local/bin/retrieve_dicoms.py --outputDir ${odir}/2BP --aec SYNAPSERESEARCH --aet 2BPMRI_2 --namednode 10.27.107.244 --modality MR --subjectID ${MRN} --studyDate ${StudyDate}"


# Search the DICOM node for the study info.
# AET: Application Entity Title is used to identify a DICOM application
#AET = 'SYNAPSERESEARCH'
# AEC: The called Application Entity Title of the DICOM node that is called.
#AEC = 'PACSDCM'
# The named node is the DICOM peer that is called.
#NAMEDNODE = 'pacsstor.tch.harvard.edu'
#PORT = 104

# aet: PACSDCM
# namednode: pacsstor.tch.harvard.edu
# dicomport: 104

# aet: SYNAPSERESEARCH
# namednode: 10.20.2.28
#          synapseresearch.tch.harvard.edu
# dicomport: 104

# 2BP research
# aet: 2BPMRI_2
# namednode: 10.27.107.244
# dicomport: 104

# Retrieve from Synapse:
#   sudo docker run --rm -it --volume `pwd`:/data crl/dicom-tools \
# retrieve_dicoms.py --outputDir . --subjectID NNNNNNN \
# --studyDate YYYYMMDD --aet SYNAPSERESEARCH \
#  --aec PACSDCM --namednode pacsstor.tch.harvard.edu
#

# Retrieve from SynapseResearch:
#   sudo docker run --rm -it --volume `pwd`:/data crl/dicom-tools \
# retrieve_dicoms.py --outputDir . --subjectID NNNNNNN \
# --studyDate YYYYMMDD --aet PACSDCM --aec SYNAPSERESEARCH \
#  --namednode 10.20.2.28

