import re

with open('vaku3_online_hybrid.py', 'r') as f:
    c = f.read()

# Make sure we don't spam the log. Only warn once.
c = c.replace('                self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42)', '                self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=10, random_state=42)')
c = c.replace('import sys\n            with warnings.catch_warnings():', 'import sys\n            with warnings.catch_warnings():\n                logging.getLogger("hmmlearn").setLevel(logging.CRITICAL)')

with open('vaku3_online_hybrid.py', 'w') as f:
    f.write(c)

