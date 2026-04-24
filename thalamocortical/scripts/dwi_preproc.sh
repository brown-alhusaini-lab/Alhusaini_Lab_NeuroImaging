#!/bin/bash
#SBATCH --job-name=dwi_preproc
#SBATCH --partition=batch          # or 'gpu' if GPU eddy becomes available
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16         # more cores -> faster eddy_cpu
#SBATCH --mem=32G
#SBATCH --time=20:00:00            # generous wall time for CPU eddy
#SBATCH --output=/oscar/home/anguy214/logs/dwi_%A_%a.out
#SBATCH --error=/oscar/home/anguy214/logs/dwi_%A_%a.err
#SBATCH --array=0-0                # replace with (num_subjects - 1); %5 = 5 at a time
 
# ── Fail fast on any error, undefined var, or failed pipe ────────────
set -euo pipefail
 
# ── Load modules on OSCAR ─────────────────────────────────────────────
module load mrtrix3/3.0.6-ylq2
module load fsl/6.0.7.19s-jqc4
module load ants/2.5.1-qwt3
 
# ── Parameters (edit these) ───────────────────────────────────────────
GROUP="controls"
SESSION="ses-01"
BASE_DIR="/oscar/data/salhusai/DIPARK"
 
i="sub-c100"
 
echo "Processing subject: ${i}"
 
# ── Paths ─────────────────────────────────────────────────────────────
dwi_path=${BASE_DIR}/rawdata/${i}/${SESSION}/dwi
output_path=${BASE_DIR}/derivatives/dwiprepro-mrtrix/${i}/${SESSION}
 
mkdir -p ${output_path}/mrtrix
mkdir -p /oscar/home/anguy214/logs
 
# ── Build b=0 pair for distortion correction ─────────────────────────
# Same idea as the original: take the first b=0 from AP and the first b=0
# from PA, concatenate them into a 2-volume series for -rpe_pair.
# Difference from original: build as .mif with -json_import so PE metadata
# (PhaseEncodingDirection, TotalReadoutTime) is carried in the header.
# This is required because your PA file is a full DWI series (not just
# a single b=0), and because MRtrix needs PE info to drive topup.
mrconvert $dwi_path/${i}_${SESSION}_acq-b1000_dir-ap_dwi.nii.gz - \
          -json_import $dwi_path/${i}_${SESSION}_acq-b1000_dir-ap_dwi.json \
          -coord 3 0 -axes 0,1,2 | \
  mrconvert - $output_path/${i}_${SESSION}_b0_ap.mif -force
 
mrconvert $dwi_path/${i}_${SESSION}_acq-b1000_dir-pa_dwi.nii.gz - \
          -json_import $dwi_path/${i}_${SESSION}_acq-b1000_dir-pa_dwi.json \
          -coord 3 0 -axes 0,1,2 | \
  mrconvert - $output_path/${i}_${SESSION}_b0_pa.mif -force
 
mrcat $output_path/${i}_${SESSION}_b0_ap.mif \
      $output_path/${i}_${SESSION}_b0_pa.mif \
      $output_path/${i}_${SESSION}_b0s_all.mif -axis 3 -force
 
# ── Convert AP DWI and denoise (AP-only, matches original) ───────────
mrconvert $dwi_path/${i}_${SESSION}_acq-b1000_dir-ap_dwi.nii.gz \
          $output_path/${i}_${SESSION}_dwi_raw.mif \
          -fslgrad $dwi_path/${i}_${SESSION}_acq-b1000_dir-ap_dwi.bvec \
                   $dwi_path/${i}_${SESSION}_acq-b1000_dir-ap_dwi.bval \
          -json_import $dwi_path/${i}_${SESSION}_acq-b1000_dir-ap_dwi.json -force
 
dwidenoise $output_path/${i}_${SESSION}_dwi_raw.mif \
           $output_path/${i}_${SESSION}_dwi_denoised.mif \
           -noise $output_path/${i}_${SESSION}_noise.mif -force
 
# ── Preprocessing with -rpe_pair (matches original pipeline intent) ──
# -rpe_header tells MRtrix to read PE info from each file's header, which
# we populated via -json_import above. Functionally equivalent to the
# original's -rpe_pair + -pe_dir AP, but actually works with your data.
dwifslpreproc -rpe_header \
  -se_epi $output_path/${i}_${SESSION}_b0s_all.mif \
  -eddy_options "--repol " \
  $output_path/${i}_${SESSION}_dwi_denoised.mif \
  -eddyqc_all $output_path/mrtrix/eddy \
  $output_path/mrtrix/${i}_${SESSION}_dndwi.mif -force
 
# ── Convert to nii, extract b0, brain extraction ─────────────────────
mrconvert $output_path/mrtrix/${i}_${SESSION}_dndwi.mif \
          $output_path/mrtrix/${i}_${SESSION}_data.nii.gz \
          -stride 1,2,3,4 -force
 
fslroi $output_path/mrtrix/${i}_${SESSION}_data.nii.gz \
       $output_path/mrtrix/${i}_${SESSION}_nodif.nii.gz 0 1
 
bet $output_path/mrtrix/${i}_${SESSION}_nodif.nii.gz \
    $output_path/mrtrix/${i}_${SESSION}_brain -m -n -f 0.3
 
mrconvert $output_path/mrtrix/${i}_${SESSION}_brain_mask.nii.gz \
          $output_path/mrtrix/${i}_${SESSION}_mask.mif -force
 
# ── Bias correction ──────────────────────────────────────────────────
dwibiascorrect ants \
  -mask $output_path/mrtrix/${i}_${SESSION}_mask.mif \
  $output_path/mrtrix/${i}_${SESSION}_dndwi.mif \
  $output_path/mrtrix/${i}_${SESSION}_dnbcdwi.mif -force
 
# ── Tensor fitting ───────────────────────────────────────────────────
dwi2tensor $output_path/mrtrix/${i}_${SESSION}_dnbcdwi.mif \
  -mask $output_path/mrtrix/${i}_${SESSION}_mask.mif \
  $output_path/mrtrix/${i}_${SESSION}_dt.mif -force
 
tensor2metric $output_path/mrtrix/${i}_${SESSION}_dt.mif \
  -fa     $output_path/mrtrix/${i}_${SESSION}_fa.mif \
  -adc    $output_path/mrtrix/${i}_${SESSION}_md.mif \
  -vector $output_path/mrtrix/${i}_${SESSION}_ev.mif -force
 
# ── Response function estimation ─────────────────────────────────────
dwi2response dhollander \
  $output_path/mrtrix/${i}_${SESSION}_dnbcdwi.mif \
  $output_path/mrtrix/${i}_${SESSION}_wm_response.txt \
  $output_path/mrtrix/${i}_${SESSION}_gm_response.txt \
  $output_path/mrtrix/${i}_${SESSION}_csf_response.txt \
  -nocleanup -force
 
# ── FOD estimation ───────────────────────────────────────────────────
dwi2fod msmt_csd \
  -mask $output_path/mrtrix/${i}_${SESSION}_mask.mif \
  $output_path/mrtrix/${i}_${SESSION}_dnbcdwi.mif \
  $output_path/mrtrix/${i}_${SESSION}_wm_response.txt  $output_path/mrtrix/${i}_${SESSION}_wm.mif \
  $output_path/mrtrix/${i}_${SESSION}_gm_response.txt  $output_path/mrtrix/${i}_${SESSION}_gm.mif \
  $output_path/mrtrix/${i}_${SESSION}_csf_response.txt $output_path/mrtrix/${i}_${SESSION}_csf.mif -force
 
echo "Done: ${i}"