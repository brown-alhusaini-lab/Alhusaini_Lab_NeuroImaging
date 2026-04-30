import numpy as np
import sys

subjid = sys.argv[1]
base = f'/oscar/data/salhusai/DIPARK/thalamo_project/subjects/{subjid}/thomas/{subjid}_scale-2_connectome_sift2.csv'

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

csv_txt = np.loadtxt(base, delimiter=",")

nucleus_strength_map = {name: np.sum(csv_txt[label - 1, :]) for name, label in nucleus_map.items()}
print(nucleus_strength_map)