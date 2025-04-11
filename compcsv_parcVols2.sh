#!/bin/bash

if [ -z "$2" ] ; then
	echo ""
	echo "	Incorrect arguments supplied!"
	echo "	usage: sh $0 PARCELLATION OUTPUT_CSV"
	echo "	Outputs selected volumes (from the atlas key in the script)"
	echo "	for the input into a spreadsheet. If it's a new .csv, column"
	echo "	headers will be added. If not, it will just append ID & volumes."
	echo ""
	exit
	fi

# text file with each label (format: "NUMBER NAME") in a new line
atlaskey="documents/4compute-STAkey-vENA-2_4.txt"
# comput volume binary
compute="crlComputeVolume"
parc=${1}
output=${2}

# verify inputs
if [[ ! -f $parc ]] ; then
	echo "ERR: $parc is not a file"
	exit 1
	fi
csvType=$(file "$output")
if [[ -f $output && ! $csvType == *":"*"text"* ]] ; then
	echo "ERR: Specified output is not a text file"
	exit 1
	fi

declare -a labels
declare -a names
let count=0
# store label information
while read keyline ; do
	labels[${count}]=`echo $keyline | awk -F' ' '{ print $1 }'`
	names[${count}]=`echo $keyline | awk -F' ' '{print $2 }'`
	# check if there is any label value over 1000 - crlComputeVolume can't handle that
	if [ ${labels[$count]} -gt 1000 ] ; then
		echo "WARNING: as of 02/14/17 crlComputeVolume cannot handle label values greater than 1000 !!!"
	fi
	((count++))
	done < "${atlaskey}"

# setting column headers - this only happens with a new csv
if [[ ! -f $output ]] ; then
	let sedNUM=1
	let xcount=0
	echo "SubjectID" >> ${output}
	# this is a while loop to print out our column of label names into the header row
        while read keyline ; do
		# just print out our key to terminal
                echo "selected: ${keyline}"
                # take the line as it exists now
		line=`sed "1q;d" ${output}`
                # replace our first row with itself PLUS the next label name tacked on 
		sed -i ''$sedNUM's/.*/'$line','${names[$xcount]}'/' ${output}
                ((xcount++))
		done < "${atlaskey}"
		echo "Number of labels: ${#labels[@]}"
	((sedNUM++))
else
	# if the csv already exists (like if the first row was just added), the above will be skipped
	echo "Output .csv already exists. Will not write column headers."
	currentLine=`wc -l ${output} | awk -F' ' '{print $1 }'`
	sedNUM="$(($currentLine+1))"
	fi

let xcount=0
# put SUBJID into first column
echo ${parc} >> ${output}
# a while loop for putting the label values for one case into a row
while ( [ ${xcount} -lt ${count} ] ) ; do
	# get the volume for this label
	vol=`${compute} ${parc} ${labels[$xcount]}`
	# take the line as it exists now
	line=`sed "${sedNUM}q;d" ${output}`
	# replace with itself PLUS the next label volume
	sed -i ''$sedNUM's|.*|'$line','$vol'|' ${output}
	# print result to terminal
	echo "${parc}, label ${labels[$xcount]}: ${vol}"
	((xcount++))
	done
((sedNUM++))
