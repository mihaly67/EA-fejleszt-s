import re

def fix_mq5(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Check if we need to add a history loader
    if "CheckLoadHistory" not in content:
        history_loader = """
//+------------------------------------------------------------------+
//| Biztonságos adatletöltő (History loader)                         |
//+------------------------------------------------------------------+
bool ForceLoadHistory(string symbol, ENUM_TIMEFRAMES period, datetime start_date, datetime end_date)
  {
   Print("Adat letöltés ellenőrzése: ", EnumToString(period));

   // Kényszerítsük ki a frissítést
   datetime current_time = TimeCurrent();
   int max_wait = 100;

   while(!SeriesInfoInteger(symbol, period, SERIES_SYNCHRONIZED) && max_wait > 0 && !IsStopped())
     {
      Sleep(100);
      max_wait--;
     }

   MqlRates temp[];
   int copied = CopyRates(symbol, period, start_date, end_date, temp);

   max_wait = 50;
   while(copied <= 0 && max_wait > 0 && !IsStopped())
     {
      Sleep(200);
      copied = CopyRates(symbol, period, start_date, end_date, temp);
      max_wait--;
     }

   if(copied > 0)
     {
      Print(EnumToString(period), " letöltve, sorok száma: ", copied);
      return true;
     }

   Print("❌ Sikertelen adatletöltés: ", EnumToString(period));
   return false;
  }
"""
        # Insert before OnStart
        content = content.replace("void OnStart()", history_loader + "\nvoid OnStart()")

    # Replace CopyRates directly with ForceLoadHistory check if needed, or just add prints
    # Let's also fix the lookahead bias while we are at it.
    # The bar closes at `time + PeriodSeconds(period)`. We should only increment when tick_time_sec >= close_time.

    content = content.replace("rates_5m[idx_5m + 1].time <= tick_time_sec", "rates_5m[idx_5m + 1].time + 300 <= tick_time_sec")
    content = content.replace("rates_15m[idx_15m + 1].time <= tick_time_sec", "rates_15m[idx_15m + 1].time + 900 <= tick_time_sec")
    content = content.replace("rates_30m[idx_30m + 1].time <= tick_time_sec", "rates_30m[idx_30m + 1].time + 1800 <= tick_time_sec")

    # Also we should print the copied sizes to the terminal to debug.
    print_statement = """
   PrintFormat("✅ Letöltött adatok: M5=%d, M15=%d, M30=%d, Ticks=%d", copied_5m, copied_15m, copied_30m, total_ticks);
   if(copied_5m < 100) Print("⚠️ FIGYELEM: Nagyon kevés M5 adat van! Lehet, hogy nem töltött be a history.");
"""
    if "✅ Letöltött adatok" not in content:
        content = content.replace("if(copied_5m <= 0 || copied_15m <= 0 || copied_30m <= 0)", print_statement + "\n   if(copied_5m <= 0 || copied_15m <= 0 || copied_30m <= 0)")

    with open(filepath, 'w') as f:
        f.write(content)

fix_mq5('MQL5/Scripts/Merkava_Data_Miner_MTF.mq5')
