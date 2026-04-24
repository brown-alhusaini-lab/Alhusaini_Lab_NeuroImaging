import numpy as np
import sys
import os

# Usage: python3 5_qc_connectome.py <subject_id>
subjid = sys.argv[1]
base = f'/oscar/data/salhusai/DIPARK/thalamo_project/subjects/{subjid}/thomas'

connectome_types = ['sift2', 'sift2_scaled', 'fa']
n_thal = 16  # 8 bilateral THOMAS nuclei across all scales

overall_pass = True

for scale in [1, 2, 3]:
    print(f'\n{"="*40}')
    print(f'Scale {scale}')
    print(f'{"="*40}')

    for ctype in connectome_types:
        path = f'{base}/{subjid}_scale-{scale}_connectome_{ctype}.csv'
        print(f'\n  [{ctype}]')

        # Check file exists
        if not os.path.exists(path):
            print(f'    FAIL — file not found')
            overall_pass = False
            continue

        # Check file is not empty
        if os.path.getsize(path) == 0:
            print(f'    FAIL — file is empty')
            overall_pass = False
            continue

        m = np.loadtxt(path, delimiter=',')
        thal = m[-n_thal:, :]

        # Run checks
        checks = {
            'Shape correct':        m.shape[0] == m.shape[1],
            'Symmetric':            np.allclose(m, m.T),
            'Has non-zero entries': np.count_nonzero(m) > 0,
            'No NaN values':        not np.isnan(m).any(),
            'No negative values':   (m >= 0).all(),
            'Thalamic nodes connected': np.count_nonzero(thal) > 0,
        }

        for check, result in checks.items():
            status = 'PASS' if result else 'FAIL'
            if not result:
                overall_pass = False
            print(f'    {status} — {check}')

        # Summary stats
        print(f'    ---- stats ----')
        print(f'    Shape:             {m.shape}')
        print(f'    Non-zero entries:  {np.count_nonzero(m)}')
        print(f'    Max value:         {m.max():.2f}')
        print(f'    Min non-zero:      {m[m > 0].min():.4f}')
        print(f'    Thalamic non-zero: {np.count_nonzero(thal)}')
        print(f'    Thalamic max:      {thal.max():.2f}')

print(f'\n{"="*40}')
print(f'Overall: {"PASS" if overall_pass else "FAIL — check above"}')
print(f'{"="*40}\n')
