import numpy as np
import pandas as pd

nucleus_map = {"AV-L" : 115,
                    "AV-R" : 129,
                    "VA-L" : 116,
                    "VA-R" : 130,
                    "VLa-L" : 117,
                    "VLa-R" : 131,
                    "VLP-L" : 118,
                    "VLP-R" : 132,
                    "VPL-L" : 119,
                    "VPL-R" : 133,
                    "Pul-L" : 120,
                    "Pul-R" : 134,
                    "CM-L" : 121,
                    "CM-R" : 135,
                    "MD-Pf-L" : 122,
                    "MD-Pf-R" : 136}

with open(f'/oscar/data/salhusai/DIPARK/subjid.txt', 'r') as f:
    strength_map_list = []
    for line in f:
        subjid = line.strip()
        base = f'/oscar/data/salhusai/DIPARK/thalamo_project/subjects/{subjid}/thomas/{subjid}_scale-2_connectome_sift2.csv'
        csv_txt = np.loadtxt(base, delimiter=",")
        subj_dict = {"subjid": f"{subjid}"}
        nucleus_strength_map = {name: np.sum(csv_txt[label - 1, :]) for name, label in nucleus_map.items()}
        final_dict = subj_dict | nucleus_strength_map
        strength_map_list.append(final_dict)

df = pd.DataFrame(strength_map_list)
df.to_csv("nucleus_strength.csv", index=False)

