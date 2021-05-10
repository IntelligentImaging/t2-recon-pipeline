Bash scripts for reconstructing and post-processing fetal T2 data

General workflow:

1. PULL DATA
retrieve-anon.sh [MRN] [DOS] MR [OUTPUT DIRECTORY]

2. CONVERT and set up RECON PROC DIR, RUN 2Ddensenet
prep-fetal2.sh [RAW CASE DIR] [STUDY RECON DIR]

3. Check T2 stacks in [CASE RECON DIR], remove bad to ../notgood

4. Create mask for reference stack, named mask_*.nii.gz

5. Run RECON
Generate SVRTK docker run script: sh svrtk-dock-gen.sh [nii]

5. DEOBLIQUE and CREATE REORIENTED RECONS (to each stack)
reorient-fetal.sh [RECON]

6. Initial N4, net mask
reg-prep2.sh [BEST ORTHOGANAL REORIENTED STACK]

7. Validate and correct recon mask

8. Final BIAS CORRECTION, CROP IMAGE and INTENSITY NORMALIZATION
normalize-fetal.sh -m mask.nii.gz [BEST] 3

9. REGISTER to ATLAS SPACE
reg-flirt.sh

10. SEGMENTATION
FetalAtlasSeg.sh

