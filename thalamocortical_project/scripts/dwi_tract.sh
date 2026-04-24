#!/bin/bash
#SBATCH --job-name=dwi_tract
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=/oscar/home/anguy214/logs/tract_%A_%a.out
#SBATCH --error=/oscar/home/anguy214/logs/tract_%A_%a.err
#SBATCH --array=0-0                # expand when scaling to multiple subjects
 
# ── Fail fast ────────────────────────────────────────────────────────
set -euo pipefail
 
# ── Load modules ─────────────────────────────────────────────────────
module load mrtrix3/3.0.6-ylq2
module load fsl/6.0.7.19s-jqc4
module load ants/2.5.1-qwt3
module load freesurfer/8.0.0-7ye6
 
# ── Parameters (edit these) ──────────────────────────────────────────
GROUP="controls"
SESSION="ses-01"
BASE_DIR="/oscar/data/salhusai/DIPARK"
FS_BASE="${BASE_DIR}/ENIGMA/Nipoppy/derivatives/freesurfer/7.3.2/output/${SESSION}"
 
# FreeSurfer needs SUBJECTS_DIR set even for non-recon commands
export SUBJECTS_DIR=${FS_BASE}
 
i="sub-c100"
 
echo "Processing subject: ${i}"
 
# ── Paths ────────────────────────────────────────────────────────────
atlas_base=${FS_BASE}/${i}/mri
diffusion_base=${BASE_DIR}/derivatives/dwiprepro-mrtrix/${i}/${SESSION}/mrtrix
t1_path=${BASE_DIR}/rawdata/${i}/${SESSION}/anat/${i}_${SESSION}_acq-mprage_T1w.nii.gz
 
mkdir -p /oscar/home/anguy214/logs
 
# ── Sanity check: required inputs exist ──────────────────────────────
for f in "${atlas_base}/brain.mgz" \
         "${atlas_base}/orig/001.mgz" \
         "${diffusion_base}/${i}_${SESSION}_nodif.nii.gz" \
         "${diffusion_base}/${i}_${SESSION}_wm.mif" \
         "${t1_path}"; do
  if [ ! -e "$f" ]; then
    echo "ERROR: required input missing: $f"
    exit 1
  fi
done
 
# ── FreeSurfer brain.mgz -> native T1 space NIfTI ────────────────────
# FreeSurfer's brain.mgz lives in 'conformed' space (256^3, 1mm, LIA).
# Resample it back to the original T1 grid, then convert to NIfTI so
# non-FreeSurfer tools can use it.
mri_vol2vol --mov  ${atlas_base}/brain.mgz \
            --targ ${atlas_base}/orig/001.mgz \
            --regheader \
            --o    ${atlas_base}/brain_native.mgz \
            --nearest
 
mrconvert ${atlas_base}/brain_native.mgz \
          ${atlas_base}/brain_native.nii.gz -force
rm ${atlas_base}/brain_native.mgz
 
# ── Rigid registration: T1 brain -> diffusion (b=0) space ────────────
# FSL flirt substitutes for reg_aladin -rigOnly (NiftyReg not available
# on OSCAR). 6-DOF rigid, normalized mutual information cost, which is
# the standard choice for inter-modality T1/DWI alignment.
flirt -in  ${atlas_base}/brain_native.nii.gz \
      -ref ${diffusion_base}/${i}_${SESSION}_nodif.nii.gz \
      -out ${diffusion_base}/${i}_${SESSION}_diff_space_brain.nii.gz \
      -omat ${diffusion_base}/${i}_${SESSION}_t12diff.mat \
      -dof 6 \
      -cost normmi
 
# ── 5-tissue-type segmentation (from T1, in native T1 space) ─────────
5ttgen fsl ${t1_path} \
           ${diffusion_base}/${i}_${SESSION}_5tt_native.nii.gz -force
 
# ── Warp 5TT into diffusion space using the rigid transform ──────────
# Nearest-neighbour interpolation preserves the discrete tissue labels
# in each of the 5 volumes (CGM, SGM, WM, CSF, pathological).
flirt -in  ${diffusion_base}/${i}_${SESSION}_5tt_native.nii.gz \
      -ref ${diffusion_base}/${i}_${SESSION}_nodif.nii.gz \
      -applyxfm -init ${diffusion_base}/${i}_${SESSION}_t12diff.mat \
      -out ${diffusion_base}/${i}_${SESSION}_5tt.nii.gz \
      -interp nearestneighbour
 
# ── Tractography: 5M streamlines with ACT + dynamic seeding ──────────
tckgen ${diffusion_base}/${i}_${SESSION}_wm.mif \
       -act ${diffusion_base}/${i}_${SESSION}_5tt.nii.gz \
       -select 5000000 \
       -seed_dynamic ${diffusion_base}/${i}_${SESSION}_wm.mif \
       ${diffusion_base}/${i}_${SESSION}_5M.tck -force
 
# ── SIFT2: streamline weighting for biologically meaningful counts ──
tcksift2 ${diffusion_base}/${i}_${SESSION}_5M.tck \
         ${diffusion_base}/${i}_${SESSION}_wm.mif \
         ${diffusion_base}/${i}_${SESSION}_5M_sift.txt -force
 
echo "Done: ${i}"
