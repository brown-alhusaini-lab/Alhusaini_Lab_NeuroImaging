#!/bin/bash
#SBATCH --job-name=thomas
#SBATCH --time=06:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4
#SBATCH --output=/oscar/home/azeanala/logs/thomas_%j.out
#SBATCH --error=/oscar/home/azeanala/logs/thomas_%j.err

BASEDIR=/oscar/data/salhusai/DIPARK
BIDS=$BASEDIR/bids_export/alhusaini/study-dipark/bids
SIF=$BASEDIR/thalamo_project/thomasmerged.sif
SESSION=ses-01

while IFS= read -r subjid; do
echo "Processing $subjid"

# SET THE BASES
T1=$BIDS/$subjid/$SESSION/anat/${subjid}_${SESSION}_acq-mprage_T1w.nii.gz
OUTDIR=$BASEDIR/thalamo_project/subjects/$subjid/thomas
mkdir -p $OUTDIR

# COPY T1w to THOMAS FOLDER
cp $T1 $OUTDIR/${subjid}_T1w.nii.gz

# THOMAS demands to be in the directory where the T1w is...
cd $OUTDIR

# RUN THOMAS
apptainer exec \
    -B ${PWD}:${PWD} \
    --pwd ${PWD} \
    $SIF \
    hipsthomas_csh -i ${subjid}_T1w.nii.gz -t1

# RE-ORGANISE / TIDY FILES
cp left/thomasfull.nii.gz ${subjid}_thomas_left.nii.gz
cp right/thomasrfull.nii.gz ${subjid}_thomas_right.nii.gz
rm -rf left right temp tempr

# Move back to the subject list
cd $BASEDIR
    echo "Done: $subjid"

done < $BASEDIR/subjid.txt

