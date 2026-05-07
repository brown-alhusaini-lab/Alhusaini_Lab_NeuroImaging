#!/bin/bash
#SBATCH --job-name=connectome
#SBATCH --time=08:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --output=/oscar/home/azeanala/logs/connectome_%A_%a.out
#SBATCH --error=/oscar/home/azeanala/logs/connectome_%A_%a.err

BASEDIR=/oscar/data/salhusai/DIPARK
SESSION=ses-01

module load mrtrix3/3.0.6-ylq2
module load fsl/6.0.7.19s-jqc4
module load anaconda3

subjid=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ~/subjid.txt)

echo "Processing $subjid"

diffusion_base=$BASEDIR/derivatives/dwiprepro-mrtrix/$subjid/$SESSION/mrtrix
thomas_atlas=$BASEDIR/thalamo_project/subjects/$subjid/thomas

# Sample FA along streamlines (once per subject, not per scale)
tcksample \
    ${diffusion_base}/${subjid}_${SESSION}_10M.tck \
    ${diffusion_base}/${subjid}_${SESSION}_fa.mif \
    ${thomas_atlas}/${subjid}_${SESSION}_fa.csv \
    -stat_tck mean \
    -precise \
    -force

python3 /oscar/data/salhusai/DIPARK/thalamo_project/scripts/utils/fix_fa_nan.py \
    ${thomas_atlas}/${subjid}_${SESSION}_fa.csv

transformconvert \
    ${diffusion_base}/${subjid}_${SESSION}_t12diff.mat \
    ${thomas_atlas}/${subjid}_scale-1_parcellation_thomas.nii.gz \
    ${diffusion_base}/${subjid}_${SESSION}_nodif.nii.gz \
    flirt_import \
    ${thomas_atlas}/${subjid}_t12diff_mrtrix.txt -force

# Create warp for streamlines dwi → T1 space
warpinit ${thomas_atlas}/${subjid}_scale-1_parcellation_thomas.nii.gz \
    ${thomas_atlas}/${subjid}_w_i.mif -force

transformcompose \
    ${thomas_atlas}/${subjid}_w_i.mif \
    ${thomas_atlas}/${subjid}_t12diff_mrtrix.txt \
    ${thomas_atlas}/${subjid}_warp_dwi_to_t1.mif \
    -template ${diffusion_base}/${subjid}_${SESSION}_nodif.nii.gz -force

tcktransform \
    ${diffusion_base}/${subjid}_${SESSION}_10M.tck \
    ${thomas_atlas}/${subjid}_warp_dwi_to_t1.mif \
    ${thomas_atlas}/${subjid}_10M_t1space.tck -force

for scale in 1 2 3; do

    echo "Scale $scale"

# Build SIFT2 weighted connectome
    tck2connectome -symmetric \
        -tck_weights_in ${diffusion_base}/${subjid}_${SESSION}_10M_sift.txt \
        ${thomas_atlas}/${subjid}_10M_t1space.tck \
        ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz \
        ${thomas_atlas}/${subjid}_scale-${scale}_connectome_sift2_t1space.csv -force

    # Build SIFT2 connectome corrected for node size
    tck2connectome -symmetric -scale_invnodevol \
        -tck_weights_in ${diffusion_base}/${subjid}_${SESSION}_10M_sift.txt \
        ${thomas_atlas}/${subjid}_10M_t1space.tck \
        ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz \
        ${thomas_atlas}/${subjid}_scale-${scale}_connectome_sift2_scaled_t1space.csv -force

    # Build FA weighted connectome
    tck2connectome -symmetric \
        ${thomas_atlas}/${subjid}_10M_t1space.tck \
        ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz \
        ${thomas_atlas}/${subjid}_scale-${scale}_connectome_fa_t1space.csv \
    -scale_file ${thomas_atlas}/${subjid}_${SESSION}_fa.csv \
        -stat_edge mean -force

echo "Done scale $scale for $subjid"

done # end scale loop

echo "Done: $subjid"
