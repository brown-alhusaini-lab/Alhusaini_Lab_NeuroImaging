#!/bin/bash
#SBATCH --job-name=lausanne
#SBATCH --time=04:00:00
#SBATCH --mem=16G
#SBATCH --output=/oscar/home/azeanala/logs/lausanne_%j.out
#SBATCH --error=/oscar/home/azeanala/logs/lausanne_%j.err
## Code needed to generate extra parcellations

# Need the following in the same location as the script

# fsaverage - a folder which stores all the information about the additional parcellations
# subjid.txt - txt file that stores the filepath of freesurfer folders of the subject you want to run

#--
#Set up FREESURFER PATHS (can remove if set up in terminal)
module load freesurfer/8.0.0-7ye6
source $FREESURFER_HOME/SetUpFreeSurfer.sh


#alias ll='ls -lasG'

## Find where this "genstats.sh" code is located for
#BASEDIR=$(dirname "$0")

# Cd into the location where this bit of code is stored
BASEDIR=/oscar/data/salhusai/DIPARK
cd $BASEDIR

echo "set up complete"

export SUBJECTS_DIR=$BASEDIR/procsubj
cp -r $BASEDIR/fsaverage/* $SUBJECTS_DIR/fsaverage/

##ƒor every file path stored in subjid.txt
while IFS= read -r subjid; do
    echo $subjid
    mkdir -p $SUBJECTS_DIR/$subjid/stats/
    cd $SUBJECTS_DIR
    #ln -s $FREESURFER_HOME/subjects/fsaverage fsaverage
    
    # Create an array that contains the names of the new parcellations we would like to use.
    declare -a arr=("myaparc_36" "myaparc_60" "myaparc_125")    
    # For each new parcellation scheme
    for i in "${arr[@]}";do
	
        ATLAS=$i
        echo $ATLAS

# resamples right hemi-sphere CorticalSurface
        mri_surf2surf \
  --srcsubject fsaverage \
  --trgsubject $subjid \
  --hemi rh \
  --sval-annot $ATLAS \
  --tval $SUBJECTS_DIR/$subjid/label/rh.$ATLAS.annot

        cp $SUBJECTS_DIR/$subjid/surf/rh.pial.T1 $SUBJECTS_DIR/$subjid/surf/rh.pial
#mris_anatomical_stats -a $datadir/$subjid/label/rh.$ATLAS.annot -f $datadir/$subjid/stats/rh.$ATLAS.stats $subjid rh &

	# resamples left hemi-sphere CorticalSurface
        mri_surf2surf \
  --srcsubject fsaverage \
  --trgsubject $subjid \
  --hemi lh \
  --sval-annot $ATLAS \
  --tval $SUBJECTS_DIR/$subjid/label/lh.$ATLAS.annot

        cp $SUBJECTS_DIR/$subjid/surf/lh.pial.T1 $SUBJECTS_DIR/$subjid/surf/lh.pial
#mris_anatomical_stats -a $datadir/$subjid/label/lh.$ATLAS.annot -f $datadir/$subjid/stats/lh.$ATLAS.stats $subjid lh &
        
        
        #Maps the cortical labels from the automatic cortical parcellation (aparc) to the automatic segmentation volume (aseg).
        

	mri_aparc2aseg --s $subjid --annot $ATLAS --o $SUBJECTS_DIR/$subjid/mri/$ATLAS.mgz
    done  # end atlas loop

done < $BASEDIR/subjid.txt  # end subject loop
