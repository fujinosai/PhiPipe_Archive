#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
----------------------------------------------------------------------------------
`basename $0` retrieves parcel-wise morphological measures from recon-all results
----------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/freesurfer 
        -b /home/alex/output/stats
        -c t1
        -d 1
----------------------------------------------------------------------------------
Required arguments:
        -a:  FreeSurfer recon-all directory   
        -b:  output directory
        -c:  output prefix

Optional arguments:
        -d:  use Aseg Atlas (set 1 to turn on)
        -e:  use DK Atlas (set 1 to turn on)
        -f:  use Schaefer Atlas (set 1 to turn on)
----------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## recon-all directory
             RECONALL=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## use Aseg Atlas
             USEAseg=$OPTARG
             ;;
          e) ## use DK Atlas
             USEDK=$OPTARG
             ;;
          f) ## use Schaefer Atlas
             USESchaefer=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -b ${RECONALL} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## set FreeSurfer environmental variables
export SUBJECTS_DIR=$(dirname ${RECONALL})
SUBJECT=$(basename ${RECONALL})

## extract the volume of Aseg Atlas
if [[ ${USEAseg} -eq 1 ]]
then
    asegstats2table --subjects ${SUBJECT} --meas volume --tablefile ${OUTDIR}/mytmp_Aseg_volume.txt
    ## remove uninteresting or redundant columns
    cat ${OUTDIR}/mytmp_Aseg_volume.txt | cut -f 6-9,13,14,16,24-30,67 | sed 's/EstimatedTotalIntraCranialVol/eTIV/' > ${OUTDIR}/${PREFIX}_Aseg_volume.sum
    rm ${OUTDIR}/mytmp_*.txt
    ## check the existence of output files
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_Aseg_volume.sum
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi

## extract the thickness/area/volume of DK Atals
if [[ ${USEDK} -eq 1 ]]
then
    for meas in thickness area volume
    do
      for hemi in lh rh
      do
          aparcstats2table --subjects ${SUBJECT} --hemi ${hemi} --parc aparc --meas ${meas} --tablefile ${OUTDIR}/mytmp_DK_${hemi}_${meas}.txt
          ## remove uninteresting or redundant columns (e.g., BrainSegVolNotVent)
          if [[ $meas == "volume" ]]
          then
              ## remove redundant column in volume estimation (i.e., eTIV)
              if [[ $hemi == "lh" ]]
              then
                  cat ${OUTDIR}/mytmp_DK_${hemi}_${meas}.txt | cut -f 2-35 > ${OUTDIR}/${PREFIX}_DK_${hemi}_${meas}.txt
              else
                  cat ${OUTDIR}/mytmp_DK_${hemi}_${meas}.txt | cut -f 2-35,37 > ${OUTDIR}/${PREFIX}_DK_${hemi}_${meas}.txt
              fi
          else
              cat ${OUTDIR}/mytmp_DK_${hemi}_${meas}.txt | cut -f 2-36 > ${OUTDIR}/${PREFIX}_DK_${hemi}_${meas}.txt
          fi
      done
      ## merge lh & rh into one file
      paste ${OUTDIR}/${PREFIX}_DK_lh_${meas}.txt ${OUTDIR}/${PREFIX}_DK_rh_${meas}.txt > ${OUTDIR}/mytmp_DK_${meas}.txt
      ## remove extra strings to make region names shorter
      cat ${OUTDIR}/mytmp_DK_${meas}.txt | sed "s/_${meas}//g" > ${OUTDIR}/${PREFIX}_DK_${meas}.txt
    done
    rm ${OUTDIR}/mytmp_*.txt ${OUTDIR}/${PREFIX}_DK_*h_*.txt
    ## rename the suffix to be more informative and consistent with other modalities
    mv ${OUTDIR}/${PREFIX}_DK_thickness.txt ${OUTDIR}/${PREFIX}_DK_thickness.mean
    mv ${OUTDIR}/${PREFIX}_DK_area.txt ${OUTDIR}/${PREFIX}_DK_area.sum
    mv ${OUTDIR}/${PREFIX}_DK_volume.txt ${OUTDIR}/${PREFIX}_DK_volume.sum
    ## check the existence of output files
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_DK_thickness.mean -a ${OUTDIR}/${PREFIX}_DK_area.sum -a ${OUTDIR}/${PREFIX}_DK_volume.sum
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi

## extract the thickness/area/volume of Schaefer Atlas
if [[ ${USESchaefer} -eq 1 ]]
then
    for meas in thickness area volume
    do
      for hemi in lh rh
      do
          aparcstats2table --subjects ${SUBJECT} --hemi ${hemi} --parc Schaefer.100Parcels.7Networks --meas ${meas} --tablefile ${OUTDIR}/mytmp_Schaefer_${hemi}_${meas}.txt
          ## remove uninteresting or redundant columns (e.g., BrainSegVolNotVent)
          if [[ $meas == "volume" ]]
          then
              ## remove redundant column in volume estimation (i.e., eTIV)
              if [[ $hemi == "lh" ]]
              then
                  cat ${OUTDIR}/mytmp_Schaefer_${hemi}_${meas}.txt | cut -f 2-51 > ${OUTDIR}/${PREFIX}_Schaefer_${hemi}_${meas}.txt
              else
                  cat ${OUTDIR}/mytmp_Schaefer_${hemi}_${meas}.txt | cut -f 2-51,53 > ${OUTDIR}/${PREFIX}_Schaefer_${hemi}_${meas}.txt
              fi
          else
              cat ${OUTDIR}/mytmp_Schaefer_${hemi}_${meas}.txt | cut -f 2-52 > ${OUTDIR}/${PREFIX}_Schaefer_${hemi}_${meas}.txt
          fi
      done
      ## merge lh & rh into one file
      paste ${OUTDIR}/${PREFIX}_Schaefer_lh_${meas}.txt ${OUTDIR}/${PREFIX}_Schaefer_rh_${meas}.txt > ${OUTDIR}/mytmp_Schaefer_${meas}.txt
      ## remove extra strings (lh_/rh_, _thickness) to make region names shorter
      cat ${OUTDIR}/mytmp_Schaefer_${meas}.txt | sed "s/_${meas}//g" | sed "s/[lr]h_7Networks_//g" > ${OUTDIR}/${PREFIX}_Schaefer_${meas}.txt
    done
    rm ${OUTDIR}/mytmp_*.txt ${OUTDIR}/${PREFIX}_Schaefer_*h_*.txt
    ## rename the suffix to be more informative and consistent with other modalities
    mv ${OUTDIR}/${PREFIX}_Schaefer_thickness.txt ${OUTDIR}/${PREFIX}_Schaefer_thickness.mean
    mv ${OUTDIR}/${PREFIX}_Schaefer_area.txt ${OUTDIR}/${PREFIX}_Schaefer_area.sum
    mv ${OUTDIR}/${PREFIX}_Schaefer_volume.txt ${OUTDIR}/${PREFIX}_Schaefer_volume.sum
    ## check the existence of output files
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_Schaefer_thickness.mean -a ${OUTDIR}/${PREFIX}_Schaefer_area.sum -a ${OUTDIR}/${PREFIX}_Schaefer_volume.sum
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi
