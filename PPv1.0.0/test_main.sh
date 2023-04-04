#! /bin/bash
## test each step and pipeline
export PhiPipe=/home/huyang/MRIPipe/PP20200331
PID=$1
T1=/home/huyang/MRIPipe/TestData/PP20200331/YOUNG/t1.nii.gz
REST=/home/huyang/MRIPipe/TestData/PP20200331/YOUNG/rest.nii.gz
DWI=/home/huyang/MRIPipe/TestData/PP20200331/YOUNG/dwi.nii.gz
BVAL=/home/huyang/MRIPipe/TestData/PP20200331/YOUNG/bvals
BVEC=/home/huyang/MRIPipe/TestData/PP20200331/YOUNG/bvecs
TR=2
STTYPE=0
PEDIR=2
DOPT=1

start=$(date +%s)

## each step
bash ${PhiPipe}/test_step.sh -a ${T1} -b ${REST} -c ${DWI} -d ${BVAL} -e ${BVEC} -f ${TR} -g ${STTYPE} -h ${PEDIR} -i ${PID}

## t1 processing pipeline (9 Hours)
if [[ $PID -eq 111 ]]
then
    bash ${PhiPipe}/test_pipe.sh -a ${T1} -j ${PID} 
fi

## t1+bold processing pipeline (0.6 Hour) 
if [[ $PID -eq  222 ]]
then
    bash ${PhiPipe}/test_pipe.sh -a ${T1} -b ${REST} -f ${TR} -g ${STTYPE} -j ${PID}
fi

## t1+dwi processing pipeline (44 Hour) 
if [[ $PID -eq 333 ]]
then
    bash ${PhiPipe}/test_pipe.sh -a ${T1} -c ${DWI} -d ${BVAL} -e ${BVEC} -h ${PEDIR} -i ${DOPT} -j ${PID}
fi

## online processing pipeline 
if [[ $PID -eq 444 ]]
then
    bash ${PhiPipe}/test_pipe.sh -a ${T1} -b ${REST} -c ${DWI} -d ${BVAL} -e ${BVEC} -f ${TR} -g ${STTYPE} -h ${PEDIR} -i ${DOPT} -j ${PID}
fi

## PHI cluster
if [[ $PID -eq 555 ]]
then
    bash ${PhiPipe}/test_pipe.sh -a ${T1} -b ${REST} -c ${DWI} -d ${BVAL} -e ${BVEC} -f ${TR} -g ${STTYPE} -h ${PEDIR} -i ${DOPT} -j ${PID}
fi

## SMHC cluster
if [[ $PID -eq 666 ]]
then
    bash ${PhiPipe}/test_pipe.sh -a ${T1} -b ${REST} -c ${DWI} -d ${BVAL} -e ${BVEC} -f ${TR} -g ${STTYPE} -h ${PEDIR} -i ${DOPT} -j ${PID}
fi

end=$(date +%s)
runtime=$((end-start))
printf "Elapsed Time: %s sec\n" $runtime

