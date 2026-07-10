import os
import glob
print("Keresem a csv-ket a home könyvtárban is (ha van jogosultság)...")
try:
    for root, dirs, files in os.walk('/home'):
        for file in files:
            if file.endswith('.csv') and 'DOM' in file:
                print(os.path.join(root, file))
except Exception as e:
    print(e)
