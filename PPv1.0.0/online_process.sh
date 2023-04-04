#! /bin/bash

## processing multi-modal data online
## written by Alex / 2019-09-24 / free_learner@163.com
## revised by Alex / 2019-10-08 / free_learner@163.com
## revised by Alex / 2020-04-10 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` processes t1/bold/dwi images online

Usage example:

bash $0 -a /home/alex/PhiPipe
        -b /home/alex/data/t1.nii.gz 
        -c /home/alex/data/bold.nii.gz
        -d 2
        -e 0
        -f /home/alex/data/dwi.nii.gz
        -g /home/alex/data/bvals
        -h /home/alex/data/bvecs 
        -i 2
        -j 0
        -k proj01
        -l sub01

Required arguments:

        -a:  scripts path
        -b:  t1 image
        -c:  bold image
        -d:  repetition time
        -e:  slice timing type (0/1/2/3/4/5/6:none/seqplus/seqminus/altplus/altplus2/altminus/altminus2)
        -f:  dwi image
        -g:  b-value
        -h:  b-vector
        -i:  phase encoding direction (1/2/3:X/Y/Z)
        -j:  do probabilistic tractography (Yes/No:1/0)
        -k:  project ID
        -l:  subject ID

USAGE
    exit 1
}

if [[ $# -lt 4 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:j:k:l:" OPT
    do
      case $OPT in
          a) ## PhiPipe path
             SCRIPTDIR=$OPTARG
             ;;
          b) ## T1-weighted image
             T1IMAGE=$OPTARG
             ;;
          c) ## BOLD image
             BOLDIMAGE=$OPTARG
             ;;
          d) ## Repetition Time
             TR=$OPTARG
             ;;
          e) ## Slice Timing Type
             STTYPE=$OPTARG
             ;;
          f) ## DWI image
             DWIIMAGE=$OPTARG
             ;;
          g) ## b-value
             BVAL=$OPTARG
             ;;
          h) ## b-vector
             BVEC=$OPTARG
             ;;
          i) ## phase encoding direction
             PEDIR=$OPTARG
             ;;
          j) ## do probabilistic tractography
             DOPT=$OPTARG
             ;;
          k) ## project ID
             PJID=$OPTARG
             ;;
          l) ## subject ID
             SJID=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

if [[ ! -d ${SCRIPTDIR} ]]
then
    echo "Error: ${SCRIPTDIR} not found. Please check!!!"
    exit 1
fi
export PhiPipe=${SCRIPTDIR}

## T1/BOLD/DWI processing
if [[ -f ${T1IMAGE} ]]
then
   ## run t1 pipeline
   LOGDIR=$(dirname ${T1IMAGE})
   echo "T1 Processing" > ${LOGDIR}/current_status.log
   bash ${PhiPipe}/t1_process.sh -a ${T1IMAGE}
fi

if [[ -f ${BOLDIMAGE} ]]
then
   ## run bold pipeline
   echo "REST Processing" > ${LOGDIR}/current_status.log
   bash ${PhiPipe}/t1bold_process.sh -a ${T1IMAGE} -b ${BOLDIMAGE} \
         -g 5 -i ${TR} -j ${STTYPE} -k 0.01 -l 0.1
fi

if [[ -f ${DWIIMAGE} ]]
then
   ## run dwi pipeline
   echo "DWI Processing" > ${LOGDIR}/current_status.log
   bash ${PhiPipe}/t1dwi_process.sh -a ${T1IMAGE} -b ${DWIIMAGE} \
        -g ${BVAL} -h ${BVEC} -i ${PEDIR} -k ${DOPT}
fi

## T1 image post-hoc processing
if [[ -f ${T1IMAGE} ]]
then
   ## zip files for downloading
   T1DIR=$(dirname ${T1IMAGE})
   T1DOWNLD=${T1DIR}/t1_downld
   mkdir -p ${T1DOWNLD}
   # all t1 results
    SOURCE=${T1DIR}/t1_proc
    TARGET=${T1DOWNLD}/${PJID}_${SJID}_t1_results.zip
    cd ${SOURCE}
    zip -r ${TARGET} ./*
   # t1 stats
    SOURCE=${T1DIR}/t1_proc/stats
    TARGET=${T1DOWNLD}/${PJID}_${SJID}_t1_stats.zip
    cd ${SOURCE}
    zip -r ${TARGET} ./*
   ## make webpages for downloading
   echo "<HTML><TITLE>Downlad Processed Results</TITLE><BODY>" > ${T1DIR}/download.html
   echo "<p>Processed Results for <b>${PJID} ${SJID}</b></p>" >> ${T1DIR}/download.html
   echo "<a href="${T1DOWNLD}/${PJID}_${SJID}_t1_results.zip">All T1 processed results</a><br>" >> ${T1DIR}/download.html
   echo "<a href="${T1DOWNLD}/${PJID}_${SJID}_t1_stats.zip">Processed T1 files for statistics</a><br>" >> ${T1DIR}/download.html
   ## make webpages for T1 quality control
   mkdir -p ${T1DOWNLD}/qc
   if [[ -f ${T1DIR}/t1_proc/reg/t12mni.png ]]
   then
     cp ${T1DIR}/t1_proc/reg/t12mni.png ${T1DOWNLD}/qc/t12mni.png
   fi
   for struct in brainmask wmmask csfmask DKAseg
   do
     cp ${T1DIR}/t1_proc/masks/*${struct}.png ${T1DOWNLD}/qc/t1_${struct}.png
   done
   echo "<HTML><TITLE>T1 quality control</TITLE><BODY>" > ${T1DOWNLD}/t1qc.html
   echo "<p>Quality Check for <b>${PJID} ${SJID}</b></p>" >> ${T1DOWNLD}/t1qc.html
   echo "<a href="${T1DOWNLD}/qc/t1_brainmask.png"><img src="${T1DOWNLD}/qc/t1_brainmask.png" WIDTH=1000><br>T1 brain extraction</a><br>" >> ${T1DOWNLD}/t1qc.html
   echo "<a href="${T1DOWNLD}/qc/t1_wmmask.png"><img src="${T1DOWNLD}/qc/t1_wmmask.png" WIDTH=1000><br>T1 WM segmentation</a><br>" >> ${T1DOWNLD}/t1qc.html
   echo "<a href="${T1DOWNLD}/qc/t1_csfmask.png"><img src="${T1DOWNLD}/qc/t1_csfmask.png" WIDTH=1000><br>T1 CSF segmentation </a><br>" >> ${T1DOWNLD}/t1qc.html
   echo "<a href="${T1DOWNLD}/qc/t1_DKAseg.png"><img src="${T1DOWNLD}/qc/t1_DKAseg.png" WIDTH=1000><br>T1 DK+Aseg parcellation </a><br>" >> ${T1DOWNLD}/t1qc.html
   if [[ -f ${T1DOWNLD}/qc/t12mni.png ]]
   then
     echo "<a href="${T1DOWNLD}/qc/t12mni.png"><img src="${T1DOWNLD}/qc/t12mni.png" WIDTH=1000><br>T1 to MNI152 registration </a><br>" >> ${T1DOWNLD}/t1qc.html
   fi
   echo '</BODY></HTML>' >> ${T1DOWNLD}/t1qc.html
fi

## BOLD image processing
if [[ -f ${BOLDIMAGE} ]]
then
   ## zip files for downloading
   BOLDDIR=$(dirname ${BOLDIMAGE})
   BOLDDOWNLD=${BOLDDIR}/bold_downld
   mkdir -p ${BOLDDOWNLD}
   # all bold results
   SOURCE=${BOLDDIR}/bold_proc
   TARGET=${BOLDDOWNLD}/${PJID}_${SJID}_bold_results.zip
   cd ${SOURCE}
   zip -r ${TARGET} ./*
   # bold stats
   SOURCE=${BOLDDIR}/bold_proc/stats
   TARGET=${BOLDDOWNLD}/${PJID}_${SJID}_bold_stats.zip
   cd ${SOURCE}
   zip -r ${TARGET} ./*
   ## make webpages for downloading
   echo "<a href="${BOLDDOWNLD}/${PJID}_${SJID}_bold_results.zip">All BOLD fMRI processed results</a><br>" >> ${T1DIR}/download.html
   echo "<a href="${BOLDDOWNLD}/${PJID}_${SJID}_bold_stats.zip">Processed BOLD fMRI files for statistics</a><br>" >> ${T1DIR}/download.html
   ## make webpages for bold quality control
   mkdir -p ${BOLDDOWNLD}/qc
   cp ${BOLDDIR}/bold_proc/reg/bold2t1.png ${BOLDDOWNLD}/qc/bold2t1.png
   for struct in brainmask wmmask csfmask DKAseg
   do
     cp ${BOLDDIR}/bold_proc/masks/*${struct}.png ${BOLDDOWNLD}/qc/bold_${struct}.png
   done
   cp ${BOLDDIR}/bold_proc/mni/bold2mni.png ${BOLDDOWNLD}/qc/bold2mni.png
   cp ${BOLDDIR}/bold_proc/motion/*.png ${BOLDDOWNLD}/qc/bold_motion.png
   cp ${BOLDDIR}/bold_proc/motion/*.metric ${BOLDDOWNLD}/qc/bold_mc.metric
   MEANFD=$(cat ${BOLDDOWNLD}/qc/bold_mc.metric | sed -n 3p | cut -d ":" -f2 | sed 's/\ //g' | cut -c 1-4)
   OUTRATIO=$(cat ${BOLDDOWNLD}/qc/bold_mc.metric | sed -n 4p | cut -d ":" -f2 | sed 's/\ //g' | cut -c 1-4)
   echo "<HTML><TITLE>BOLD fMRI quality control</TITLE><BODY>" > ${BOLDDOWNLD}/boldqc.html
   echo "<p>Quality Check for <b>${PJID} ${SJID}</b></p>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold_motion.png"><img src="${BOLDDOWNLD}/qc/bold_motion.png" WIDTH=1000 ><br>BOLD motion (meanFD:${MEANFD} outlierRatio:${OUTRATIO})</a><br>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold_brainmask.png"><img src="${BOLDDOWNLD}/qc/bold_brainmask.png" WIDTH=1000><br>BOLD brain mask</a><br>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold_wmmask.png"><img src="${BOLDDOWNLD}/qc/bold_wmmask.png" WIDTH=1000><br>BOLD WM mask</a><br>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold_csfmask.png"><img src="${BOLDDOWNLD}/qc/bold_csfmask.png" WIDTH=1000><br>BOLD CSF mask </a><br>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold_DKAseg.png"><img src="${BOLDDOWNLD}/qc/bold_DKAseg.png" WIDTH=1000><br>BOLD DKAseg mask </a><br>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold2t1.png"><img src="${BOLDDOWNLD}/qc/bold2t1.png" WIDTH=1000><br>BOLD to T1 registration </a><br>" >> ${BOLDDOWNLD}/boldqc.html
   echo "<a href="${BOLDDOWNLD}/qc/bold2mni.png"><img src="${BOLDDOWNLD}/qc/bold2mni.png" WIDTH=1000><br>BOLD to MNI transformation </a><br>" >> ${BOLDDOWNLD}/boldqc.html   
   echo '</BODY></HTML>' >> ${BOLDDOWNLD}/boldqc.html
fi

## DWI image processing
if [[ -f ${DWIIMAGE} ]]
then
   ## zip files for downloading
   DWIDIR=$(dirname ${DWIIMAGE})
   DWIDOWNLD=${DWIDIR}/dwi_downld
   mkdir -p ${DWIDOWNLD}
   # all dwi results
   SOURCE=${DWIDIR}/dwi_proc
   TARGET=${DWIDOWNLD}/${PJID}_${SJID}_dwi_results.zip
   cd ${SOURCE}
   zip -r ${TARGET} ./*
   # dwi stats
   SOURCE=${DWIDIR}/dwi_proc/stats
   TARGET=${DWIDOWNLD}/${PJID}_${SJID}_dwi_stats.zip
   cd ${SOURCE}
   zip -r ${TARGET} ./*
   ## make webpages for downloading
   echo "<a href="${DWIDOWNLD}/${PJID}_${SJID}_dwi_results.zip">All DWI processed results</a><br>" >> ${T1DIR}/download.html
   echo "<a href="${DWIDOWNLD}/${PJID}_${SJID}_dwi_stats.zip">Processed DWI files for statistics</a><br>" >> ${T1DIR}/download.html
   ## make webpages for T1 quality control
   mkdir -p ${DWIDOWNLD}/qc
   cp ${DWIDIR}/dwi_proc/reg/*.png ${DWIDOWNLD}/qc/dwi2t1.png
   cp ${DWIDIR}/dwi_proc/dtifit/*.png ${DWIDOWNLD}/qc/fa2mni.png
   for struct in brainmask DKAseg
   do
     cp ${DWIDIR}/dwi_proc/masks/*${struct}.png ${DWIDOWNLD}/qc/dwi_${struct}.png
   done
   echo "<HTML><TITLE>DWI quality control</TITLE><BODY>" > ${DWIDOWNLD}/dwiqc.html
   echo "<p>Quality Check for <b>${PJID} ${SJID}</b></p>" >> ${DWIDOWNLD}/dwiqc.html
   echo "<a href="${DWIDOWNLD}/qc/dwi_brainmask.png"><img src="${DWIDOWNLD}/qc/dwi_brainmask.png" WIDTH=1000><br>DWI brain mask</a><br>" >> ${DWIDOWNLD}/dwiqc.html
   echo "<a href="${DWIDOWNLD}/qc/dwi_DKAseg.png"><img src="${DWIDOWNLD}/qc/dwi_DKAseg.png" WIDTH=1000><br>DWI DKAseg mask</a><br>" >> ${DWIDOWNLD}/dwiqc.html
   echo "<a href="${DWIDOWNLD}/qc/dwi2t1.png"><img src="${DWIDOWNLD}/qc/dwi2t1.png" WIDTH=1000><br>DWI to T1 registration</a><br>" >> ${DWIDOWNLD}/dwiqc.html
   echo "<a href="${DWIDOWNLD}/qc/fa2mni.png"><img src="${DWIDOWNLD}/qc/fa2mni.png" WIDTH=1000><br>FA to MNI152 transformation</a><br>" >> ${DWIDOWNLD}/dwiqc.html
   echo '</BODY></HTML>' >> ${DWIDOWNLD}/dwiqc.html
fi

echo '</BODY></HTML>' >> ${T1DIR}/download.html

echo "Finished" > ${LOGDIR}/current_status.log
