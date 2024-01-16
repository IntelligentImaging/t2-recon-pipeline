# T2 Fetal Recon Pipeline
The T2 recon pipeline is a set of instructions and scripts for going from raw T2 fetal data stacks to a super resolution 3D reconstruction (Gholipour et al. 2017). It's generally more efficient to run these steps for groups of images one section at a time. For example, first do Recon Setup for all scans, then run SVRTK for all scans, then do registration pre-processing for all scans, etc.
## Prequisites
- Be on a CRL server machine
- Processing machines Clemente has used include (all CentOS7): zephyr, boreas, auster, eurus, dingo, anchorage (Clemente's workstation). Ubuntu machines such as barnes, french, saadi, iced may work but I'm not sure. Try using bash script.sh instead of sh script.sh.
- Source CRkit in your bash profile
  
    Something like: `source /opt/el7/pkgs/crkit/nightly/20220213/bin/crkit-env.sh`
    
- Have the fetal processing pipeline binary directory in your PATH: `/fileserver/fetal/software/bin`

The servers above should be ready to go. If getting set up on a new machine, you will need:
- Docker: https://docs.docker.com/engine/install/
- The SVRTK Docker image: https://github.com/SVRTK/svrtk-docker-gpu
- Davood's recon brain extraction docker: https://hub.docker.com/r/davoodk/brain_extraction

Helpful tools:
- ITK-SNAP (for viewing images and drawing/editing ROI's)
- detox (convenient tool to fix directory names with special characters)
## Data prep and setup
1. Pull data to CRL server. This step will most likely already be completed by Clemente. Only applies to scans performed at BCH.
 
    `sh retrieve-fetal.sh [MRN] [DOS] MR [OUTPUT DIRECTORY]`
1. Convert data from DICOM to NIFTI and set up recon directory:

    `sh prep-fetal.sh [RAW CASE DIR] [STUDY RECON DIR]`<br>
    This script will create a case processing folder in *STUDY RECON DIR* and place all T2 stacks in a subfolder *STUDY/CASEID/svrtk*. Henceforth this is referred to as the *recon directory*.
1. Check T2 stacks in the recon directory, archive bad stacks in *STUDY/CASEID/notgood*
    - Stacks that do not have the entire brain should be archived
    - Stacks in which the fetus changes orientation (from coronal to sagittal, for example) should be archived
    - Oblique stacks should be archived if there are better stacks
    - Only ~4-9 stacks are needed; if there are more they can be removed/ignored.  
1. Create a rough ROI for reconstruction, named *mask_x.nii.gz*, where "x" is the corresponding stack number. I do this in ITK-SNAP.<br>
![Example of the recon ROI. It doesn't need to be exact.](images/example_mask.png)
1. Generate SVRTK docker run script: `sh svrtk-gen.sh [recon directory]`
This script writes the SVRTK container command (*run-svrtk.sh*) to run the reconstruction. Looking at *recon directory*, it records all files named *fetus_\*nii.gz* as the inputs and a file named *mask_\*.nii.gz* to use as the ROI.
## Running the SVRTK reconstruction 
- Method A) Script to run a single recon: `sh svrtk-exec.sh [recon directory]`
  - While on the e2 server, you must use Singularity instead of Docker: `sh svrtk-exec.sh -s [recon directory]`
- Method B) Use this convenient script to search for all run-svrtk.sh files and run any for which the corresponding output cannot be found: `sh svrtk-allexec.sh [STUDY DIRECTORY]`<br>
*study directory* is the folder which holds all of the individual subject recon directories<br>
- Check recon output. If necessary (recon is poor), change the stack selection and/or mask, and re-run SVRTK.

## Normalization and prep for atlas-space registration
- Bias correct and generate a precise brain mask for the reconstructed image`sh reg-prep.sh -n 1 -m [SVRTK_subjID.nii.gz]`<br>This script does the following:
  - Makes a registration/ directory and copied the recon there
  - -n 1 option runs a single iteration of N4 bias correction
  - -m  Runs the Docker for Davood Karimi's Brain Extraction (outputs as registration/mask.nii.gz)
  - Validate and correct *mask.nii.gz* by overlaying on *nxb\*.nii.gz* with ITK-SNAP
## Registration to atlas-space
1. Run the register script: `sh reg-fetal-recon.sh -m mask.nii.gz -n 2 -w [input]`

    This script registers the input image to atlas images of similar gestational age. It estimates gestational age by measuring the total  volume of the brain.
  > -m mask.nii.gz tells the script to crop the input using mask.nii.gz. If you already have a masked image you can omit this argument
  > <br>-n 2 tells the script to perform two more iterations of N4 intensity bias correction. Some data may not need bias correction
  > <br>-t [argument] can be used to specify a registration target:
  > <br>&nbsp;&nbsp;&nbsp;&nbsp;ATLAS -- Fetal spatiotemporal atlas images. Default option.
  > <br>&nbsp;&nbsp;&nbsp;&nbsp;CASES -- Individual subject atlases. These are more varied; useful when ATLAS fails.
  > <br>&nbsp;&nbsp;&nbsp;&nbsp;EARLY -- A pre-selection of useful small brains (GA=17-22 weeks). Can use for the smallest/earliest brains, though the script will also detect when the input is very small and use these instead.
  > <br>&nbsp;&nbsp;&nbsp;&nbsp;[any supplied image.nii.gz] -- Alternatively you can target a specific image
  > <br>-w Matches plus/minus 1 week GA, instead of exact match.
  > <br>--ga [GA] allows you to specify a gestational age instead of having the script estimate it
2. Look through output registrations and choose the best one, then run: `sh choosereg.sh [best reg]`<br>This copies the chosen registration as *atlas_t2final_CASEID.nii.gz* and throws out all other registration attempts[^1].

# Segmentation
- Multi-atlas segmentation script for fetal data: `sh FetalAtlasSeg.sh [Imagelist] [OutputDir] [MaxThreads]`<br>
  - Image list is a path list of post-processed T2 recons (as done above) with GA's, for example:
  > /path/to/atlas_t2final_CASE001.nii.gz 34 <br>/path/to/atlas_t2final_CASE002.nii.gz 22<br>/path/to/atlas_t2final_CASE003.nii.gz 29<br>/path/to/atlas_t2final_CASE004.nii.gz 37
  - Default settings will reference full set of atlas images and individual subject atlases (ISA's) and use the *"GEPZ"* and *"region"* segmentation schemes
  - Runs partial volume correction (PVC) on the *GEPZ segmentation* 
  - -f option runs Haoran's DL CP segmentation

[^1]: Sometimes it's hard to get a good registration. In these cases, we can run a second iteration of the registration. So:<br>`sh reg-fetal -w bmnxbSVRTK_subjID_FLIRTto_fxs1.nii.gz`<br>Then, we take the twice-registered image and combine the part 1 and part 2 transforms:<br>`sh combineTransforms-t2pipeline.sh bmnxbSVRTK_subjID_FLIRTto_fxs1_FLIRTto_fys1.nii.gz`<br>This generates bmnxbSVRTK_subjID_FLIRTto_STA.nii.gz and bmnxbSVRTK_subjID_FLIRTto_STA.tfm.<br>You can then safely use `sh choosereg bmnxbSVRTK_subjID_FLIRTto_STA.nii.gz

# Flywheel Data Management 
flywheel-*.sh scripts are used to manage data downloads from FlyWheel.
- `flywheel-sync.sh` is the sync command for the e2 copy of the flywheel projects. This command seems broken and flywheel IT hasn't been able to help me. I recommend using `flywheel-dl.sh` instead
- `flywheel-dl.sh` downloads a specified dataset to a tar file. Unpack with `tar -xvf download.tar`.
- `flywheel-add.sh` is a convenience script. After unpacking a downloaded scan (which will be in a folder named `scitran`), run `sh flywheel-add.sh scitran/study/subject/scan` to copy the files over to the master directory on e2. Automates two scripts:
- - `flywheel-unzip.sh`, which unpacks the .zip files in which flywheel transmits the files 
- - `flywheel-raw.sh`, which matches the e2 flywheel directory with the e2 dicom directory
