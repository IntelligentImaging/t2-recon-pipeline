Bash scripts for reconstructing and post-processing fetal T2 data

General workflow:

1. PULL DATA
retrieve-anon.sh [MRN] [DOS] MR [OUTPUT DIRECTORY]

2. CONVERT and set up RECON PROC DIR, RUN 2Ddensenet
prep-fetal2.sh [RAW CASE DIR] [STUDY RECON DIR]

3. First check DN2D output, then CROP STACKS 
crop-fetal.sh [CASE RECON DIR]

4. Run RECON
runSVRany.sh [PREFIX] [OUTPUT]

5. DEOBLIQUE and CREATE REORIENTED RECONS (to each stack)
reorient-fetal.sh [RECON]

6. Initial N4, 3DUnet MASK, set up REG DIR
reg-prep2.sh [BEST ORTHOGANAL REORIENTED STACK]

7. Final BIAS CORRECTION, CROP IMAGE and INTENSITY NORMALIZATION
normalize-fetal.sh

8. REGISTER to ATLAS SPACE
reg-flirt.sh

9. SEGMENTATION
FetalAtlasSeg_20200526.sh

