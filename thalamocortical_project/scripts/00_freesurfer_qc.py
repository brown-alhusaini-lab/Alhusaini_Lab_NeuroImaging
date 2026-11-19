import pandas as pd
import os

BASEDIR = '/oscar/data/salhusai/DIPARK/procsubj/'
PROJECTDIR = '/oscar/data/salhusai/DIPARK/'
    
# Create QC table for all patients
with open(os.path.expanduser('~/subjid.txt'), 'r') as f:
    qc_map_list = []
    for line in f:
        subjid = line.strip()
        recon_done_ok = True
        no_error_file = False

        # Check if recon-all.done exists and recon-all.error doesn't
        if not(os.path.exists(f'{BASEDIR}{subjid}/scripts/recon-all.done')):
            recon_done_ok = False

        if not(os.path.exists(f'{BASEDIR}{subjid}/scripts/recon-all.error')):
            no_error_file = True
            
        # Build Map
        qc_map = {"subjid": subjid,
            "recon_done_ok": recon_done_ok,
            "no_error_file": no_error_file,
            }
        qc_map_list.append(qc_map)

df = pd.DataFrame(qc_map_list)

df_flagged = df[df[["recon_done_ok", "no_error_file"]].isin([False]).any(axis=1)]

# Make flagged_subjects.txt
with open(f'{PROJECTDIR}thalamo_project/qc/freesurfer_qc/flagged_subjects.txt', 'w') as f:
    for sub in df_flagged['subjid']:
        f.write(sub + '\n')

# Make flagged_subjects_details.csv
df_flagged.to_csv(f'{PROJECTDIR}thalamo_project/qc/freesurfer_qc/flagged_subjects_details.csv', index=False)

# Print table
print(df.to_string())