#!/bin/bash
#SBATCH --job-name=fs_refine
#SBATCH --time=12:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4
#SBATCH --output=/oscar/home/azeanala/logs/fs_refine_%A_%a.out
#SBATCH --error=/oscar/home/azeanala/logs/fs_refine_%A_%a.err

BASEDIR=/oscar/data/salhusai/DIPARK

module load freesurfer/8.0.0-7ye6
module load mesa
source $FREESURFER_HOME/SetUpFreeSurfer.sh

export SUBJECTS_DIR=$BASEDIR/procsubj

subjid=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ~/subjid.txt)
echo "Processing $subjid"
recon-all -autorecon2-cp -autorecon3 -s $subjid -openmp 4
echo "Done: $subjid"
