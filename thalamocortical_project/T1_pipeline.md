# Thalamocortical Structural Connectivity Pipeline

> **Note:** Login nodes are for job submission and directory management only. All heavy processing must be submitted via `sbatch`.

> **Overview:** Two parallel streams — T1 anatomical segmentation and dMRI white matter connectivity — are built independently and merged during connectome construction.
> - T1 stream: FreeSurfer → Lausanne parcellation → THOMAS thalamic segmentation → Combined parcellation
> - dMRI stream: handled by Angelina (outputs in `derivatives/dwiprepro-mrtrix/`)
> - Streams merge at Step 6 (connectome construction)

---

## Step 1: FreeSurfer recon-all

> **Note:** Step 4 (THOMAS) can be run concurrently with Steps 2–3 once XNAT2BIDS is complete — it only requires the raw T1, not FreeSurfer output.

```bash
vim $HOME/subjid.txt
```
_(add subject IDs, one per line, e.g. `sub-c100`)_

See the full FreeSurfer guide: [Oscar Pre-Processing Pipeline](../oscar_preprocessing.md)

---

## Step 2: FreeSurfer QC (Quality Control)
### First, run the automatic QC script to flag the subjects that need to be manually checked on Freeview:

```bash
vim $HOME/subjid.txt
```
_(add subject IDs, one per line, e.g. `sub-c100`)_

```bash
module load freesurfer/8.0.0-7ye6
module load anaconda3
```

```bash
python3 00_freesurfer_qc.py
```
_(runs QC script and flags which subjects have issues, prints table)_

**Output columns:**
| Column | What it checks |
|--------|---------------|
| `euler_lh` / `euler_rh` | Raw Euler number per hemisphere (0 = perfect, more negative = more defects) |
| `euler_lh_ok` / `euler_rh_ok` | Whether Euler number was successfully parsed (False = command failed) |
| `euler_val_ok` | Whether Euler number is above -200 threshold |
| `file_output_ok` | Whether all 6 key FreeSurfer output files exist |
| `missing_files` | List of any missing files |
| `mean_thickness_ok` | Whether cortical thickness is within 2 SD of cohort mean |
| `brainseg_vol_ok` | Whether brain volume is within 2 SD of cohort mean |

_(If there are missing_files, then don't run 0_freesurfer_refine.sh just yet, figure out why the files are missing first. It's likely that the FreeSurfer job just didn't complete)_

_(Any `False` in the table → that subject needs manual freeview inspection. The subjects that were flagged will be moved to /oscar/data/salhusai/DIPARK/thalamo_project/qc/freesurfer_qc/flagged_subjects.txt)_

_(flagged subject details saved in /oscar/data/salhusai/DIPARK/thalamo_project/qc/freesurfer_qc/flagged_subjects_details.csv)_

### If some subjects need to be manually checked:
> **Note:** freeview is a GUI — must be run from a Desktop session on OOD at `ood.ccv.brown.edu`

```bash
cat /oscar/data/salhusai/DIPARK/thalamo_project/qc/freesurfer_qc/flagged_subjects_details.csv
```
_(for reference of what the issues are for each flagged subject)_

```bash
cat /oscar/data/salhusai/DIPARK/thalamo_project/qc/freesurfer_qc/flagged_subjects.txt
```
_(for reference of who are the flagged subject (DON'T EDIT THIS FILE))_

```bash
module load freesurfer/8.0.0-7ye6
```

```bash
export SUBJECTS_DIR=/oscar/data/salhusai/DIPARK/procsubj
```
_(sets the FreeSurfer subjects directory so freeview knows where to look)_

```bash
freeview \
  -v $SUBJECTS_DIR/sub-XXX/mri/brain.mgz \
     $SUBJECTS_DIR/sub-XXX/mri/aseg.mgz:colormap=lut:opacity=0.2 \
  -f $SUBJECTS_DIR/sub-XXX/surf/lh.white:edgecolor=blue \
     $SUBJECTS_DIR/sub-XXX/surf/lh.pial:edgecolor=red \
     $SUBJECTS_DIR/sub-XXX/surf/rh.white:edgecolor=blue \
     $SUBJECTS_DIR/sub-XXX/surf/rh.pial:edgecolor=red
```
_(opens freeview with brain volume, segmentation overlay, and white/pial surfaces for both hemispheres)_

**QC — check all four:**
- Blue (white) surface hugs white matter boundary
- Red (pial) surface hugs grey/CSF boundary
- No holes, islands, or blowouts
- aseg labels roughly match anatomy

_(If QC passes → proceed to Step 3)_

_(If QC fails → place control points in freeview, run refinement below, then repeat Step 2)_

**Control point placement:**
1. In freeview, load `$SUBJECTS_DIR/sub-XXX/mri/brainmask.mgz` as the volume
2. Go to **Tools → Edit Voxels** (control point mode)
3. Navigate to regions where the surface is wrong
4. Click to place control points in clearly white matter voxels
5. Save via **File → Save Control Points** → saves to `$SUBJECTS_DIR/sub-XXX/tmp/control.dat`

_(For full instructions → see the [FreeSurfer control points guide](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/ControlPoints_freeview))_

```bash
sbatch /oscar/data/salhusai/DIPARK/thalamo_project/scripts/0_freesurfer_refine.sh
```
_(reruns FreeSurfer stages 2–3 using manually placed control points — must save control points in freeview first)_


## Step 3: Lausanne Parcellation

> Maps cortical atlases (`myaparc`) from fsaverage template → individual subject space, then converts to volumetric parcellations. Outputs written to `procsubj/` (required by FreeSurfer).

**Atlases produced:**
- `myaparc_36` (Scale 1)
- `myaparc_60` (Scale 2)
- `myaparc_125` (Scale 3)

```bash
vim $HOME/subjid.txt
```
_(add subject IDs, one per line, e.g. `sub-c100`)_

```bash
sbatch /oscar/data/salhusai/DIPARK/thalamo_project/scripts/1_lausanne.sh
```
_(submits the Lausanne parcellation job — expect ~8 minutes per subject)_

**Monitor:**
```bash
squeue -u $USER
```

**When Complete (Verify):**
```bash
ls /oscar/data/salhusai/DIPARK/procsubj/sub-XXX/label/ | grep myaparc
```
**Expect:**
- `lh.myaparc_36.annot`
- `rh.myaparc_36.annot`
- `lh.myaparc_60.annot`
- `rh.myaparc_60.annot`
- `lh.myaparc_125.annot`
- `rh.myaparc_125.annot`

```bash
ls /oscar/data/salhusai/DIPARK/procsubj/sub-XXX/mri/ | grep myaparc
```
**Expect:**
- `myaparc_36.mgz`
- `myaparc_60.mgz`
- `myaparc_125.mgz`

_(If missing → check `/oscar/home/$USER/logs/lausanne_XXXXXX.err`)_

---

## Step 4: THOMAS Thalamic Segmentation

> Segments thalamic nuclei (AV, CM, MDPf, PUL, VA, VLA, VLP, VPL) from the raw T1 using the THOMAS atlas. Runs inside an Apptainer container. Can run concurrently with Steps 2–3.

```bash
vim $HOME/subjid.txt
```
_(add subject IDs, one per line, e.g. `sub-c100`)_

```bash
sbatch /oscar/data/salhusai/DIPARK/thalamo_project/scripts/2_thomas.sh
```
_(submits the THOMAS segmentation job — expect ~1-2 hours per subject)_

**Monitor:**
```bash
squeue -u $USER
```

**When Complete (Verify):**
```bash
ls /oscar/data/salhusai/DIPARK/thalamo_project/subjects/sub-XXX/thomas/
```
**Expect:**
- `sub-XXX_T1w.nii.gz`
- `sub-XXX_thomas_left.nii.gz`
- `sub-XXX_thomas_right.nii.gz`

_(If missing → check `/oscar/home/$USER/logs/thomas_XXXXXX.err`)_

---

## Step 5: Combine Lausanne + THOMAS

> Replaces the single thalamus region in the Lausanne atlas with the detailed THOMAS nuclei, producing a final combined parcellation for each scale. This defines all nodes of the brain network.

```bash
vim $HOME/subjid.txt
```
_(add subject IDs, one per line)_

```bash
sbatch /oscar/data/salhusai/DIPARK/thalamo_project/scripts/3_combine_parcellation.sh
```
_(submits the combine parcellation job — expect ~1 minute per subject)_

**Monitor:**
```bash
squeue -u $USER
```

**When Complete (Verify):**
```bash
ls /oscar/data/salhusai/DIPARK/thalamo_project/subjects/sub-XXX/thomas/ | grep parcellation_thomas
```
**Expect:**
- `sub-XXX_scale-1_parcellation_thomas.nii.gz`
- `sub-XXX_scale-2_parcellation_thomas.nii.gz`
- `sub-XXX_scale-3_parcellation_thomas.nii.gz`

_(If missing → check `/oscar/home/$USER/logs/combine_parc_XXXXXX.err`)_

---

## Step 6: Connectome Construction (T1 nodes + dMRI edges) + QC

> Registers the combined parcellation to diffusion space, then builds weighted adjacency matrices using SIFT2 streamline counts. Three connectomes are produced per scale: raw SIFT2, volume-normalized SIFT2, and FA-weighted.
>
> **Requires:** Steps 2–5 complete AND dMRI outputs (_10M.tck and _10M_sift.txt) present in `derivatives/dwiprepro-mrtrix/`

```bash
vim $HOME/subjid.txt
```
_(add subject IDs, one per line)_

```bash
sbatch /oscar/data/salhusai/DIPARK/thalamo_project/scripts/4_connectome.sh
```
_(submits connectome construction job — expect ~6 mins per subject)_

**Monitor:**
```bash
squeue -u $USER
```

**When Complete (Verify):**
```bash
ls /oscar/data/salhusai/DIPARK/thalamo_project/subjects/sub-XXX/thomas/ | grep connectome
```
**Expect:**
- `sub-XXX_scale-1_connectome_sift2_t1space.csv`
- `sub-XXX_scale-1_connectome_sift2_scaled_t1space.csv`
- `sub-XXX_scale-1_connectome_fa_t1space.csv`
- `sub-XXX_scale-2_connectome_sift2_t1space.csv`
- `sub-XXX_scale-2_connectome_sift2_scaled_t1space.csv`
- `sub-XXX_scale-2_connectome_fa_t1space.csv`
- `sub-XXX_scale-3_connectome_sift2_t1space.csv`
- `sub-XXX_scale-3_connectome_sift2_scaled_t1space.csv`
- `sub-XXX_scale-3_connectome_fa_t1space.csv`
- `sub-XXX_10M_t1space.tck`

_(If missing → check `/oscar/home/$USER/logs/connectome_XXXXXX.err`)_

**QC — Connectome Sanity Check:**
```bash
module load anaconda3
```
```bash
python3 /oscar/data/salhusai/DIPARK/thalamo_project/scripts/5_qc_connectome.py sub-XXX
```
_(checks shape, symmetry, NaN/negative values, and thalamic connectivity across all 9 connectomes)_

**Expect:**
- All checks `PASS`
- `Overall: PASS`

_(If any check fails → inspect that scale/type and cross-reference the `.err` log)_

**If Check Fails**

_(If `Thalamic nodes connected: FAIL` or suspicious registration → visually inspect in FSLeyes:)_

```bash
module load fsl/6.0.7.19s-jqc4
```

```bash
fsleyes \
  /oscar/data/salhusai/DIPARK/thalamo_project/subjects/sub-XXX/thomas/sub-XXX_T1w.nii.gz \
  /oscar/data/salhusai/DIPARK/thalamo_project/subjects/sub-XXX/thomas/sub-XXX_scale-1_parcellation_thomas.nii.gz \
  /oscar/data/salhusai/DIPARK/thalamo_project/subjects/sub-XXX/thomas/sub-XXX_10M_t1space.tck
```
_(replace sub-XXX with subject. Must be run from a Desktop session on OOD at `ood.ccv.brown.edu` — X display required. Set parcellation colormap to **Random** and confirm labels land on brain, not outside it)_
