# Oscar Pre-Processing Code

> **Note:** Login nodes are for job submission and directory management only. All heavy processing must be submitted via `sbatch`.

---

## MULTIPLE SUBJECTS

### XNAT2BIDS

```bash
ssh -X $USER@ssh.ccv.brown.edu
```

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

```bash
ls /oscar/scratch/$USER/sourcedata/alhusaini/study-dipark/bids/
```
_(wait for all subjects to be processed)_

---

### T1 Staging

```bash
mkdir -p /oscar/scratch/$USER/staging
```

```bash
BIDS=/oscar/scratch/$USER/sourcedata/alhusaini/study-dipark/bids
INP=/oscar/scratch/$USER/staging
```

```bash
rm -f "$INP"/*.nii.gz
```

```bash
SUBJECTS="sub-c121 sub-c122 sub-c130"
```
_(insert subjects above as many as needed)_

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

---

### FreeSurfer

> **First time only:** Create `submit_recon_array.sh` in your home directory. Copy and paste the script below into the file and delete everything else. Don't forget to change your email in the first line.

```bash
vim submit_recon_array.sh
```

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

**Double check:**
```bash
ls -l $INP
```

**Every time — update array size and submit:**

```bash
vim submit_recon_array.sh
```
_(Change `#SBATCH --array=0-N` where N is number of subjects - 1)_
_(Change memory if needed)_

```bash
cd /oscar/home/$USER
```

```bash
sbatch submit_recon_array.sh
```

**Monitor:**
```bash
squeue -u $USER
```

```bash
ls -lt /oscar/home/$USER/logs | head
```

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
