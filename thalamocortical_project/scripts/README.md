| Script | Description |
|--------|-------------|
| `0_freesurfer_refine.sh` | Optional FreeSurfer refinement using control points |
| `1_lausanne.sh` | Lausanne cortical parcellation |
| `2_thomas.sh` | THOMAS thalamic segmentation |
| `3_combine_parcellation.sh` | Combines Lausanne + THOMAS into final parcellation |
| `4_connectome.sh` | Builds SIFT2 and FA connectomes |
| `5_qc_connectome.py` | QC checks on all 9 connectome outputs |
| `fix_fa_nan.py` | Replaces NaN values in FA streamline file |
| `dwi_preproc.sh` | dMRI preprocessing |
| `dwi_tract.sh` | Tractography + SIFT2 weighting |
