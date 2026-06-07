import re

with open("vaku3_online_hybrid.py", "r") as f:
    content = f.read()

# Make sure we re-instantiate HMM on every window to avoid transmat explosion.
old_fit = """            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                self.hmm_model.fit(observations)"""

new_fit = """            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42)
                self.hmm_model.fit(observations)"""

content = content.replace(old_fit, new_fit)

with open("vaku3_online_hybrid.py", "w") as f:
    f.write(content)
