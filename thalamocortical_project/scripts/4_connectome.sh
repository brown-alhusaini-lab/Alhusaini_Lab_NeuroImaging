#!/bin/bash
#SBATCH --job-name=connectome
#SBATCH --time=04:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4
#SBATCH --output=/oscar/home/azeanala/logs/connectome_%j.out
#SBATCH --error=/oscar/home/azeanala/logs/connectome_%j.err

BASEDIR=/oscar/data/salhusai/DIPARK
SESSION=ses-01

module load mrtrix3/3.0.6-ylq2
module load fsl/6.0.7.19s-jqc4
module load anaconda3

while IFS= read -r subjid; do

    echo "Processing $subjid"

    diffusion_base=$BASEDIR/derivatives/dwiprepro-mrtrix/$subjid/$SESSION/mrtrix
    thomas_atlas=$BASEDIR/thalamo_project/subjects/$subjid/thomas

    # Sample FA along streamlines (once per subject, not per scale)
    tcksample \
        ${diffusion_base}/${subjid}_${SESSION}_5M.tck \
        ${diffusion_base}/${subjid}_${SESSION}_fa.mif \
        ${thomas_atlas}/${subjid}_${SESSION}_fa.csv \
        -stat_tck mean \
        -precise
    
    python3 /oscar/data/salhusai/DIPARK/thalamo_project/scripts/fix_fa_nan.py \
        ${thomas_atlas}/${subjid}_${SESSION}_fa.csv

    for scale in 1 2 3; do

        echo "Scale $scale"

        # Register parcellation to diffusion space
        flirt \
            -in ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz \
            -ref ${diffusion_base}/${subjid}_${SESSION}_nodif.nii.gz \
            -applyxfm -init ${diffusion_base}/${subjid}_${SESSION}_t12diff.mat \
            -out ${thomas_atlas}/${subjid}_scale-${scale}_diff_space_labels_thomas.nii.gz \
            -interp nearestneighbour

	# Build SIFT2 weighted connectome
        tck2connectome -symmetric \
            -tck_weights_in ${diffusion_base}/${subjid}_${SESSION}_5M_sift.txt \
            ${diffusion_base}/${subjid}_${SESSION}_5M.tck \
            ${thomas_atlas}/${subjid}_scale-${scale}_diff_space_labels_thomas.nii.gz \
            ${thomas_atlas}/${subjid}_scale-${scale}_connectome_sift2.csv -force

        # Build SIFT2 connectome corrected for node size
        tck2connectome -symmetric -scale_invnodevol \
            -tck_weights_in ${diffusion_base}/${subjid}_${SESSION}_5M_sift.txt \
            ${diffusion_base}/${subjid}_${SESSION}_5M.tck \
            ${thomas_atlas}/${subjid}_scale-${scale}_diff_space_labels_thomas.nii.gz \
            ${thomas_atlas}/${subjid}_scale-${scale}_connectome_sift2_scaled.csv -force

        # Build FA weighted connectome
        tck2connectome -symmetric \
            ${diffusion_base}/${subjid}_${SESSION}_5M.tck \
            ${thomas_atlas}/${subjid}_scale-${scale}_diff_space_labels_thomas.nii.gz \
            ${thomas_atlas}/${subjid}_scale-${scale}_connectome_fa.csv \
	    -scale_file ${thomas_atlas}/${subjid}_${SESSION}_fa.csv \
            -stat_edge mean -force

	echo "Done scale $scale for $subjid"

    done # end scale loop

    echo "Done: $subjid"

done < $BASEDIR/subjid.txt # end subject loop
