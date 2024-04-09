
show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input]
    flirt -in newvol -ref refvol -out outvol -init invol2refvol.mat -applyxfm
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi 
