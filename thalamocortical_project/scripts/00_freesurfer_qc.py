import pandas as pd
import os
import subprocess
import statistics

BASEDIR = '/oscar/data/salhusai/DIPARK/procsubj/'
PROJECTDIR = '/oscar/data/salhusai/DIPARK/'

c_list = []
pd_list = []
et_list = []
dip_list = []

# Create lists of each cohort
def rih_getter(subjid : str):
    if "RIH" in subjid:
        subjid = subjid.split("/")[0]   
    return subjid

def df_tracker_helper(subjid : str):
    if "DIP" in subjid:
        subjid = rih_getter(subjid)
        dip_list.append("sub-" + subjid.lower())
    elif "ET" in subjid:
        subjid = rih_getter(subjid)
        et_list.append("sub-" + subjid.lower())
    elif "PD" in subjid:
        subjid = rih_getter(subjid)
        pd_list.append("sub-" + subjid.lower())
    elif "C" in subjid:
        subjid = rih_getter(subjid)
        c_list.append("sub-" + subjid.lower())


df_tracker = pd.read_csv(f'{PROJECTDIR}processing_tracker.csv')
for index, row in df_tracker.iterrows():
    if row['FreeSurfer recon'] == 'Completed':
        df_tracker_helper(row['Subject ID'])


# Calculate Sample Mean and Standard Deviation for MeanThickness and BrainSeg for each cohort
# First grab all MeanThickness and BrainSeg for each patient and group values by cohort
c_thickness_vals = []
c_brainseg_vals = []
for sub in c_list:
    if os.path.exists(f'{BASEDIR}{sub}/stats/lh.aparc.stats'):
        with open(f'{BASEDIR}{sub}/stats/lh.aparc.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "MeanThickness" in line:
                    thickness = line.split(",")[3].strip()
                    c_thickness_vals.append(float(thickness))
                    break
    if os.path.exists(f'{BASEDIR}{sub}/stats/aseg.stats'):
        with open(f'{BASEDIR}{sub}/stats/aseg.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "BrainSegVol" in line:
                    volume = line.split(",")[3].strip()
                    c_brainseg_vals.append(float(volume))
                    break


pd_thickness_vals = []
pd_brainseg_vals = []
for sub in pd_list:
    if os.path.exists(f'{BASEDIR}{sub}/stats/lh.aparc.stats'):
        with open(f'{BASEDIR}{sub}/stats/lh.aparc.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "MeanThickness" in line:
                    thickness = line.split(",")[3].strip()
                    pd_thickness_vals.append(float(thickness))
                    break
    if os.path.exists(f'{BASEDIR}{sub}/stats/aseg.stats'):
        with open(f'{BASEDIR}{sub}/stats/aseg.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "BrainSegVol" in line:
                    volume = line.split(",")[3].strip()
                    pd_brainseg_vals.append(float(volume))
                    break

et_thickness_vals = []
et_brainseg_vals = []
for sub in et_list:
    if os.path.exists(f'{BASEDIR}{sub}/stats/lh.aparc.stats'):
        with open(f'{BASEDIR}{sub}/stats/lh.aparc.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "MeanThickness" in line:
                    thickness = line.split(",")[3].strip()
                    et_thickness_vals.append(float(thickness))
                    break
    if os.path.exists(f'{BASEDIR}{sub}/stats/aseg.stats'):
        with open(f'{BASEDIR}{sub}/stats/aseg.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "BrainSegVol" in line:
                    volume = line.split(",")[3].strip()
                    et_brainseg_vals.append(float(volume))
                    break

dip_thickness_vals = []
dip_brainseg_vals = []
for sub in dip_list:
    if os.path.exists(f'{BASEDIR}{sub}/stats/lh.aparc.stats'):
        with open(f'{BASEDIR}{sub}/stats/lh.aparc.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "MeanThickness" in line:
                    thickness = line.split(",")[3].strip()
                    dip_thickness_vals.append(float(thickness))
                    break
    if os.path.exists(f'{BASEDIR}{sub}/stats/aseg.stats'):
        with open(f'{BASEDIR}{sub}/stats/aseg.stats', 'r') as f:
            for line in f:
                line = line.strip()
                if "BrainSegVol" in line:
                    volume = line.split(",")[3].strip()
                    dip_brainseg_vals.append(float(volume))
                    break

# Calculate values
cohort_stats = {
    'c': {
        'mean_thickness': statistics.mean(c_thickness_vals),
        'std_thickness': statistics.stdev(c_thickness_vals),
        'mean_brainseg': statistics.mean(c_brainseg_vals),
        'std_brainseg': statistics.stdev(c_brainseg_vals)
},
    'pd': {
        'mean_thickness': statistics.mean(pd_thickness_vals),
        'std_thickness': statistics.stdev(pd_thickness_vals),
        'mean_brainseg': statistics.mean(pd_brainseg_vals),
        'std_brainseg': statistics.stdev(pd_brainseg_vals)
},
    'et': {
        'mean_thickness': statistics.mean(et_thickness_vals),
        'std_thickness': statistics.stdev(et_thickness_vals),
        'mean_brainseg': statistics.mean(et_brainseg_vals),
        'std_brainseg': statistics.stdev(et_brainseg_vals)
},
    'dip': {
        'mean_thickness': statistics.mean(dip_thickness_vals),
        'std_thickness': statistics.stdev(dip_thickness_vals),
        'mean_brainseg': statistics.mean(dip_brainseg_vals),
        'std_brainseg': statistics.stdev(dip_brainseg_vals)
}
}

def sub_cohort_finder(subjid: str) -> str:
    if subjid in c_list:
        return 'c'
    elif subjid in pd_list:
        return 'pd'
    elif subjid in et_list:
        return 'et'
    elif subjid in dip_list:
        return 'dip'
    
    
# Create QC table for all patients
with open(os.path.expanduser('~/subjid.txt'), 'r') as f:
    qc_map_list = []
    for line in f:
        subjid = line.strip()
        file_output_ok = True
        missing_files = []
        euler_lh_ok = True
        euler_rh_ok = True

        euler_lh_val = None
        euler_rh_val = None

        cohort = sub_cohort_finder(subjid)

        # Check if FreeSurfer outputs exist
        files = ['mri/brain.mgz', 'mri/aseg.mgz', 'surf/lh.white', 'surf/lh.pial', 'surf/rh.white', 'surf/rh.pial']
        for file in files:
            if not(os.path.exists(f'{BASEDIR}{subjid}/{file}')):
                file_output_ok = False
                missing_files.append(file)

        # Find Euler Number
        euler_lh = subprocess.run(['mris_euler_number', f'{BASEDIR}{subjid}/surf/lh.white'], capture_output=True, text=True)
        try:
            euler_lh_val = int(euler_lh.stdout.split("=")[-1].split(" ")[-1])
        except ValueError:
            euler_lh_ok = False

        euler_rh = subprocess.run(['mris_euler_number', f'{BASEDIR}{subjid}/surf/rh.white'], capture_output=True, text=True)
        try:
            euler_rh_val = int(euler_rh.stdout.split("=")[-1].split(" ")[-1])
        except ValueError:
            euler_rh_ok = False

        euler_val_ok = True
        if euler_lh_val != None and euler_rh_val != None:
            if min(euler_lh_val, euler_rh_val) < -200:
                euler_val_ok = False
        
        # Find Mean Thickness
        if cohort == None:
            mean_thickness_ok = None
            brainseg_vol_ok = None
        else:
            if os.path.exists(f'{BASEDIR}{subjid}/stats/lh.aparc.stats'):
                with open(f'{BASEDIR}{subjid}/stats/lh.aparc.stats', 'r') as f_stats:
                    for line in f_stats:
                        line = line.strip()
                        if "MeanThickness" in line:
                            subj_mean_thickness = line.split(",")[3].strip()
                            break

                mean_thickness_ok = abs((float(subj_mean_thickness) - cohort_stats[cohort]['mean_thickness']) / cohort_stats[cohort]['std_thickness']) < 2
            else:
                mean_thickness_ok = None

            # Find Brainseg Volume
            if os.path.exists(f'{BASEDIR}{subjid}/stats/aseg.stats'):
                with open(f'{BASEDIR}{subjid}/stats/aseg.stats', 'r') as f_stats:
                    for line in f_stats:
                        line = line.strip()
                        if "BrainSegVol" in line:
                            subj_brainseg_volume = line.split(",")[3].strip()
                            break

                brainseg_vol_ok = abs((float(subj_brainseg_volume) - cohort_stats[cohort]['mean_brainseg']) / cohort_stats[cohort]['std_brainseg']) < 2
            else:
                brainseg_vol_ok = None
        
        # Build Map
        qc_map = {"subjid": subjid,
                     "euler_lh": euler_lh_val,
                     "euler_rh": euler_rh_val,
                     "file_output_ok": file_output_ok,
                     "missing_files": missing_files,
                     "euler_lh_ok": euler_lh_ok,
                     "euler_rh_ok": euler_rh_ok,
                     "euler_val_ok": euler_val_ok,
                     "mean_thickness_ok": mean_thickness_ok,
                     "brainseg_vol_ok": brainseg_vol_ok
                     }
        qc_map_list.append(qc_map)

df = pd.DataFrame(qc_map_list)
print(df.to_string())