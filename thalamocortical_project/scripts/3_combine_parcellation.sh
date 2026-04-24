#!/bin/bash
#SBATCH --job-name=combine_parc
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --output=/oscar/home/azeanala/logs/combine_parc_%j.out
#SBATCH --error=/oscar/home/azeanala/logs/combine_parc_%j.err

BASEDIR=/oscar/data/salhusai/DIPARK
LABELS=$BASEDIR/thalamo_project/labels

module load freesurfer/8.0.0-7ye6
source $FREESURFER_HOME/SetUpFreeSurfer.sh
module load fsl/6.0.7.19s-jqc4
module load mrtrix3/3.0.6-ylq2

SESSION=ses-01

while IFS= read -r subjid; do

    echo "Processing $subjid"

    thomas_atlas=$BASEDIR/thalamo_project/subjects/$subjid/thomas
    parc_base=$BASEDIR/procsubj/$subjid/mri
    
    for scale in 1 2 3; do

        echo "Scale $scale"

        if [ $scale -eq 1 ]; then myaparc=36; fi
        if [ $scale -eq 2 ]; then myaparc=60; fi
        if [ $scale -eq 3 ]; then myaparc=125; fi

	# Convert aseg to nii.gz for intracranial volume correction
        mri_vol2vol --mov ${parc_base}/aseg.mgz --targ ${parc_base}/orig/001.mgz --regheader --o ${thomas_atlas}/aseg.mgz --nearest
        mrconvert ${thomas_atlas}/aseg.mgz ${thomas_atlas}/aseg.nii.gz -force
        rm ${thomas_atlas}/aseg.mgz

        # Convert Lausanne parcellation to nii.gz
        mri_vol2vol --mov ${parc_base}/myaparc_${myaparc}.mgz --targ ${parc_base}/orig/001.mgz --regheader --o ${thomas_atlas}/myaparc_${myaparc}.mgz --nearest
        mrconvert ${thomas_atlas}/myaparc_${myaparc}.mgz ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz -force
        rm ${thomas_atlas}/myaparc_${myaparc}.mgz
	
	# Extract thalamus mask from Lausanne (scale 1 only)
        if [ $scale -eq 1 ]; then
            rt_thal=49; lt_thal=10
            fslmaths ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz -thr ${rt_thal} -uthr ${rt_thal} -bin ${thomas_atlas}/${subjid}_thalamus_right.nii.gz
            fslmaths ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz -thr ${lt_thal} -uthr ${lt_thal} -bin ${thomas_atlas}/${subjid}_thalamus_left.nii.gz
        fi

	# Relabel Lausanne atlas to consistent numbering
        labelconvert ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz \
            $LABELS/Scale${scale}_old_thomas_labels.txt \
            $LABELS/Scale${scale}_new_thomas_labels.txt \
            ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz -force

	# Punch out thalamus voxels from Lausanne to make room for THOMAS
        fslmaths ${thomas_atlas}/${subjid}_thomas_left.nii.gz \
            -add ${thomas_atlas}/${subjid}_thomas_right.nii.gz \
            -bin ${thomas_atlas}/thomasB.nii.gz
        fslmaths ${thomas_atlas}/thomasB.nii.gz \
            -mul -1 -add 1 \
            ${thomas_atlas}/thomasI.nii.gz
        fslmaths ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz \
            -mul ${thomas_atlas}/thomasI.nii.gz \
            ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz

	# Scale THOMAS label numbers to prevent clashes with Lausanne
        fslmaths ${thomas_atlas}/${subjid}_thomas_right.nii.gz \
            -mul 1000 ${thomas_atlas}/thomas_rightX1000.nii.gz
        fslmaths ${thomas_atlas}/${subjid}_thomas_left.nii.gz \
            -mul 1001 ${thomas_atlas}/thomas_leftX1001.nii.gz
        fslmaths ${thomas_atlas}/thomas_rightX1000.nii.gz \
            -add ${thomas_atlas}/thomas_leftX1001.nii.gz \
            ${thomas_atlas}/thomas_XB.nii.gz
        fslmaths ${thomas_atlas}/${subjid}_scale-${scale}_parcellation.nii.gz \
            -add ${thomas_atlas}/thomas_XB.nii.gz \
            ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz

	# Fix label numbering on combined Lausanne + THOMAS parcellation
        labelconvert ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz \
            $LABELS/Scale${scale}_old_thomas_labels_thalamus.txt \
            $LABELS/Scale${scale}_new_thomas_labels_thalamus.txt \
            ${thomas_atlas}/${subjid}_scale-${scale}_parcellation_thomas.nii.gz -force

	echo "Done scale $scale for $subjid"

    done # end scale loop

    echo "Done: $subjid"

    # Clean up intermediate temp files
    rm -f ${thomas_atlas}/thomasB.nii.gz
    rm -f ${thomas_atlas}/thomasI.nii.gz
    rm -f ${thomas_atlas}/thomas_rightX1000.nii.gz
    rm -f ${thomas_atlas}/thomas_leftX1001.nii.gz
    rm -f ${thomas_atlas}/thomas_XB.nii.gz

done < $BASEDIR/subjid.txt # end subject loop
