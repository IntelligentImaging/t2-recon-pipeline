#!/bin/bash

if [ $# -ne 6 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [1st TFM] [2nd TFM] [moving IM: 1st TFM] [moving IM: 2nd TFM] [reference IM] [OUTPUT TFM.tfm]"
	echo "Combines two transforms into one file"
	echo "Script will convert .mat flirt transforms to itk"
	exit
	fi

# set inputs
TFM1="$1"
TFM2="$2"
MOV1="$3"
MOV2="$4"
REF="$5"
TFMcom="$6"

# select available python3 version
# if python3.5 -V | grep -q "Python 3.5" ; then
# 	echo Python3.5
# 	py="python3.5"
# elif python3.6 -V | grep -q "Python3.6" ; then
	# echo Python3.6
	# py="python3.6"
# else
# 	echo "Neither Python3.5 nor Python3.6 found"
	# echo "Exiting"
	# exit
# fi

# programs and scripts
c3d="/fileserver/fetal/bin/c3d_affine_tool"
affineSH="${FETALDTI}/changeTFMnameInFileToAffine.py"
compose="crlComposeAffineTransforms"
LOG="run-combineTFM.sh"

if [[ -f run-combineTFM.sh ]] ; then rm -v $LOG ; fi

# convert TFM1 to ITK
if [[ ${TFM1} == *.mat ]] ; then
	echo "$TFM1 is FLIRT .mat, converting to ITK .tfm"
	tmp=`basename ${TFM1} .mat`
	TFM1ITK="${tmp}.tfm"
    TFM1tmp="${TFM1ITK}.$RANDOM"
	cmd="$c3d -ref $REF -src $MOV1 $TFM1 -fsl2ras -oitk $TFM1ITK"
	echo $cmd >> $LOG
	$cmd
	# Change type designation to "AffineTransform_double_3_3"
    cmd=`sed -e 's,MatrixOffsetTransformBase_double_3_3,AffineTransform_double_3_3,g' $TFM1ITK > $TFM1tmp ; mv $TFM1tmp $TFM1ITK`
	# cmd="python $affineSH $TFM1ITK"
	echo $cmd >> $LOG
	$cmd
else
	TFM1ITK="$TFM1"
fi

# convert TFM2 to ITK
if [[ ${TFM2} == *.mat ]] ; then
        echo "$TFM2 is FLIRT .mat, converting to ITK .tfm"
        tmp=`basename ${TFM2} .mat`
        TFM2ITK="${tmp}.tfm"
        TFM2tmp="${TFM2ITK}.$RANDOM"
        cmd="$c3d -ref $REF -src $MOV2 $TFM2 -fsl2ras -oitk $TFM2ITK"
	echo $cmd >> $LOG
	$cmd
	# Change type designation to "AffineTransform_double_3_3"
    cmd=`sed -e 's,MatrixOffsetTransformBase_double_3_3,AffineTransform_double_3_3,g' $TFM2ITK > $TFM2tmp ; mv $TFM2tmp $TFM2ITK`
    # cmd="python $affineSH $TFM2ITK"
	echo $cmd >> $LOG
	$cmd
else
        TFM2ITK="$TFM2"
fi

cmd="$compose ${TFM2ITK} ${TFM1ITK} ${TFMcom}"
echo $cmd >> $LOG
$cmd

#/home/ch191070/bin/c3d_affine_tool -ref t2_t2_1272s1.nii.gz -src t2_b0_1272s1_ncc.nii.gz b0-t2_1272s1_ncc_part2.mat -fsl2ras -oitk b0-t2_1272s1_ncc_part2.tfm

#python3.5 /home/ch191070/scripts/fetalDTI/changeTFMnameInFileToAffine.py b0-t2_1272s1_ncc_part2.tfm

#crlComposeAffineTransforms b0-t2_1272s1_ncc.tfm b0-t2_1272s1_ncc_part2.tfm b0-t2_1272s1_nccflirt.tfm 

echo "Created $TFMcom"
echo "You can verify with:"
echo "crlResampler ${MOV1} ${TFMcom} ${REF} bspline VERIFY.nii.gz"
