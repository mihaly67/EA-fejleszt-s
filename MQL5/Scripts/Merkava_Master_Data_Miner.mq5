//+------------------------------------------------------------------+
//|                                Merkava_Master_Data_Miner.mq5     |
//|                                                                  |
//| Purpose: Extracts pure, deep M1 OHLCV historical data.           |
//|          This is the definitive base layer. All indicators       |
//|          (AMA, Stochastic, Pivots) are calculated dynamically in |
//|          the Python pipeline.                                    |
//+------------------------------------------------------------------+
#property copyright "Jules Agent"
#property version   "4.00"
#property script_show_inputs

input int InpLookbackDays = 180;  // Data history length in days (Default: 6 Months)

void OnStart()
  {
   Print("🚀 Starting Merkava Master M1 Data Miner...");
   string symbol = Symbol();

   // 1. Prepare Data Arrays
   MqlRates rates_m1[];
   ArraySetAsSeries(rates_m1, true);

   datetime endTime = TimeCurrent();
   datetime startTime = endTime - (InpLookbackDays * 24 * 60 * 60);

   int copied = CopyRates(symbol, PERIOD_M1, startTime, endTime, rates_m1);
   if(copied <= 0)
     {
      Print("❌ Error copying M1 rates. Ensure your MT5 has sufficient history downloaded.");
      return;
     }

   // 2. Open File
   string filename = "Master_Raw_" + symbol + "_M1.csv";
   int file_handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
   if(file_handle == INVALID_HANDLE)
     {
      Print("❌ Error opening file for writing.");
      return;
     }

   // Write Header
   FileWrite(file_handle, "Time", "Open", "High", "Low", "Close", "TickVolume", "RealVolume", "Spread");

   // 3. Iterate and Extract (Iterate backwards to save oldest first for ML chronological logic)
   Print("⏳ Extracting ", copied, " raw M1 bars. This may take a moment...");

   for(int i = copied - 1; i >= 0; i--)
     {
      datetime bar_time = rates_m1[i].time;

      FileWrite(file_handle,
                TimeToString(bar_time, TIME_DATE|TIME_SECONDS),
                DoubleToString(rates_m1[i].open, _Digits),
                DoubleToString(rates_m1[i].high, _Digits),
                DoubleToString(rates_m1[i].low, _Digits),
                DoubleToString(rates_m1[i].close, _Digits),
                IntegerToString(rates_m1[i].tick_volume),
                DoubleToString(rates_m1[i].real_volume, 0),
                IntegerToString(rates_m1[i].spread)
                );
     }

   FileClose(file_handle);
   Print("✅ Master Export Complete. Saved to MQL5/Files/", filename);
  }
//+------------------------------------------------------------------+
