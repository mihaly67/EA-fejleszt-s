with open("vaku3_online_hybrid.py", "r") as f:
    content = f.read()

content = content.replace('import warnings', 'import warnings\n            from hmmlearn.hmm import GaussianHMM\n            self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42)')
with open("vaku3_online_hybrid.py", "w") as f:
    f.write(content)
