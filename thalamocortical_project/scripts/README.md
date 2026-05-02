| Script | Description |
|--------|-------------|
| `0_freesurfer_refine.sh` | Optional FreeSurfer refinement using control points |
| `1_lausanne.sh` | Lausanne cortical parcellation |
| `2_thomas.sh` | THOMAS thalamic segmentation (`thomas_csh_big`) |
| `3_combine_parcellation.sh` | Combines Lausanne + THOMAS into final parcellation |
| `4_connectome.sh` | Builds SIFT2 and FA connectomes in T1 space (10M streamlines) |
| `5_qc_connectome.py` | QC checks on all connectome outputs |
| `6_node_strength.py` | Extracts node strength for thalamic nuclei |
| `dwi_preproc.sh` | dMRI preprocessing |
| `dwi_tract.sh` | Tractography + SIFT2 weighting |

**Utilities (`utils/`):**
| Script | Description |
|--------|-------------|
| `fix_fa_nan.py` | Replaces NaN values in FA streamline file (called by `4_connectome.sh`) |