#!/bin/bash

# Fetal MRI segmentation pipeline script
#
# This script takes input lists for INPUTS, TEMPLATE IMAGES, and TEMPLATE IMAGE LABELS,
# does a series of registrations with ANTS, and then runs STAPLE segmentation using the registered
# images as the segmentation atlases. The script only uses template images that are
# within +/-1 week gestational age of the input. INPUTS needs to be masked, registered,
# and intensity corrected. There is a cross propagation option for using the
# registered-to-input-labels as additional segmentation atlas images. Output parcellation is put
# into OutputDir/seg/ . "PVC" stands for partial volume correction and will be placed into
# OutputDir/PVC/ (ask Ali for details).
# 
# Clemente Velasco-Annis, 2016, 2017"
# clemente.velasco-annis@childrens.harvard.edu"

shopt -s extglob

# Binary/program directories
antspath="/fileserver/fetal/atlas/ants/"

# Default STA atlas list # # # # # # # # # 
tlist="/fileserver/fetal/segmentation/templates/STA_GEPZ/tlist_old.txt"
# # # PREFIXES OF DEFAULT ATLAS LABELS # #
# GEPZ = standard tissue seg
# GEPZ-WMZ = with subplate, normally only used for GA < 32 weeks
# region = regional segmentation (parcellation)
AllLabs="GEPZ GEPZ-WMZ region"
# # # # # # # # # # # # # # # # # # # # # #

# # # Set segmentation to ON or OFF # # #
# You can disable this setting if you only want the registrations to happen
segmentation="ON"                       
# # # # # # # # # # # # # # # # # # # # #
PartialVolumeCorrection="ON"
LCP="112" # Cortical plate label used to test PVC output behavior
# # # # # # # # # # # # # # # # # # # # #

# Arguments and help message
show_help () {
cat << EOF
    ----------------------------------------------------------
    Incorrect arguments supplied!
    Usage: sh ${0} [-h] [-a AtlasList.txt -l AtlasLabelsPrefix] [-p OutputSegPrefix] -- [Imagelist] [OutputDir] [MaxThreads]
    
        -h      display this help and exit
        -a      [optional] supply a structual ATLAS text list
                formatted with one image per row and GA
                for example:
                    PATH/atlas30.nii.gz 30
                    PATH/atlas31.nii.gz 31
                    ...etc
        -l      [required if -a is specified] supply string to
                designate atlas label prefix. Labels should be in
                the same directory as the corresponding atlas image
                and must be named with format: PREFIX-SameAsAtlas.ext
                using the above example, there should be files named:
                    PATH/PREFIX-atlas30.nii.gz
                    PATH/PREFIX-atlas31.nii.gz
                    ...etc
        -p      [optional] specify output segmentation prefix
                default: mas

        [InputList] A text file with a list of input images
                formatted with one image per row and GA, i.e.
                    PATH/image01.nii.gz 32
                    PATH/image02.nii.gz 29
                    PATH/image03.nii.gz 31
                    ...etc

        [OutputDir] Output directory for all working files
                and output segmentations

        [MaxThreads] Maximum number of CPUs for running
        registrations and STAPLE (usually 8-12)
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

# Parsing optional arguments
while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -a)
            if [[ -f "$2" ]] ; then
                tlist=$2 # replaces default template image list with user argument
                shift
            else
                die 'error: "-a" requires a text list of atlases'
            fi
            ;;
        -l)
            if [ -n "$2" ] ; then
                userlabs=$2 # script will replace default atlas prefixes with this
                shift
            else
                die 'error: "-l" requires a label prefix (the rest of the filename should match the atlas)'
            fi
            ;;
        -p)
            if [ -n "$2" ] ; then
                OutputPrefix=$2
                shift
            else
                die 'error: "-p" requires prefix be specified'
            fi
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -?*)
            printf 'warning: unknown option (ignored: %s\n' "$1" >&2
            ;;
        *) # default case, no options
            break
    esac
    shift
done

# Parse required inputs
if [ ! $# = 3 ] ; then
    show_help
    exit
fi

# Assign arguments
inputs="$1"
outdir="$2"
NThreads="$3"

# If optional atlas labels given, use those instead
if [[ -n $userlabs ]] ; then
    AllLabs="$userlabs"
fi

# Checking that input list is a text file
inputsType=$(file "$inputs")
if ! [[ $inputsType == *":"*"text"* ]] ; then
	echo "error: argument #1 (inputs) was not a text file." 
	echo "Should be a text file formatted: [IMAGE] [GA]"
    exit 1
fi

# Checking that template list is a text file
tlistType=$(file "$tlist")
if [[ ! $tlistType == *":"*"text"* ]] ; then
	echo "Atlas T2 list not found or is not a text file."
	exit 1
fi

# Check that template structural images exist
CheckTemplates=""
while read CHECK ; do
	path=`echo $CHECK | awk -F' ' '{ print $1 }'`
	if [[ ! -f $path ]] ; then
		CheckTemplates="ERROR"
		echo "error: $path doesn't exist"
	fi
done < $tlist
if [[ "$CheckTemplates" = "ERROR" ]] ; then
	echo "Couldn't find template(s). Check the paths in template list."
    exit 1
fi

# Checking ouput segmentation prefix syntax
if [[ "$OutputPrefix" == *\/* ]] || [[ "$OutputPrefix" == *\\* ]] ; then
	echo "Don't put a slash character in the OutputPrefix (\$5)! It is no bueno."
	exit 1
fi

# Checking number of threads is a natural number
re='^[0-9]+$'
if ! [[ $NThreads =~ $re && $NThreads -ne 0 ]] ; then
    echo "error: argument six (MaxThreads) was not a natural number." >&2; exit 1
fi
# # # Finished checking arguments and variables # # #

# # # Case directory setups begin # # # 
echo "Making case directory, setting some variables, starting template propagation..."
# Create output DIR and copy scripts and binaries
mkdir -pv "$outdir"
tools="${outdir}/tools"
mkdir -pv "$tools"
cp $0 -nv ${tools}/seg.sh
# check to see if processing script has changed
if ! cmp -s $0 ${tools}/seg.sh ; then
	echo "The segmentation script has changed"
	echo "Either use ${tools}/seg.sh or clear it if you're really sure you want to change the processing script"
	exit
fi
cp ${antspath}/ANTS -vu ${tools}/
cp ${antspath}/WarpImageMultiTransform -vu ${tools}/
cp ${tlist} -vu ${tools}/
ANTS="${tools}/ANTS"
WARP="${tools}/WarpImageMultiTransform"
SEG="crlProbabilisticGMMSTAPLE"
PVC="/fileserver/fetal/software/bin/crlCorrectFetalPartialVoluming"
VOL="/fileserver/fetal/software/bin/crlComputeVolume"
MATH="crlImageAlgebra"
baseTLIST=`basename $tlist`
TLIST="${tools}/${baseTLIST}"

# Default output prefix
if [ -n $OutputPrefix] ; then
    OutputPrefix="MAS"
fi

# Begin 'for loop' for each atlas segmentation scheme
# default labels are specified at top of script
# probably GEPZ, GEPZ-WMZ, and regions
for lpref in $AllLabs ; do
    echo
    echo "## Process registrations for all cases for atlas segmentation $lpref ##"
    OutPre2="${OutputPrefix}-${lpref}"

    # Atlas registration loop for all input cases
    while read line; do 
        echo
        image=`readlink -f $(echo $line | awk -F' ' '{ print $1 }')`
        echo "# Input case information #"
        echo "time : `date`"
        echo "image : ${image}"
        echo "atlas seg: ${lpref}"
        if [[ ! -f ${image} ]] ; then
            echo "  ERROR: ${image} not found! Check path"
            echo "  Skipping to next input"
            echo
            continue
        fi

        # Record gestational age range for deciding atlas references
        GA=`echo $line | awk -F' ' '{ print $2 }'`
        if [[ $GA -eq "" ]] ; then
            echo "  ERROR: Input ${image} had no GA specified. Please add GA as second column of input list and try again."
            echo "  Skipping to next input"
            echo 
            continue
        fi
        GAm=`expr $GA - 1`
        GAp=`expr $GA + 1`
        echo "Gestational Age : $GA"
        echo

        # Finish setting up case directory
        name=`echo $(basename $image) | awk -F'.' '{ print $1 }'`
        caseout="${outdir}/${name}"
        mkdir -pv ${caseout}/log
        # Copy of input case text list for this case only
        echo "$line" > ${caseout}/log/inputGA-${OutPre2}_${GA}.txt
        # "Run" script for this case only
        echo "sh ${tools}/seg.sh -a ${TLIST} -l "${AllLabs}" -p ${OutPre2} ${caseout}/log/inputGA-${OutPre2}_${GA}.txt ${outdir} ${NThreads}" > ${caseout}/log/run-${OutPre2}_${name}.sh
        # Registrations go here
        mkdir -pv ${caseout}/template_rT
        # Make a case dir copy of the image - we'll use the copy for processing
        casebase=`basename $image`
        caseim=${caseout}/${casebase}
        cp ${image} -nv ${caseim}
        
        # Reading atlas text files and selecting same, +1, and -1 week templates
        # and locating counterpart labels files
        # Full paths
        declare -a ARRAY_T
        declare -a ARRAY_S
        # File names without paths or extensions
        declare -a ARRAY_T_NAME
        declare -a ARRAY_S_NAME
        let count=0
        # For each template in the template list, compare GA to input case
        while read LINE ; do
            # Grab GA of template
            GAtemplate=`echo $LINE | awk -F' ' '{ print $2 }'`
            casebase=`basename ${image}`
            PathOfT=`echo $LINE | awk -F' ' '{ print $1 }'`
            baseT=`basename ${PathOfT}`
            dirT=`dirname ${PathOfT}`
            # We only select atlases within 1 week GA and don't share the same filename as the input case
            if [[ ( ${GAtemplate} == ${GA} || ${GAtemplate} == ${GAm} || ${GAtemplate} == ${GAp} ) && ! ${casebase} == ${baseT} ]] ; then
                # Grab template full path
                ARRAY_T[${count}]=${PathOfT}
                # Chop off directory path
                tmpName=${ARRAY_T[$count]##*/}
                # Chop off extension
                ARRAY_T_NAME[$count]=${tmpName%%.*}
                # Get the atlas label name by adding label prefix 
             #   ARRAY_S_NAME[$count]=`echo ${ARRAY_T_NAME[$count]} | sed "s,${ARRAY_T_NAME[$count]},${lpref}-${ARRAY_T_NAME[$count]},"`
                ARRAY_S_NAME[$count]=${lpref}-${ARRAY_T_NAME[$count]}
                # Get full path by searching for the label name in same directory as the atlas
                ARRAY_S[$count]=`find ${dirT} -type f -name ${ARRAY_S_NAME[$count]}.nii\* | head -n1`
                ((count++))
            fi
        done < "${TLIST}"

        # Print out atlas information for this case
        echo Number of atlas images: ${#ARRAY_T[@]:0:$count}
        echo Number of atlas labels: ${#ARRAY_S[@]:0:$count}
        echo "  Atlases:"
        printf '%s\n' "${ARRAY_T[@]:0:$count}"
        echo "  Applicable Labels:"
        echo "  NOTE: OKAY if there are none, or if there are blanks"
        echo "        If there are none, segmentation will not process for label atlas '$OutputPrefix'"
        echo "        Listed labels (below) should match the order of listed atlases (above)"
        printf '%s\n' "${ARRAY_S[@]:0:$count}"
        # Check that at least one atlas was found, but it's advisable to have at least 3
        if [[ $count -eq 0 ]] ; then
            echo "Didn't find ANY template images of similar GA. Make sure you have the right template lists selected. Alternatively, if you don't have template images for this GA=$GA, you can try changing the GA of the subject in $inputs to another age for which there are templates."
            echo "Moving on to next case because there are no matches."
            continue
        fi
        echo
        # Multithreading ANTS, which creates warp files for registration of template grayscale and parcellation to the target image
        # Number of threads maxes out at the user defined number
        let npr=0
        echo "Staring non-rigid registration (ANTS)..."
        tcount=0
        while ( [ $tcount -lt $count ] ) ; do
            while ( [ $npr -lt $NThreads ] ) ; do
                if [ $tcount -lt $count ] ; then
                    # Skip if this reg is already done
                    if [[ ! -e ${outdir}/${name}/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}Warpxvec.nii.gz || ! -e ${outdir}/${name}/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}InverseWarpxvec.nii.gz || ! -e ${outdir}/${name}/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}Affine.txt ]] ; then
                            echo "ANTS register ${ARRAY_T_NAME[$tcount]} to ${name}"
                        # Registration command
                        # This produces the "case123Warp.nii.gz", "case123InverseWarp.nii.gz", and "case123Affine.txt" files
                        $ANTS 3 -m PR[${image}, ${ARRAY_T[$tcount]},1,2] -o ${outdir}/${name}/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}\.nii.gz -r Gauss[3,0] --affine-metric-type MI -i 100x100x20 -t SyN[0.4] &
                    else
                        echo "Found transform for ${ARRAY_T_NAME[$tcount]} to ${name}. Skipping..."
                    fi
                    # Increase counts
                    npr=$[ $npr + 1 ]
                    tcount=$[ $tcount + 1 ]
                else
                    npr=$NThreads
                fi
            done
            wait
            npr=0
        done

        # Multithreading Warp for each template image - applying the transformation to the grayscale
        echo "Applying transformations to templates..."
        let npr=0
        tcount=0
        while ( [ ${tcount} -lt ${count} ] ) ; do
            while ( [ ${npr} -lt ${NThreads} ] ) ; do
                if [ ${tcount} -lt ${count} ] ; then
                    if [[ ! -f "$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}.nii.gz ]]; then
                        echo "Applying transform: ${ARRAY_T[$tcount]} to ${name}..."
                        # This produces the warped grayscale e.g. "template123_to_case123.nii.gz"
                        $WARP 3 ${ARRAY_T[$tcount]} "$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}.nii.gz -R ${image} "$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}\Warp.nii.gz "$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_${name}\Affine.txt &
                    else
                        echo "Atlas has been transformed. Skipping"
                    fi
                    npr=$[ ${npr} + 1 ]
                    tcount=$[ ${tcount} + 1 ]
                else
                    npr=$NThreads
                fi
            done
            wait
            npr=0
        done

        # Multithreading Warp for each template labels
        echo "Applying transformations to template labels"	
        let npr=0
        tcount=0
        while ( [ ${tcount} -lt ${count} ] ) ; do
            while ( [ ${npr} -lt ${NThreads} ] ) ; do
                if [ ${tcount} -lt ${count} ] ; then
                    if [[ ! -f "$outdir"/"$name"/template_rT/r${ARRAY_S_NAME[$tcount]}_to_${name}.nii.gz && -f "${ARRAY_S[$tcount]}" ]]; then
                        echo "Transforming ${ARRAY_S[$tcount]} to ${name}"
                        # This produces the warped parcellation e.g. "template123parc_to_case123.nii.gz"
                        $WARP 3 ${ARRAY_S[$tcount]} "$outdir"/"$name"/template_rT/r${ARRAY_S_NAME[$tcount]}_to_${name}.nii.gz -R ${image} "$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_"$name"\Warp.nii.gz "$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_"$name"\Affine.txt --use-NN &
                    elif [[ ! -f "${ARRAY_S[$tcount]}" ]] ; then
                        echo "No label file for ${ARRAY_T_NAME[$tcount]}"
                    else
                        echo ""$outdir"/"$name"/template_rT/r${ARRAY_S_NAME[$tcount]}_to_${name}.nii.gz already exists. Skipping..."
                    fi
                    npr=$[ $npr + 1 ]
                    tcount=$[ $tcount + 1 ]
                else
                    npr=$NThreads
                fi
            done
            wait
            npr=0
        done

        # Appending images+labels to list files for segmentation
        # Remove the olds ones
        if [[ -f ""$outdir"/"$name"/log/atlas_for_${OutPre2}.txt" ]]; then rm -v "$outdir"/"$name"/log/atlas_for_${OutPre2}.txt ; fi
        if [[ -f ""$outdir"/"$name"/log/labels_for_${OutPre2}.txt" ]]; then rm -v "$outdir"/"$name"/log/labels_for_${OutPre2}.txt ; fi
        # Write the new ones
        echo "Writing template to text file "$outdir"/"$name"/log/atlas_for_${OutPre2}.txt"
        for ((tcount=0;tcount<$count;++tcount)) ; do
            if [[ -f ""$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_"$name".nii.gz" && -f ""$outdir"/"$name"/template_rT/r${ARRAY_S_NAME[$tcount]}_to_"$name".nii.gz" ]] ; then
                echo ""$outdir"/"$name"/template_rT/r${ARRAY_T_NAME[$tcount]}_to_"$name".nii.gz" >> "$outdir"/"$name"/log/atlas_for_${OutPre2}.txt
                echo ""$outdir"/"$name"/template_rT/r${ARRAY_S_NAME[$tcount]}_to_"$name".nii.gz" >> "$outdir"/"$name"/log/labels_for_${OutPre2}.txt
            fi	
        done
        
        # End of T2 input list loop (atlas label loop still running)
        done < $inputs 

    ## STAPLE multiatlas segmentation ##
    if [[ $segmentation = "ON" ]] ; then
        echo "# # # # # # # # # # # # # # # # # # # # # # # #"
        echo "Starting STAPLE segmentation... # # # # # # # #"
        echo "# # # # # # # # # # # # # # # # # # # # # # # #"
        echo ""

        let ecount=0
        # Start a new T2 input case loop
        while read line; do 
            # Get path, name, and GA
            image=`readlink -f $(echo $line | awk -F' ' '{ print $1 }')`
            echo "time : `date`"
            echo "segmentation scheme: $OutPre2"
            echo "image : ${image}"
            GA=`echo $line | awk -F' ' '{ print $2 }'`
            name=`echo $(basename $image) | awk -F'.' '{ print $1 }'`
            echo "name : $name"
        
            # Create output segmentation directory
            if [[ ! -d ""$outdir"/"$name"/seg" ]]; then mkdir -v ""$outdir"/"$name"/seg"; fi

            # Output segmentation file names
            OutSeg="${outdir}/${name}/seg/${OutPre2}_${name}.nii.gz"
            OutPVC="${outdir}/${name}/PVC/${OutPre2}-pvc_${name}.nii.gz"
    #		corIt2="${outdir}/${name}/PVC/it2-pvc-${OutPre2}_${name}.nii.gz"

            # Use this so we can check number of atlases (can't STAPLE if we only have one atlas, after all)
            let labcount=`wc -l "$outdir"/"$name"/log/labels_for_${OutPre2}.txt | cut -d' ' -f1`
            # Check to see we have the script-generated lists of (registered) atlas+labels            
            if [[ ! -e "$outdir"/"$name"/log/labels_for_${OutPre2}.txt || ! -e "$outdir"/"$name"/log/atlas_for_${OutPre2}.txt || $labcount -lt 2 ]] ; then
                echo "  Insufficient transformed atlas images and/or ${OutPre2} parcellations for this case, so STAPLE won't segment ${OutPre2}."
                echo "  If this was unexpected, validate that the input GA matches at least one atlas. Skipping to next input."
                echo ""
                continue
            fi

            # Run segmenation
            if [ ! -e ${OutSeg} ] ; then
                echo "${OutSeg} not found. Processing..."
                $SEG -S "$outdir"/"$name"/log/labels_for_${OutPre2}.txt -T ${image} -I "$outdir"/"$name"/log/atlas_for_${OutPre2}.txt -O ${OutSeg} -x 16 -y 16 -z 16 -X 1 -Y 1 -Z 1 -p ${NThreads}
            else echo "${OutSeg} already exists. Skipping..."
            fi

            # Check conditions to run PVC
            if [[ ${PartialVolumeCorrection} = "ON" ]] ; then
                if [[ ! ${OutPVC} == *"GEPZ"* ]] ; then
                    echo "Not a WM/GM tissue segmentation. Skipping PVC"
                    echo ""
                    continue
                fi
                if [[ ! -e ${OutSeg} ]] ; then
                    echo "  error: ${OutSeg} was not created for some reason, so there's nothing to correct (partial volume correction)."
                    echo ""
                    continue
                fi
                
                # Run PVC
                if [[ ! -e ${OutPVC} ]] ; then
                    echo "Partial volume correction not found. Running..."
                    if [[ ! -d ""$outdir"/"$name"/PVC" ]]; then mkdir -v ""$outdir"/"$name"/PVC"; fi
                    echo "Iteration one"
                    $PVC ${image} ${OutSeg} ${OutPVC} 0.1
                    echo "We're only doing one iteration currently"
    #				echo "Iteration two:"
    #				$PVC ${image} ${corIt1} ${corIt2} 0.5 0.2 0
                    else echo "Partial volume correction ${OutPVC} already complete. Skipping..."
                fi
                    
                # A check to compare output of PVC and confirm that is is decreasing CP volume as intended
                echo "Checking PVC output..."
                BEFORE=`crlComputeVolume ${OutSeg} ${LCP}`
                AFTER=`crlComputeVolume ${OutPVC} ${LCP}`
                declare -a EARRAY
                if (( $(echo "scale=2 ; 100-(${AFTER}/${BEFORE})*100 < 2" | bc -l) )) ; then
                    echo "  FAILURE: Problem detected. Change from SEG to PVC-it1 was less than 2%"
                    echo "PVC didn't have the desired effect of decreasing CP label."
                    echo "Do the CP, SP, and WM labels match what $PVC is expecting?" 
                    EARRAY[${ecount}]=${OutPVC}
                    ((ecount++))
                else echo "  SUCCESS: PVC appears to have had the desired effect (CP change was > 2%)"
                fi
        else echo "Partial volume correction is turned off"
            echo "Open the script in a text editor to turn it on (there is a switch near the top)"
        fi
        echo


        # This is the end of the T2 inputs loop for segmentation for this label scheme
        done < $inputs
    else
        echo ""
        echo "Segmentation turned off - open the script in a text editor to turn it on (there is a switch near the top)"
        echo ""
    fi
done
# End of the entire loop!! Weee! Now to do the next atlas labels- should be faster since registrations are already done    

# # # Post-processing # # #
echo "# # # Post-processing steps begin # # #"
echo

while read line; do
    # Get path, name
    image=`readlink -f $(echo $line | awk -F' ' '{ print $1 }')`
    name=`echo $(basename $image) | awk -F'.' '{ print $1 }'`
    echo "name : $name"

    # # HAORAN DL CP SEGMENTATION - FetalCPSeg - HDL # #
    echo "# # FetalCPSeg deep learning model for CP segmentation # #"
    # Location of the trained model
    FCPS="${outdir}/${name}/FCPS"
    Fsrc="/fileserver/fetal/segmentation/FetalCPSeg/FetalCPSeg-Programe/"
    Fenv="/fileserver/fetal/venv/HDLenv/bin/activate"
    Fin="${outdir}/${name}/FCPS/Input"
    Fsub="${Fin}/${name}"
    Fout="${FCPS}/FCPS_${name}.nii.gz"
    echo
    if [[ ! -f "${Fout}" ]] ; then
        echo "time : `date`"
        echo "Install model for subject"
        mkdir -pv ${Fsub}
        cp ${Fsrc} -r ${FCPS}/
        cp ${image} -v ${Fsub}/image.nii.gz
        echo "Source virtual environment"
        source $Fenv
        cd ${FCPS}
        python FetalCPSeg-Programe/Test/infer_novel.py
        cd -
        deactivate
        echo "Resample model prediction"
        crlCopyImageInformation ${Fsub}/predict.nii.gz ${Fsub}/cii.nii.gz ${Fsub}/image.nii.gz 1
        echo "FetalCPSeg complete"
        cp ${Fsub}/cii.nii.gz -v ${Fout}
    else echo "FCPS output found. Skipping..."
    fi
    echo

    # CP region multiplication
    echo "# # Image algebra steps # #"
    # Output dir for calculations
    calc="${outdir}/${name}/calc"
    mkdir -pv $calc
    # Check that we have a GEPZ seg and a region seg
    GEPZ="${outdir}/${name}/PVC/MAS-GEPZ-pvc_${name}.nii.gz"
    REGION="${outdir}/${name}/seg/MAS-region_${name}.nii.gz"
    if [[ -f "${GEPZ}" && -f "${REGION}" ]] ; then
        pvcs=`find ${outdir}/${name}/PVC/ -type f -name \*-GEPZ\*pvc_${name}.nii.gz`
        echo "These CP's will be parcellated: ${pvcs}"
        for parc in $pvcs ; do 
            echo "Parcellate GEPZ segs using Region seg"
            parcbase=`basename $parc`
            sub=`echo $parcbase | sed 's,MAS-GEPZ\(.*-pvc\),MAS-GEPZ\1-ParCP,'`
            CPmask="${calc}/CPmask.nii.gz"
            CPnone="${calc}/CPnone.nii.gz"
            CPparc="${calc}/CPparc.nii.gz"
            parcOUT="${calc}/${sub}"
            # Create CP mask from GEPZ
            crlRelabelImages $parc $parc "112 113" "1 1" ${CPmask} 0
            # Create no-CP seg from GEPZ
            crlRelabelImages $parc $parc "112 113" "0 0" ${CPnone}
            # Multiply region by CP
            $MATH ${CPmask} multiply $REGION ${CPparc}
            # Add parcellated CP back to full segmentation
            $MATH ${CPnone} add ${CPparc} ${parcOUT}
            echo "Output: ${parcOUT}"

            # Add FCPS CP to PVC
            echo "Insert FCPS into PVC"
            FinvCP="${calc}/FinvCP.nii.gz"
            CPnone2="${calc}/CPnone2.nii.gz"
            rFout="${calc}/rFout.nii.gz"
            sub2=`echo $parcbase | sed 's,MAS-GEPZ\(.*-pvc\),MAS-GEPZ\1-wFCPS,'`
            # This is the file which has the inserted FCPS CP
            insert="${calc}/${sub2}"
            crlRelabelImages ${Fout} ${Fout} "1" "0" ${FinvCP} 1
            crlRelabelImages ${Fout} ${Fout} "1" "112" ${rFout}
            $MATH ${CPnone} multiply ${FinvCP} ${CPnone2}
            $MATH ${CPnone2} add ${rFout} ${insert}
            echo "Output: ${insert}" 

            # Remove temp files
            rm ${CPmask} ${CPnone} ${CPparc} ${FinvCP} ${CPnone2} ${rFout}
        done
    else echo "GEPZ or Region segs were not found for image. Skipping."
    fi
    echo "Parcelate FetalCPSeg using region seg"
    if [[ -f "${Fout}" && -f "${REGION}" ]] ; then
        Fbase=`basename $Fout`
        Falg="${calc}/FCPS-ParCP_${name}.nii.gz"
        $MATH ${REGION} multiply ${Fout} ${Falg} 
    else echo "FetalCPSeg or Region segs were not found for image. Skipping"
    fi

    # Make LEFT/RIGHT mask
    # echo
    # echo "Genarating LEFT/RIGHT mask (work in progress)"
    # LR="${calc}/LR-${name}.nii.gz"
    # crlRelabelImages ${REGION} ${REGION} \
        # "1  2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40  41  42  43  44  45  46  47  48  49  50  51  52  53  54  55  56  57  58  59  60  61  62  63  64  65  66  67  68  69  70  71  72  73  74  75  76  77  78  79  80  81  82  83  84  85  86  87  88  89  90  91  92  93  94  95  96  97  98  99  100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127" \
        # "1  2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   3   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   1   2   3   3   1   2   1   2   1   2   1   2   1   2   1   2   3   3   1   2" \
        # $LR 0
    # echo "Reassign GEPZ/FCPS combo CP label to have a left and right side"
    # crlRelabelImages $LR $LR "2" "1" ${calc}/onlyR.nii.gz 0
    # crlImageAlgebra ${calc}/onlyR.nii.gz multiply $insert ${calc}/onlyRinsert.nii.gz
    # crlImageAlgebra ${calc}/onlyRinsert.nii.gz add $insert ${calc}/LR-${sub2}
    # rm ${calc}/onlyR.nii.gz ${calc}/onlyRinsert.nii.gz
    echo

done < $inputs

echo

# Report if there was an error dectected in the partial volume corrections
echo "Report of partial volume success/failure:"
if [[ ${ecount} -gt 0 ]] ; then
	echo "A problem was detected with the output of PVC for the following cases. Check to make sure it is adjusting segmentations as intended"
	printf '%s\n' "${EARRAY[@]:0:$ecount}"
else echo "No PVC issues detected"
fi
