with open("vaku3_online_hybrid.py", "r") as f:
    content = f.read()

content = content.replace('self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42)', 'self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42, params="mc", init_params="smc")\n            self.hmm_model.startprob_ = np.array([1.0/3, 1.0/3, 1.0/3])\n            self.hmm_model.transmat_ = np.array([[0.8, 0.1, 0.1], [0.1, 0.8, 0.1], [0.1, 0.1, 0.8]])')

with open("vaku3_online_hybrid.py", "w") as f:
    f.write(content)
