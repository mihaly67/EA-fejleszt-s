import re

def fix_mtf(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Update version
    content = content.replace('version   "1.04"', 'version   "1.05"')

    # The problem might be the `rates_5m[idx_5m + 1].time + 300 <= tick_time_sec` logic.
    # Actually, in CopyRates the most recent bar is at the end of the array (if not AS_SERIES).
    # MqlRates arrays returned by CopyRates have oldest data at index 0 and newest at index (copied - 1).
    # So idx starts at 0 (oldest).
    # A tick with time tick_time_sec should use the close of the rate bar whose time is <= tick_time_sec.
    # The while loop increments idx if the NEXT bar's time <= tick_time_sec. This is correct if we want the current bar's close.
    # BUT wait! If we want the historical close (i.e., the last COMPLETED bar), we must only shift to it when it is fully closed!
    # A 5m bar that starts at 10:00 is completed at 10:05. So at 10:05:00 tick, we can use the 10:00 bar's close.
    # So `rates[idx + 1].time + period_seconds <= tick_time_sec` is correct for NO LOOKAHEAD BIAS.
    #
    # Wait, why is the value not changing?
    # Maybe because mtf_start_date is only 2 days before InpStartDate, and the tick loop starts exactly at InpStartDate.
    # Let's check how we initialize `last_5m_close`.
    # `double last_5m_close = rates_5m[0].close;`
    # What if `rates_5m[0].time` is 2 days ago? The `while` loop MUST catch up to `InpStartDate`.
    # Let's fix the while loop to correctly catch up.
    # Ah! The `tick_time_sec` could be greater than `rates_5m[idx_5m+1].time` by a lot initially.
    # BUT wait, the MT5 server time issue?

    # Let's simplify and make it robust by making it AS_SERIES = false, which is default.
    # Let's add a sync loop at the very beginning of the tick loop, or before it.

    # Let's just write a fully safe sync logic.
    # We want the MOST RECENT CLOSED BAR.

    sync_logic_old = """      // MTF szinkronizáció
      while(idx_5m < copied_5m - 1 && rates_5m[idx_5m + 1].time + 300 <= tick_time_sec)
        {
         idx_5m++;
         last_5m_close = rates_5m[idx_5m].close;
        }
      while(idx_15m < copied_15m - 1 && rates_15m[idx_15m + 1].time + 900 <= tick_time_sec)
        {
         idx_15m++;
         last_15m_close = rates_15m[idx_15m].close;
        }
      while(idx_30m < copied_30m - 1 && rates_30m[idx_30m + 1].time + 1800 <= tick_time_sec)
        {
         idx_30m++;
         last_30m_close = rates_30m[idx_30m].close;
        }"""

    sync_logic_new = """      // MTF szinkronizáció - Szuperszigorú gyorsítótár
      // A CopyRates legrégebbi adata a 0. indexen van.
      // Amíg a következő gyertya LEZÁRULT (time + időtartam <= jelenlegi tick idő), addig lépünk előre.
      while(idx_5m < copied_5m - 1 && (rates_5m[idx_5m + 1].time + 300) <= tick_time_sec)
        {
         idx_5m++;
        }
      last_5m_close = rates_5m[idx_5m].close;

      while(idx_15m < copied_15m - 1 && (rates_15m[idx_15m + 1].time + 900) <= tick_time_sec)
        {
         idx_15m++;
        }
      last_15m_close = rates_15m[idx_15m].close;

      while(idx_30m < copied_30m - 1 && (rates_30m[idx_30m + 1].time + 1800) <= tick_time_sec)
        {
         idx_30m++;
        }
      last_30m_close = rates_30m[idx_30m].close;"""

    content = content.replace(sync_logic_old, sync_logic_new)

    with open("MQL5/Scripts/Merkava_Data_Miner_MTF_v1.05.mq5", "w") as f_out:
        f_out.write(content)

fix_mtf("MQL5/Scripts/Merkava_Data_Miner_MTF.mq5")
