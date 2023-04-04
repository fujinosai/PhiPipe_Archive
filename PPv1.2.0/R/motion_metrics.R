## this script was used in bold_motion.sh
## calculate Power's FD, motion parameter expansions (Friston's autoregressive model), motion outliers and summary metrics
Args <- commandArgs(trailingOnly=TRUE)
## the first arguments Args[1]
fname <- paste(Args[1],'_mc.matrix', sep='')
## the 6 motion parameters
mc <- as.matrix(read.table(fname))
## the motion parameters one time point before to account for delayed motion effect
## in some papers (See Ciric et al., 2018), the temporal derivatives of motion parameters were used, which should be equivalent (via linear combination) in nuisance regression
## in some papers (see Power et al., 2014), the motion parameters were detrended. The underlying consideration is unknown to me. 
mcar <- rbind(0,mc[-dim(mc)[1],])
mcsqr <- mc^2
mcarsqr <- mcar^2
## the Friston's 24-parameter model
mc_model <- cbind(mc,mcar,mcsqr,mcarsqr)
fname <- paste(Args[1],'_mc.model', sep='')
write.table(mc_model, fname, quote = FALSE, row.names = FALSE, col.names = FALSE)
## for AFNI's 3dvolreg, the first three parameters are rotations in the orders of roll, pitch, yaw (rotations about Z/X/Y axes). The unit is degree.
## the 4th-6th parameters are translations in the Z/X/Y directions. The unit is mm.
## for FSL's mcflirt, the first three parameters are pitch, yaw, roll in radian, and the 4th-6th parameters are X/Y/Z translations in mm.
## reference: https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind1411&L=FSL&P=R75575&1=fsl&9=A&I=-3&J=on&K=3&d=No+Match%3BMatch%3BMatches&z=4
mcrot <- mc[,1:3]
mctrans <- mc[,4:6]
## the maximum translation and rotation, which were used as summary metrics to exclude subjects in early days but obsolete now.
## maximum translaton/rotation only reflect the largest head motion and depend on the reference volume selection in motion correction.  
## In future versions, the maximum metrics should be removed and include more informative measures to quantify the overall head motion (after careful validation).
maxrot <- max(abs(mcrot))
maxtrans <- max(abs(mctrans))
## convert rotation from degree(radian) to millimeters by assuming the the brain is a sphere of radius 50 mm.
mc[,1:3] <- (mc[,1:3]*pi/180)*50
## Power's FD is the sum of frame-wise changes of absolute translational and rotational displacements. (See Power et al., 2012)
fd <-rowSums(abs(rbind(0,diff(mc))))
meanfd <- mean(fd)
## the motion outlier had a FD > FD_threshold
## the outlier ratio is the ratio between the number of outliers and total number of volumes
fdratio <- sum(fd > Args[2])/length(fd)
mc_metric <- setNames(c(maxrot,maxtrans,meanfd,fdratio), c('MaxRot:','MaxTrans:','MeanFD:','OutlierRatio:'))
fname <- paste(Args[1], '_mc.metric', sep='')
write.table(mc_metric, fname, quote=FALSE, row.names=TRUE, col.names=FALSE)
fname <- paste(Args[1], '_mc.fd', sep='')
write.table(fd, fname, quote=FALSE, row.names=FALSE, col.names=FALSE)
## fdcensor was used in AFNI's 3dTproject, in which a value of 0 means the volume would be excluded while a value of 1 means included
fdcensor <- ifelse(fd > Args[2], 0, 1)
fname <- paste(Args[1], '_mc.censor', sep='')
write.table(fdcensor, fname, quote=FALSE, row.names=FALSE, col.names=FALSE)
