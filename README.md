# T2 Fetal Recon Pipeline
The T2 recon pipeline is a set of instructions and scripts for going from raw T2 fetal data stacks to a super resolution 3D reconstruction (Gholipour et al. 2017). It's generally more efficient to run these steps for groups of images one section at a time. For example, first do Recon Setup for all scans, then run SVRTK for all scans, then do registration pre-processing for all scans, etc.
# Prequisites
- Be on a CRL server machine
- Currently may need to specifically be on latte (Clemente's machine) or another machine with GPU's installed
- Have Ali's binary directory in your PATH: `/home/ch135192/bin`
- Docker: https://docs.docker.com/engine/install/
- SVRTK Docker: https://github.com/SVRTK/svrtk-docker-gpu
- Davood's recon brain extraction docker: https://hub.docker.com/r/davoodk/brain_extraction
# Recon setup
1. Pull data to CRL server. This step will most likely already be completed by Clemente. Only applies to scans performed at BCH. 
<br>`sh retrieve-fetal.sh [MRN] [DOS] MR [OUTPUT DIRECTORY]`
2. Convert data from DICOM to NIFTI and set up recon directory: `sh prep-fetal.sh [RAW CASE DIR] [STUDY RECON DIR]`
This script will create a case processing folder in *STUDY RECON DIR* and place all T2 stacks in a subfolder *STUDY/CASEID/nii*. I will refer to this folder henceforth as the *recon directory*.
3. Check T2 stacks in the recon directory, archive bad stacks in *STUDY/CASEID/notgood*
- Stacks that do not have the entire brain should be archived
- Stacks in which the fetus changes orientation (from coronal to sagittal, for example) should be archived
- Oblique stacks should be archived if there are better stacks
- Only ~4-9 stacks are needed; if there are more they can be removed/ignored. 
5. Create rough mask or ROI for recon initialization, named *mask_x.nii.gz*, where "x" is the corresponding stack number. I normally do this in ITK-SNAP.
6. Generate SVRTK docker run script: `sh svrtk-gen.sh [recon directory]`
This script writes the SVRTK container command (*run-svrtk.sh*) to run the reconstruction. Looking at *recon directory*, it records all files named *fetus_\*nii.gz* as the inputs and a file named *mask_\*.nii.gz* to use as the ROI.
# Running the SVRTK Docker container
6. Method A) Script to run a single recon: `sh svrtk-exec.sh [recon directory]`
<br>OR Method B) Use this convenient script to search for all run-svrtk.sh files and run any for which the corresponding output cannot be found: `sh svrtk-allexec.sh [STUDY DIRECTORY]`<br>
*study directory* is the folder which holds all of the individual subject recon directories<br>
7. Check recon and change stack selection and/or mask, and re-run SVRTK if necessary.

# Pre-process recon for registration
8. Reorient recon: `sh reorient-fetal.sh [recon.nii.gz]`
<br>Supply the output SVRTK recon. This script reorients the recon based on each input T2 stack.
9. Choose a good orientation. Look through the *r3DreconO_fetus_\*.nii.gz* files and choose one which is orthogonal
10. Run N4 bias correction and set up the registration: `sh reg-prep.sh [r3Drecon0fetus_x.nii.gz] [n4 iterations]`<br>
- This creates a sub-directory named *registration*, copies the chosen recon, and runs N4 bias correction *x* times.
- This correction will help the automated brain extraction. 1 iteration may be sufficient. It will take several minutes to process.
- Output will be named registration/nxbr3DreconOfetus_\*.nii.gz
- Note: You can supply "0" if no bias correction is necessary 
11. Run Davood's brain extraction docker: `davood_temp_be.sh registration/nxbr3DreconOfetus_\*.nii.gz`<br>
- Output is registration/mask.nii.gz
- Validate and correct *mask.nii.gz* by overlaying on *nxb\*.nii.gz* with ITKSNAP
# Registration
12. Run N4 bias correction (again) and register to atlas space: `sh reg-fetal-recon.sh -m mask.nii.gz -n 3 -t [TARGET] -w [input] [ga]`<br>
- This script crops the image using *mask.nii.gz*, runs *n* iterations of N4, and performs multiple registration attempts, matching *input* to *target* by *GA*
- *TARGET* has four options:
  - ATLAS -- Fetal spatiotemporal atlas images. Default option.
  - CASES -- Individual subject recons (which are in atlas space). These are more varied; useful when ATLAS fails.
  - EARLY -- A pre-selection of useful small brains (GA=17-22 weeks). Use for the smallest/earliest brains.
  - [any supplied image.nii.gz] -- Alternatively you can supply any image 
 - *-w* Matches plus/minus 1 week GA, instead of exact match.
 - If you specify "est" for the GA, the script will estimate GA by comparing the mask volume to the atlas images
 So, basic usage could be: `sh reg-fetal-recon.sh -m mask.nii.gz -n 3 -w nxbr3DreconOfetus_x.nii.gz est`
   or `sh reg-fetal-recon.sh -w mbnxbr3DreconOfetus_x.nii.gz est`
 13. Look through output registrations and choose the best one, then run: `sh choosereg.sh [best reg]`
<br>Copies best registration as *atlas_t2final_CASEID.nii.gz*, throws out all other registration attempts.

# Segmentation
14. Multi-atlas segmentation script for fetal data: `sh FetalAtlasSeg.sh [Imagelist] [OutputDir] [MaxThreads]`<br>
- Image list is a path list of post-processed T2 recons (as done above) with GA's, for example:
> /path/to/atlas_t2final_CASE001.nii.gz 34 <br>/path/to/atlas_t2final_CASE002.nii.gz 22<br>/path/to/atlas_t2final_CASE003.nii.gz 29<br>/path/to/atlas_t2final_CASE004.nii.gz 37
- Default settings will reference full set of atlas images and individual subject atlases (ISA's) and use the *"GEPZ"* and *"region"* segmentation schemes
- Also runs partial volume correction (PVC) on the *GEPZ segmentation*, Haoran's DL CP segmentation, and image algebra to parcellate cortical plate segmentations 
