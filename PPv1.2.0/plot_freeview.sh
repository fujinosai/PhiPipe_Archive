#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------
`basename $0` creates snapshots using freeview for quality check
The script will pop-up windows and may not work in server
-----------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/nu.mgz
        -b /home/alex/input/lh.pial:edgecolor=yellow
        -c /home/alex/input/rh.pial:edgecolor=yellow
        -d /home/alex/output
        -e t1_pial
-----------------------------------------------------------------
Required arguments (at least one volume or surface file must be supplied):
        -a:  volume file and related sub-options
        -b:  left hemisphere surface file and related sub-options
        -c:  right hemishere surface file and related sub-options
        -d:  output directory
        -e:  output prefix

Optional arguments:
        -f:  whether freeview is usable (1 means usable)
-----------------------------------------------------------------
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
          a) ## volume file with sub-options
             VARRAY+=("$OPTARG")
             ;;
          b) ## left hemisphere surface file with sub-options
             LSARRAY+=("$OPTARG")
             ;;
          c) ## right hemisphere surface file with sub-options
             RSARRAY+=("$OPTARG")
             ;;          
          d) ## output directory
             OUTDIR=$OPTARG
             ;;
          e) ## output prefix
             PREFIX=$OPTARG
             ;;
          f) ## usable freeview 
             USABLE=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
    done
fi

## check whether freeview could be used?
if [[ $USABLE -ne 1 ]]
then
    freeview -quit
    if [[ $? -ne 0 ]]
    then
        echo "freeview could not be used !!!"
        exit 1
    fi
fi
 
## if PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## deal with multiple volume files
if [[ ! -z ${VARRAY} ]]
then
    VOLFILES="-v"
    for ITEM in "${VARRAY[@]}"
    do
        ## the first colon separates file and sub-options
        FILE=$( echo $ITEM | cut -d ':' -f1 )
        if [[ ! -f $FILE ]]
        then
            echo "File $FILE doesn't exist. Please check !!!"
            exit 1
        fi
        VOLFILES="$VOLFILES $ITEM"
    done
fi

## deal with multiple left-hemi surface files
if [[ ! -z ${LSARRAY} ]]
then
    LSURFFILES="-f"
    for ITEM in "${LSARRAY[@]}"
    do
        ## the first colon separates file and sub-options
        FILE=$( echo $ITEM | cut -d ':' -f1 )
        if [[ ! -f $FILE ]]
        then
            echo "File $FILE doesn't exist. Please check !!!"
            exit 1
        fi
        LSURFFILES="$LSURFFILES $ITEM"
    done
fi

## deal with multiple right-hemi surface files
if [[ ! -z ${RSARRAY} ]]
then
    RSURFFILES="-f"
    for ITEM in "${RSARRAY[@]}"
    do
        ## the first colon separates file and sub-options
        FILE=$( echo $ITEM | cut -d ':' -f1 )
        if [[ ! -f $FILE ]]
        then
            echo "File $FILE doesn't exist. Please check !!!"
            exit 1
        fi
        RSURFFILES="$RSURFFILES $ITEM"
    done
fi

## if INPUT file/OUTPUT folder exist?
bash ${PhiPipe}/check_inout.sh -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## make temporary directory to save intermediate files
mkdir ${OUTDIR}/mytmp$$

## change to temporary directory to save typing
ORIGDIR=$(pwd)
cd ${OUTDIR}/mytmp$$

## if volume file (and/or surface file) supplied
if [[ ! -z ${VOLFILES} ]]
then
    ## get the first volume file to obtain the orientation and resolution 
    FIRSTVOL=$(echo ${VOLFILES} | awk '{print $2}' | cut -d ':' -f1)
    ORIENT=$(mri_info ${FIRSTVOL} --orientation)
    DIM=($(mri_info ${FIRSTVOL} --dim))
    ## create freeview commands
    ## load all files one time and save multiple pictures: https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg63545.html
    ## some options don't work as expected and freeview could not run in the background, which limits its use in server. I tried to find alternative softwares.
    echo "freeview --layout 1 ${VOLFILES} ${LSURFFILES} ${RSURFFILES}" | tee cmd_s.txt cmd_c.txt > cmd_a.txt
    ## there are 48 possible combinations in orientation
    ## to determine which slice corresponds to which spatial direction
    case ${ORIENT} in
      LPI|RPI|LPS|RPS|LAI|RAI|LAS|RAS)    
        ## for unknown reasons, the viewport doesn't work so visualize each view separately
        idx=1
        for frac in 0.35 0.45 0.55 0.65
        do
          ## Sagittal view
          ## get the number of slice to be displayed 
          ## use bc: https://askubuntu.com/questions/217570/bc-set-number-of-digits-after-decimal-point
          nslice=$(echo "${frac}*${DIM[0]}/1" | bc) 
          echo "-viewport sagittal -slice ${nslice} 1 1 -ss mytmp_s${idx}.png" >> cmd_s.txt
          ## Coronal view
          nslice=$(echo "${frac}*${DIM[1]}/1" | bc)
          echo "-viewport coronal -slice 1 ${nslice} 1 -ss mytmp_c${idx}.png" >> cmd_c.txt
          ## Axial view
          nslice=$(echo "${frac}*${DIM[2]}/1" | bc)
          echo "-viewport axial -slice 1 1 ${nslice} -ss mytmp_a${idx}.png" >> cmd_a.txt
          idx=$(( $idx + 1 ))
        done
        ;;
      LIP|RIP|LSP|RSP|LIA|RIA|LSA|RSA)
        idx=1
        for frac in 0.35 0.45 0.55 0.65
        do
          nslice=$(echo "${frac}*${DIM[0]}/1" | bc)
          echo "-viewport sagittal -slice ${nslice} 1 1 -ss mytmp_s${idx}.png" >> cmd_s.txt
          nslice=$(echo "${frac}*${DIM[2]}/1" | bc)
          echo "-viewport coronal -slice 1 1 ${nslice} -ss mytmp_c${idx}.png" >> cmd_c.txt
          nslice=$(echo "${frac}*${DIM[1]}/1" | bc)
          echo "-viewport axial -slice 1 ${nslice} 1 -ss mytmp_a${idx}.png" >> cmd_a.txt
          idx=$(( $idx + 1 ))
        done
        ;;
      PLI|PRI|PLS|PRS|ALI|ARI|ALS|ARS)
        idx=1
        for frac in 0.35 0.45 0.55 0.65
        do
          nslice=$(echo "${frac}*${DIM[1]}/1" | bc)
          echo "-viewport sagittal -slice ${nslice} 1 1 -ss mytmp_s${idx}.png" >> cmd_s.txt
          nslice=$(echo "${frac}*${DIM[0]}/1" | bc)
          echo "-viewport coronal -slice 1 1 ${nslice} -ss mytmp_c${idx}.png" >> cmd_c.txt
          nslice=$(echo "${frac}*${DIM[2]}/1" | bc)
          echo "-viewport axial -slice 1 ${nslice} 1 -ss mytmp_a${idx}.png" >> cmd_a.txt
          idx=$(( $idx + 1 ))
        done
        ;;
      IPL|IPR|SPL|SPR|IAL|IAR|SAL|SAR)
        idx=1
        for frac in 0.35 0.45 0.55 0.65
        do
          nslice=$(echo "${frac}*${DIM[2]}/1" | bc)
          echo "-viewport sagittal -slice ${nslice} 1 1 -ss mytmp_s${idx}.png" >> cmd_s.txt
          nslice=$(echo "${frac}*${DIM[1]}/1" | bc)
          echo "-viewport coronal -slice 1 1 ${nslice} -ss mytmp_c${idx}.png" >> cmd_c.txt
          nslice=$(echo "${frac}*${DIM[0]}/1" | bc)
          echo "-viewport axial -slice 1 ${nslice} 1 -ss mytmp_a${idx}.png" >> cmd_a.txt
          idx=$(( $idx + 1 ))
        done
        ;;
      PIL|PIR|AIL|AIR|PSL|PSR|ASL|ASR)
        idx=1
        for frac in 0.35 0.45 0.55 0.65
        do
          nslice=$(echo "${frac}*${DIM[2]}/1" | bc)
          echo "-viewport sagittal -slice ${nslice} 1 1 -ss mytmp_s${idx}.png" >> cmd_s.txt
          nslice=$(echo "${frac}*${DIM[0]}/1" | bc)
          echo "-viewport coronal -slice 1 1 ${nslice} -ss mytmp_c${idx}.png" >> cmd_c.txt
          nslice=$(echo "${frac}*${DIM[1]}/1" | bc)
          echo "-viewport axial -slice 1 ${nslice} 1 -ss mytmp_a${idx}.png" >> cmd_a.txt
          idx=$(( $idx + 1 ))
        done
        ;;
      ILP|ILA|SLP|SLA|IRP|IRA|SRP|SRA)
        idx=1
        for frac in 0.35 0.45 0.55 0.65
        do
          nslice=$(echo "${frac}*${DIM[1]}/1" | bc)
          echo "-viewport sagittal -slice ${nslice} 1 1 -ss mytmp_s${idx}.png" >> cmd_s.txt
          nslice=$(echo "${frac}*${DIM[2]}/1" | bc)
          echo "-viewport coronal -slice 1 1 ${nslice} -ss mytmp_c${idx}.png" >> cmd_c.txt
          nslice=$(echo "${frac}*${DIM[0]}/1" | bc)
          echo "-viewport axial -slice 1 ${nslice} 1 -ss mytmp_a${idx}.png" >> cmd_a.txt
          idx=$(( $idx + 1 ))
        done
        ;;
      *)
        echo "Unrecognized orientation !!!"
        exit 1
        ;;
    esac
    echo "-quit" | tee -a cmd_s.txt cmd_c.txt >> cmd_a.txt
    ## make snapshots
    freeview -cmd cmd_s.txt
    freeview -cmd cmd_c.txt
    freeview -cmd cmd_a.txt
    ## crop snapshots
    for idx in {1..4}
    do
       for view in s c a
       do
          ## keep 45% width and 100% height of original size, which may be adjusted dynamically
          convert mytmp_${view}${idx}.png -gravity Center -crop 45x100%+0+0 mytmp_${view}${idx}.png
       done
    done
    ## append all slices
    convert mytmp_s1.png mytmp_s2.png mytmp_s3.png mytmp_s4.png mytmp_c1.png mytmp_c2.png mytmp_c3.png mytmp_c4.png mytmp_a1.png mytmp_a2.png mytmp_a3.png mytmp_a4.png -background black +append ${OUTDIR}/${PREFIX}.png
else
    ## if both hemisphere files supplied, first visualize the left, then the right, and finally both
    if [[ ! -z ${LSURFFILES} ]] && [[ ! -z ${LSURFFILES} ]] 
    then
        ## left hemi
        echo "freeview --layout 1 -viewport 3d ${LSURFFILES}" > cmd_lh.txt
        ## lateral view
        echo "-cam Azimuth 0 -ss mytmp_lh_lateral.png" >> cmd_lh.txt
        ## medial view 
        echo "-cam Azimuth 180 -ss mytmp_lh_medial.png" >> cmd_lh.txt
        ## right hemi
        echo "freeview --layout 1 -viewport 3d ${RSURFFILES}" > cmd_rh.txt
        ## lateral view
        echo "-cam Azimuth 0 -ss mytmp_rh_medial.png" >> cmd_rh.txt
        ## medial view 
        echo "-cam Azimuth 180 -ss mytmp_rh_lateral.png" >> cmd_rh.txt
        ## both hemi
        echo "freeview --layout 1 -viewport 3d ${LSURFFILES} ${RSURFFILES}" > cmd_bh.txt    
        ## superior view
        echo "-cam Azimuth 180 Elevation 90 Roll 90 -ss mytmp_bh_superior.png" >> cmd_bh.txt
        ## inferior view
        echo "-cam Elevation -180 -ss mytmp_bh_inferior.png" >> cmd_bh.txt   
        echo "-quit" | tee -a cmd_lh.txt cmd_rh.txt >> cmd_bh.txt
        ## make snapshots
        freeview -cmd cmd_lh.txt
        freeview -cmd cmd_rh.txt
        freeview -cmd cmd_bh.txt
        ## crop snapshots
        for view in lh_lateral lh_medial rh_lateral rh_medial
        do
          ## keep 45% width and 100% height of original size, which may be adjusted dynamically
          convert mytmp_${view}.png -gravity Center -crop 45x100%+0+0 mytmp_${view}.png
        done
        ## special treatment for superior and inferior view, because the freeview output is not centered
        OFFSETX=$(identify -format '%[fx:w/11]' mytmp_bh_superior.png)
        convert mytmp_bh_superior.png -gravity Center -crop 45x100%+${OFFSETX}+0 mytmp_bh_superior.png
        OFFSETX=$(identify -format '%[fx:w/13]' mytmp_bh_inferior.png)
        convert mytmp_bh_inferior.png -gravity Center -crop 45x100%-${OFFSETX}+0 mytmp_bh_inferior.png
        ## append all views
        convert mytmp_lh_lateral.png mytmp_lh_medial.png mytmp_rh_medial.png mytmp_rh_lateral.png mytmp_bh_superior.png mytmp_bh_inferior.png -background black +append ${OUTDIR}/${PREFIX}.png
    fi
fi

## return to the original directory and remove temporary folder 
cd ${ORIGDIR}
rm -r ${OUTDIR}/mytmp$$

## check the existence of output files
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.png
if [[ $? -eq 1 ]]
then
    exit 1
fi

