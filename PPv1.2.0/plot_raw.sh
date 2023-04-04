#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-------------------------------------------------------------------
`basename $0` plots orthogonal slices for raw data quality check
-------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/t1.nii.gz 
        -b /home/alex/output
        -c t1
        -d 1
-------------------------------------------------------------------
Required arguments:
        -a:  raw 3D/4D image (for 4D image, plot the average data) 
        -b:  output directory
        -c:  output prefix
        
Optional arguments:
        -d:  reorient image to standard space (set 1 to turn on)
-------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:" OPT
    do
      case $OPT in
          a) ## raw image
             RAWIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## reorient to standard space
             REORIENT=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
    done
fi

## if PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT file/OUTPUT folder exist?
bash ${PhiPipe}/check_inout.sh -a ${RAWIMAGE} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## make temporary directory to save intermediate files
## $$ is the process ID to make the name unique
## to make temporary directory, this script could be run by multiple processes and generate results in the same folder simutaneously
mkdir -p ${OUTDIR}/mytmp$$

## change to temporary directory to save typing
## ORIGDIR saves the original directory before changing into the temporary one
ORIGDIR=$(pwd)
cd ${OUTDIR}/mytmp$$

## if 4D image, calculate the mean image
NVOL=$(fslnvols ${RAWIMAGE})
if [[ $NVOL -ne 1 ]]
then
    fslmaths ${RAWIMAGE} -Tmean mytmp_rawmean.nii.gz
    RAWIMAGE=mytmp_rawmean.nii.gz
fi

## whether orient image to standard space
if [[ ${REORIENT} -eq 1 ]]
then 
     fslreorient2std ${RAWIMAGE} mytmp_rawimage.nii.gz
     RAWIMAGE=mytmp_rawimage.nii.gz
fi

##  plot
MinMax=($(fslstats ${RAWIMAGE} -r))
slicer ${RAWIMAGE} -s 2 -i ${MinMax[0]} ${MinMax[1]} -u -x 0.35 mytmp_s1.png -x 0.45 mytmp_s2.png -x 0.55 mytmp_s3.png -x 0.65 mytmp_s4.png -y 0.35 mytmp_c1.png -y 0.45 mytmp_c2.png -y 0.55 mytmp_c3.png -y 0.65 mytmp_c4.png -z 0.35 mytmp_a1.png -z 0.45 mytmp_a2.png -z 0.55 mytmp_a3.png -z 0.65 mytmp_a4.png 

## append all slices
pngappend mytmp_s1.png + mytmp_s2.png + mytmp_s3.png + mytmp_s4.png + mytmp_c1.png + mytmp_c2.png + mytmp_c3.png + mytmp_c4.png + mytmp_a1.png + mytmp_a2.png + mytmp_a3.png + mytmp_a4.png ${OUTDIR}/${PREFIX}.png

## return to the original directory and remove temporary folder 
cd ${ORIGDIR}
rm -r ${OUTDIR}/mytmp$$

## check the existence of output files
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.png
if [[ $? -eq 1 ]]
then
    exit 1
fi
