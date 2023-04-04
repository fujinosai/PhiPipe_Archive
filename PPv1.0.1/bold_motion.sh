#! /bin/bash

## head motion correction of bold fMRI images and computing head motion measures using FSL's mcflirt
## written by Alex / 2019-01-09 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs head motion correction of bold fmri images and computes head motion measures

Usage example:

bash $0 -a /home/alex/data/rest.nii.gz 
        -b /home/alex/data 
        -c rest 
        -d /home/alex/data/rest_ref.nii.gz
        -e 5
        -f 0.5

Required arguments:

        -a:  4D bold fMRI image
        -b:  output directory
        -c:  output prefix

Optional arguments:

        -d:  reference image as the target
        -e:  number of dummy scans to be removed (default:0)
        -f:  fd threshold to detect large head motion volumes (defalut:0.5)

USAGE
    exit 1
}

## parse arguments 
if [[ $# -lt 3 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## bold fMRI file
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## reference image
             REFIMAGE=$OPTARG
             ;;
          e) ## number of dummy scans
             DVOL=$OPTARG
             ;;
          f) ## fd threshold
             THRESH=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## whether remove first few volumes
if [[ ! -z ${DVOL} ]] && [[ ${DVOL} -gt 0 ]]
then
     TOTVOL=$(fslnvols ${BOLDIMAGE})
     REMVOL=$(( ${TOTVOL} - ${DVOL} ))
     fslroi ${BOLDIMAGE} ${OUTDIR}/${PREFIX}_dr.nii.gz ${DVOL} ${REMVOL}
else
     ln -s ${BOLDIMAGE} ${OUTDIR}/${PREFIX}_dr.nii.gz
fi

## extract mid-time volume as reference file or use explicit reference file for registration
if [[ ! -z ${REFIMAGE} ]]
then
     ln -s ${REFIMAGE} ${OUTDIR}/${PREFIX}_ref.nii.gz
else
     TOTVOL=$(fslnvols ${OUTDIR}/${PREFIX}_dr.nii.gz)
     MIDVOL=$(expr ${TOTVOL} / 2)
     fslroi ${OUTDIR}/${PREFIX}_dr.nii.gz ${OUTDIR}/${PREFIX}_ref.nii.gz ${MIDVOL} 1
fi    

## motion correction

mcflirt -in ${OUTDIR}/${PREFIX}_dr.nii.gz -out ${OUTDIR}/${PREFIX}_mc -plots -reffile ${OUTDIR}/${PREFIX}_ref.nii.gz -spline_final

## compute framewise displacement, motion parameter extensions and motion outliers
if [[ -z ${THRESH} ]]
then
    THRESH=0.5
fi
Rscript -e "Args <- commandArgs(TRUE);\
   fname <- paste(Args[1],'_mc.par', sep='');\
   mc <- as.matrix(read.table(fname));\
   mcar <- rbind(0,mc[-dim(mc)[1],]);\
   mcsqr <- mc^2;\
   mcarsqr <- mcar^2;\
   mc_model <- cbind(mc,mcar,mcsqr,mcarsqr);\
   fname <- paste(Args[1],'_mc.model', sep='');\
   write.table(mc_model, fname, quote = FALSE, row.names = FALSE, col.names = FALSE);\
   mcrot <- mc[,1:3]*180/pi; mctrans <- mc[,4:6];\
   mc[,1:3] <- mc[,1:3]*50;\
   maxrot <- max(abs(mcrot)); maxtrans <- max(abs(mctrans));\
   fd <-rowSums(abs(rbind(0,diff(mc))));meanfd <- mean(fd);\
   fdspike <- ifelse(fd > Args[2], 0, 1);\
   fdratio <- sum(fd > Args[2])/length(fd);\
   mc_metric <- setNames(c(maxrot,maxtrans,meanfd,fdratio), c('MaxRot:','MaxTrans:','MeanFD:','OutlierRatio:'));\
   fname <- paste(Args[1], '_mc.metric', sep='');\
   write.table(mc_metric, fname, quote=FALSE, row.names=TRUE, col.names=FALSE);\
   fname <- paste(Args[1], '_mc.fd', sep='');\
   write.table(fd, fname, quote=FALSE, row.names=FALSE, col.names=FALSE);\
   fname <- paste(Args[1], '_mc.censor', sep='');\
   write.table(fdspike, fname, quote=FALSE, row.names=FALSE, col.names=FALSE)" ${OUTDIR}/${PREFIX} ${THRESH}

## plot motion parameters
cat ${OUTDIR}/${PREFIX}_mc.par | awk -v factor=57.29578 '{printf "%2.10f %2.10f %2.10f\n", $1 * factor, $2 * factor, $3 * factor}' > ${OUTDIR}/mytmp_rad2deg.txt
fsl_tsplot -i ${OUTDIR}/mytmp_rad2deg.txt -t 'estimated rotations (degree)' -u 1 --start=1 --finish=3 -a Rx,Ry,Rz -w 640 -h 144 -o ${OUTDIR}/mytmp_rot.png
fsl_tsplot -i ${OUTDIR}/${PREFIX}_mc.par -t 'estimated translations (mm)' -u 1 --start=4 --finish=6 -a Tx,Ty,Tz -w 640 -h 144 -o ${OUTDIR}/mytmp_trans.png
fsl_tsplot -i ${OUTDIR}/${PREFIX}_mc.fd -t 'framewise displacement (mm)' -u 1 -a fd -w 640 -h 144 -o ${OUTDIR}/mytmp_fd.png
pngappend ${OUTDIR}/mytmp_rot.png + ${OUTDIR}/mytmp_trans.png + ${OUTDIR}/mytmp_fd.png ${OUTDIR}/${PREFIX}_motion.png

## remove temporary files
rm ${OUTDIR}/mytmp* 
rm ${OUTDIR}/${PREFIX}_dr.nii.gz
