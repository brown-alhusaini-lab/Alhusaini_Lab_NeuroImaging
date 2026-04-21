# Oscar Pre-Processing Pipeline

> **Note:** Login nodes are for job submission and directory management only. All heavy processing must be submitted via `sbatch`.

---

## MULTIPLE SUBJECTS

### XNAT2BIDS

```bash
ssh -X $USER@ssh.ccv.brown.edu
```
_(run this if you are in your computer's native terminal not OOD)_

```bash
vim /oscar/data/salhusai/DIPARK/x2b_myconfig.toml
```
_(change subjects)_

```bash
module load anaconda3
```

```bash
python /oscar/data/bnc/shared/scripts/oscar-scripts/run_xnat2bids.py --config /oscar/data/salhusai/DIPARK/x2b_myconfig.toml
```

_(wait for all subjects to be processed, you should see them being populated into the folder eventually.)_

```bash
ls /oscar/scratch/$USER/sourcedata/alhusaini/study-dipark/bids/
```
_(confirm subject folders appeared before continuing)_

---

### T1 Staging
> Goal: gather one T1 scan per subject into a single folder so FreeSurfer can process them in parallel.
```bash
mkdir -p /oscar/scratch/$USER/staging
```
_(creates your personal staging directory if it doesn't exist yet)_

```bash
BIDS=/oscar/scratch/$USER/sourcedata/alhusaini/study-dipark/bids
INP=/oscar/scratch/$USER/staging
```
_(sets shorthand variables for the BIDS data location and your staging folder)_

```bash
rm -f "$INP"/*.nii.gz
```
_(clears any leftover .nii.gz files from a previous run to start fresh)_

```bash
SUBJECTS="sub-c121 sub-c122 sub-c130"
```
_(list every subject you want to process, space separated)_

```bash
ls $BIDS | head
```
_(confirms your BIDS directory contains subject folders — if empty, xnat2bids didn't work or path is wrong)_

```bash
for sub in $SUBJECTS; do
  t1=$(ls "$BIDS/$sub"/ses-*/anat/*T1w*.nii.gz 2>/dev/null | head -n 1)
  if [ -z "$t1" ]; then
    echo "No T1 found for $sub (skipping)"
    continue
  fi
  ln -sf "$t1" "$INP/${sub}_T1w.nii.gz"
  echo "Linked $sub"
done
```
_(for each subject: find their T1 scan inside the BIDS folder, then create a shortcut (symlink) in your staging folder — this avoids copying large files)_

**Double check — confirm your T1 files are linked correctly before submitting:**
```bash
ls -l $INP
```
_(you should see one .nii.gz file per subject, pointing to a path in BIDS. If empty or missing subjects, the staging loop failed — do NOT continue to FreeSurfer)_

```bash
ls $INP | wc -l
```
_(should match the number of subjects you listed — if not, something is missing)_

---

### FreeSurfer

> **⚠️ First time only — run once to create your personal SLURM script:**

```bash
vim submit_recon_array.sh
```
_(copy and paste the script below, delete everything else, change your email on line 1)_

```bash
#!/bin/bash
#SBATCH --mail-user="your_email@brown.edu"
#SBATCH --mail-type=END,FAIL
#SBATCH --job-name=recon
#SBATCH --output=/oscar/home/$USER/logs/recon_%A_%a.out
#SBATCH --error=/oscar/home/$USER/logs/recon_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --array=0-19
# ^^^^^ Don't forget to change EVERY TIME

# Load FreeSurfer 8.0.0
module load freesurfer/8.0.0-7ye6
module load mesa
module unload anaconda3

# Set environment variables
export SUBJECTS_DIR="/oscar/data/salhusai/DIPARK/procsubj"
INPUT_DIR="/oscar/scratch/$USER/staging"

# Pick the Nth T1 file in INPUT_DIR (array task IDs should be 0..N-1)
T1=$(ls -1 "$INPUT_DIR"/*.nii.gz | sed -n "$((SLURM_ARRAY_TASK_ID+1))p")
[ -n "$T1" ] || { echo "ERROR: No T1 found for task $SLURM_ARRAY_TASK_ID in $INPUT_DIR"; exit 1; }
SUBJ_ID=$(basename "$T1" | sed 's/_T1w\.nii\.gz$//')
recon-all -s "$SUBJ_ID" -i "$T1" -all -openmp 4
```

> **Every time — do the following:**

```bash
vim submit_recon_array.sh
```
_(Change `#SBATCH --array=0-N` where N = number of subjects - 1. Example: 18 subjects → --array=0-17)_

_(Change memory amount if needed)_

```bash
cd /oscar/home/$USER
```

```bash
sbatch submit_recon_array.sh
```
_(make sure your staging folder is correct before submitting — each subject will run a ~20 hour job. After submitting, wait ~5 minutes then check the queue (monitor) to confirm jobs are running and haven't crashed immediately)_

**Monitor:**
```bash
squeue -u $USER
```
_(run this ~5 minutes after submitting — you should see one job per subject. If the queue is empty, check your logs immediately (check next cell))_

```bash
ls -lt /oscar/home/$USER/logs | head
```
_(open the most recent log and look for: "ERROR", "No T1 found", or jobs exiting early. If logs are empty or missing, the job may not have started)_

---

## SINGLE SUBJECT _(legacy — for debugging or single subject rerun)_

```bash
ssh -X $USER@ssh.ccv.brown.edu
```

```bash
vim /oscar/data/salhusai/DIPARK/x2b_myconfig.toml
```
_(change to subject ID, e.g. c130)_

```bash
module load anaconda3
```

```bash
python /oscar/data/bnc/shared/scripts/oscar-scripts/run_xnat2bids.py --config /oscar/data/salhusai/DIPARK/x2b_myconfig.toml
```

```bash
cd /oscar/scratch/$USER/sourcedata/alhusaini/study-dipark/bids
```
_(wait for subject folder to appear, then `ls`, navigate to `sub-XXX/ses-01/anat`)_

Copy `T1w.nii.gz`, then:

```bash
vim freesurfer.script.sh
```
_(change recon subject and path)_

```bash
sbatch freesurfer.script.sh
```
