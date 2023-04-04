#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
--------------------------------------------------------------------
`basename $0` checks whether input/output files or folders exist
--------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/t1.nii.gz
        -a /home/alex/input/rest.nii.gz
        -b /home/alex/output

Required arguments (at least one of them is given):
        -a: files with absolute path
        -b: folders with absolute path
--------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 2 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:" OPT
    do
      case $OPT in
         a) ## files
             FARRAY+=("$OPTARG")
             ;;
         b) ## directories
             DARRAY+=("$OPTARG")
             ;;
         *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
    done
fi

## check files
if [[ ! -z ${FARRAY} ]]
then
    for FILE in "${FARRAY[@]}"
    do
        if [[ ! -f $FILE ]]
        then 
            echo "File $FILE doesn't exist. Please check !!!"
            exit 1
        fi
    done
fi

## check folders
if [[ ! -z ${DARRAY} ]]
then
    for DIR in "${DARRAY[@]}"
    do
        if [[ ! -d $DIR ]]
        then
            echo "Folder $DIR doesn't exist. Please check !!!"
            exit 1
        fi
    done
fi
