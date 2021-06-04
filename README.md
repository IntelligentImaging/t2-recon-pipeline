Bash scripts for reconstructing and post-processing fetal T2 data

General workflow:

1. PULL DATA
retrieve-anon.sh [MRN] [DOS] MR [OUTPUT DIRECTORY]

2. CONVERT and set up RECON PROC DIR
prep-fetal2.sh [RAW CASE DIR] [STUDY RECON DIR]

3. Check T2 stacks in [CASE RECON DIR], remove bad to ../notgood

4. Create mask for reference stack, named mask_*.nii.gz

5. Run RECON
Generate SVRTK docker run script: sh svrtk-dock-gen.sh [nii]

6a. DEOBLIQUE and CREATE REORIENTED RECONS (to each stack)
reorient-fetal.sh [RECON] 

6b. Visually check outputs and note the best (orthogonal) oriented stack

7. Initial N4
reg-prep2.sh [BEST ORTHOGANAL REORIENTED STACK] [# N4 iterations]

8. Automated recon mask - waiting for this to be made available from Davood

9. Validate and correct recon mask

10. REGISTRATION, which includes image crop, final N4 bias correction, intensity normalization, and the registration itself
sh reg-fetal-recon.sh [-h] [-m|--mask mask.nii.gz] [-n|--normalize n] [-t|--target] [-w|--wide] -- [input] [ga]

11. SEGMENTATION
sh FetalAtlasSeg.sh [-h] [-a AtlasList.txt -l AtlasLabelsPrefix] [-p OutputSegPrefix] -- [Imagelist] [OutputDir] [MaxThreads]

