import urllib.request

url = "https://raw.githubusercontent.com/mihaly67/EA-fejleszt-s/main/MQL5/Experts/Merkava_Behavioral_Profiler_v1.4_Online.mq5"
urllib.request.urlretrieve(url, "Merkava_Behavioral_Profiler_v1.5_Online.mq5")
print("✅ Sikeresen lementve a jelenlegi mappába: Merkava_Behavioral_Profiler_v1.5_Online.mq5")
