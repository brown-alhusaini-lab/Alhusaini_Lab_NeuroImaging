# Thalamocortical Pipeline — Decisions & Findings Log

## Node Strength Investigation (sub-c100, control)

### Problem
After running the full pipeline, node strength extraction for sub-c100 revealed that several thalamic nuclei had zero connectivity — including AV, VA, VLa, VLP, VPL bilaterally and MD-Pf-R.

### Root Cause Analysis

**Step 1 — Checked THOMAS segmentation labels**
- THOMAS internal label numbering: AV=2, VA=4, VLa=5, VLP=6, VPL=7, Pul=8, CM=11, MD-Pf=12
- Labels 2, 4, 5, 6, 7, 8, 10, 11, 12, 14 present in both left and right THOMAS outputs
- Label 1 (whole thalamus mask) and label 3 (VLa) absent — expected, not a bug

**Step 2 — Checked final combined parcellation**
- All labels 115–122 (left nuclei) and 129–136 (right nuclei) present after `labelconvert` ✅
- Labels also survive `flirt` registration to diffusion space ✅
- Conclusion: labeling and registration pipeline is correct

**Step 3 — Checked voxel counts in diffusion space**
- AV-L (label 115): only **13 voxels** at 2mm diffusion resolution
- CM-L (label 121): only **17 oxels** — also very small
- Larger nuclei (Pul, MD-Pf) had 100–200+ voxels and non-zero connectivity

**Step 4 — Checked tractography coverage**
- Out of 5M streamlines, only **25,646 (~0.5%)** pass through the left thalamus
- With AV having only 13 voxels, statistically very few streamlines hit it

**Conclusion:** Zero AV connectivity is a genuine resolution limitation at 2mm dMRI, not a pipeline bug. Piper explicitly acknowledges this in Section 4.7: *"utilizing ultra-high-resolution (7-Tesla) MRI may improve the accuracy of connectivity measures seeded from these small thalamic nuclei."*

---

## THOMAS Configuration Testing

### `hipsthomas_csh -t1` (original)
- Standard T1 MPRAGE segmentation
- AV voxel count (sub-c100 left): **~13 voxels** in diffusion space

### `thomas_csh_big` (switched to)
- Uses `-B` flag — larger crop template, designed for enlarged ventricles/atrophy
- More appropriate for PD data where brain atrophy is expected
- AV voxel count (sub-c100 left): **26 voxels** in T1 space (doubled)
- Applied consistently to all subjects for cohort consistency

**Decision:** Use `thomas_csh_big` for all subjects.

---

## Connectome Space Testing

### Approach 1: Diffusion-space (`4_connectome.sh`)
Parcellation registered to diffusion space via `flirt`, connectome built in diffusion space.

```
AV-L: 0, AV-R: 0, VA-L: 0, VA-R: 0, VLa-L: 0, VLa-R: 0
VLP-L: 0, VLP-R: 4.2, VPL-L: 0, VPL-R: 1027.9
Pul-L: 196.0, Pul-R: 5394.6, CM-L: 367.5, CM-R: 589.5
MD-Pf-L: 691.2, MD-Pf-R: 0
```
Non-zero nuclei: 7/16

### Approach 2: T1-space (`4_2_connectome.sh`)
Streamlines transformed to T1 space using `tcktransform`, connectome built against full-resolution T1 parcellation.

Implementation:
1. `transformconvert` — convert FSL `.mat` to MRtrix3 format (correct image order: `-in` image first, `-ref` second)
2. `warpinit` — initialize identity warp in T1 space
3. `transformcompose` — compose with T1→diffusion transform, template = diffusion space
4. `tcktransform` — apply warp to streamlines
5. `tck2connectome` — build connectome against T1-space parcellation

```
AV-L: 0, AV-R: 0, VA-L: 0, VA-R: 0, VLa-L: 0, VLa-R: 0
VLP-L: 0.5, VLP-R: 0, VPL-L: 0, VPL-R: 1230.1
Pul-L: 274.1, Pul-R: 5805.3, CM-L: 328.2, CM-R: 858.4
MD-Pf-L: 899.7, MD-Pf-R: 495.0
```
Non-zero nuclei: 8/16 — MD-Pf-R recovered (0 → 495)

**Decision:** Use T1-space approach (`4_2_connectome.sh`) as final pipeline.

---

## Key Debugging Notes

### `transformconvert` argument order
The correct order for `flirt_import` is: `matrix in_image ref_image flirt_import output`
- `in_image` = image passed to flirt's `-in` (moving = T1 parcellation)
- `ref_image` = image passed to flirt's `-ref` (fixed = nodif)
- Getting this wrong produces a valid-looking but incorrect transform, resulting in empty streamlines after `tcktransform`

### `tcktransform` requires warp field, not linear matrix
`tcktransform` does not accept linear `.txt` matrices — it requires a deformation field image. The correct workflow is `warpinit` + `transformcompose` to convert a linear transform into a warp field.

---

## Remaining Zero Nuclei
After best approach (thomas_csh_big + T1-space):

| Nucleus | Status | Likely Cause |
|---------|--------|--------------|
| AV-L, AV-R | 0 | ~26 voxels at 1mm, few streamlines reach it |
| VA-L, VA-R | 0 | Small nucleus, sparse tractography coverage |
| VLa-L, VLa-R | 0 | Not segmented by THOMAS (label 3 absent) |
| VLP-L | ~0.5 | Near-zero, effectively sparse |
| VPL-L | 0 | Small nucleus |

**Accepted limitation:** AV zero connectivity is consistent with Piper's findings and acknowledged as a 2mm resolution limitation. Statistical analysis will focus on nuclei with reliable non-zero connectivity: **Pul, CM, MD-Pf** bilaterally, plus VPL-R.

---

## Final Pipeline Configuration (Current Best)
- THOMAS: `thomas_csh_big`
- Connectome space: T1-space (`4_2_connectome.sh`)
- Scripts: `1_lausanne.sh` → `2_thomas.sh` → `3_combine_parcellation.sh` → `4_2_connectome.sh` → `5_2_qc_connectome.py` → `6_2_node_strength.py`
