#! /bin/bash

## overlay one image over another and plot orthogonal slices for quality check
## written by Alex / 2019-01-08 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` overlays one image over another and plot orthogonal slices for quality check

Usage example:

bash $0 -a /home/alex/data/t1.nii.gz 
        -b /home/alex/data/t1_brain.nii.gz 
        -c /home/alex/data/
        -d t1_bet
        -e 1
        -f 1

Required arguments:

        -a:  background image
        -b:  overlay image
        -c:  output directory
        -d:  output prefix
        
Optional arguments:

        -e:  display mode (default:mask, 1/2:contour/edge)
        -f:  reorient image to standard space (set 1 to turn on)

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 4 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## background image
             BIMAGE=$OPTARG
             ;;
          b) ## overlay image
             OIMAGE=$OPTARG
             ;;
          c) ## output directory
             OUTDIR=$OPTARG
             ;;
          d) ## output prefix
             PREFIX=$OPTARG
             ;;
          e) ## display mode
             MODE=$OPTARG
             ;;
          f) ## reorient to standard space
             REORIENT=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## change to output directory to save typing
cd ${OUTDIR}

## whether orient image to standard space
if [[ ${REORIENT} -eq 1 ]]
then 
     fslreorient2std ${BIMAGE} mytmp_bimage.nii.gz; BIMAGE=mytmp_bimage.nii.gz
     fslreorient2std ${OIMAGE} mytmp_oimage.nii.gz; OIMAGE=mytmp_oimage.nii.gz
fi

##  whether plot the contour/edge
if [[ ${MODE} -eq 1 ]]
then
     slicer ${BIMAGE} ${OIMAGE} -s 2 -x 0.35 mytmp_s1.png -x 0.45 mytmp_s2.png -x 0.55 mytmp_s3.png -x 0.65 mytmp_s4.png -y 0.35 mytmp_c1.png -y 0.45 mytmp_c2.png -y 0.55 mytmp_c3.png -y 0.65 mytmp_c4.png -z 0.35 mytmp_a1.png -z 0.45 mytmp_a2.png -z 0.55 mytmp_a3.png -z 0.65 mytmp_a4.png 
elif [[ ${MODE} -eq 2 ]]
then
     3dcalc -a ${OIMAGE} -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k -expr 'ispositive(a)*amongst(0,b,c,d,e,f,g)' -prefix mytmp_edge.nii.gz
     overlay 1 1 ${BIMAGE} -a mytmp_edge.nii.gz 1 1 mytmp_overlay.nii.gz
     slicer mytmp_overlay.nii.gz -s 2 -x 0.35 mytmp_s1.png -x 0.45 mytmp_s2.png -x 0.55 mytmp_s3.png -x 0.65 mytmp_s4.png -y 0.35 mytmp_c1.png -y 0.45 mytmp_c2.png -y 0.55 mytmp_c3.png -y 0.65 mytmp_c4.png -z 0.35 mytmp_a1.png -z 0.45 mytmp_a2.png -z 0.55 mytmp_a3.png -z 0.65 mytmp_a4.png
else 
     overlay 1 1 ${BIMAGE} -a ${OIMAGE} 1 1 mytmp_overlay.nii.gz
     slicer mytmp_overlay.nii.gz -s 2 -x 0.35 mytmp_s1.png -x 0.45 mytmp_s2.png -x 0.55 mytmp_s3.png -x 0.65 mytmp_s4.png -y 0.35 mytmp_c1.png -y 0.45 mytmp_c2.png -y 0.55 mytmp_c3.png -y 0.65 mytmp_c4.png -z 0.35 mytmp_a1.png -z 0.45 mytmp_a2.png -z 0.55 mytmp_a3.png -z 0.65 mytmp_a4.png
fi

## append all slices and remove temporary files
pngappend mytmp_s1.png + mytmp_s2.png + mytmp_s3.png + mytmp_s4.png + mytmp_c1.png + mytmp_c2.png + mytmp_c3.png + mytmp_c4.png + mytmp_a1.png + mytmp_a2.png + mytmp_a3.png + mytmp_a4.png ${PREFIX}.png

rm mytmp*

