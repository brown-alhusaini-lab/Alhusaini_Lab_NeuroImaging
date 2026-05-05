import pandas as pd
import os
import subprocess

BASEDIR = os.path.expanduser('~/data/DIPARK/procsubj/')
with open(os.path.expanduser('~/subjid.txt'), 'r') as f:
    euler_map_list = []
    for line in f:
        subjid = line.strip()
        file_ouput_issue = ''
        euler_lh_issue = ''
        euler_rh_issue = ''
        flag = ''

        euler_lh_val = None
        euler_rh_val = None

        # Check if FreeSurfer outputs exist
        files = ['mri/brain.mgz', 'mri/aseg.mgz', 'surf/lh.white', 'surf/lh.pial', 'surf/rh.white', 'surf/rh.pial']
        for file in files:
            if not(os.path.exists(f'{BASEDIR}{subjid}/{file}')):
                file_ouput_issue += f"{file} doesn't exist. "

        # Find Euler Number
        euler_lh = subprocess.run(['mris_euler_number', f'{BASEDIR}{subjid}/surf/lh.white'], capture_output=True, text=True)
        try:
            euler_lh_val = int(euler_lh.stdout.split("=")[-1].split(" ")[-1])
        except ValueError:
            euler_lh_issue += "Euler lh value doesn't exist! "

        euler_rh = subprocess.run(['mris_euler_number', f'{BASEDIR}{subjid}/surf/rh.white'], capture_output=True, text=True)
        try:
            euler_rh_val = int(euler_rh.stdout.split("=")[-1].split(" ")[-1])
        except ValueError:
            euler_rh_issue += "Euler rh value doesn't exist! "

        if euler_lh_val != None and euler_rh_val != None:
            if min(euler_lh_val, euler_rh_val) < -200:
                flag += ' Euler value too low! '

        # Build Map
        euler_map = {"subjid": subjid,
                     "euler_lh": euler_lh_val,
                     "euler_rh": euler_rh_val,
                     "flag": file_ouput_issue + euler_lh_issue + euler_rh_issue + flag}
        euler_map_list.append(euler_map)

df = pd.DataFrame(euler_map_list)
print(df.to_string())
        
