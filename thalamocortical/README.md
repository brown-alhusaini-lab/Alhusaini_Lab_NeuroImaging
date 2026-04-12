# Thalamocortical Structural Connectivity Pipeline

Pipeline for investigating structural connectivity between thalamic nuclei and cortical regions using diffusion MRI, applied to the DIPARK Parkinson's disease dataset at Brown University.

Adapted from [Piper et al. (2026)](https://doi.org/10.1002/epi.70099) — originally developed for pediatric focal epilepsy.

---

## Pipeline Overview

Two parallel streams merge at connectome construction:
T1 MRI → FreeSurfer → Lausanne → THOMAS → Final Parcellation (Nodes)
↘
Connectome → Statistics
↗
dMRI → Preprocessing → FOD Estimation → Tractography → SIFT2 (Edges)
---

## Documents

| File | Description |
|------|-------------|
| `pipeline.md` | Full T1 stream pipeline (FreeSurfer → Lausanne → THOMAS → Combine) |
| `dmri.md` | dMRI stream pipeline (Preprocessing → Tractography → Connectome) |
| `statistical_analysis.md` | Statistical analysis (Node strength → GLM → Z-scoring → Group comparison) |

---

## Dependencies

- [Piper et al. (2026) — original pipeline paper](https://doi.org/10.1002/epi.70099)
- [Piper et al. GitHub repo](https://github.com/roryjpiper/thalamus_dMRI_epilepsy)
- [Brain Connectivity Toolbox](https://sites.google.com/site/bctnet)
- [Simple Brain Plot](https://github.com/dutchconnectomelab/Simple-Brain-Plot)
- [THOMAS thalamic segmentation](https://github.com/thalamicseg/hipsthomasdocker)
- [MRtrix3](https://www.mrtrix.org/)

---

## Contact

Ayman Zeanalabdeen — ayman_zeanalabdeen@brown.edu
