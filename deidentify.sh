#!/bin/bash 
if [[ $1 == "" ]] || [[ $2 == "" ]] || [[ $3 == "" ]]; then 
	echo "deidentify.sh [DICOM DIRECTORY] [OUTPUT DIRECTORY] [STUDY IDENTIFIER]" 
    echo 
    echo "searches out all files in DICOM DIRECTORY"
    echo "makes copies in OUTPUT DIRECTORY"
    echo "replaces patientID with STUDY IDENTIFIER"
    echo "maybe STUDY IDENTIFIER should just be xxx"
	exit 
fi

IN="$1"
OUT="$2"
ID="$3"
unset modifytags
unset removetags
for dcm in `find $IN -type f`; do 
	# if dcmftest "$dcm"; then
		dirfull=`dirname "$dcm"`
		dicomdir=`basename "$dirfull"`
		if [[ ! -e "$OUT"/"$dicomdir" ]]; then 
			mkdir -pv "$OUT"/"$dicomdir"
		fi
		cp -f "$dcm" "$OUT"/"$dicomdir"
		PatientName=\(0010\,0010\)
		PatientID=\(0010\,0020\)
		if dcmdump "$dcm" | grep -i --silent "$PatientName"; then
			modifytags=("${modifytags[@]}" -m "$PatientName"="$ID")
		fi
		if dcmdump "$dcm" | grep -i --silent "$PatientID"; then
			modifytags=("${modifytags[@]}" -m "$PatientID"="$ID")
		fi
		StudyDate=\(0008\,0020\)
		if dcmdump "$dcm" | grep -i --silent "$StudyDate"; then 
			year=`dcmdump "$dcm" | grep -i "$StudyDate" | awk '$0=$2' FS=[ RS=] | grep -Eo '\b(((19|20)[0-9][0-9])|2100)'`
			modifytags=("${modifytags[@]}" -m "$StudyDate"="$year")
		fi
		InstanceCreationDate=\(0008\,0012\) 
		SeriesDate=\(0008\,0021\)
		AcquisitionDate=\(0008\,0022\)
		ContentDate=\(0008\,0023\)
		AccessionNumber=\(0008\,0050\)
		InstitutionName=\(0008\,0080\)
		InstitutionAddress=\(0008\,0081\)
		ReferringPhysicianName=\(0008\,0090\)
		StationName=\(0008\,1010\)
		PhysiciansOfRecord=\(0008\,1048\)
		PerformingPhysicianName=\(0008\,1050\)
		OperatorsName=\(0008\,1070\)
		PatientBirthDate=\(0010\,0030\)
		PatientSex=\(0010\,0040\)
		PatientAge=\(0010\,1010\)
		IssuerOfPatientID=\(0010\,0021\)
		OtherPatientIDs=\(0010\,1000\)
		PatientAddress=\(0010\,1040\)
		PatientTelephoneNumbers=\(0010\,2154\)
		PerformedProcedureStepStartDate=\(0040\,0244\)
		PerformedProcedureStepStartTime=\(0040\,0245\)
		PerformedProcedureStepID=\(0040\,0253\)
        FrameAcquisitionDateTime="(0018,9074)"
        FrameReferenceDateTime="(0018,9151)"
		RequestingPhysician=\(0032\,1032\)
		StudyInstanceUID="(0020,000d)"
		SeriesInstanceUID="(0020,000e)"
		StudyID=\(0020\,0010\)
		RequestingService=\(0032\,1033\)
#		TransmitCoilName=\(0018\,1251\)
#		SoftwareVersions=\(0018\,1020\)
		DeviceSerialNumber=\(0018\,1000\)
		StudyDescription=\(0008\,1030\)
		InstitutionalDepartmentName=\(0008\,1040\)
#		ManufacturerModelName=\(0008\,1090\)
        MediaStorageSOPInstanceUID="(0002,0003)"
        SOPInstanceUID="(0008,0018)"
        AcquisitionDateTime="(0008,002a)"
        ReferencedSOPInstanceUID=\(0008\,1155\)
        FrameOfReferenceUID="(0020,0052)"
        DimensionOrganizationUID="(0020,9164)"
        PerformedProcedureStepEndDate="(0040,0250)"
        IssueDateOfImagingServiceRequest="(0040,2004)"
        UnkTime="(0021,1060)"
		for x in $InstanceCreationDate $SeriesDate $AcquisitionDate $ContentDate $AccessionNumber $InstitutionName $InstitutionAddress $ReferringPhysicianName $StationName $PhysiciansOfRecord $PerformingPhysicianName $OperatorsName $PatientBirthDate $PatientSex $PatientAge $IssuerOfPatientID $OtherPatientIDs $PatientAddress $PatientTelephoneNumbers $PerformedProcedureStepStartDate $PerformedProcedureStepStartTime $PerformedProcedureStepID $RequestingPhysician $StudyInstanceUID $SeriesInstanceUID $StudyID $RequestingService $DeviceSerialNumber $StudyDescription $InstitutionalDepartmentName $FrameAcquisitionDateTime $FrameReferenceDateTime $MediaStorageSOPInstanceUID $SOPInstanceUID $AcquisitionDateTime $ReferencedSOPInstanceUID $FrameOfReferenceUID $DimensionOrganizationUID $PerformedProcedureStepEndDate $IssueDateOfImagingServiceRequest $UnkTime ; do 
			removetags=("${removetags[@]}" -e "$x")
		done
		dcmodify -imt -nb "${modifytags[@]}" "${removetags[@]}"  "$OUT"/"$dicomdir"/`basename "$dcm"`
		unset modifytags
		unset removetags
	# fi 
done  	



