#! /bin/bash

## construct ROI-ROI connectivity matrix using FSL' probtrackx2
## written by Alex / 2019-09-15 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` constructs ROI-ROI connectivity matrix using FSL' probtrackx2

Usage example:

bash $0 -a /home/alex/data/bedpostx
        -b /home/alex/data
        -c roi_atlas
        -d /home/alex/data/roi_atlas.nii.gz
        -e /home/alex/data/roi_labels.txt

Required arguments:

        -a: bedpostx directory
        -b: output directory
        -c: output prefix
        -d: roi masks
        -e: roi labels

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 5 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## bedpostx directory
             BEDPOSTX=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## ROI mask
             ROIMASK=$OPTARG
             ;;
          e) ## ROI label
             LABEL=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## split roi masks
mkdir -p ${OUTDIR}/mytmp_roimask
for idx in $(cat ${LABEL} | awk '{print $1}')
do
    3dcalc -a ${ROIMASK} -expr "not(a-${idx})" -prefix ${OUTDIR}/mytmp_roimask/roi${idx}.nii.gz
    ls ${OUTDIR}/mytmp_roimask/roi${idx}.nii.gz >> ${OUTDIR}/mytmp_roimask/masks.txt
done

## probablistic tractography
probtrackx2 --network -x ${OUTDIR}/mytmp_roimask/masks.txt -l --onewaycondition --omatrix1 --opd --ompl -c 0.2 -S 2000 --steplength=0.5 -P 5000 --fibthresh=0.01 --distthresh=0.0 --sampvox=0.0 --forcedir -s ${BEDPOSTX}/merged -m ${BEDPOSTX}/nodif_brain_mask --dir=${OUTDIR}/${PREFIX}

## compute connectivity probability matrix
Rscript -e " Args <- commandArgs(TRUE);\
            fname <- paste(Args[1],'/fdt_network_matrix', sep='');\
            countMat <- as.matrix(read.table(fname));\
            NROI <- nrow(countMat);\
            probMat <- matrix(0,nrow=NROI,ncol=NROI);\
            probMat <- countMat/matrix(rep(rowSums(countMat),NROI), nrow=NROI);\
            probMat <- (probMat + t(probMat))/2;\
            fname <- paste(Args[1],'/fdt_prob.mat', sep='');\
            write.table(probMat, fname, quote=FALSE, row.names=FALSE, col.names=FALSE);\
            " ${OUTDIR}/${PREFIX}

## check ROI coverage
bash ${PhiPipe}/roi_stats.sh -a ${BEDPOSTX}/nodif_brain_mask.nii.gz -b ${OUTDIR}/${PREFIX} -c ${PREFIX} -d ${ROIMASK} -e ${LABEL}
rm ${OUTDIR}/${PREFIX}/${PREFIX}.mean

## remove temporary files
rm -r ${OUTDIR}/mytmp_roimask

