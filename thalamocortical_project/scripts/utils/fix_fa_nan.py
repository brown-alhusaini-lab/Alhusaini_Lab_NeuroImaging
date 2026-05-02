import numpy as np
import sys

path = sys.argv[1]
d = np.genfromtxt(path, delimiter=',')
d = np.nan_to_num(d, nan=0.0)
np.savetxt(path, d, delimiter=',')
print(f"Fixed NaNs in {path}")
