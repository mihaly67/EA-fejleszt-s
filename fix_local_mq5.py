import os
import re

old_file = "MQL5/Scripts/Merkava_Data_Miner_MTF_v1.05.mq5"
new_file = "MQL5/Scripts/Merkava_Data_Miner_MTF_v1.06.mq5"

with open(old_file, 'r') as f:
    content = f.read()

# Update version
content = content.replace('version   "1.05"', 'version   "1.06"')

# Insert ArraySetAsSeries to be absolutely safe
if "ArraySetAsSeries(rates_5m, false);" not in content:
    insertion = """
   ArraySetAsSeries(rates_5m, false);
   ArraySetAsSeries(rates_15m, false);
   ArraySetAsSeries(rates_30m, false);

   PrintFormat("DEBUG START: Ticks Start=%s, Rates5M Start=%s, Rates5M End=%s",
      TimeToString((datetime)(tick_array[0].time_msc/1000)),
      TimeToString(rates_5m[0].time),
      TimeToString(rates_5m[copied_5m-1].time));
"""
    anchor = """   if(total_ticks <= 0)
     {
      Print("❌ HIBA: Nem található tick adat az adott időszakra.");
      FileClose(file_handle);
      return;
     }"""
    content = content.replace(anchor, anchor + "\n" + insertion)


with open(new_file, 'w') as f:
    f.write(content)

os.remove(old_file)
