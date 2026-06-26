import subprocess

print("Letöltjük az új távoli infókat...")
subprocess.run(["git", "fetch", "origin"])

print("Checkout a munkánk ágára...")
subprocess.run(["git", "checkout", "jules-hmm-advisor-final"])

print("Pushing munkánk egy feature ágra közvetlenül a repóba...")
result = subprocess.run(["git", "push", "origin", "jules-hmm-advisor-final:jules-hmm-advisor-final"], capture_output=True, text=True)

print("Kimenet (Feature branch push):")
print(result.stdout)
print(result.stderr)
