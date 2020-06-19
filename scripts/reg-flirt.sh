#!/bin/bash

# Fetal registration using example case brains

if [[ $# -lt 3 || $# -gt 4 ]] ; then
        echo "No argument supplied!"
        echo "usage: sh $0 [cropped brain image] [rounded GA (weeks)] [reference] [-w]"
        echo
        echo "A fetal reconstruction pipeline script"
        echo "Registers [cropped brain image] to reference images which are in atlas space"
        echo
       	echo "[reference] must be either: 'ATLAS', 'CASES', or a path to a target brain image"
        echo "add -w option to also register to plus and minus 1 week GA references"
        exit
        fi

INPUT=`readlink -f $1`
GA="$2"
TARGET="$3"
OPT="$4"
DIR=`dirname $INPUT`
SCRIPT="${DIR}/run-reg.sh"

if [[ -f $SCRIPT ]] ; then rm -v $SCRIPT ; fi

# registration command to be called later
function register {
                baseT="`basename ${template%%.*}`"
                output=${basebrain}_FLIRTto_${baseT}
                echo "input is $INPUT"
                echo "base name is $basebrain" 
                echo "template image is $template"
		echo "template GA is $tga"
                echo "output files are $output"
                echo "Running FLIRT!"
                cmd="flirt -dof 6 -cost corratio -in $INPUT -ref ${template} -omat ${output}.mat -out ${output}"
		echo $cmd >> $SCRIPT
		$cmd
                }

# for naming output files
basebrain="${INPUT%%.*}"

# lists with registration templates
if   [[ $TARGET == "CASES" ]] ; then
	echo "*** Registering $INPUT to same-age cases ***"
        tlist="/fileserver/fetal/segmentation/templates/regtemplates/cases.csv"
elif [[ $TARGET == "ATLAS" ]] ; then
	echo "*** Registering $INPUT to same-age STA images ***"
        tlist="/fileserver/fetal/segmentation/templates/regtemplates/STA.csv"
elif [[ -f $TARGET ]] ; then
        echo "Registering to file"
	template=`readlink -f $TARGET`
	tga="NA"
	basebrain="${INPUT%%.*}"
	register
	warning="n"
else
        echo "Supplied argument for reference invalid"
        exit
        fi

if [[ $TARGET == "ATLAS" || $TARGET == "CASES" ]] ; then 
	# inspect list of possible registration templates
	while read line ; do 
		# name of template
		template=`readlink -f $(echo $line | awk -F' ' '{ print $1 }')`
		# GA of template
		tga=`echo $line | awk -F' ' '{ print $2 }'`
		# check if template GA is match for our input GA, if so run command
		# if -w is set it will check for +/-1 GA templates
		if [[ $GA -eq $tga ]] || [[ $OPT = "-w" && ( ${GA}-${tga} -eq 1 || ${GA}-${tga} -eq -1 ) ]] ; then
			register
			warning="n"
			echo
		fi
	done < ${tlist}
	fi

if [[ ! "$warning" = "n" ]] ; then
	echo "No templates of correct GA were found for ${input}"
fi
